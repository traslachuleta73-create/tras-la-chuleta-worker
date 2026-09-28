-- Tests permission and approval state; PDF upload itself requires configured Worker secret.
BEGIN;
DO $setup$
DECLARE v_business uuid; v_admin uuid; v_platform uuid; v_ficha uuid;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_admin FROM public.profiles WHERE business_id=v_business AND role_code='ADMIN';
  SELECT id INTO STRICT v_platform FROM public.profiles WHERE business_id=v_business AND role_code='CAJA';
  INSERT INTO public.platform_operators(user_id) VALUES(v_platform);
  INSERT INTO public.business_ficha_versions(business_id,version,document_path)
    VALUES(v_business,1,v_business::text||'/1.pdf') RETURNING id INTO v_ficha;
  PERFORM set_config('test.admin',v_admin::text,true);
  PERFORM set_config('test.platform',v_platform::text,true);
  PERFORM set_config('test.ficha',v_ficha::text,true);
  PERFORM set_config('test.business',v_business::text,true);
END;
$setup$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE v_admin uuid:=current_setting('test.admin')::uuid;
  v_platform uuid:=current_setting('test.platform')::uuid;
  v_ficha uuid:=current_setting('test.ficha')::uuid;
  v_business uuid:=current_setting('test.business')::uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);
  BEGIN
    PERFORM public.approve_ficha_version(v_ficha,'TLC');
    RAISE EXCEPTION 'FAIL_CLIENT_APPROVED_TLC_SIDE';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'PLATFORM_ROLE_REQUIRED' THEN RAISE; END IF; END;
  PERFORM public.approve_ficha_version(v_ficha,'CLIENTE');
  PERFORM set_config('request.jwt.claim.sub',v_platform::text,true);
  BEGIN
    PERFORM public.create_ficha_version(v_business,v_business::text||'/2.pdf');
    RAISE EXCEPTION 'FAIL_FICHA_CREATED_WITHOUT_PDF';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'FICHA_PDF_NOT_UPLOADED' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.approve_ficha_version(v_ficha,'CLIENTE');
    RAISE EXCEPTION 'FAIL_PLATFORM_APPROVED_CLIENT_SIDE';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'CLIENT_ADMIN_REQUIRED' THEN RAISE; END IF; END;
  PERFORM public.approve_ficha_version(v_ficha,'TLC');
  IF NOT EXISTS(SELECT 1 FROM public.business_ficha_versions
                WHERE id=v_ficha AND client_approved AND tlc_approved
                  AND client_approved_by=v_admin AND tlc_approved_by=v_platform) THEN
    RAISE EXCEPTION 'FAIL_TWO_SIDED_APPROVAL'; END IF;
  RAISE NOTICE 'PASS: client and TLC approvals require distinct authorized accounts';
END;
$test$;
ROLLBACK;
