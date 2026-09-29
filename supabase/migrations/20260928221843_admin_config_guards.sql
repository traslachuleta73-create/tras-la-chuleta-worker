-- Toda escritura de configuración pasa por RPC auditada; RLS mantiene lectura por BUSINESS.
REVOKE ALL ON public.products,public.product_categories,public.product_stations,
  public.stations,public.service_modes,public.spaces,public.business_channels,
  public.business_payment_methods,public.business_modules,public.business_presence,
  public.business_locations,public.business_ficha_versions,public.profiles
  FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.products,public.product_categories,public.product_stations,
  public.stations,public.service_modes,public.spaces,public.business_channels,
  public.business_payment_methods,public.business_modules,public.business_presence,
  public.business_locations,public.business_ficha_versions,public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.configure_service_mode(p_code text,p_name text,
  p_enabled boolean,p_reason text)
RETURNS public.service_modes LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_mode public.service_modes; v_before jsonb;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF p_code NOT IN ('MESA','BARRA','PARA_LLEVAR') THEN RAISE EXCEPTION 'INVALID_SERVICE_MODE'; END IF;
  IF NULLIF(trim(p_name),'') IS NULL OR NULLIF(trim(p_reason),'') IS NULL THEN RAISE EXCEPTION 'REQUIRED_FIELD_MISSING'; END IF;
  IF NOT COALESCE((SELECT tlc_approved AND client_approved FROM public.business_ficha_versions
                   WHERE business_id=v_business ORDER BY version DESC LIMIT 1),false)
    THEN RAISE EXCEPTION 'APPROVED_FICHA_REQUIRED'; END IF;
  SELECT * INTO v_mode FROM public.service_modes WHERE business_id=v_business AND code=p_code FOR UPDATE;
  v_before:=CASE WHEN FOUND THEN to_jsonb(v_mode) ELSE NULL END;
  IF v_before IS NULL THEN
    INSERT INTO public.service_modes(business_id,code,name,is_active)
      VALUES(v_business,p_code,trim(p_name),p_enabled) RETURNING * INTO v_mode;
  ELSE
    UPDATE public.service_modes SET name=trim(p_name),is_active=p_enabled
      WHERE id=v_mode.id RETURNING * INTO v_mode;
  END IF;
  PERFORM private.write_audit(v_business,'SERVICE_MODE_CONFIGURED','SERVICE_MODE',v_mode.id::text,
                              v_before,to_jsonb(v_mode),trim(p_reason));
  RETURN v_mode;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_product_config(p_product_id uuid,p_name text,
  p_price numeric,p_available boolean,p_unavailable_reason text,p_reason text)
RETURNS public.products LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_product public.products; v_before jsonb;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_name),'') IS NULL OR NULLIF(trim(p_reason),'') IS NULL OR p_price IS NULL OR p_price<0
    THEN RAISE EXCEPTION 'INVALID_PRODUCT_CHANGE'; END IF;
  IF NOT p_available AND NULLIF(trim(p_unavailable_reason),'') IS NULL
    THEN RAISE EXCEPTION 'UNAVAILABLE_REASON_REQUIRED'; END IF;
  IF NOT COALESCE((SELECT tlc_approved AND client_approved FROM public.business_ficha_versions
                   WHERE business_id=v_business ORDER BY version DESC LIMIT 1),false)
    THEN RAISE EXCEPTION 'APPROVED_FICHA_REQUIRED'; END IF;
  SELECT * INTO v_product FROM public.products WHERE id=p_product_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_FOUND'; END IF;
  v_before:=to_jsonb(v_product);
  UPDATE public.products SET name=trim(p_name),price=p_price,is_available=p_available,
    unavailable_reason=CASE WHEN p_available THEN NULL ELSE trim(p_unavailable_reason) END,updated_at=now()
    WHERE id=p_product_id RETURNING * INTO v_product;
  PERFORM private.write_audit(v_business,'PRODUCT_CONFIGURED','PRODUCT',v_product.id::text,
                              v_before,to_jsonb(v_product),trim(p_reason));
  RETURN v_product;
END;
$function$;

REVOKE ALL ON FUNCTION public.configure_service_mode(text,text,boolean,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.update_product_config(uuid,text,numeric,boolean,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.configure_service_mode(text,text,boolean,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_product_config(uuid,text,numeric,boolean,text,text) TO authenticated;
