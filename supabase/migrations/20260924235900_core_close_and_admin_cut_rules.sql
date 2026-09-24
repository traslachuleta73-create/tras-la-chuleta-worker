-- Alinea cortes, consumos, pagos y cancelaciones con las decisiones operativas aprobadas.
-- La transición de consumos es OPEN -> PENDING_CLOSE -> CLOSED; CANCELLED es terminal y no cuenta como pago.

ALTER TABLE public.consumptions
  DROP CONSTRAINT IF EXISTS consumptions_status_check;
ALTER TABLE public.consumptions
  ADD CONSTRAINT consumptions_status_check
  CHECK (status = ANY (ARRAY['OPEN'::text, 'PENDING_CLOSE'::text, 'CLOSED'::text, 'CANCELLED'::text]));

CREATE OR REPLACE FUNCTION public.open_cut(p_operator_user_id uuid DEFAULT auth.uid())
RETURNS public.cuts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_operator public.profiles;
  v_cut public.cuts;
BEGIN
  IF private.current_role_code() <> 'ADMIN' THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;

  SELECT * INTO v_operator
  FROM public.profiles
  WHERE id = p_operator_user_id
    AND business_id = v_business
    AND is_active
    AND role_code = 'CAJA';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_CUT_OPERATOR';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.cuts
    WHERE business_id = v_business AND status = 'OPEN'
  ) THEN
    RAISE EXCEPTION 'OPEN_CUT_ALREADY_EXISTS';
  END IF;

  INSERT INTO public.cuts (business_id, status, opened_at, operator_user_id)
  VALUES (v_business, 'OPEN', now(), p_operator_user_id)
  RETURNING * INTO v_cut;

  PERFORM private.write_audit(
    v_business, 'CUT_OPENED', 'CUT', v_cut.id::text,
    NULL, to_jsonb(v_cut), NULL
  );

  RETURN v_cut;
END;
$function$;

CREATE OR REPLACE FUNCTION public.request_consumption_close(p_consumption_id uuid)
RETURNS public.consumptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
  v_before jsonb;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN', 'CAJA', 'MESERO') THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;

  SELECT * INTO v_consumption
  FROM public.consumptions
  WHERE id = p_consumption_id AND business_id = v_business
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status <> 'OPEN' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN'; END IF;

  v_before := to_jsonb(v_consumption);
  UPDATE public.consumptions
  SET status = 'PENDING_CLOSE'
  WHERE id = p_consumption_id
  RETURNING * INTO v_consumption;

  PERFORM private.write_audit(
    v_business, 'CONSUMPTION_CLOSE_REQUESTED', 'CONSUMPTION',
    v_consumption.id::text, v_before, to_jsonb(v_consumption), NULL
  );
  RETURN v_consumption;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_payment(
  p_consumption_id uuid,
  p_method_code text,
  p_amount numeric,
  p_external_reference text DEFAULT NULL::text
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
  v_payment public.payments;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN', 'CAJA') THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'INVALID_PAYMENT_AMOUNT'; END IF;

  SELECT * INTO v_consumption
  FROM public.consumptions
  WHERE id = p_consumption_id AND business_id = v_business
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status <> 'PENDING_CLOSE' THEN
    RAISE EXCEPTION 'CONSUMPTION_NOT_PENDING_CLOSE';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.business_payment_methods
    WHERE business_id = v_business AND method_code = p_method_code AND is_enabled
  ) THEN RAISE EXCEPTION 'PAYMENT_METHOD_NOT_ENABLED'; END IF;

  INSERT INTO public.payments(
    business_id, consumption_id, status, method_code, amount, external_reference, created_by
  )
  VALUES (
    v_business, p_consumption_id, 'PENDING', p_method_code, p_amount, p_external_reference, auth.uid()
  )
  RETURNING * INTO v_payment;

  PERFORM private.write_audit(
    v_business, 'PAYMENT_CREATED', 'PAYMENT', v_payment.id::text,
    NULL, to_jsonb(v_payment), NULL
  );
  RETURN v_payment;
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_payment(p_payment_id uuid)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_payment public.payments;
  v_before jsonb;
  v_consumption public.consumptions;
  v_total numeric;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN', 'CAJA') THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;

  SELECT * INTO v_payment
  FROM public.payments
  WHERE id = p_payment_id AND business_id = private.current_business_id()
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND'; END IF;
  IF v_payment.status <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_PAYMENT_STATE'; END IF;

  SELECT * INTO v_consumption
  FROM public.consumptions
  WHERE id = v_payment.consumption_id AND business_id = v_payment.business_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status <> 'PENDING_CLOSE' THEN
    RAISE EXCEPTION 'CONSUMPTION_NOT_PENDING_CLOSE';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payments p
    WHERE p.consumption_id = v_payment.consumption_id
      AND p.business_id = v_payment.business_id
      AND p.status = 'CONFIRMED' AND p.id <> v_payment.id
  ) THEN RAISE EXCEPTION 'CONSUMPTION_ALREADY_PAID'; END IF;

  SELECT COALESCE(sum(oi.quantity * oi.unit_price), 0)
  INTO v_total
  FROM public.orders o
  JOIN public.order_items oi ON oi.order_id = o.id
  WHERE o.consumption_id = v_payment.consumption_id
    AND o.business_id = v_payment.business_id
    AND o.status <> 'CANCELLED';

  IF v_total <= 0 THEN RAISE EXCEPTION 'CONSUMPTION_HAS_NO_CHARGEABLE_TOTAL'; END IF;
  IF v_payment.amount <> v_total THEN RAISE EXCEPTION 'PAYMENT_AMOUNT_MISMATCH'; END IF;

  v_before := to_jsonb(v_payment);
  UPDATE public.payments
  SET status = 'CONFIRMED', confirmed_at = now(), confirmed_by = auth.uid()
  WHERE id = p_payment_id
  RETURNING * INTO v_payment;

  PERFORM private.write_audit(
    v_payment.business_id, 'PAYMENT_CONFIRMED', 'PAYMENT', v_payment.id::text,
    v_before, to_jsonb(v_payment), NULL
  );
  RETURN v_payment;
