-- Matriz Maestra CONSOLIDADA_CORREGIDA v7: entrega por modalidad y cierre atómico.
-- La modalidad se configura por BUSINESS; un consumo sin modalidad no puede entregarse.

CREATE OR REPLACE FUNCTION public.open_consumption(p_space_id uuid, p_service_mode_id uuid)
RETURNS public.consumptions
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN', 'CAJA') THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;
  IF p_space_id IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM public.spaces s WHERE s.id=p_space_id AND s.business_id=v_business AND s.is_active) THEN
    RAISE EXCEPTION 'SPACE_NOT_AVAILABLE';
  END IF;
  IF p_service_mode_id IS NULL OR NOT EXISTS
    (SELECT 1 FROM public.service_modes sm
      WHERE sm.id=p_service_mode_id AND sm.business_id=v_business AND sm.is_active) THEN
    RAISE EXCEPTION 'SERVICE_MODE_NOT_AVAILABLE';
  END IF;
  INSERT INTO public.consumptions(business_id,space_id,service_mode_id,status,created_by)
  VALUES(v_business,p_space_id,p_service_mode_id,'OPEN',auth.uid())
  RETURNING * INTO v_consumption;
  PERFORM private.write_audit(v_business,'CONSUMPTION_OPENED','CONSUMPTION',
                              v_consumption.id::text,NULL,to_jsonb(v_consumption),NULL);
  RETURN v_consumption;
END;
$function$;

CREATE OR REPLACE FUNCTION public.deliver_order(p_order_id uuid)
RETURNS public.orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders;
  v_before jsonb;
  v_mode text;
  v_role text := private.current_role_code();
BEGIN
  SELECT o.* INTO v_order FROM public.orders o
   WHERE o.id = p_order_id AND o.business_id = private.current_business_id()
   FOR UPDATE OF o;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT upper(replace(trim(sm.code), ' ', '_')) INTO v_mode
    FROM public.consumptions c
    LEFT JOIN public.service_modes sm ON sm.id = c.service_mode_id AND sm.business_id = c.business_id
   WHERE c.id = v_order.consumption_id AND c.business_id = v_order.business_id;

  IF v_mode = 'MESA' THEN
    IF v_role <> 'MESERO' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  ELSIF v_mode IN ('BARRA', 'PARA_LLEVAR') THEN
    IF v_role <> 'CAJA' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  ELSE
    RAISE EXCEPTION 'DELIVERY_MODALITY_NOT_CONFIGURED';
  END IF;

  IF v_order.status <> 'READY' THEN RAISE EXCEPTION 'INVALID_ORDER_STATE'; END IF;
  IF EXISTS (SELECT 1 FROM public.order_items oi
              WHERE oi.order_id = v_order.id
                AND oi.ready_at IS NULL) THEN
    RAISE EXCEPTION 'ORDER_HAS_UNREADY_ITEMS';
  END IF;

  v_before := to_jsonb(v_order);
  UPDATE public.orders
     SET status = 'DELIVERED', delivered_at = now(), delivered_by = auth.uid(), updated_at = now()
   WHERE id = p_order_id AND business_id = v_order.business_id
   RETURNING * INTO v_order;
  PERFORM private.write_audit(v_order.business_id, 'ORDER_DELIVERED', 'ORDER',
                              v_order.id::text, v_before, to_jsonb(v_order), NULL);
  RETURN v_order;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_payment(
  p_consumption_id uuid, p_method_code text, p_amount numeric,
  p_external_reference text DEFAULT NULL::text)
RETURNS public.payments
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
  v_payment public.payments;
