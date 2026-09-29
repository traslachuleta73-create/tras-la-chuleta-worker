-- Run only against staging; all fixture data is rolled back.
BEGIN;
DO $setup$
DECLARE v_business uuid; v_mesa uuid; v_bar uuid; v_mesa_consumption uuid; v_bar_consumption uuid;
  v_bar_user uuid; v_waiter uuid; v_cashier uuid;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_bar_user FROM public.profiles WHERE business_id=v_business AND role_code='BARRA';
  SELECT id INTO STRICT v_waiter FROM public.profiles WHERE business_id=v_business AND role_code='MESERO';
  SELECT id INTO STRICT v_cashier FROM public.profiles WHERE business_id=v_business AND role_code='CAJA';
  INSERT INTO public.service_modes(business_id,code,name)
    VALUES(v_business,'MESA','Mesa prueba') RETURNING id INTO v_mesa;
  INSERT INTO public.service_modes(business_id,code,name)
    VALUES(v_business,'BARRA','Barra prueba') RETURNING id INTO v_bar;
  INSERT INTO public.consumptions(business_id,service_mode_id,status)
    VALUES(v_business,v_mesa,'OPEN') RETURNING id INTO v_mesa_consumption;
  INSERT INTO public.consumptions(business_id,service_mode_id,status)
    VALUES(v_business,v_bar,'OPEN') RETURNING id INTO v_bar_consumption;
  PERFORM set_config('test.business',v_business::text,true);
  PERFORM set_config('test.mesa_consumption',v_mesa_consumption::text,true);
  PERFORM set_config('test.bar_consumption',v_bar_consumption::text,true);
  PERFORM set_config('test.bar_user',v_bar_user::text,true);
  PERFORM set_config('test.waiter',v_waiter::text,true);
  PERFORM set_config('test.cashier',v_cashier::text,true);
END;
$setup$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE v_business uuid:=current_setting('test.business')::uuid;
  v_mesa uuid:=current_setting('test.mesa_consumption')::uuid;
  v_bar uuid:=current_setting('test.bar_consumption')::uuid;
  v_bar_user uuid:=current_setting('test.bar_user')::uuid;
  v_waiter uuid:=current_setting('test.waiter')::uuid;
  v_cashier uuid:=current_setting('test.cashier')::uuid; v_order public.orders;
  v_product uuid; v_station uuid; v_channel text;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  SELECT channel_code INTO STRICT v_channel FROM public.business_channels WHERE business_id=v_business AND is_enabled LIMIT 1;
  SELECT p.id,ps.station_id INTO STRICT v_product,v_station FROM public.products p
    JOIN public.product_stations ps ON ps.product_id=p.id JOIN public.stations s ON s.id=ps.station_id
    WHERE p.business_id=v_business AND s.station_type='BARRA' AND p.is_active AND p.is_available LIMIT 1;

  PERFORM set_config('request.jwt.claim.sub',v_bar_user::text,true);
  IF (SELECT count(*) FROM public.consumptions WHERE id IN (v_mesa,v_bar)) <> 1
      OR NOT EXISTS(SELECT 1 FROM public.consumptions WHERE id=v_bar) THEN
    RAISE EXCEPTION 'FAIL_BAR_CONSUMPTION_VISIBILITY';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.products WHERE id=v_product)
      OR NOT EXISTS(SELECT 1 FROM public.product_stations WHERE product_id=v_product AND station_id=v_station) THEN
    RAISE EXCEPTION 'FAIL_BAR_CATALOG_VISIBILITY';
  END IF;
  BEGIN
    PERFORM public.open_consumption(NULL,(SELECT service_mode_id FROM public.consumptions WHERE id=v_bar));
    RAISE EXCEPTION 'FAIL_BAR_OPENED_CONSUMPTION';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.create_order(v_mesa,v_channel,NULL);
    RAISE EXCEPTION 'FAIL_BAR_CREATED_MESA_ORDER';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'SERVICE_MODE_NOT_ALLOWED' THEN RAISE; END IF;
  END;
  v_order:=public.create_order(v_bar,v_channel,NULL);
  PERFORM public.add_order_item(v_order.id,v_product,v_station,1,NULL);
  IF v_order.status<>'NEW' THEN RAISE EXCEPTION 'FAIL_BAR_ORDER_NOT_NEW'; END IF;
  BEGIN
    PERFORM public.validate_order(v_order.id);
    RAISE EXCEPTION 'FAIL_BAR_VALIDATED_ORDER';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub',v_waiter::text,true);
  IF EXISTS(SELECT 1 FROM public.consumptions WHERE id=v_bar) OR NOT EXISTS(SELECT 1 FROM public.consumptions WHERE id=v_mesa) THEN
    RAISE EXCEPTION 'FAIL_WAITER_CONSUMPTION_VISIBILITY';
  END IF;
  BEGIN
    PERFORM public.create_order(v_bar,v_channel,NULL);
    RAISE EXCEPTION 'FAIL_WAITER_CREATED_BAR_ORDER';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'SERVICE_MODE_NOT_ALLOWED' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  IF (SELECT count(*) FROM public.consumptions WHERE id IN (v_mesa,v_bar))<>2 THEN
    RAISE EXCEPTION 'FAIL_CASHIER_CONSUMPTION_VISIBILITY';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.products WHERE id=v_product) THEN RAISE EXCEPTION 'FAIL_CASHIER_CATALOG_VISIBILITY'; END IF;
  PERFORM public.validate_order(v_order.id);
  IF (SELECT status FROM public.orders WHERE id=v_order.id)<>'RECEIVED' THEN RAISE EXCEPTION 'FAIL_CASHIER_VALIDATION'; END IF;
  RAISE NOTICE 'PASS: bar creates in bar only; catalog and modality visibility; Caja validates';
END;
$test$;
ROLLBACK;
