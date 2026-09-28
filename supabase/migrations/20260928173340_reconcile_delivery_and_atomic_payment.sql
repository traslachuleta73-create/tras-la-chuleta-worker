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

-- Solo CAJA libera el pedido estructurado a sus estaciones.
CREATE OR REPLACE FUNCTION public.validate_order(p_order_id uuid)
RETURNS public.orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders;
  v_before jsonb;
BEGIN
  IF private.current_role_code() <> 'CAJA' THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  SELECT * INTO v_order FROM public.orders
   WHERE id=p_order_id AND business_id=private.current_business_id() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.status <> 'NEW' THEN RAISE EXCEPTION 'INVALID_ORDER_STATE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.consumptions
                  WHERE id=v_order.consumption_id AND business_id=v_order.business_id AND status='OPEN') THEN
    RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.order_items WHERE order_id=v_order.id) THEN
    RAISE EXCEPTION 'ORDER_HAS_NO_ITEMS';
  END IF;
  v_before := to_jsonb(v_order);
  UPDATE public.orders SET status='RECEIVED',received_at=now(),updated_at=now()
   WHERE id=v_order.id AND business_id=v_order.business_id RETURNING * INTO v_order;
  PERFORM private.write_audit(v_order.business_id,'ORDER_VALIDATED_BY_CASHIER',
                              'ORDER',v_order.id::text,v_before,to_jsonb(v_order),NULL);
  RETURN v_order;
END;
$function$;

CREATE OR REPLACE FUNCTION public.receive_order_station(p_order_id uuid,p_station_id uuid)
RETURNS public.order_station_work
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_business uuid := private.current_business_id();
  v_order public.orders;
  v_work public.order_station_work;
  v_station public.stations;
  v_before jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders
   WHERE id=p_order_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.status NOT IN ('RECEIVED','PREPARING') THEN
    RAISE EXCEPTION 'ORDER_AWAITS_CASHIER_VALIDATION';
  END IF;
  SELECT * INTO v_work FROM public.order_station_work
   WHERE order_id=p_order_id AND station_id=p_station_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_STATION_NOT_FOUND'; END IF;
  SELECT * INTO v_station FROM public.stations
   WHERE id=p_station_id AND business_id=v_business AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'STATION_NOT_AVAILABLE'; END IF;
  IF private.current_role_code() <> 'ADMIN'
     AND private.current_role_code() <> v_station.station_type THEN
    RAISE EXCEPTION 'STATION_NOT_ALLOWED';
  END IF;
  IF v_work.status <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_STATION_STATE'; END IF;
  v_before := to_jsonb(v_work);
  UPDATE public.order_station_work
     SET status='RECEIVED',received_at=now(),received_by=auth.uid(),updated_at=now()
   WHERE id=v_work.id RETURNING * INTO v_work;
  PERFORM private.write_audit(v_business,'ORDER_STATION_RECEIVED',
                              'ORDER_STATION_WORK',v_work.id::text,
                              v_before,to_jsonb(v_work),NULL);
  RETURN v_work;
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
REVOKE ALL ON FUNCTION public.validate_order(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.receive_order_station(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.open_consumption(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_payment(uuid,text,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.confirm_payment(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.request_consumption_close(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.close_consumption(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.deliver_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_order_station(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_consumption(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_payment(uuid,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_payment(uuid) TO authenticated;
-- La matriz permite a ADMIN y CAJA ejecutar el corte; conserva su cierre inmutable.
CREATE OR REPLACE FUNCTION public.execute_cut(p_cut_id uuid, p_totals jsonb)
 RETURNS cuts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_cut public.cuts;
  v_before jsonb;
  v_executed_at timestamptz := now();
  v_total numeric;
  v_payment_count integer;
  v_by_method jsonb;
  v_consumptions jsonb;
  v_totals jsonb;
begin
  select * into v_cut
  from public.cuts
  where id = p_cut_id
    and business_id = private.current_business_id()
  for update;

  if not found then
    raise exception 'CUT_NOT_FOUND';
  end if;

  if private.current_role_code() not in ('ADMIN','CAJA') then
    raise exception 'ROLE_NOT_ALLOWED';
  end if;

  if v_cut.status <> 'OPEN' then
    raise exception 'CUT_ALREADY_EXECUTED';
  end if;

  if v_cut.operator_user_id is null then
    raise exception 'CUT_OPERATOR_REQUIRED';
  end if;

  select coalesce(sum(p.amount),0), count(*)
  into v_total, v_payment_count
  from public.payments p
  where p.business_id = v_cut.business_id
    and p.status = 'CONFIRMED'
    and p.confirmed_at >= v_cut.opened_at
    and p.confirmed_at < v_executed_at;

  select coalesce(jsonb_object_agg(x.method_code, x.amount), '{}'::jsonb)
  into v_by_method
  from (
    select p.method_code, sum(p.amount) amount
    from public.payments p
    where p.business_id = v_cut.business_id
      and p.status = 'CONFIRMED'
      and p.confirmed_at >= v_cut.opened_at
      and p.confirmed_at < v_executed_at
    group by p.method_code
  ) x;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'consumption_id', p.consumption_id,
      'consumption_number', c.consumption_number,
      'total_paid', p.total_paid
    )
    order by c.consumption_number
  ), '[]'::jsonb)
  into v_consumptions
  from (
    select p.consumption_id, sum(p.amount) total_paid
    from public.payments p
    where p.business_id = v_cut.business_id
      and p.status = 'CONFIRMED'
      and p.confirmed_at >= v_cut.opened_at
      and p.confirmed_at < v_executed_at
    group by p.consumption_id
  ) p
  join public.consumptions c
    on c.id = p.consumption_id
   and c.business_id = v_cut.business_id;

  v_totals := jsonb_build_object(
    'total', v_total,
    'payment_count', v_payment_count,
    'by_method', v_by_method,
    'consumptions', v_consumptions
  );

  v_before := to_jsonb(v_cut);

  update public.cuts
  set status = 'EXECUTED',
      executed_at = v_executed_at,
      executed_by = auth.uid(),
      totals = v_totals
  where id = p_cut_id
  returning * into v_cut;

  perform private.write_audit(
    v_cut.business_id,
    'CUT_EXECUTED',
    'CUT',
    v_cut.id::text,
    v_before,
    to_jsonb(v_cut),
    null
  );

  return v_cut;
end;
$function$;
