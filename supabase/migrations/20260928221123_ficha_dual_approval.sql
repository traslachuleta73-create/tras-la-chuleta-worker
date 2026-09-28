-- Solo una cuenta designada por Tras La Chuleta puede crear y aprobar como plataforma.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('fichas','fichas',false,5242880,ARRAY['application/pdf'])
ON CONFLICT (id) DO NOTHING;
CREATE TABLE public.platform_operators (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.platform_operators ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_operators FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.is_platform_operator()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT EXISTS(SELECT 1 FROM public.platform_operators WHERE user_id=auth.uid() AND is_active);
$function$;
REVOKE ALL ON FUNCTION public.is_platform_operator() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.is_platform_operator() TO authenticated;

CREATE OR REPLACE FUNCTION public.create_ficha_version(p_business_id uuid,p_document_path text)
RETURNS public.business_ficha_versions LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_version integer; v_ficha public.business_ficha_versions;
BEGIN
  IF NOT public.is_platform_operator() THEN RAISE EXCEPTION 'PLATFORM_ROLE_REQUIRED'; END IF;
  IF p_document_path IS NULL OR length(trim(p_document_path))=0 THEN RAISE EXCEPTION 'PDF_REQUIRED'; END IF;
  PERFORM 1 FROM public.businesses WHERE id=p_business_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BUSINESS_NOT_FOUND'; END IF;
  SELECT COALESCE(max(version),0)+1 INTO v_version FROM public.business_ficha_versions WHERE business_id=p_business_id;
  IF p_document_path <> p_business_id::text || '/' || v_version::text || '.pdf' THEN
    RAISE EXCEPTION 'INVALID_FICHA_PATH'; END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='fichas' AND name=p_document_path) THEN
    RAISE EXCEPTION 'FICHA_PDF_NOT_UPLOADED'; END IF;
  INSERT INTO public.business_ficha_versions(business_id,version,document_path)
    VALUES(p_business_id,v_version,p_document_path) RETURNING * INTO v_ficha;
  PERFORM private.write_audit(p_business_id,'FICHA_VERSION_CREATED','FICHA',v_ficha.id::text,
                              NULL,to_jsonb(v_ficha),NULL);
  RETURN v_ficha;
END;
$function$;

CREATE OR REPLACE FUNCTION public.approve_ficha_version(p_ficha_id uuid,p_side text)
RETURNS public.business_ficha_versions LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_ficha public.business_ficha_versions; v_before jsonb;
BEGIN
  IF p_side NOT IN ('CLIENTE','TLC') THEN RAISE EXCEPTION 'INVALID_APPROVAL_SIDE'; END IF;
  SELECT * INTO v_ficha FROM public.business_ficha_versions WHERE id=p_ficha_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'FICHA_NOT_FOUND'; END IF;
  IF p_side='TLC' AND NOT public.is_platform_operator() THEN RAISE EXCEPTION 'PLATFORM_ROLE_REQUIRED'; END IF;
  IF p_side='CLIENTE' AND NOT EXISTS(
    SELECT 1 FROM public.profiles WHERE id=auth.uid() AND business_id=v_ficha.business_id
      AND role_code='ADMIN' AND is_active) THEN RAISE EXCEPTION 'CLIENT_ADMIN_REQUIRED'; END IF;
  IF p_side='TLC' AND v_ficha.tlc_approved OR p_side='CLIENTE' AND v_ficha.client_approved THEN
    RAISE EXCEPTION 'FICHA_ALREADY_APPROVED'; END IF;
  IF p_side='TLC' AND v_ficha.client_approved_by=auth.uid()
     OR p_side='CLIENTE' AND v_ficha.tlc_approved_by=auth.uid() THEN
    RAISE EXCEPTION 'TWO_DISTINCT_APPROVERS_REQUIRED'; END IF;
  v_before:=to_jsonb(v_ficha);
  IF p_side='TLC' THEN
    UPDATE public.business_ficha_versions SET tlc_approved=true,tlc_approved_at=now(),tlc_approved_by=auth.uid()
      WHERE id=p_ficha_id RETURNING * INTO v_ficha;
  ELSE
    UPDATE public.business_ficha_versions SET client_approved=true,client_approved_at=now(),client_approved_by=auth.uid()
      WHERE id=p_ficha_id RETURNING * INTO v_ficha;
  END IF;
  PERFORM private.write_audit(v_ficha.business_id,'FICHA_APPROVED_'||p_side,'FICHA',p_ficha_id::text,
                              v_before,to_jsonb(v_ficha),NULL);
  RETURN v_ficha;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_ficha_version(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.approve_ficha_version(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_ficha_version(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_ficha_version(uuid,text) TO authenticated;