END;
$function$;

CREATE OR REPLACE FUNCTION public.close_consumption(p_consumption_id uuid)
RETURNS public.consumptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
  v_before jsonb;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN', 'CAJA') THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;

  SELECT * INTO v_consumption
  FROM public.consumptions
  WHERE id = p_consumption_id AND business_id = v_business
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status <> 'PENDING_CLOSE' THEN
    RAISE EXCEPTION 'CONSUMPTION_NOT_PENDING_CLOSE';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.payments
    WHERE consumption_id = p_consumption_id
      AND business_id = v_business
      AND status = 'CONFIRMED'
  ) THEN RAISE EXCEPTION 'CONFIRMED_PAYMENT_REQUIRED'; END IF;

  v_before := to_jsonb(v_consumption);
  UPDATE public.consumptions
  SET status = 'CLOSED', closed_at = now()
  WHERE id = p_consumption_id
  RETURNING * INTO v_consumption;

  PERFORM private.write_audit(
    v_business, 'CONSUMPTION_CLOSED', 'CONSUMPTION', v_consumption.id::text,
    v_before, to_jsonb(v_consumption), NULL
  );
  RETURN v_consumption;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_consumption(p_consumption_id uuid, p_reason text)
RETURNS public.consumptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
  v_before jsonb;
  v_payment public.payments;
  v_payment_before jsonb;
BEGIN
  IF private.current_role_code() <> 'ADMIN' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_reason), '') IS NULL THEN RAISE EXCEPTION 'CANCELLATION_REASON_REQUIRED'; END IF;

  SELECT * INTO v_consumption
  FROM public.consumptions
  WHERE id = p_consumption_id AND business_id = v_business
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status NOT IN ('OPEN', 'PENDING_CLOSE') THEN
    RAISE EXCEPTION 'CONSUMPTION_NOT_CANCELLABLE';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.payments
    WHERE consumption_id = p_consumption_id
      AND business_id = v_business
      AND status = 'CONFIRMED'
  ) THEN RAISE EXCEPTION 'CONFIRMED_CONSUMPTION_CANNOT_BE_CANCELLED'; END IF;

  FOR v_payment IN
    SELECT * FROM public.payments
    WHERE consumption_id = p_consumption_id
      AND business_id = v_business
      AND status = 'PENDING'
    FOR UPDATE
  LOOP
    v_payment_before := to_jsonb(v_payment);
    UPDATE public.payments
    SET status = 'CANCELLED', cancelled_at = now()
    WHERE id = v_payment.id
    RETURNING * INTO v_payment;
    PERFORM private.write_audit(
      v_business, 'PAYMENT_CANCELLED_WITH_CONSUMPTION', 'PAYMENT',
      v_payment.id::text, v_payment_before, to_jsonb(v_payment), trim(p_reason)
    );
  END LOOP;

  v_before := to_jsonb(v_consumption);
  UPDATE public.consumptions
  SET status = 'CANCELLED', closed_at = now()
  WHERE id = p_consumption_id
  RETURNING * INTO v_consumption;

  PERFORM private.write_audit(
    v_business, 'CONSUMPTION_CANCELLED', 'CONSUMPTION', v_consumption.id::text,
    v_before, to_jsonb(v_consumption), trim(p_reason)
  );
  RETURN v_consumption;
END;
$function$;

REVOKE ALL ON FUNCTION public.request_consumption_close(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_consumption_close(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.close_consumption(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_consumption(uuid) TO authenticated;
