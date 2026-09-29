DROP POLICY audit_select_same_business ON public.audit_log;
CREATE POLICY audit_select_admin_business ON public.audit_log FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code()='ADMIN');

DROP POLICY profiles_select_own_business ON public.profiles;
CREATE POLICY profiles_select_self_or_admin_business ON public.profiles FOR SELECT TO authenticated
USING (id=auth.uid() OR (business_id=private.current_business_id() AND private.current_role_code()='ADMIN'));

CREATE OR REPLACE FUNCTION public.deactivate_business_user(p_user_id uuid,p_reason text)
RETURNS public.profiles LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_profile public.profiles; v_before jsonb;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_reason),'') IS NULL THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
  IF p_user_id=auth.uid() THEN RAISE EXCEPTION 'CANNOT_DEACTIVATE_SELF'; END IF;
  SELECT * INTO v_profile FROM public.profiles
    WHERE id=p_user_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF NOT v_profile.is_active THEN RAISE EXCEPTION 'USER_ALREADY_INACTIVE'; END IF;
  v_before:=to_jsonb(v_profile);
  UPDATE public.profiles SET is_active=false,updated_at=now()
    WHERE id=p_user_id RETURNING * INTO v_profile;
  PERFORM private.write_audit(v_business,'USER_DEACTIVATED','PROFILE',p_user_id::text,
                              v_before,to_jsonb(v_profile),trim(p_reason));
  RETURN v_profile;
END;
$function$;
REVOKE ALL ON FUNCTION public.deactivate_business_user(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.deactivate_business_user(uuid,text) TO authenticated;
