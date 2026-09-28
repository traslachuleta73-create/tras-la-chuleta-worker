BEGIN;
DO $setup$
DECLARE v_business uuid; v_admin uuid; v_cashier uuid; v_waiter uuid;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_admin FROM public.profiles WHERE business_id=v_business AND role_code='ADMIN';
  SELECT id INTO STRICT v_cashier FROM public.profiles WHERE business_id=v_business AND role_code='CAJA';
  SELECT id INTO STRICT v_waiter FROM public.profiles WHERE business_id=v_business AND role_code='MESERO';
  PERFORM set_config('test.admin',v_admin::text,true);
  PERFORM set_config('test.cashier',v_cashier::text,true);
  PERFORM set_config('test.waiter',v_waiter::text,true);
END;
$setup$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE v_admin uuid:=current_setting('test.admin')::uuid;
  v_cashier uuid:=current_setting('test.cashier')::uuid;
  v_waiter uuid:=current_setting('test.waiter')::uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  IF EXISTS(SELECT 1 FROM public.profiles WHERE id=v_waiter) THEN
    RAISE EXCEPTION 'FAIL_CASHIER_READ_OTHER_PROFILE';
  END IF;
  BEGIN
    PERFORM public.deactivate_business_user(v_waiter,'Intento indebido');
    RAISE EXCEPTION 'FAIL_CASHIER_DEACTIVATED_USER';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'ROLE_NOT_ALLOWED' THEN RAISE; END IF; END;

  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);
  BEGIN
    PERFORM public.deactivate_business_user(v_admin,'Autodesactivación');
    RAISE EXCEPTION 'FAIL_ADMIN_DEACTIVATED_SELF';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'CANNOT_DEACTIVATE_SELF' THEN RAISE; END IF; END;
  PERFORM public.deactivate_business_user(v_waiter,'Prueba reversible');
  IF (SELECT is_active FROM public.profiles WHERE id=v_waiter)
      OR NOT EXISTS(SELECT 1 FROM public.audit_log
                    WHERE entity_id=v_waiter::text AND action='USER_DEACTIVATED' AND reason='Prueba reversible') THEN
    RAISE EXCEPTION 'FAIL_DEACTIVATION_AUDIT';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE entity_id=v_waiter::text) THEN
    RAISE EXCEPTION 'FAIL_CASHIER_READ_AUDIT';
  END IF;
  RAISE NOTICE 'PASS: admin deactivation, reason audit, self and cashier denial';
END;
$test$;
ROLLBACK;
