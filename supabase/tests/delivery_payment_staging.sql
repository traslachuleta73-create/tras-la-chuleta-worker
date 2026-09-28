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
  v_admin_consumption public.consumptions;
  v_table_order public.orders;
  v_bar_order public.orders;
  v_unvalidated public.orders;
  v_admin_order public.orders;
  v_payment public.payments;
  v_cut public.cuts;
  v_product uuid;
  v_station uuid;
  v_station_role text;
  v_station_user uuid;
  v_price numeric;
  v_channel text;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_cashier FROM public.profiles WHERE business_id=v_business AND role_code='CAJA';
  SELECT id INTO STRICT v_waiter FROM public.profiles WHERE business_id=v_business AND role_code='MESERO';
  SELECT id INTO STRICT v_admin FROM public.profiles WHERE business_id=v_business AND role_code='ADMIN';
  SELECT id,station_type INTO STRICT v_station,v_station_role FROM public.stations WHERE business_id=v_business AND station_type='COCINA' LIMIT 1;
  SELECT p.id,p.price INTO STRICT v_product,v_price FROM public.products p
    JOIN public.product_stations ps ON ps.product_id=p.id AND ps.station_id=v_station
    WHERE p.business_id=v_business AND p.price>0 LIMIT 1;
  SELECT id INTO STRICT v_station_user FROM public.profiles
   WHERE business_id=v_business AND role_code=v_station_role;
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
  INSERT INTO public.consumptions(business_id,status,service_mode_id)
    VALUES(v_business,'OPEN',v_mode_mesa) RETURNING * INTO v_admin_consumption;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status,ready_at)
    VALUES(v_business,v_table.id,v_channel,'READY',now()) RETURNING * INTO v_table_order;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status,ready_at)
    VALUES(v_business,v_bar.id,v_channel,'READY',now()) RETURNING * INTO v_bar_order;
  INSERT INTO public.order_items(order_id,product_id,station_id,quantity,unit_price,ready_at)
    VALUES(v_table_order.id,v_product,v_station,1,v_price,now()),
          (v_bar_order.id,v_product,v_station,1,v_price,now());
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status)
    VALUES(v_business,v_bar.id,v_channel,'NEW') RETURNING * INTO v_unvalidated;
  INSERT INTO public.order_items(order_id,product_id,station_id,quantity,unit_price)
    VALUES(v_unvalidated.id,v_product,v_station,1,v_price);
  PERFORM set_config('request.jwt.claim.sub',v_station_user::text,true);
  BEGIN
    PERFORM public.receive_order_station(v_unvalidated.id,v_station);
    RAISE EXCEPTION 'FAIL_STATION_RECEIVED_BEFORE_CAJA';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ORDER_AWAITS_CASHIER_VALIDATION' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub',v_waiter::text,true);
  BEGIN
    PERFORM public.validate_order(v_unvalidated.id);
    RAISE EXCEPTION 'FAIL_MESERO_VALIDATED_ORDER';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'ROLE_NOT_ALLOWED' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.validate_order(v_unvalidated.id);
  PERFORM set_config('request.jwt.claim.sub',v_station_user::text,true);
  PERFORM public.receive_order_station(v_unvalidated.id,v_station);
  IF (SELECT status FROM public.orders WHERE id=v_unvalidated.id) <> 'RECEIVED' THEN
    RAISE EXCEPTION 'FAIL_VALIDATED_ORDER_STATE';
  END IF;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status)
    VALUES(v_business,v_admin_consumption.id,v_channel,'NEW') RETURNING * INTO v_admin_order;
  INSERT INTO public.order_items(order_id,product_id,station_id,quantity,unit_price)
    VALUES(v_admin_order.id,v_product,v_station,1,v_price);
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.validate_order(v_admin_order.id);
  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);
  PERFORM public.receive_order_station(v_admin_order.id,v_station);
  IF (SELECT status FROM public.order_station_work WHERE order_id=v_admin_order.id AND station_id=v_station) <> 'RECEIVED' THEN
    RAISE EXCEPTION 'FAIL_ADMIN_STATION_RECEIPT';
  END IF;

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
  INSERT INTO public.cuts(business_id,status,opened_at,operator_user_id)
    VALUES(v_business,'OPEN',now() - interval '1 hour',v_cashier) RETURNING * INTO v_cut;
  PERFORM public.execute_cut(v_cut.id,'{}'::jsonb);
  IF (SELECT status FROM public.cuts WHERE id=v_cut.id) <> 'EXECUTED' THEN
    RAISE EXCEPTION 'FAIL_CAJA_EXECUTED_CUT';
  END IF;
  RAISE NOTICE 'PASS: cocina, admin estación, entrega, cobro, cierre y corte Caja';
END;
$test$;
ROLLBACK;
