-- Station-local preparation and explicit cashier handoff before global READY.
ALTER TABLE public.orders
  ADD COLUMN cashier_received_at timestamptz,
  ADD COLUMN cashier_received_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ADD COLUMN ready_at timestamptz,
  ADD COLUMN ready_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check
  CHECK (status = ANY (ARRAY[
    'NEW'::text, 'RECEIVED'::text, 'PREPARING'::text,
    'READY_FOR_CASHIER'::text, 'CASHIER_ASSEMBLING'::text,
    'READY'::text, 'DELIVERED'::text, 'CANCELLED'::text
  ]));

CREATE TABLE public.order_station_work (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE RESTRICT,
  order_id uuid NOT NULL,
  station_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'PENDING',
  received_at timestamptz,
  received_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  preparing_at timestamptz,
  preparing_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ready_at timestamptz,
  ready_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT order_station_work_status_check
    CHECK (status = ANY (ARRAY['PENDING'::text,'RECEIVED'::text,'PREPARING'::text,'READY'::text,'CANCELLED'::text])),
  CONSTRAINT order_station_work_order_station_key UNIQUE (business_id,order_id,station_id),
  CONSTRAINT order_station_work_order_same_business_fk
    FOREIGN KEY (business_id,order_id) REFERENCES public.orders(business_id,id) ON DELETE RESTRICT,
  CONSTRAINT order_station_work_station_same_business_fk
    FOREIGN KEY (business_id,station_id) REFERENCES public.stations(business_id,id) ON DELETE RESTRICT
);

ALTER TABLE public.order_station_work ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.order_station_work FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.order_station_work TO authenticated;
CREATE POLICY order_station_work_select_authorized
ON public.order_station_work
FOR SELECT TO authenticated
USING (
  business_id = private.current_business_id()
  AND (
    private.current_role_code() IN ('ADMIN','CAJA')
    OR EXISTS (
      SELECT 1 FROM public.stations s
      WHERE s.id = order_station_work.station_id
        AND s.business_id = order_station_work.business_id
        AND s.station_type = private.current_role_code()
    )
  )
);

-- Backfill station work from the existing item history without rewriting order statuses.
INSERT INTO public.order_station_work (business_id,order_id,station_id,status,ready_at,ready_by)
SELECT o.business_id, oi.order_id, oi.station_id,
       CASE
         WHEN o.status = 'CANCELLED' THEN 'CANCELLED'
         WHEN bool_and(oi.ready_at IS NOT NULL) THEN 'READY'
         ELSE 'PENDING'
       END,
       max(oi.ready_at),
       (array_agg(oi.ready_by ORDER BY oi.ready_at DESC NULLS LAST))[1]
FROM public.order_items oi
JOIN public.orders o ON o.id=oi.order_id
GROUP BY o.business_id,oi.order_id,oi.station_id,o.status
ON CONFLICT (business_id,order_id,station_id) DO NOTHING;

CREATE OR REPLACE FUNCTION private.sync_order_station_work()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid;
BEGIN
  SELECT business_id INTO v_business FROM public.orders WHERE id=NEW.order_id;
  IF v_business IS NULL THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  INSERT INTO public.order_station_work(business_id,order_id,station_id,status)
  VALUES(v_business,NEW.order_id,NEW.station_id,'PENDING')
  ON CONFLICT (business_id,order_id,station_id) DO NOTHING;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.sync_order_station_work() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER order_items_sync_station_work
AFTER INSERT ON public.order_items
FOR EACH ROW EXECUTE FUNCTION private.sync_order_station_work();