BEGIN
  IF private.current_role_code() <> 'CAJA' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'INVALID_PAYMENT_AMOUNT'; END IF;

  SELECT * INTO v_consumption FROM public.consumptions
   WHERE id = p_consumption_id AND business_id = v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status <> 'OPEN' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.business_payment_methods
                  WHERE business_id = v_business AND method_code = p_method_code AND is_enabled) THEN
    RAISE EXCEPTION 'PAYMENT_METHOD_NOT_ENABLED';
  END IF;

  INSERT INTO public.payments(business_id, consumption_id, status, method_code,
                              amount, external_reference, created_by)
  VALUES (v_business, p_consumption_id, 'PENDING', p_method_code, p_amount,
          p_external_reference, auth.uid()) RETURNING * INTO v_payment;
  PERFORM private.write_audit(v_business, 'PAYMENT_CREATED', 'PAYMENT', v_payment.id::text,
                              NULL, to_jsonb(v_payment), NULL);
  RETURN v_payment;
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_payment(p_payment_id uuid)
RETURNS public.payments
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_payment public.payments;
  v_payment_before jsonb;
  v_consumption public.consumptions;
  v_consumption_before jsonb;
  v_total numeric;
BEGIN
  IF private.current_role_code() <> 'CAJA' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  SELECT * INTO v_payment FROM public.payments
   WHERE id = p_payment_id AND business_id = private.current_business_id() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND'; END IF;
  IF v_payment.status <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_PAYMENT_STATE'; END IF;

  SELECT * INTO v_consumption FROM public.consumptions
   WHERE id = v_payment.consumption_id AND business_id = v_payment.business_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status <> 'OPEN' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN'; END IF;
  IF EXISTS (SELECT 1 FROM public.payments p
              WHERE p.consumption_id = v_payment.consumption_id
                AND p.business_id = v_payment.business_id
                AND p.status = 'CONFIRMED' AND p.id <> v_payment.id) THEN
    RAISE EXCEPTION 'CONSUMPTION_ALREADY_PAID';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orders o
              WHERE o.consumption_id = v_payment.consumption_id
                AND o.business_id = v_payment.business_id
                AND o.status NOT IN ('DELIVERED', 'CANCELLED')) THEN
    RAISE EXCEPTION 'ORDERS_NOT_DELIVERED';
  END IF;

  SELECT coalesce(sum(oi.quantity * oi.unit_price), 0) INTO v_total
    FROM public.orders o JOIN public.order_items oi ON oi.order_id = o.id
   WHERE o.consumption_id = v_payment.consumption_id
     AND o.business_id = v_payment.business_id AND o.status = 'DELIVERED';
  IF v_total <= 0 THEN RAISE EXCEPTION 'CONSUMPTION_HAS_NO_CHARGEABLE_TOTAL'; END IF;
  IF v_payment.amount <> v_total THEN RAISE EXCEPTION 'PAYMENT_AMOUNT_MISMATCH'; END IF;

  v_payment_before := to_jsonb(v_payment);
  UPDATE public.payments
     SET status = 'CONFIRMED', confirmed_at = now(), confirmed_by = auth.uid()
   WHERE id = p_payment_id AND business_id = v_payment.business_id
   RETURNING * INTO v_payment;
  PERFORM private.write_audit(v_payment.business_id, 'PAYMENT_CONFIRMED', 'PAYMENT',
                              v_payment.id::text, v_payment_before, to_jsonb(v_payment), NULL);

  v_consumption_before := to_jsonb(v_consumption);
  UPDATE public.consumptions SET status = 'CLOSED', closed_at = now()
   WHERE id = v_consumption.id AND business_id = v_consumption.business_id
   RETURNING * INTO v_consumption;
  PERFORM private.write_audit(v_consumption.business_id, 'CONSUMPTION_CLOSED',
                              'CONSUMPTION', v_consumption.id::text,
                              v_consumption_before, to_jsonb(v_consumption), NULL);
  RETURN v_payment;
END;
$function$;

-- Las rutas heredadas de cierre manual no deben adelantar ni duplicar el cierre financiero.
CREATE OR REPLACE FUNCTION public.request_consumption_close(p_consumption_id uuid)
RETURNS public.consumptions
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'CLOSE_IS_AUTOMATIC';
END;
$function$;

CREATE OR REPLACE FUNCTION public.close_consumption(p_consumption_id uuid)
RETURNS public.consumptions
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'CLOSE_IS_AUTOMATIC';
END;
$function$;

REVOKE ALL ON FUNCTION public.deliver_order(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.open_consumption(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_payment(uuid,text,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.confirm_payment(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.request_consumption_close(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.close_consumption(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deliver_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_consumption(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_payment(uuid,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_payment(uuid) TO authenticated;
