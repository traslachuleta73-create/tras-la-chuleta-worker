-- Lectura operativa del catálogo: BUSINESS y rol se comprueban en RLS.
CREATE POLICY products_read_operational ON public.products FOR SELECT TO authenticated
USING (business_id = private.current_business_id() AND private.current_role_code() IN ('CAJA','MESERO','BARRA','COCINA'));
CREATE POLICY stations_read_operational ON public.stations FOR SELECT TO authenticated
USING (business_id = private.current_business_id() AND private.current_role_code() IN ('CAJA','MESERO','BARRA','COCINA'));
CREATE POLICY product_stations_read_operational ON public.product_stations FOR SELECT TO authenticated
USING (private.current_role_code() IN ('CAJA','MESERO','BARRA','COCINA') AND EXISTS (
  SELECT 1 FROM public.products p WHERE p.id=product_stations.product_id AND p.business_id=private.current_business_id()
));
CREATE POLICY spaces_read_operational ON public.spaces FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code() IN ('CAJA','MESERO','BARRA'));
CREATE POLICY service_modes_read_operational ON public.service_modes FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code() IN ('CAJA','MESERO','BARRA'));
CREATE POLICY channels_read_operational ON public.business_channels FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code() IN ('CAJA','MESERO','BARRA'));
CREATE POLICY payment_methods_read_cashier ON public.business_payment_methods FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code()='CAJA');

-- COCINA no consulta consumos. MESERO y BARRA ven solo su modalidad.
DROP POLICY consumptions_select_same_business ON public.consumptions;
CREATE POLICY consumptions_select_operational ON public.consumptions FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND (
  private.current_role_code() IN ('ADMIN','CAJA')
  OR (private.current_role_code()='MESERO' AND EXISTS (
    SELECT 1 FROM public.service_modes sm WHERE sm.id=consumptions.service_mode_id AND sm.business_id=consumptions.business_id AND sm.code='MESA'))
  OR (private.current_role_code()='BARRA' AND EXISTS (
    SELECT 1 FROM public.service_modes sm WHERE sm.id=consumptions.service_mode_id AND sm.business_id=consumptions.business_id AND sm.code='BARRA'))
));

CREATE OR REPLACE FUNCTION public.create_order(p_consumption_id uuid,p_channel_code text,p_notes text DEFAULT NULL)
RETURNS public.orders LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_consumption public.consumptions;
  v_mode_code text; v_order public.orders; v_role text:=private.current_role_code();
BEGIN
  IF v_role NOT IN ('ADMIN','CAJA','MESERO','BARRA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  SELECT * INTO v_consumption FROM public.consumptions
    WHERE id=p_consumption_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status<>'OPEN' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN'; END IF;
  SELECT code INTO v_mode_code FROM public.service_modes
    WHERE id=v_consumption.service_mode_id AND business_id=v_business AND is_active;
  IF v_mode_code IS NULL THEN RAISE EXCEPTION 'SERVICE_MODE_NOT_AVAILABLE'; END IF;
  IF (v_role='MESERO' AND v_mode_code<>'MESA')
     OR (v_role='BARRA' AND v_mode_code<>'BARRA') THEN RAISE EXCEPTION 'SERVICE_MODE_NOT_ALLOWED'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.business_channels WHERE business_id=v_business
                AND channel_code=p_channel_code AND is_enabled) THEN RAISE EXCEPTION 'CHANNEL_NOT_ENABLED'; END IF;
  INSERT INTO public.orders(business_id,consumption_id,channel_code,status,notes,created_by)
    VALUES(v_business,p_consumption_id,p_channel_code,'NEW',p_notes,auth.uid()) RETURNING * INTO v_order;
  PERFORM private.write_audit(v_business,'ORDER_CREATED','ORDER',v_order.id::text,NULL,to_jsonb(v_order),NULL);
  RETURN v_order;
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_order_item(p_order_id uuid,p_product_id uuid,p_station_id uuid,
                                                  p_quantity numeric,p_notes text DEFAULT NULL)
RETURNS public.order_items LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_role text:=private.current_role_code();
  v_order public.orders; v_consumption public.consumptions; v_mode_code text;
  v_product public.products; v_item public.order_items;
BEGIN
  IF v_role NOT IN ('ADMIN','CAJA','MESERO','BARRA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT * INTO v_consumption FROM public.consumptions
    WHERE id=v_order.consumption_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND OR v_consumption.status<>'OPEN' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_OPEN'; END IF;
  SELECT code INTO v_mode_code FROM public.service_modes
    WHERE id=v_consumption.service_mode_id AND business_id=v_business AND is_active;
  IF (v_role='MESERO' AND v_mode_code<>'MESA')
     OR (v_role='BARRA' AND v_mode_code<>'BARRA') THEN RAISE EXCEPTION 'SERVICE_MODE_NOT_ALLOWED'; END IF;
  IF (v_role IN ('MESERO','BARRA') AND v_order.status<>'NEW')
      OR (v_role IN ('ADMIN','CAJA') AND v_order.status NOT IN ('NEW','RECEIVED')) THEN
    RAISE EXCEPTION 'ORDER_NOT_MODIFIABLE';
  END IF;
  SELECT * INTO v_product FROM public.products
    WHERE id=p_product_id AND business_id=v_business AND is_active AND is_available;
  IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_AVAILABLE'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.product_stations WHERE product_id=p_product_id AND station_id=p_station_id)
    THEN RAISE EXCEPTION 'PRODUCT_STATION_NOT_CONFIGURED'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.stations WHERE id=p_station_id AND business_id=v_business AND is_active)
    THEN RAISE EXCEPTION 'STATION_NOT_AVAILABLE'; END IF;
  IF p_quantity<=0 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
  INSERT INTO public.order_items(order_id,product_id,station_id,quantity,unit_price,notes)
    VALUES(p_order_id,p_product_id,p_station_id,p_quantity,v_product.price,p_notes) RETURNING * INTO v_item;
  PERFORM private.write_audit(v_business,'ORDER_ITEM_ADDED','ORDER_ITEM',v_item.id::text,NULL,to_jsonb(v_item),NULL);
  RETURN v_item;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_order(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.add_order_item(uuid,uuid,uuid,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_order(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_order_item(uuid,uuid,uuid,numeric,text) TO authenticated;
