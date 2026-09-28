BEGIN;
DO $setup$
DECLARE v_business uuid; v_admin uuid; v_cashier uuid; v_waiter uuid;
  v_mode uuid; v_consumption uuid; v_order uuid; v_payment uuid; v_channel text;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_admin FROM public.profiles WHERE business_id=v_business AND role_code='ADMIN';
  SELECT id INTO STRICT v_cashier FROM public.profiles WHERE business_id=v_business AND role_code='CAJA';
  SELECT id INTO STRICT v_waiter FROM public.profiles WHERE business_id=v_business AND role_code='MESERO';
  SELECT channel_code INTO STRICT v_channel FROM public.business_channels WHERE business_id=v_business AND is_enabled LIMIT 1;
  INSERT INTO public.service_modes(business_id,code,name) VALUES(v_business,'MESA','Mesa prueba') RETURNING id INTO v_mode;
  INSERT INTO public.consumptions(business_id,service_mode_id,status)
    VALUES(v_business,v_mode,'CLOSED') RETURNING id INTO v_consumption;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status,delivered_at,delivered_by)
    VALUES(v_business,v_consumption,v_channel,'DELIVERED',now(),v_waiter) RETURNING id INTO v_order;
  INSERT INTO public.payments(business_id,consumption_id,status,method_code,amount,confirmed_at,confirmed_by)
    VALUES(v_business,v_consumption,'CONFIRMED','CASH',150,now(),v_cashier) RETURNING id INTO v_payment;
  PERFORM set_config('test.admin',v_admin::text,true);
  PERFORM set_config('test.cashier',v_cashier::text,true);
  PERFORM set_config('test.order',v_order::text,true);
  PERFORM set_config('test.payment',v_payment::text,true);
END;
$setup$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE v_admin uuid:=current_setting('test.admin')::uuid;
  v_cashier uuid:=current_setting('test.cashier')::uuid;
  v_order uuid:=current_setting('test.order')::uuid;
  v_payment uuid:=current_setting('test.payment')::uuid;
  v_profile public.profiles;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);
  BEGIN
    PERFORM public.attach_business_user(gen_random_uuid(),'Nueva Cocina','COCINA','Nuevo Laredo',NULL);
    RAISE EXCEPTION 'FAIL_ATTACHED_NONEXISTENT_AUTH_USER';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'AUTH_USER_NOT_FOUND' THEN RAISE; END IF; END;
  v_profile:=public.edit_business_user(v_cashier,'Caja piloto','CAJA','Nuevo Laredo',NULL,'Ajuste de nombre');
  IF v_profile.display_name<>'Caja piloto' THEN RAISE EXCEPTION 'FAIL_USER_EDIT'; END IF;
  BEGIN
    PERFORM public.set_service_mode_enabled('MESA',false,'Prueba sin ficha');
    RAISE EXCEPTION 'FAIL_CONFIG_WITHOUT_FICHA';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'APPROVED_FICHA_REQUIRED' THEN RAISE; END IF; END;
  PERFORM public.void_delivered_order(v_order,'Entrega errónea');
  IF (SELECT voided_after_delivery_at FROM public.orders WHERE id=v_order) IS NULL
    THEN RAISE EXCEPTION 'FAIL_DELIVERED_EXCEPTION'; END IF;
  PERFORM public.record_payment_refund(v_payment,50,'Devolución parcial','REF-TEST');
  BEGIN
    PERFORM public.record_payment_refund(v_payment,101,'Exceso de devolución',NULL);
    RAISE EXCEPTION 'FAIL_OVER_REFUND';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'REFUND_EXCEEDS_PAYMENT' THEN RAISE; END IF; END;
  IF NOT EXISTS(SELECT 1 FROM public.audit_log WHERE action='DELIVERED_ORDER_VOIDED' AND entity_id=v_order::text)
     OR NOT EXISTS(SELECT 1 FROM public.audit_log WHERE action='PAYMENT_REFUND_RECORDED' AND entity_id=v_payment::text)
    THEN RAISE EXCEPTION 'FAIL_ADMIN_AUDIT'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  BEGIN
    PERFORM public.attach_business_user(gen_random_uuid(),'Nueva Cocina','COCINA','Nuevo Laredo',NULL);
    RAISE EXCEPTION 'FAIL_CASHIER_ATTACHED_USER';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'ROLE_NOT_ALLOWED' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.record_payment_refund(v_payment,1,'Caja no autorizada',NULL);
    RAISE EXCEPTION 'FAIL_CASHIER_REFUNDED';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'ROLE_NOT_ALLOWED' THEN RAISE; END IF; END;
  RAISE NOTICE 'PASS: admin user edit, refund cap, delivered exception, ficha gate and audit';
END;
$test$;
ROLLBACK;
