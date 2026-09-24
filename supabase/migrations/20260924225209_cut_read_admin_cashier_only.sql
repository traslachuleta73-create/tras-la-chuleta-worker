-- Los cortes y sus discrepancias financieras solo son visibles para ADMIN y CAJA.
DROP POLICY IF EXISTS cuts_select_same_business ON public.cuts;
CREATE POLICY cuts_select_same_business
ON public.cuts
FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code()=ANY(ARRAY['ADMIN'::text,'CAJA'::text]));

DROP POLICY IF EXISTS cut_discrepancies_select_same_business ON public.cut_discrepancies;
CREATE POLICY cut_discrepancies_select_same_business
ON public.cut_discrepancies
FOR SELECT TO authenticated
USING (business_id=private.current_business_id() AND private.current_role_code()=ANY(ARRAY['ADMIN'::text,'CAJA'::text]));
