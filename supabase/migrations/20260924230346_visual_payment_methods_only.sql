-- Los métodos disponibles son categorías visuales; no conectan con proveedores de pago.
-- Se conservan códigos anteriores para proteger el historial, pero se deshabilitan para nuevos cobros.
UPDATE public.business_payment_methods SET is_enabled=false WHERE method_code NOT IN ('CASH','CARD','TRANSFER');
INSERT INTO public.business_payment_methods(business_id,method_code,display_name,is_enabled)
SELECT b.id,m.method_code,m.display_name,true FROM public.businesses b
CROSS JOIN (VALUES ('CASH'::text,'Efectivo'::text),('CARD'::text,'Tarjeta'::text),('TRANSFER'::text,'Transferencia'::text)) AS m(method_code,display_name)
ON CONFLICT(business_id,method_code) DO UPDATE SET display_name=EXCLUDED.display_name,is_enabled=true;

CREATE OR REPLACE FUNCTION public.create_payment(p_consumption_id uuid,p_method_code text,p_amount numeric,p_external_reference text DEFAULT NULL::text)
RETURNS public.payments LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_business uuid:=private.current_business_id(); v_consumption public.consumptions; v_payment public.payments;
BEGIN
  IF private.current_role_code() NOT IN ('ADMIN','CAJA') THEN RAISE EXCEPTION 'ROLE_NOT_ALLOWED'; END IF;
  IF p_amount<=0 THEN RAISE EXCEPTION 'INVALID_PAYMENT_AMOUNT'; END IF;
  IF p_method_code NOT IN ('CASH','CARD','TRANSFER') THEN RAISE EXCEPTION 'PAYMENT_METHOD_NOT_SUPPORTED'; END IF;
  SELECT * INTO v_consumption FROM public.consumptions WHERE id=p_consumption_id AND business_id=v_business FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CONSUMPTION_NOT_FOUND'; END IF;
  IF v_consumption.status<>'PENDING_CLOSE' THEN RAISE EXCEPTION 'CONSUMPTION_NOT_PENDING_CLOSE'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.business_payment_methods WHERE business_id=v_business AND method_code=p_method_code AND is_enabled) THEN RAISE EXCEPTION 'PAYMENT_METHOD_NOT_ENABLED'; END IF;
  INSERT INTO public.payments(business_id,consumption_id,status,method_code,amount,external_reference,created_by)
  VALUES(v_business,p_consumption_id,'PENDING',p_method_code,p_amount,p_external_reference,auth.uid()) RETURNING * INTO v_payment;
  PERFORM private.write_audit(v_business,'PAYMENT_CREATED','PAYMENT',v_payment.id::text,NULL,to_jsonb(v_payment),NULL);
  RETURN v_payment;
END;
$function$;
