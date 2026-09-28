-- Ejecutar solo en staging. El rollback elimina los datos de prueba.
BEGIN;
DO $test$
DECLARE
  v_business uuid;
  v_cashier uuid;
  v_waiter uuid;
  v_admin uuid;
  v_mode_mesa uuid;
  v_mode_barra uuid;
  v_table public.consumptions;
  v_bar public.consumptions;
  v_table_order public.orders;
  v_bar_order public.orders;
  v_payment public.payments;
  v_product uuid;
  v_station uuid;
  v_price numeric;
  v_channel text;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_cashier FROM public.profiles WHERE business_id=v_business AND role_code='CAJA';
  SELECT id INTO STRICT v_waiter FROM public.profiles WHERE business_id=v_business AND role_code='MESERO';
  SELECT id INTO STRICT v_admin FROM public.profiles WHERE business_id=v_business AND role_code='ADMIN';
  SELECT id, price INTO STRICT v_product, v_price FROM public.products WHERE business_id=v_business AND price>0 LIMIT 1;
  SELECT id INTO STRICT v_station FROM public.stations WHERE business_id=v_business LIMIT 1;
  SELECT channel_code INTO STRICT v_channel FROM public.business_channels WHERE business_id=v_business AND is_enabled LIMIT 1;
  PERFORM set_config('request.jwt.claim.sub',v_waiter::text,true);
  BEGIN
    PERFORM public.open_consumption(NULL,NULL);
    RAISE EXCEPTION 'FAIL_MESERO_OPENED_CONSUMPTION';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  BEGIN
    PERFORM public.open_consumption(NULL,NULL);
    RAISE EXCEPTION 'FAIL_CONSUMPTION_WITHOUT_MODE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'SERVICE_MODE_NOT_AVAILABLE' THEN RAISE; END IF;
  END;
  INSERT INTO public.service_modes(business_id,code,name) VALUES(v_business,'MESA','Mesa prueba') RETURNING id INTO v_mode_mesa;
  INSERT INTO public.service_modes(business_id,code,name) VALUES(v_business,'BARRA','Barra prueba') RETURNING id INTO v_mode_barra;
  INSERT INTO public.consumptions(business_id,status,service_mode_id)
    VALUES(v_business,'OPEN',v_mode_mesa) RETURNING * INTO v_table;
  INSERT INTO public.consumptions(business_id,status,service_mode_id)
    VALUES(v_business,'OPEN',v_mode_barra) RETURNING * INTO v_bar;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status,ready_at)
    VALUES(v_business,v_table.id,v_channel,'READY',now()) RETURNING * INTO v_table_order;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status,ready_at)
    VALUES(v_business,v_bar.id,v_channel,'READY',now()) RETURNING * INTO v_bar_order;
  INSERT INTO public.order_items(order_id,product_id,station_id,quantity,unit_price,ready_at)
    VALUES(v_table_order.id,v_product,v_station,1,v_price,now()),
          (v_bar_order.id,v_product,v_station,1,v_price,now());

  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  BEGIN
    PERFORM public.deliver_order(v_table_order.id);
    RAISE EXCEPTION 'FAIL_CAJA_DELIVERED_MESA';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;
  v_payment := public.create_payment(v_table.id,'CASH',v_price,NULL);
  BEGIN
    PERFORM public.confirm_payment(v_payment.id);
    RAISE EXCEPTION 'FAIL_PAYMENT_BEFORE_DELIVERY';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ORDERS_NOT_DELIVERED' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub',v_waiter::text,true);
  BEGIN
    PERFORM public.deliver_order(v_bar_order.id);
    RAISE EXCEPTION 'FAIL_MESERO_DELIVERED_BARRA';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;
  PERFORM public.deliver_order(v_table_order.id);

  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);
  BEGIN
    PERFORM public.confirm_payment(v_payment.id);
    RAISE EXCEPTION 'FAIL_ADMIN_CONFIRMED_PAYMENT';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.deliver_order(v_bar_order.id);
  PERFORM public.confirm_payment(v_payment.id);
  IF (SELECT status FROM public.consumptions WHERE id=v_table.id) <> 'CLOSED' THEN
    RAISE EXCEPTION 'FAIL_CONSUMPTION_NOT_CLOSED';
  END IF;
  BEGIN
    PERFORM public.create_order(v_table.id,v_channel,NULL);
    RAISE EXCEPTION 'FAIL_NEW_ORDER_ON_CLOSED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'CONSUMPTION_NOT_OPEN' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS: entrega por modalidad, bloqueo cobro prematuro, rol Caja, cierre automático, consumo cerrado';
END;
$test$;
ROLLBACK;
