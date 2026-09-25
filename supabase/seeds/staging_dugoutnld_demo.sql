-- STAGING ONLY: Dugout NLD demo tenant and catalog for manual button-driven flow checks.
-- One-time seed for the isolated tras-la-chuleta-staging project.
-- Does not create/copy Auth users, credentials, or production operational records.
-- Food/combos route to COCINA; packaged drinks route to BARRA for test scenarios.

DO $$
DECLARE
  v_business_id uuid;
  v_cocina_id uuid;
  v_barra_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM public.businesses WHERE slug = 'dugoutnld') THEN
    RAISE EXCEPTION 'Dugout NLD already exists in this staging project; seed is one-time';
  END IF;

  INSERT INTO public.roles (code, name, description) VALUES
    ('ADMIN', 'Administrador', 'Rol operativo base de administración'),
    ('BARRA', 'Barra', 'Rol operativo base de barra'),
    ('CAJA', 'Caja', 'Rol operativo base de caja'),
    ('COCINA', 'Cocina', 'Rol operativo base de cocina'),
    ('MESERO', 'Mesero', 'Rol operativo base de mesero')
  ON CONFLICT (code) DO NOTHING;

  INSERT INTO public.businesses (trade_name, slug, city, distinctive, is_active)
  VALUES ('Dugout NLD', 'dugoutnld', 'Nuevo Laredo', 'DUGOUT', true)
  RETURNING id INTO v_business_id;

  INSERT INTO public.stations (business_id, code, name, station_type, is_active) VALUES
    (v_business_id, 'COCINA', 'Cocina', 'COCINA', true),
    (v_business_id, 'BARRA', 'Barra', 'BARRA', true);
  SELECT id INTO v_cocina_id FROM public.stations WHERE business_id = v_business_id AND code = 'COCINA';
  SELECT id INTO v_barra_id FROM public.stations WHERE business_id = v_business_id AND code = 'BARRA';

  INSERT INTO public.business_channels (business_id, channel_code, is_enabled) VALUES
    (v_business_id, 'MESERO', true),
    (v_business_id, 'MOSTRADOR', true),
    (v_business_id, 'QR', true),
    (v_business_id, 'NFC', true),
    (v_business_id, 'WHATSAPP', true);

  INSERT INTO public.business_payment_methods (business_id, method_code, display_name, is_enabled) VALUES
    (v_business_id, 'CASH', 'Efectivo', true),
    (v_business_id, 'CARD', 'Tarjeta', true),
    (v_business_id, 'TRANSFER', 'Transferencia', true);

  INSERT INTO public.product_categories (business_id, name, sort_order, is_active) VALUES
    (v_business_id, 'Lonches y tacos', 1, true),
    (v_business_id, 'Combos', 2, true),
    (v_business_id, 'Bebidas', 3, true);

  INSERT INTO public.products (business_id, category_id, name, description, price, is_available, is_active)
  SELECT v_business_id, c.id, p.name, p.description, p.price, true, true
  FROM (VALUES
    ('Lonches y tacos', 'Lonche de Ternera', NULL::text, 80.00::numeric),
    ('Lonches y tacos', 'Taco Grande Ternera', NULL::text, 80.00::numeric),
    ('Combos', 'Combo Lonche', '2 lonches, 1 refresco y papas', 180.00::numeric),
    ('Combos', 'Combo Taco', '1 taco, 1 refresco y papas', 120.00::numeric),
    ('Combos', 'Combo Mixto', '1 lonche, 1 taco, 1 refresco y papas', 150.00::numeric),
    ('Bebidas', 'Coca-Cola de lata', NULL::text, 30.00::numeric),
    ('Bebidas', 'Botella de agua', NULL::text, 25.00::numeric)
  ) AS p(category_name, name, description, price)
  JOIN public.product_categories c
    ON c.business_id = v_business_id AND c.name = p.category_name;

  INSERT INTO public.product_stations (product_id, station_id)
  SELECT p.id,
    CASE WHEN p.name IN ('Coca-Cola de lata', 'Botella de agua') THEN v_barra_id ELSE v_cocina_id END
  FROM public.products p
  WHERE p.business_id = v_business_id;

  INSERT INTO public.audit_log (business_id, action, entity_type, entity_id, after_data, reason)
  VALUES (
    v_business_id, 'STAGING_DEMO_SEEDED', 'business', v_business_id::text,
    jsonb_build_object('slug', 'dugoutnld', 'stations', jsonb_build_array('COCINA', 'BARRA'), 'product_count', 7),
    'Datos de prueba de staging para revisión manual de funciones con botones'
  );
END $$;
