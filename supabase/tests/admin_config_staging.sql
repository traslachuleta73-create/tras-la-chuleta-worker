BEGIN;
DO $setup$
DECLARE v_business uuid; v_admin uuid; v_product uuid;
BEGIN
  SELECT id INTO STRICT v_business FROM public.businesses LIMIT 1;
  SELECT id INTO STRICT v_admin FROM public.profiles WHERE business_id=v_business AND role_code='ADMIN';
  SELECT id INTO STRICT v_product FROM public.products WHERE business_id=v_business LIMIT 1;
  INSERT INTO public.business_ficha_versions(business_id,version,document_path,client_approved,tlc_approved,
    client_approved_by,tlc_approved_by,client_approved_at,tlc_approved_at)
    VALUES(v_business,1,v_business::text||'/1.pdf',true,true,v_admin,v_admin,now(),now());
  PERFORM set_config('test.admin',v_admin::text,true);
  PERFORM set_config('test.product',v_product::text,true);
  PERFORM set_config('test.business',v_business::text,true);
END;
$setup$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE v_admin uuid:=current_setting('test.admin')::uuid;
  v_product uuid:=current_setting('test.product')::uuid;
  v_business uuid:=current_setting('test.business')::uuid;
  v_mode public.service_modes;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);
  BEGIN
    INSERT INTO public.service_modes(business_id,code,name) VALUES(v_business,'BARRA','Directo');
    RAISE EXCEPTION 'FAIL_DIRECT_CONFIG_WRITE';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  v_mode:=public.configure_service_mode('BARRA','Barra',true,'Ficha aprobada');
  IF v_mode.code<>'BARRA' THEN RAISE EXCEPTION 'FAIL_MODE_CONFIG'; END IF;
  PERFORM public.update_product_config(v_product,'Producto piloto',125,false,'Agotado temporalmente','Cambio autorizado');
  IF NOT EXISTS(SELECT 1 FROM public.products WHERE id=v_product AND name='Producto piloto'
                AND NOT is_available AND unavailable_reason='Agotado temporalmente') THEN
    RAISE EXCEPTION 'FAIL_PRODUCT_CONFIG'; END IF;
  RAISE NOTICE 'PASS: direct config denied, audited configuration after Ficha';
END;
$test$;
ROLLBACK;