CREATE OR REPLACE FUNCTION public.receive_order_station(p_order_id uuid,p_station_id uuid)
RETURNS public.order_station_work
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_order public.orders; v_work public.order_station_work; v_station public.stations; v_before_work jsonb; v_before_order jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.status NOT IN ('NEW','RECEIVED','PREPARING') THEN RAISE EXCEPTION 'INVALID_ORDER_STATE'; END IF;
  SELECT * INTO v_work FROM public.order_station_work WHERE order_id=p_order_id AND station_id=p_station_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_STATION_NOT_FOUND'; END IF;
  SELECT * INTO v_station FROM public.stations WHERE id=p_station_id AND business_id=v_business AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'STATION_NOT_AVAILABLE'; END IF;
  IF private.current_role_code()<>'ADMIN' AND private.current_role_code()<>v_station.station_type THEN RAISE EXCEPTION 'STATION_NOT_ALLOWED'; END IF;
  IF v_work.status<>'PENDING' THEN RAISE EXCEPTION 'INVALID_STATION_STATE'; END IF;

  v_before_work:=to_jsonb(v_work);
  UPDATE public.order_station_work SET status='RECEIVED',received_at=now(),received_by=auth.uid(),updated_at=now()
  WHERE id=v_work.id RETURNING * INTO v_work;
  PERFORM private.write_audit(v_business,'ORDER_STATION_RECEIVED','ORDER_STATION_WORK',v_work.id::text,v_before_work,to_jsonb(v_work),NULL);

  IF v_order.status='NEW' THEN
    v_before_order:=to_jsonb(v_order);
    UPDATE public.orders SET status='RECEIVED',received_at=now(),updated_at=now() WHERE id=p_order_id RETURNING * INTO v_order;
    PERFORM private.write_audit(v_business,'ORDER_RECEIVED','ORDER',v_order.id::text,v_before_order,to_jsonb(v_order),NULL);
  END IF;
  RETURN v_work;
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_order_station_preparation(p_order_id uuid,p_station_id uuid)
RETURNS public.order_station_work
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_order public.orders; v_work public.order_station_work; v_station public.stations; v_before_work jsonb; v_before_order jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.status NOT IN ('RECEIVED','PREPARING') THEN RAISE EXCEPTION 'INVALID_ORDER_STATE'; END IF;
  SELECT * INTO v_work FROM public.order_station_work WHERE order_id=p_order_id AND station_id=p_station_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_STATION_NOT_FOUND'; END IF;
  SELECT * INTO v_station FROM public.stations WHERE id=p_station_id AND business_id=v_business AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'STATION_NOT_AVAILABLE'; END IF;
  IF private.current_role_code()<>'ADMIN' AND private.current_role_code()<>v_station.station_type THEN RAISE EXCEPTION 'STATION_NOT_ALLOWED'; END IF;
  IF v_work.status<>'RECEIVED' THEN RAISE EXCEPTION 'INVALID_STATION_STATE'; END IF;

  v_before_work:=to_jsonb(v_work);
  UPDATE public.order_station_work SET status='PREPARING',preparing_at=now(),preparing_by=auth.uid(),updated_at=now()
  WHERE id=v_work.id RETURNING * INTO v_work;
  PERFORM private.write_audit(v_business,'ORDER_STATION_PREPARING','ORDER_STATION_WORK',v_work.id::text,v_before_work,to_jsonb(v_work),NULL);

  IF v_order.status='RECEIVED' THEN
    v_before_order:=to_jsonb(v_order);
    UPDATE public.orders SET status='PREPARING',preparing_at=now(),updated_at=now() WHERE id=p_order_id RETURNING * INTO v_order;
    PERFORM private.write_audit(v_business,'ORDER_PREPARING','ORDER',v_order.id::text,v_before_order,to_jsonb(v_order),NULL);
  END IF;
  RETURN v_work;
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_order_station_ready(p_order_item_id uuid)
RETURNS public.order_items
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_item public.order_items; v_order public.orders; v_work public.order_station_work; v_station public.stations;
  v_order_id uuid; v_before_item jsonb; v_before_work jsonb; v_before_order jsonb;
