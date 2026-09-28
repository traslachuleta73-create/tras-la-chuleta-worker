-- Cambios administrativos auditables y acotados al BUSINESS actual.
CREATE OR REPLACE FUNCTION public.edit_business_user(p_user_id uuid,p_display_name text,p_role_code text,
  p_city text,p_distinctive text,p_reason text)
RETURNS public.profiles LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_user public.profiles; v_before jsonb;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_display_name),'') IS NULL OR NULLIF(trim(p_city),'') IS NULL OR NULLIF(trim(p_reason),'') IS NULL
    THEN RAISE EXCEPTION 'REQUIRED_FIELD_MISSING'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.roles WHERE code=p_role_code) THEN RAISE EXCEPTION 'INVALID_ROLE'; END IF;
  SELECT * INTO v_user FROM public.profiles WHERE id=p_user_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF p_user_id=auth.uid() AND p_role_code<>'ADMIN' THEN RAISE EXCEPTION 'CANNOT_REMOVE_OWN_ADMIN_ROLE'; END IF;
  v_before:=to_jsonb(v_user);
  UPDATE public.profiles SET display_name=trim(p_display_name),role_code=p_role_code,
    city=trim(p_city),distinctive=NULLIF(trim(p_distinctive),''),updated_at=now()
    WHERE id=p_user_id RETURNING * INTO v_user;
  PERFORM private.write_audit(v_business,'USER_EDITED','PROFILE',p_user_id::text,
                              v_before,to_jsonb(v_user),trim(p_reason));
  RETURN v_user;
END;
$function$;

CREATE OR REPLACE FUNCTION public.attach_business_user(p_user_id uuid,p_display_name text,
  p_role_code text,p_city text,p_distinctive text)
RETURNS public.profiles LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_profile public.profiles;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_display_name),'') IS NULL OR NULLIF(trim(p_city),'') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_FIELD_MISSING'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.roles WHERE code=p_role_code) THEN RAISE EXCEPTION 'INVALID_ROLE'; END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_user_id) THEN RAISE EXCEPTION 'AUTH_USER_NOT_FOUND'; END IF;
  IF EXISTS(SELECT 1 FROM public.profiles WHERE id=p_user_id) THEN RAISE EXCEPTION 'USER_ALREADY_ASSIGNED'; END IF;
  INSERT INTO public.profiles(id,business_id,role_code,city,distinctive,display_name,is_active)
    VALUES(p_user_id,v_business,p_role_code,trim(p_city),NULLIF(trim(p_distinctive),''),trim(p_display_name),true)
    RETURNING * INTO v_profile;
  PERFORM private.write_audit(v_business,'USER_CREATED','PROFILE',p_user_id::text,
                              NULL,to_jsonb(v_profile),NULL);
  RETURN v_profile;
END;
$function$;

CREATE TABLE public.payment_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE RESTRICT,
  payment_id uuid NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  amount numeric NOT NULL CHECK (amount>0),
  reason text NOT NULL CHECK (length(trim(reason))>0),
  external_reference text,
  recorded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX payment_refunds_payment_idx ON public.payment_refunds(business_id,payment_id);
ALTER TABLE public.payment_refunds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payment_refunds FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.payment_refunds TO authenticated;
CREATE POLICY payment_refunds_select_admin ON public.payment_refunds FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code()='ADMIN');

CREATE OR REPLACE FUNCTION public.record_payment_refund(p_payment_id uuid,p_amount numeric,
  p_reason text,p_external_reference text DEFAULT NULL)