BEGIN
  SELECT order_id INTO v_order_id FROM public.order_items WHERE id=p_order_item_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_ITEM_NOT_FOUND'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=v_order_id AND business_id=private.current_business_id() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT * INTO v_item FROM public.order_items WHERE id=p_order_item_id AND order_id=v_order.id FOR UPDATE;
  SELECT * INTO v_work FROM public.order_station_work WHERE order_id=v_order.id AND station_id=v_item.station_id AND business_id=v_order.business_id FOR UPDATE;
  SELECT * INTO v_station FROM public.stations WHERE id=v_item.station_id AND business_id=v_order.business_id;

  IF private.current_role_code() NOT IN ('ADMIN','COCINA','BARRA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF private.current_role_code()<>'ADMIN' AND v_station.station_type<>private.current_role_code() THEN RAISE EXCEPTION 'STATION_NOT_ALLOWED'; END IF;
  IF v_order.status<>'PREPARING' OR v_work.status<>'PREPARING' THEN RAISE EXCEPTION 'INVALID_STATION_STATE'; END IF;
  IF v_item.ready_at IS NOT NULL THEN RAISE EXCEPTION 'ORDER_ITEM_ALREADY_READY'; END IF;

  v_before_item:=to_jsonb(v_item);
  UPDATE public.order_items SET ready_at=now(),ready_by=auth.uid() WHERE id=p_order_item_id RETURNING * INTO v_item;
  PERFORM private.write_audit(v_order.business_id,'ORDER_ITEM_READY','ORDER_ITEM',v_item.id::text,v_before_item,to_jsonb(v_item),NULL);

  IF NOT EXISTS(SELECT 1 FROM public.order_items WHERE order_id=v_order.id AND station_id=v_item.station_id AND ready_at IS NULL) THEN
    v_before_work:=to_jsonb(v_work);
    UPDATE public.order_station_work SET status='READY',ready_at=now(),ready_by=auth.uid(),updated_at=now() WHERE id=v_work.id RETURNING * INTO v_work;
    PERFORM private.write_audit(v_order.business_id,'ORDER_STATION_READY','ORDER_STATION_WORK',v_work.id::text,v_before_work,to_jsonb(v_work),NULL);
  END IF;

  IF NOT EXISTS(SELECT 1 FROM public.order_station_work WHERE order_id=v_order.id AND business_id=v_order.business_id AND status<>'READY') THEN
    v_before_order:=to_jsonb(v_order);
    UPDATE public.orders SET status='READY_FOR_CASHIER',updated_at=now() WHERE id=v_order.id RETURNING * INTO v_order;
    PERFORM private.write_audit(v_order.business_id,'ORDER_READY_FOR_CASHIER','ORDER',v_order.id::text,v_before_order,to_jsonb(v_order),NULL);
  END IF;
  RETURN v_item;
END;
$function$;

CREATE OR REPLACE FUNCTION public.receive_prepared_order(p_order_id uuid)
RETURNS public.orders LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_order public.orders; v_before jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=private.current_business_id() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF private.current_role_code() NOT IN ('ADMIN','CAJA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF v_order.status NOT IN ('READY_FOR_CASHIER','PREPARING') THEN RAISE EXCEPTION 'INVALID_ORDER_STATE'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.order_station_work WHERE order_id=v_order.id AND business_id=v_order.business_id)
     OR EXISTS(SELECT 1 FROM public.order_station_work WHERE order_id=v_order.id AND business_id=v_order.business_id AND status<>'READY')
     OR EXISTS(SELECT 1 FROM public.order_items WHERE order_id=v_order.id AND ready_at IS NULL) THEN
    RAISE EXCEPTION 'ORDER_STATIONS_NOT_READY';
  END IF;
  v_before:=to_jsonb(v_order);
  UPDATE public.orders SET status='CASHIER_ASSEMBLING',cashier_received_at=now(),cashier_received_by=auth.uid(),updated_at=now()
  WHERE id=p_order_id RETURNING * INTO v_order;
  PERFORM private.write_audit(v_order.business_id,'ORDER_RECEIVED_BY_CASHIER','ORDER',v_order.id::text,v_before,to_jsonb(v_order),NULL);
  RETURN v_order;
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_order_ready(p_order_id uuid)
RETURNS public.orders LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_order public.orders; v_before jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=private.current_business_id() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF private.current_role_code() NOT IN ('ADMIN','CAJA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF v_order.status<>'CASHIER_ASSEMBLING' OR v_order.cashier_received_at IS NULL THEN RAISE EXCEPTION 'INVALID_ORDER_STATE'; END IF;
  IF EXISTS(SELECT 1 FROM public.order_station_work WHERE order_id=v_order.id AND business_id=v_order.business_id AND status<>'READY')
     OR EXISTS(SELECT 1 FROM public.order_items WHERE order_id=v_order.id AND ready_at IS NULL) THEN
    RAISE EXCEPTION 'ORDER_STATIONS_NOT_READY';
  END IF;
  v_before:=to_jsonb(v_order);
  UPDATE public.orders SET status='READY',ready_at=now(),ready_by=auth.uid(),updated_at=now()
  WHERE id=p_order_id RETURNING * INTO v_order;
  PERFORM private.write_audit(v_order.business_id,'ORDER_READY','ORDER',v_order.id::text,v_before,to_jsonb(v_order),NULL);
  RETURN v_order;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid,p_reason text)
RETURNS public.orders LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_order public.orders; v_consumption public.consumptions; v_before jsonb;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN','CAJA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF NULLIF(trim(p_reason),'') IS NULL THEN RAISE EXCEPTION 'CANCELLATION_REASON_REQUIRED'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT * INTO v_consumption FROM public.consumptions WHERE id=v_order.consumption_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND OR v_consumption.status<>'OPEN' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN'; END IF;
  IF v_order.status NOT IN ('NEW','RECEIVED','PREPARING','READY_FOR_CASHIER','CASHIER_ASSEMBLING','READY') THEN
    RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE';
  END IF;
  v_before:=to_jsonb(v_order);
  UPDATE public.orders SET status='CANCELLED',cancelled_at=now(),cancelled_by=auth.uid(),
    cancellation_reason=trim(p_reason),updated_at=now()
  WHERE id=p_order_id RETURNING * INTO v_order;
  UPDATE public.order_station_work SET status='CANCELLED',updated_at=now()
  WHERE order_id=p_order_id AND business_id=v_business AND status<>'CANCELLED';
  PERFORM private.write_audit(v_business,'ORDER_CANCELLED','ORDER',v_order.id::text,v_before,to_jsonb(v_order),trim(p_reason));
  RETURN v_order;
END;
$function$;

REVOKE ALL ON FUNCTION public.receive_order(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.start_order_preparation(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.receive_order_station(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.receive_order_station(uuid,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.start_order_station_preparation(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.start_order_station_preparation(uuid,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.receive_prepared_order(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.receive_prepared_order(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.mark_order_ready(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mark_order_ready(uuid) TO authenticated;