RETURNS public.payment_refunds LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_payment public.payments;
  v_refunded numeric; v_refund public.payment_refunds;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_reason),'') IS NULL THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
  IF p_amount IS NULL OR p_amount<=0 THEN RAISE EXCEPTION 'INVALID_REFUND_AMOUNT'; END IF;
  SELECT * INTO v_payment FROM public.payments WHERE id=p_payment_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND'; END IF;
  IF v_payment.status<>'CONFIRMED' THEN RAISE EXCEPTION 'PAYMENT_NOT_CONFIRMED'; END IF;
  SELECT COALESCE(sum(amount),0) INTO v_refunded FROM public.payment_refunds
    WHERE payment_id=p_payment_id AND business_id=v_business;
  IF v_refunded+p_amount>v_payment.amount THEN RAISE EXCEPTION 'REFUND_EXCEEDS_PAYMENT'; END IF;
  INSERT INTO public.payment_refunds(business_id,payment_id,amount,reason,external_reference,recorded_by)
    VALUES(v_business,p_payment_id,p_amount,trim(p_reason),NULLIF(trim(p_external_reference),''),auth.uid())
    RETURNING * INTO v_refund;
  PERFORM private.write_audit(v_business,'PAYMENT_REFUND_RECORDED','PAYMENT',p_payment_id::text,
    to_jsonb(v_payment),to_jsonb(v_refund),trim(p_reason));
  RETURN v_refund;
END;
$function$;

ALTER TABLE public.orders ADD COLUMN voided_after_delivery_at timestamptz;
ALTER TABLE public.orders ADD COLUMN voided_after_delivery_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT;
ALTER TABLE public.orders ADD COLUMN voided_after_delivery_reason text;
CREATE OR REPLACE FUNCTION public.void_delivered_order(p_order_id uuid,p_reason text)
RETURNS public.orders LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_order public.orders; v_before jsonb;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_reason),'') IS NULL THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.status<>'DELIVERED' THEN RAISE EXCEPTION 'ORDER_NOT_DELIVERED'; END IF;
  IF v_order.voided_after_delivery_at IS NOT NULL THEN RAISE EXCEPTION 'ORDER_ALREADY_VOIDED'; END IF;
  v_before:=to_jsonb(v_order);
  UPDATE public.orders SET voided_after_delivery_at=now(),voided_after_delivery_by=auth.uid(),
    voided_after_delivery_reason=trim(p_reason),updated_at=now()
    WHERE id=p_order_id RETURNING * INTO v_order;
  PERFORM private.write_audit(v_business,'DELIVERED_ORDER_VOIDED','ORDER',p_order_id::text,
    v_before,to_jsonb(v_order),trim(p_reason));
  RETURN v_order;
END;
$function$;

-- La configuración estructural solo se modifica contra una Ficha aprobada.
CREATE OR REPLACE FUNCTION public.set_service_mode_enabled(p_code text,p_enabled boolean,p_reason text)
RETURNS public.service_modes LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_mode public.service_modes; v_before jsonb;
BEGIN
  IF private.current_role_code()<>'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_reason),'') IS NULL THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
  IF NOT COALESCE((SELECT tlc_approved AND client_approved FROM public.business_ficha_versions
                  WHERE business_id=v_business ORDER BY version DESC LIMIT 1),false) THEN
    RAISE EXCEPTION 'APPROVED_FICHA_REQUIRED'; END IF;
  SELECT * INTO v_mode FROM public.service_modes WHERE business_id=v_business AND code=p_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SERVICE_MODE_NOT_FOUND'; END IF;
  v_before:=to_jsonb(v_mode);
  UPDATE public.service_modes SET is_active=p_enabled WHERE id=v_mode.id RETURNING * INTO v_mode;
  PERFORM private.write_audit(v_business,'SERVICE_MODE_CHANGED','SERVICE_MODE',v_mode.id::text,
    v_before,to_jsonb(v_mode),trim(p_reason));
  RETURN v_mode;
END;
$function$;

REVOKE ALL ON FUNCTION public.edit_business_user(uuid,text,text,text,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.attach_business_user(uuid,text,text,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.record_payment_refund(uuid,numeric,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.void_delivered_order(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.set_service_mode_enabled(text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.edit_business_user(uuid,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attach_business_user(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_payment_refund(uuid,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.void_delivered_order(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_service_mode_enabled(text,boolean,text) TO authenticated;
