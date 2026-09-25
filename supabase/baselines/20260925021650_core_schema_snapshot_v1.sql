-- Staging-only schema baseline captured from production catalogs on 2026-09-25.
-- Schema and behavior only; no production rows, auth users, or customer secrets are included.
-- Do not apply to the populated production database.
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
SET search_path = public, extensions;

CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE public.audit_log (id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  business_id uuid,
  actor_user_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL,
  before_data jsonb,
  after_data jsonb,
  reason text);

CREATE TABLE public.business_channels (business_id uuid NOT NULL,
  channel_code text NOT NULL,
  is_enabled boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.business_ficha_versions (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  version integer NOT NULL,
  document_path text,
  tlc_approved boolean DEFAULT false NOT NULL,
  client_approved boolean DEFAULT false NOT NULL,
  tlc_approved_at timestamp with time zone,
  client_approved_at timestamp with time zone,
  tlc_approved_by uuid,
  client_approved_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.business_locations (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  name text NOT NULL,
  address text,
  city text,
  distinctive text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.business_modules (business_id uuid NOT NULL,
  module_code text NOT NULL,
  is_enabled boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.business_payment_methods (business_id uuid NOT NULL,
  method_code text NOT NULL,
  display_name text NOT NULL,
  is_enabled boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.business_presence (business_id uuid NOT NULL,
  presence_code text NOT NULL,
  url text,
  is_enabled boolean DEFAULT true NOT NULL,
  display_order integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.businesses (id uuid DEFAULT gen_random_uuid() NOT NULL,
  legal_name text,
  trade_name text NOT NULL,
  slug text NOT NULL,
  city text NOT NULL,
  distinctive text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.consumptions (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  consumption_number bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  space_id uuid,
  service_mode_id uuid,
  status text DEFAULT 'OPEN'::text NOT NULL,
  opened_at timestamp with time zone DEFAULT now() NOT NULL,
  closed_at timestamp with time zone,
  created_by uuid);

CREATE TABLE public.cut_discrepancies (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  cut_id uuid NOT NULL,
  discrepancy_type text NOT NULL,
  amount numeric NOT NULL,
  reason text NOT NULL,
  related_user_id uuid,
  recorded_by uuid,
  recorded_at timestamp with time zone DEFAULT now() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.cuts (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  status text DEFAULT 'OPEN'::text NOT NULL,
  opened_at timestamp with time zone DEFAULT now() NOT NULL,
  executed_at timestamp with time zone,
  executed_by uuid,
  totals jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  operator_user_id uuid);

CREATE TABLE public.order_items (id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  station_id uuid NOT NULL,
  quantity numeric(12,3) NOT NULL,
  unit_price numeric(12,2) NOT NULL,
  notes text,
  ready_at timestamp with time zone,
  ready_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.order_notification_preferences (order_id uuid NOT NULL,
  business_id uuid NOT NULL,
  channel_code text NOT NULL,
  target text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.order_station_work (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  order_id uuid NOT NULL,
  station_id uuid NOT NULL,
  status text DEFAULT 'PENDING'::text NOT NULL,
  received_at timestamp with time zone,
  received_by uuid,
  preparing_at timestamp with time zone,
  preparing_by uuid,
  ready_at timestamp with time zone,
  ready_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.orders (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  consumption_id uuid NOT NULL,
  order_number bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  channel_code text NOT NULL,
  status text DEFAULT 'NEW'::text NOT NULL,
  notes text,
  created_by uuid,
  received_at timestamp with time zone,
  preparing_at timestamp with time zone,
  delivered_at timestamp with time zone,
  delivered_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  cancelled_at timestamp with time zone,
  cancelled_by uuid,
  cancellation_reason text,
  replacement_for_order_id uuid,
  cashier_received_at timestamp with time zone,
  cashier_received_by uuid,
  ready_at timestamp with time zone,
  ready_by uuid);

CREATE TABLE public.payments (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  consumption_id uuid NOT NULL,
  status text DEFAULT 'PENDING'::text NOT NULL,
  method_code text NOT NULL,
  amount numeric(12,2) NOT NULL,
  external_reference text,
  created_by uuid,
  confirmed_by uuid,
  confirmed_at timestamp with time zone,
  expired_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.product_categories (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  name text NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.product_stations (product_id uuid NOT NULL,
  station_id uuid NOT NULL);

CREATE TABLE public.products (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  category_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  price numeric(12,2) NOT NULL,
  is_available boolean DEFAULT true NOT NULL,
  unavailable_reason text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.profiles (id uuid NOT NULL,
  business_id uuid NOT NULL,
  role_code text NOT NULL,
  city text NOT NULL,
  distinctive text,
  display_name text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.roles (code text NOT NULL,
  name text NOT NULL,
  description text);

CREATE TABLE public.service_modes (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.spaces (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  location_id uuid,
  name text NOT NULL,
  space_type text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.stations (id uuid DEFAULT gen_random_uuid() NOT NULL,
  business_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  station_type text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);

ALTER TABLE public.business_channels ADD CONSTRAINT business_channels_pkey PRIMARY KEY (business_id, channel_code);

ALTER TABLE public.business_ficha_versions ADD CONSTRAINT business_ficha_versions_business_id_version_key UNIQUE (business_id, version);

ALTER TABLE public.business_ficha_versions ADD CONSTRAINT business_ficha_versions_pkey PRIMARY KEY (id);

ALTER TABLE public.business_locations ADD CONSTRAINT business_locations_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.business_locations ADD CONSTRAINT business_locations_business_id_name_key UNIQUE (business_id, name);

ALTER TABLE public.business_locations ADD CONSTRAINT business_locations_pkey PRIMARY KEY (id);

ALTER TABLE public.business_modules ADD CONSTRAINT business_modules_pkey PRIMARY KEY (business_id, module_code);

ALTER TABLE public.business_payment_methods ADD CONSTRAINT business_payment_methods_pkey PRIMARY KEY (business_id, method_code);

ALTER TABLE public.business_presence ADD CONSTRAINT business_presence_code_check CHECK (presence_code = ANY (ARRAY['GOOGLE_MAPS'::text, 'GOOGLE_REVIEWS'::text, 'FACEBOOK'::text, 'INSTAGRAM'::text, 'TIKTOK'::text, 'WHATSAPP'::text]));

ALTER TABLE public.business_presence ADD CONSTRAINT business_presence_pkey PRIMARY KEY (business_id, presence_code);

ALTER TABLE public.businesses ADD CONSTRAINT businesses_pkey PRIMARY KEY (id);

ALTER TABLE public.businesses ADD CONSTRAINT businesses_slug_key UNIQUE (slug);

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_business_id_consumption_number_key UNIQUE (business_id, consumption_number);

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_pkey PRIMARY KEY (id);

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_status_check CHECK (status = ANY (ARRAY['OPEN'::text, 'PENDING_CLOSE'::text, 'CLOSED'::text, 'CANCELLED'::text]));

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_amount_check CHECK (amount > 0::numeric);

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_discrepancy_type_check CHECK (discrepancy_type = ANY (ARRAY['SHORTAGE'::text, 'SURPLUS'::text]));

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_pkey PRIMARY KEY (id);

ALTER TABLE public.cuts ADD CONSTRAINT cuts_pkey PRIMARY KEY (id);

ALTER TABLE public.cuts ADD CONSTRAINT cuts_status_check CHECK (status = ANY (ARRAY['OPEN'::text, 'EXECUTED'::text]));

ALTER TABLE public.order_items ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);

ALTER TABLE public.order_items ADD CONSTRAINT order_items_quantity_check CHECK (quantity > 0::numeric);

ALTER TABLE public.order_items ADD CONSTRAINT order_items_unit_price_check CHECK (unit_price >= 0::numeric);

ALTER TABLE public.order_notification_preferences ADD CONSTRAINT order_notification_preferences_target_check CHECK (length(TRIM(BOTH FROM target)) >= 1 AND length(TRIM(BOTH FROM target)) <= 255);

ALTER TABLE public.order_notification_preferences ADD CONSTRAINT order_notification_preferences_pkey PRIMARY KEY (order_id);

ALTER TABLE public.order_notification_preferences ADD CONSTRAINT order_notification_preferences_channel_check CHECK (length(TRIM(BOTH FROM channel_code)) >= 1 AND length(TRIM(BOTH FROM channel_code)) <= 50);

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_order_station_key UNIQUE (business_id, order_id, station_id);

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_pkey PRIMARY KEY (id);

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_status_check CHECK (status = ANY (ARRAY['PENDING'::text, 'RECEIVED'::text, 'PREPARING'::text, 'READY'::text, 'CANCELLED'::text]));

ALTER TABLE public.orders ADD CONSTRAINT orders_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.orders ADD CONSTRAINT orders_business_id_order_number_key UNIQUE (business_id, order_number);

ALTER TABLE public.orders ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (status = ANY (ARRAY['NEW'::text, 'RECEIVED'::text, 'PREPARING'::text, 'READY_FOR_CASHIER'::text, 'CASHIER_ASSEMBLING'::text, 'READY'::text, 'DELIVERED'::text, 'CANCELLED'::text]));

ALTER TABLE public.payments ADD CONSTRAINT payments_amount_check CHECK (amount > 0::numeric);

ALTER TABLE public.payments ADD CONSTRAINT payments_pkey PRIMARY KEY (id);

ALTER TABLE public.payments ADD CONSTRAINT payments_status_check CHECK (status = ANY (ARRAY['PENDING'::text, 'CONFIRMED'::text, 'EXPIRED'::text, 'CANCELLED'::text]));

ALTER TABLE public.product_categories ADD CONSTRAINT product_categories_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.product_categories ADD CONSTRAINT product_categories_business_id_name_key UNIQUE (business_id, name);

ALTER TABLE public.product_categories ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);

ALTER TABLE public.product_stations ADD CONSTRAINT product_stations_pkey PRIMARY KEY (product_id, station_id);

ALTER TABLE public.products ADD CONSTRAINT products_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);

ALTER TABLE public.products ADD CONSTRAINT products_price_check CHECK (price >= 0::numeric);

ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.roles ADD CONSTRAINT roles_pkey PRIMARY KEY (code);

ALTER TABLE public.service_modes ADD CONSTRAINT service_modes_business_id_code_key UNIQUE (business_id, code);

ALTER TABLE public.service_modes ADD CONSTRAINT service_modes_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.service_modes ADD CONSTRAINT service_modes_pkey PRIMARY KEY (id);

ALTER TABLE public.spaces ADD CONSTRAINT spaces_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.spaces ADD CONSTRAINT spaces_business_id_name_key UNIQUE (business_id, name);

ALTER TABLE public.spaces ADD CONSTRAINT spaces_pkey PRIMARY KEY (id);

ALTER TABLE public.stations ADD CONSTRAINT stations_business_id_code_key UNIQUE (business_id, code);

ALTER TABLE public.stations ADD CONSTRAINT stations_business_id_id_key UNIQUE (business_id, id);

ALTER TABLE public.stations ADD CONSTRAINT stations_pkey PRIMARY KEY (id);

CREATE INDEX audit_log_actor_user_idx ON public.audit_log USING btree (actor_user_id);

CREATE INDEX audit_log_business_time_idx ON public.audit_log USING btree (business_id, occurred_at DESC);

CREATE INDEX business_ficha_client_approved_by_idx ON public.business_ficha_versions USING btree (client_approved_by);

CREATE INDEX business_ficha_tlc_approved_by_idx ON public.business_ficha_versions USING btree (tlc_approved_by);

CREATE INDEX business_presence_business_id_idx ON public.business_presence USING btree (business_id);

CREATE INDEX consumptions_business_service_mode_idx ON public.consumptions USING btree (business_id, service_mode_id);

CREATE INDEX consumptions_business_space_idx ON public.consumptions USING btree (business_id, space_id);

CREATE INDEX consumptions_business_status_idx ON public.consumptions USING btree (business_id, status);

CREATE INDEX consumptions_created_by_idx ON public.consumptions USING btree (created_by);

CREATE INDEX consumptions_service_mode_idx ON public.consumptions USING btree (service_mode_id);

CREATE INDEX consumptions_space_idx ON public.consumptions USING btree (space_id);

CREATE INDEX cut_discrepancies_business_cut_idx ON public.cut_discrepancies USING btree (business_id, cut_id);

CREATE INDEX cut_discrepancies_cut_id_idx ON public.cut_discrepancies USING btree (cut_id);

CREATE INDEX cut_discrepancies_recorded_by_idx ON public.cut_discrepancies USING btree (recorded_by);

CREATE INDEX cut_discrepancies_related_user_id_idx ON public.cut_discrepancies USING btree (related_user_id);

CREATE INDEX cuts_business_status_idx ON public.cuts USING btree (business_id, status);

CREATE INDEX cuts_executed_by_idx ON public.cuts USING btree (executed_by);

CREATE UNIQUE INDEX cuts_one_open_per_business_idx ON public.cuts USING btree (business_id) WHERE (status = 'OPEN'::text);

CREATE INDEX cuts_operator_user_id_idx ON public.cuts USING btree (operator_user_id);

CREATE INDEX order_items_order_idx ON public.order_items USING btree (order_id);

CREATE INDEX order_items_product_idx ON public.order_items USING btree (product_id);

CREATE INDEX order_items_ready_by_idx ON public.order_items USING btree (ready_by);

CREATE INDEX order_items_station_idx ON public.order_items USING btree (station_id);

CREATE INDEX idx_order_notification_preferences_business ON public.order_notification_preferences USING btree (business_id);

CREATE INDEX orders_business_consumption_idx ON public.orders USING btree (business_id, consumption_id);

CREATE INDEX orders_business_status_idx ON public.orders USING btree (business_id, status);

CREATE INDEX orders_cancelled_by_idx ON public.orders USING btree (cancelled_by);

CREATE INDEX orders_channel_idx ON public.orders USING btree (business_id, channel_code);

CREATE INDEX orders_consumption_idx ON public.orders USING btree (consumption_id);

CREATE INDEX orders_created_by_idx ON public.orders USING btree (created_by);

CREATE INDEX orders_delivered_by_idx ON public.orders USING btree (delivered_by);

CREATE INDEX orders_replacement_for_idx ON public.orders USING btree (replacement_for_order_id);

CREATE INDEX payments_business_consumption_idx ON public.payments USING btree (business_id, consumption_id);

CREATE INDEX payments_confirmed_by_idx ON public.payments USING btree (confirmed_by);

CREATE INDEX payments_created_by_idx ON public.payments USING btree (created_by);

CREATE INDEX payments_method_idx ON public.payments USING btree (business_id, method_code);

CREATE UNIQUE INDEX payments_one_confirmed_per_consumption ON public.payments USING btree (consumption_id) WHERE (status = 'CONFIRMED'::text);

CREATE INDEX product_categories_business_idx ON public.product_categories USING btree (business_id);

CREATE INDEX product_stations_station_idx ON public.product_stations USING btree (station_id);

CREATE INDEX products_business_category_idx ON public.products USING btree (business_id, category_id);

CREATE INDEX products_business_idx ON public.products USING btree (business_id);

CREATE INDEX products_category_idx ON public.products USING btree (category_id);

CREATE INDEX profiles_business_idx ON public.profiles USING btree (business_id);

CREATE INDEX profiles_role_idx ON public.profiles USING btree (role_code);

CREATE INDEX spaces_business_location_idx ON public.spaces USING btree (business_id, location_id);

CREATE INDEX spaces_location_idx ON public.spaces USING btree (location_id);

ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.business_channels ADD CONSTRAINT business_channels_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.business_ficha_versions ADD CONSTRAINT business_ficha_versions_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.business_ficha_versions ADD CONSTRAINT business_ficha_versions_client_approved_by_fkey FOREIGN KEY (client_approved_by) REFERENCES auth.users(id);

ALTER TABLE public.business_ficha_versions ADD CONSTRAINT business_ficha_versions_tlc_approved_by_fkey FOREIGN KEY (tlc_approved_by) REFERENCES auth.users(id);

ALTER TABLE public.business_locations ADD CONSTRAINT business_locations_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.business_modules ADD CONSTRAINT business_modules_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.business_payment_methods ADD CONSTRAINT business_payment_methods_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.business_presence ADD CONSTRAINT business_presence_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_service_mode_id_fkey FOREIGN KEY (service_mode_id) REFERENCES service_modes(id) ON DELETE RESTRICT;

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_service_mode_same_business_fk FOREIGN KEY (business_id, service_mode_id) REFERENCES service_modes(business_id, id);

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_space_id_fkey FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE RESTRICT;

ALTER TABLE public.consumptions ADD CONSTRAINT consumptions_space_same_business_fk FOREIGN KEY (business_id, space_id) REFERENCES spaces(business_id, id);

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_cut_id_fkey FOREIGN KEY (cut_id) REFERENCES cuts(id) ON DELETE RESTRICT;

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.cut_discrepancies ADD CONSTRAINT cut_discrepancies_related_user_id_fkey FOREIGN KEY (related_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.cuts ADD CONSTRAINT cuts_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.cuts ADD CONSTRAINT cuts_executed_by_fkey FOREIGN KEY (executed_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.cuts ADD CONSTRAINT cuts_operator_user_fkey FOREIGN KEY (operator_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.order_items ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE RESTRICT;

ALTER TABLE public.order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT;

ALTER TABLE public.order_items ADD CONSTRAINT order_items_ready_by_fkey FOREIGN KEY (ready_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.order_items ADD CONSTRAINT order_items_station_id_fkey FOREIGN KEY (station_id) REFERENCES stations(id) ON DELETE RESTRICT;

ALTER TABLE public.order_notification_preferences ADD CONSTRAINT order_notification_preferences_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

ALTER TABLE public.order_notification_preferences ADD CONSTRAINT order_notification_preferences_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id);

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_order_same_business_fk FOREIGN KEY (business_id, order_id) REFERENCES orders(business_id, id) ON DELETE RESTRICT;

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_preparing_by_fkey FOREIGN KEY (preparing_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_ready_by_fkey FOREIGN KEY (ready_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_received_by_fkey FOREIGN KEY (received_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.order_station_work ADD CONSTRAINT order_station_work_station_same_business_fk FOREIGN KEY (business_id, station_id) REFERENCES stations(business_id, id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_cashier_received_by_fkey FOREIGN KEY (cashier_received_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_channel_same_business_fk FOREIGN KEY (business_id, channel_code) REFERENCES business_channels(business_id, channel_code);

ALTER TABLE public.orders ADD CONSTRAINT orders_consumption_id_fkey FOREIGN KEY (consumption_id) REFERENCES consumptions(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_consumption_same_business_fk FOREIGN KEY (business_id, consumption_id) REFERENCES consumptions(business_id, id);

ALTER TABLE public.orders ADD CONSTRAINT orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_delivered_by_fkey FOREIGN KEY (delivered_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_ready_by_fkey FOREIGN KEY (ready_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.orders ADD CONSTRAINT orders_replacement_for_order_id_fkey FOREIGN KEY (replacement_for_order_id) REFERENCES orders(id) ON DELETE RESTRICT;

ALTER TABLE public.payments ADD CONSTRAINT payments_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.payments ADD CONSTRAINT payments_confirmed_by_fkey FOREIGN KEY (confirmed_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.payments ADD CONSTRAINT payments_consumption_id_fkey FOREIGN KEY (consumption_id) REFERENCES consumptions(id) ON DELETE RESTRICT;

ALTER TABLE public.payments ADD CONSTRAINT payments_consumption_same_business_fk FOREIGN KEY (business_id, consumption_id) REFERENCES consumptions(business_id, id);

ALTER TABLE public.payments ADD CONSTRAINT payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.payments ADD CONSTRAINT payments_method_same_business_fk FOREIGN KEY (business_id, method_code) REFERENCES business_payment_methods(business_id, method_code);

ALTER TABLE public.product_categories ADD CONSTRAINT product_categories_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.product_stations ADD CONSTRAINT product_stations_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;

ALTER TABLE public.product_stations ADD CONSTRAINT product_stations_station_id_fkey FOREIGN KEY (station_id) REFERENCES stations(id) ON DELETE RESTRICT;

ALTER TABLE public.products ADD CONSTRAINT products_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.products ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE RESTRICT;

ALTER TABLE public.products ADD CONSTRAINT products_category_same_business_fk FOREIGN KEY (business_id, category_id) REFERENCES product_categories(business_id, id);

ALTER TABLE public.profiles ADD CONSTRAINT profiles_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE RESTRICT;

ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_code_fkey FOREIGN KEY (role_code) REFERENCES roles(code) ON DELETE RESTRICT;

ALTER TABLE public.service_modes ADD CONSTRAINT service_modes_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.spaces ADD CONSTRAINT spaces_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

ALTER TABLE public.spaces ADD CONSTRAINT spaces_business_location_same_business_fk FOREIGN KEY (business_id, location_id) REFERENCES business_locations(business_id, id);

ALTER TABLE public.spaces ADD CONSTRAINT spaces_location_id_fkey FOREIGN KEY (location_id) REFERENCES business_locations(id) ON DELETE RESTRICT;

ALTER TABLE public.stations ADD CONSTRAINT stations_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION private.close_consumption_on_confirmed_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.status = 'CONFIRMED' then
    update public.consumptions
       set status = 'CLOSED',
           closed_at = coalesce(new.confirmed_at, now())
     where id = new.consumption_id
       and status = 'OPEN';
  end if;

  return new;
end;
$function$


;CREATE OR REPLACE FUNCTION private.current_business_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select p.business_id
  from public.profiles p
  where p.id = auth.uid()
    and p.is_active = true
  limit 1;
$function$


;CREATE OR REPLACE FUNCTION private.current_role_code()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select p.role_code
  from public.profiles p
  where p.id = auth.uid()
    and p.is_active = true
  limit 1;
$function$


;CREATE OR REPLACE FUNCTION private.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(private.current_role_code() = 'ADMIN', false);
$function$


;CREATE OR REPLACE FUNCTION private.require_active_user()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select p.id
  from public.profiles p
  where p.id = auth.uid()
    and p.is_active = true
  limit 1;
$function$


;CREATE OR REPLACE FUNCTION private.require_any_role(required_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and p.role_code = any(required_roles)
  );
$function$


;CREATE OR REPLACE FUNCTION private.require_role(required_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and p.role_code = required_role
  );
$function$


;CREATE OR REPLACE FUNCTION private.sync_order_station_work()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE OR REPLACE FUNCTION private.write_audit(p_business_id uuid, p_action text, p_entity_type text, p_entity_id text, p_before jsonb, p_after jsonb, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.audit_log (
    business_id, actor_user_id, action, entity_type, entity_id,
    before_data, after_data, reason
  )
  values (
    p_business_id, auth.uid(), p_action, p_entity_type, p_entity_id,
    p_before, p_after, p_reason
  );
end;
$function$


;CREATE OR REPLACE FUNCTION public.add_order_item(p_order_id uuid, p_product_id uuid, p_station_id uuid, p_quantity numeric, p_notes text DEFAULT NULL::text)
 RETURNS order_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare v_business uuid:=private.current_business_id(); v_order public.orders; v_product public.products; v_item public.order_items;
begin
 if private.current_role_code() not in ('ADMIN','CAJA','MESERO') then raise exception 'ROLE_NOT_ALLOWED'; end if;
 select * into v_order from public.orders where id=p_order_id and business_id=v_business for update;
 if not found then raise exception 'ORDER_NOT_FOUND'; end if;
 if v_order.status not in ('NEW','RECEIVED') then raise exception 'ORDER_NOT_MODIFIABLE'; end if;
 select * into v_product from public.products where id=p_product_id and business_id=v_business and is_active and is_available;
 if not found then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
 if not exists(select 1 from public.product_stations where product_id=p_product_id and station_id=p_station_id) then raise exception 'PRODUCT_STATION_NOT_CONFIGURED'; end if;
 if not exists(select 1 from public.stations where id=p_station_id and business_id=v_business and is_active) then raise exception 'STATION_NOT_AVAILABLE'; end if;
 if p_quantity<=0 then raise exception 'INVALID_QUANTITY'; end if;
 insert into public.order_items(order_id,product_id,station_id,quantity,unit_price,notes)
 values(p_order_id,p_product_id,p_station_id,p_quantity,v_product.price,p_notes) returning * into v_item;
 perform private.write_audit(v_business,'ORDER_ITEM_ADDED','ORDER_ITEM',v_item.id::text,null,to_jsonb(v_item),null);
 return v_item;
end; $function$


;CREATE OR REPLACE FUNCTION public.cancel_consumption(p_consumption_id uuid, p_reason text)
 RETURNS consumptions
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
$function$


;CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid, p_reason text)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE OR REPLACE FUNCTION public.close_consumption(p_consumption_id uuid)
 RETURNS consumptions
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
$function$


;CREATE OR REPLACE FUNCTION public.confirm_payment(p_payment_id uuid)
 RETURNS payments
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
$function$


;CREATE OR REPLACE FUNCTION public.create_order(p_consumption_id uuid, p_channel_code text, p_notes text DEFAULT NULL::text)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare v_business uuid:=private.current_business_id(); v_consumption public.consumptions; v_order public.orders;
begin
 if private.current_role_code() not in ('ADMIN','CAJA','MESERO') then raise exception 'ROLE_NOT_ALLOWED'; end if;
 select * into v_consumption from public.consumptions where id=p_consumption_id and business_id=v_business for update;
 if not found then raise exception 'CONSUMPTION_NOT_FOUND'; end if;
 if v_consumption.status<>'OPEN' then raise exception 'CONSUMPTION_NOT_OPEN'; end if;
 if not exists(select 1 from public.business_channels where business_id=v_business and channel_code=p_channel_code and is_enabled) then raise exception 'CHANNEL_NOT_ENABLED'; end if;
 insert into public.orders(business_id,consumption_id,channel_code,status,notes,created_by)
 values(v_business,p_consumption_id,p_channel_code,'NEW',p_notes,auth.uid()) returning * into v_order;
 perform private.write_audit(v_business,'ORDER_CREATED','ORDER',v_order.id::text,null,to_jsonb(v_order),null);
 return v_order;
end; $function$


;CREATE OR REPLACE FUNCTION public.create_payment(p_consumption_id uuid, p_method_code text, p_amount numeric, p_external_reference text DEFAULT NULL::text)
 RETURNS payments
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
  IF p_method_code NOT IN ('CASH', 'CARD', 'TRANSFER') THEN
    RAISE EXCEPTION 'PAYMENT_METHOD_NOT_SUPPORTED';
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
$function$


;CREATE OR REPLACE FUNCTION public.deliver_order(p_order_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_order public.orders;
  v_before jsonb;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
    and business_id = private.current_business_id()
  for update;

  if not found then raise exception 'ORDER_NOT_FOUND'; end if;

  if private.current_role_code() not in ('ADMIN','MESERO','CAJA') then
    raise exception 'ROLE_NOT_ALLOWED';
  end if;

  if v_order.status <> 'READY' then
    raise exception 'INVALID_ORDER_STATE';
  end if;

  if exists (
    select 1
    from public.order_items oi
    where oi.order_id = v_order.id
      and oi.ready_at is null
  ) then
    raise exception 'ORDER_HAS_UNREADY_ITEMS';
  end if;

  v_before := to_jsonb(v_order);

  update public.orders
     set status = 'DELIVERED',
         delivered_at = now(),
         delivered_by = auth.uid(),
         updated_at = now()
   where id = p_order_id
   returning * into v_order;

  perform private.write_audit(
    v_order.business_id, 'ORDER_DELIVERED', 'ORDER', v_order.id::text,
    v_before, to_jsonb(v_order), null
  );

  return v_order;
end;
$function$


;CREATE OR REPLACE FUNCTION public.execute_cut(p_cut_id uuid, p_totals jsonb)
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

  if private.current_role_code() <> 'ADMIN' then
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
$function$


;CREATE OR REPLACE FUNCTION public.get_print_document(p_document_type text, p_order_id uuid DEFAULT NULL::uuid, p_consumption_id uuid DEFAULT NULL::uuid, p_cut_id uuid DEFAULT NULL::uuid, p_station_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_business_id uuid := private.current_business_id();
  v_role text := private.current_role_code();
  v_document_type text := upper(trim(p_document_type));
  v_order record;
  v_consumption record;
  v_cut record;
  v_station record;
  v_items jsonb;
  v_orders jsonb;
  v_consumptions jsonb;
  v_total numeric(14,2);
begin
  if v_role not in ('ADMIN','CAJA') then
    raise exception using errcode='42501', message='PRINT_ROLE_NOT_ALLOWED';
  end if;

  if v_document_type = 'COMANDA' then
    if p_order_id is null then
      raise exception using errcode='22023', message='PRINT_ORDER_REQUIRED';
    end if;
    if p_station_id is null then
      raise exception using errcode='22023', message='PRINT_STATION_REQUIRED';
    end if;

    select o.id,o.business_id,o.order_number,o.consumption_id
      into v_order
    from public.orders o
    where o.id=p_order_id and o.business_id=v_business_id;

    if not found then
      raise exception using errcode='P0002', message='PRINT_ORDER_NOT_FOUND';
    end if;

    select s.id,s.code,s.name
      into v_station
    from public.stations s
    where s.id=p_station_id and s.business_id=v_business_id and s.is_active;

    if not found then
      raise exception using errcode='P0002', message='PRINT_STATION_NOT_FOUND';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
      'product_name',p.name,
      'quantity',oi.quantity,
      'notes',nullif(trim(coalesce(oi.notes,'')),'')
    ) order by oi.id),'[]'::jsonb)
    into v_items
    from public.order_items oi
    join public.products p on p.id=oi.product_id
    where oi.order_id=v_order.id
      and oi.station_id=v_station.id;

    if jsonb_array_length(v_items)=0 then
      raise exception using errcode='P0002', message='PRINT_STATION_HAS_NO_ITEMS';
    end if;

    perform private.write_audit(
      v_business_id,'PRINT_COMANDA_REQUESTED','ORDER',v_order.id::text,
      null,jsonb_build_object('document_type','COMANDA','order_number',v_order.order_number,'station_id',v_station.id,'station_code',v_station.code),null
    );

    return jsonb_build_object(
      'document_type','COMANDA',
      'business_id',v_business_id,
      'order_id',v_order.id,
      'order_number',v_order.order_number,
      'station_id',v_station.id,
      'station_code',v_station.code,
      'station_name',v_station.name,
      'items',v_items
    );

  elsif v_document_type = 'CONSUMO' then
    if p_consumption_id is null then
      raise exception using errcode='22023', message='PRINT_CONSUMPTION_REQUIRED';
    end if;

    select c.id,c.business_id,c.consumption_number,c.status
      into v_consumption
    from public.consumptions c
    where c.id=p_consumption_id and c.business_id=v_business_id;

    if not found then
      raise exception using errcode='P0002', message='PRINT_CONSUMPTION_NOT_FOUND';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
      'order_id',x.order_id,
      'order_number',x.order_number,
      'total',x.total
    ) order by x.order_number),'[]'::jsonb)
    into v_orders
    from (
      select o.id order_id,o.order_number,
             coalesce(sum(oi.quantity*oi.unit_price),0)::numeric(14,2) total
      from public.orders o
      left join public.order_items oi on oi.order_id=o.id
      where o.business_id=v_business_id
        and o.consumption_id=v_consumption.id
        and o.status <> 'CANCELLED'
      group by o.id,o.order_number
    ) x;

    select coalesce(sum((z->>'total')::numeric),0)::numeric(14,2)
      into v_total
    from jsonb_array_elements(v_orders) z;

    perform private.write_audit(
      v_business_id,'PRINT_CONSUMO_REQUESTED','CONSUMPTION',v_consumption.id::text,
      null,jsonb_build_object('document_type','CONSUMO','consumption_number',v_consumption.consumption_number),null
    );

    return jsonb_build_object(
      'document_type','CONSUMO',
      'business_id',v_business_id,
      'consumption_id',v_consumption.id,
      'consumption_number',v_consumption.consumption_number,
      'status',v_consumption.status,
      'orders',v_orders,
      'total',v_total
    );

  elsif v_document_type = 'CORTE' then
    if p_cut_id is null then
      raise exception using errcode='22023', message='PRINT_CUT_REQUIRED';
    end if;

    select c.id,c.business_id,c.status,c.opened_at,c.executed_at,c.totals
      into v_cut
    from public.cuts c
    where c.id=p_cut_id and c.business_id=v_business_id;

    if not found then
      raise exception using errcode='P0002', message='PRINT_CUT_NOT_FOUND';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
      'consumption_id',z->>'consumption_id',
      'consumption_number',z->>'consumption_number',
      'total',coalesce((z->>'total_paid')::numeric,0)::numeric(14,2)
    ) order by (z->>'consumption_number')::bigint),'[]'::jsonb)
      into v_consumptions
    from jsonb_array_elements(coalesce(v_cut.totals->'consumptions','[]'::jsonb)) z;

    v_total := coalesce((v_cut.totals->>'total')::numeric,0)::numeric(14,2);

    perform private.write_audit(
      v_business_id,'PRINT_CORTE_REQUESTED','CUT',v_cut.id::text,
      null,jsonb_build_object('document_type','CORTE','cut_status',v_cut.status),null
    );

    return jsonb_build_object(
      'document_type','CORTE',
      'business_id',v_business_id,
      'cut_id',v_cut.id,
      'status',v_cut.status,
      'opened_at',v_cut.opened_at,
      'executed_at',v_cut.executed_at,
      'consumptions',v_consumptions,
      'total',v_total
    );

  else
    raise exception using errcode='22023', message='PRINT_DOCUMENT_TYPE_NOT_SUPPORTED';
  end if;
end;
$function$


;CREATE OR REPLACE FUNCTION public.mark_order_ready(p_order_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE OR REPLACE FUNCTION public.mark_order_station_ready(p_order_item_id uuid)
 RETURNS order_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE OR REPLACE FUNCTION public.open_consumption(p_space_id uuid, p_service_mode_id uuid)
 RETURNS consumptions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_business uuid := private.current_business_id();
  v_consumption public.consumptions;
begin
  if private.current_role_code() not in ('ADMIN','CAJA','MESERO') then
    raise exception 'ROLE_NOT_ALLOWED';
  end if;

  if p_space_id is not null
     and not exists (
       select 1
       from public.spaces s
       where s.id = p_space_id
         and s.business_id = v_business
         and s.is_active
     ) then
    raise exception 'SPACE_NOT_AVAILABLE';
  end if;

  if p_service_mode_id is not null
     and not exists (
       select 1
       from public.service_modes sm
       where sm.id = p_service_mode_id
         and sm.business_id = v_business
         and sm.is_active
     ) then
    raise exception 'SERVICE_MODE_NOT_AVAILABLE';
  end if;

  insert into public.consumptions(
    business_id, space_id, service_mode_id, status, created_by
  )
  values(
    v_business, p_space_id, p_service_mode_id, 'OPEN', auth.uid()
  )
  returning * into v_consumption;

  perform private.write_audit(
    v_business,
    'CONSUMPTION_OPENED',
    'CONSUMPTION',
    v_consumption.id::text,
    null,
    to_jsonb(v_consumption),
    null
  );

  return v_consumption;
end;
$function$


;CREATE OR REPLACE FUNCTION public.open_cut(p_operator_user_id uuid DEFAULT auth.uid())
 RETURNS cuts
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
$function$


;CREATE OR REPLACE FUNCTION public.receive_order(p_order_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_order public.orders;
  v_before jsonb;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
    AND business_id = private.current_business_id()
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  IF private.current_role_code() NOT IN ('ADMIN','CAJA','MESERO','COCINA','BARRA') THEN
    RAISE EXCEPTION 'ROLE_NOT_ALLOWED';
  END IF;

  IF v_order.status <> 'NEW' THEN
    RAISE EXCEPTION 'INVALID_ORDER_STATE';
  END IF;

  v_before := to_jsonb(v_order);

  UPDATE public.orders
     SET status = 'RECEIVED',
         received_at = now(),
         updated_at = now()
   WHERE id = p_order_id
   RETURNING * INTO v_order;

  PERFORM private.write_audit(
    v_order.business_id, 'ORDER_RECEIVED', 'ORDER', v_order.id::text,
    v_before, to_jsonb(v_order), null
  );

  RETURN v_order;
END;
$function$


;CREATE OR REPLACE FUNCTION public.receive_order_station(p_order_id uuid, p_station_id uuid)
 RETURNS order_station_work
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE OR REPLACE FUNCTION public.receive_prepared_order(p_order_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE OR REPLACE FUNCTION public.replace_order(p_order_id uuid, p_reason text, p_notes text, p_items jsonb)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_business uuid := private.current_business_id();
  v_order public.orders;
  v_replacement public.orders;
  v_consumption public.consumptions;
  v_before jsonb;
  v_item jsonb;
  v_product public.products;
  v_station public.stations;
  v_product_id uuid;
  v_station_id uuid;
  v_quantity numeric;
  v_notes text;
begin
  if private.current_role_code() not in ('ADMIN','CAJA') then
    raise exception 'ROLE_NOT_ALLOWED';
  end if;

  if nullif(trim(p_reason),'') is null then
    raise exception 'CANCELLATION_REASON_REQUIRED';
  end if;

  if jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'REPLACEMENT_ITEMS_REQUIRED';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and business_id = v_business
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  select * into v_consumption
  from public.consumptions
  where id = v_order.consumption_id
    and business_id = v_business
  for update;

  if not found or v_consumption.status <> 'OPEN' then
    raise exception 'CONSUMPTION_NOT_OPEN';
  end if;

  if v_order.status not in ('NEW','RECEIVED') then
    raise exception 'ORDER_NOT_MODIFIABLE';
  end if;

  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_station_id := (v_item->>'station_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    if v_quantity is null or v_quantity <= 0 then
      raise exception 'INVALID_QUANTITY';
    end if;

    select * into v_product
    from public.products
    where id = v_product_id
      and business_id = v_business
      and is_active
      and is_available;

    if not found then
      raise exception 'PRODUCT_NOT_AVAILABLE';
    end if;

    select * into v_station
    from public.stations
    where id = v_station_id
      and business_id = v_business
      and is_active;

    if not found then
      raise exception 'STATION_NOT_AVAILABLE';
    end if;

    if not exists (
      select 1
      from public.product_stations ps
      where ps.product_id = v_product_id
        and ps.station_id = v_station_id
    ) then
      raise exception 'PRODUCT_STATION_NOT_CONFIGURED';
    end if;
  end loop;

  v_before := to_jsonb(v_order);

  update public.orders
  set status = 'CANCELLED',
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      cancellation_reason = trim(p_reason),
      updated_at = now()
  where id = p_order_id;

  insert into public.orders (
    business_id,
    consumption_id,
    channel_code,
    status,
    notes,
    created_by,
    replacement_for_order_id
  )
  values (
    v_business,
    v_order.consumption_id,
    v_order.channel_code,
    'NEW',
    coalesce(p_notes, v_order.notes),
    auth.uid(),
    v_order.id
  )
  returning * into v_replacement;

  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_station_id := (v_item->>'station_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;
    v_notes := nullif(v_item->>'notes','');

    insert into public.order_items (
      order_id, product_id, station_id, quantity, unit_price, notes
    )
    select
      v_replacement.id,
      v_product_id,
      v_station_id,
      v_quantity,
      p.price,
      v_notes
    from public.products p
    where p.id = v_product_id
      and p.business_id = v_business
      and p.is_active
      and p.is_available;
  end loop;

  perform private.write_audit(
    v_business,
    'ORDER_CANCELLED_FOR_REPLACEMENT',
    'ORDER',
    v_order.id::text,
    v_before,
    to_jsonb((select o from public.orders o where o.id = v_order.id)),
    trim(p_reason)
  );

  perform private.write_audit(
    v_business,
    'ORDER_REPLACEMENT_CREATED',
    'ORDER',
    v_replacement.id::text,
    null,
    to_jsonb(v_replacement),
    trim(p_reason)
  );

  return v_replacement;
end;
$function$


;CREATE OR REPLACE FUNCTION public.request_consumption_close(p_consumption_id uuid)
 RETURNS consumptions
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
$function$


;CREATE OR REPLACE FUNCTION public.set_order_notification_preference(p_order_id uuid, p_channel_code text, p_target text, p_is_active boolean DEFAULT true)
 RETURNS order_notification_preferences
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_business uuid := private.current_business_id();
  v_order public.orders;
  v_pref public.order_notification_preferences;
begin
  if private.current_role_code() not in ('ADMIN','CAJA','MESERO') then
    raise exception 'ROLE_NOT_ALLOWED';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
    and business_id = v_business
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  if p_channel_code is null or length(trim(p_channel_code)) = 0 then
    raise exception 'NOTIFICATION_CHANNEL_REQUIRED';
  end if;

  if p_target is null or length(trim(p_target)) = 0 then
    raise exception 'NOTIFICATION_TARGET_REQUIRED';
  end if;

  insert into public.order_notification_preferences(
    order_id, business_id, channel_code, target, is_active
  )
  values(
    v_order.id, v_order.business_id, trim(p_channel_code), trim(p_target), coalesce(p_is_active, true)
  )
  on conflict (order_id) do update
    set business_id = excluded.business_id,
        channel_code = excluded.channel_code,
        target = excluded.target,
        is_active = excluded.is_active,
        updated_at = now()
  returning * into v_pref;

  return v_pref;
end;
$function$


;CREATE OR REPLACE FUNCTION public.set_order_notification_preference_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$


;CREATE OR REPLACE FUNCTION public.start_order_preparation(p_order_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
declare
  v_order public.orders;
  v_before jsonb;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
    and business_id = private.current_business_id()
  for update;

  if not found then raise exception 'ORDER_NOT_FOUND'; end if;

  if private.current_role_code() not in ('ADMIN','COCINA','BARRA') then
    raise exception 'ROLE_NOT_ALLOWED';
  end if;

  if v_order.status <> 'RECEIVED' then
    raise exception 'INVALID_ORDER_STATE';
  end if;

  v_before := to_jsonb(v_order);

  update public.orders
     set status = 'PREPARING',
         preparing_at = now(),
         updated_at = now()
   where id = p_order_id
   returning * into v_order;

  perform private.write_audit(
    v_order.business_id, 'ORDER_PREPARING', 'ORDER', v_order.id::text,
    v_before, to_jsonb(v_order), null
  );

  return v_order;
end;
$function$


;CREATE OR REPLACE FUNCTION public.start_order_station_preparation(p_order_id uuid, p_station_id uuid)
 RETURNS order_station_work
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
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
$function$


;CREATE TRIGGER order_items_sync_station_work AFTER INSERT ON order_items FOR EACH ROW EXECUTE FUNCTION private.sync_order_station_work();

CREATE TRIGGER trg_order_notification_preferences_updated_at BEFORE UPDATE ON order_notification_preferences FOR EACH ROW EXECUTE FUNCTION set_order_notification_preference_updated_at();

CREATE TRIGGER trg_payment_confirmed_closes_consumption AFTER INSERT OR UPDATE OF status, confirmed_at ON payments FOR EACH ROW WHEN (new.status = 'CONFIRMED'::text) EXECUTE FUNCTION private.close_consumption_on_confirmed_payment();

CREATE POLICY audit_select_same_business ON public.audit_log AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = ( SELECT private.current_business_id() AS current_business_id)));

CREATE POLICY channels_all_own ON public.business_channels AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY ficha_select_own ON public.business_ficha_versions AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = ( SELECT private.current_business_id() AS current_business_id)));

CREATE POLICY business_locations_all_own ON public.business_locations AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY modules_all_own ON public.business_modules AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY payment_methods_all_own ON public.business_payment_methods AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY presence_all_own ON public.business_presence AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY businesses_select_own ON public.businesses AS PERMISSIVE FOR SELECT TO authenticated USING ((id = ( SELECT private.current_business_id() AS current_business_id)));

CREATE POLICY consumptions_select_same_business ON public.consumptions AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = private.current_business_id()));

CREATE POLICY cut_discrepancies_insert_authorized ON public.cut_discrepancies AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND (( SELECT private.current_role_code() AS current_role_code) = ANY (ARRAY['ADMIN'::text, 'CAJA'::text])) AND (recorded_by = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM cuts c
  WHERE ((c.id = cut_discrepancies.cut_id) AND (c.business_id = ( SELECT private.current_business_id() AS current_business_id))))) AND ((related_user_id IS NULL) OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = cut_discrepancies.related_user_id) AND (p.business_id = ( SELECT private.current_business_id() AS current_business_id)) AND p.is_active))))));

CREATE POLICY cut_discrepancies_select_same_business ON public.cut_discrepancies AS PERMISSIVE FOR SELECT TO authenticated USING (((business_id = private.current_business_id()) AND (private.current_role_code() = ANY (ARRAY['ADMIN'::text, 'CAJA'::text]))));

CREATE POLICY cuts_insert_same_business ON public.cuts AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (false);

CREATE POLICY cuts_select_same_business ON public.cuts AS PERMISSIVE FOR SELECT TO authenticated USING (((business_id = private.current_business_id()) AND (private.current_role_code() = ANY (ARRAY['ADMIN'::text, 'CAJA'::text]))));

CREATE POLICY order_items_select_same_business ON public.order_items AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_items.order_id) AND (o.business_id = private.current_business_id())))));

CREATE POLICY order_notification_preferences_select_same_business ON public.order_notification_preferences AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = private.current_business_id()));

CREATE POLICY order_station_work_select_authorized ON public.order_station_work AS PERMISSIVE FOR SELECT TO authenticated USING (((business_id = private.current_business_id()) AND ((private.current_role_code() = ANY (ARRAY['ADMIN'::text, 'CAJA'::text])) OR (EXISTS ( SELECT 1
   FROM stations s
  WHERE ((s.id = order_station_work.station_id) AND (s.business_id = order_station_work.business_id) AND (s.station_type = private.current_role_code())))))));

CREATE POLICY orders_select_same_business ON public.orders AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = private.current_business_id()));

CREATE POLICY payments_select_same_business ON public.payments AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = private.current_business_id()));

CREATE POLICY product_categories_same_business ON public.product_categories AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY product_stations_same_business ON public.product_stations AS PERMISSIVE FOR ALL TO authenticated USING ((( SELECT private.is_admin() AS is_admin) AND (EXISTS ( SELECT 1
   FROM products p
  WHERE ((p.id = product_stations.product_id) AND (p.business_id = ( SELECT private.current_business_id() AS current_business_id))))))) WITH CHECK ((( SELECT private.is_admin() AS is_admin) AND (EXISTS ( SELECT 1
   FROM (products p
     JOIN stations s ON ((s.id = product_stations.station_id)))
  WHERE ((p.id = product_stations.product_id) AND (p.business_id = ( SELECT private.current_business_id() AS current_business_id)) AND (s.business_id = ( SELECT private.current_business_id() AS current_business_id)))))));

CREATE POLICY products_same_business ON public.products AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY profiles_insert_admin ON public.profiles AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY profiles_select_own_business ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING ((business_id = ( SELECT private.current_business_id() AS current_business_id)));

CREATE POLICY profiles_update_admin ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY roles_select_authenticated ON public.roles AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY service_modes_all_own ON public.service_modes AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY spaces_all_own ON public.spaces AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

CREATE POLICY stations_all_own ON public.stations AS PERMISSIVE FOR ALL TO authenticated USING (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin))) WITH CHECK (((business_id = ( SELECT private.current_business_id() AS current_business_id)) AND ( SELECT private.is_admin() AS is_admin)));

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.business_channels ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.business_ficha_versions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.business_locations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.business_modules ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.business_payment_methods ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.business_presence ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.consumptions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cut_discrepancies ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cuts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_notification_preferences ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_station_work ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_stations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.service_modes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;

-- Remove target-role defaults, then restore only the privileges observed on the source schema.
REVOKE ALL ON SCHEMA public, private FROM PUBLIC, anon, authenticated, service_role, postgres;
REVOKE ALL ON ALL TABLES IN SCHEMA public, private FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public, private FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public, private FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA private TO authenticated;

GRANT USAGE ON SCHEMA public TO PUBLIC;

GRANT USAGE ON SCHEMA public TO postgres;

GRANT USAGE ON SCHEMA public TO anon;

GRANT USAGE ON SCHEMA public TO authenticated;

GRANT USAGE ON SCHEMA public TO service_role;

GRANT MAINTAIN, SELECT ON TABLE public.audit_log TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.audit_log TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.business_channels TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.business_channels TO service_role;

GRANT SELECT ON TABLE public.business_ficha_versions TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.business_ficha_versions TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.business_locations TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.business_locations TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.business_modules TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.business_modules TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.business_payment_methods TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.business_payment_methods TO service_role;

GRANT SELECT ON TABLE public.businesses TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.businesses TO service_role;

GRANT MAINTAIN, SELECT ON TABLE public.consumptions TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.consumptions TO service_role;

GRANT MAINTAIN, SELECT ON TABLE public.cuts TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cuts TO service_role;

GRANT MAINTAIN, SELECT ON TABLE public.order_items TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.order_items TO service_role;

GRANT SELECT ON TABLE public.order_station_work TO authenticated;

GRANT MAINTAIN, SELECT ON TABLE public.orders TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.orders TO service_role;

GRANT MAINTAIN, SELECT ON TABLE public.payments TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payments TO service_role;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.product_categories TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.product_categories TO service_role;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.product_stations TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.product_stations TO service_role;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.products TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.products TO service_role;

GRANT INSERT, SELECT, UPDATE ON TABLE public.profiles TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO service_role;

GRANT SELECT ON TABLE public.roles TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.roles TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.service_modes TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.service_modes TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.spaces TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.spaces TO service_role;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.stations TO authenticated;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.stations TO service_role;

GRANT EXECUTE ON FUNCTION private.close_consumption_on_confirmed_payment() TO authenticated;

GRANT EXECUTE ON FUNCTION private.current_business_id() TO authenticated;

GRANT EXECUTE ON FUNCTION private.current_role_code() TO authenticated;

GRANT EXECUTE ON FUNCTION private.is_admin() TO authenticated;

GRANT EXECUTE ON FUNCTION private.require_active_user() TO authenticated;

GRANT EXECUTE ON FUNCTION private.require_any_role(required_roles text[]) TO authenticated;

GRANT EXECUTE ON FUNCTION private.require_role(required_role text) TO authenticated;

GRANT EXECUTE ON FUNCTION private.write_audit(p_business_id uuid, p_action text, p_entity_type text, p_entity_id text, p_before jsonb, p_after jsonb, p_reason text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.add_order_item(p_order_id uuid, p_product_id uuid, p_station_id uuid, p_quantity numeric, p_notes text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.cancel_consumption(p_consumption_id uuid, p_reason text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.cancel_order(p_order_id uuid, p_reason text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.close_consumption(p_consumption_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.confirm_payment(p_payment_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_order(p_consumption_id uuid, p_channel_code text, p_notes text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_payment(p_consumption_id uuid, p_method_code text, p_amount numeric, p_external_reference text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.deliver_order(p_order_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.execute_cut(p_cut_id uuid, p_totals jsonb) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_print_document(p_document_type text, p_order_id uuid, p_consumption_id uuid, p_cut_id uuid, p_station_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.mark_order_ready(p_order_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.mark_order_station_ready(p_order_item_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.open_consumption(p_space_id uuid, p_service_mode_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.open_cut(p_operator_user_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.receive_order_station(p_order_id uuid, p_station_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.receive_prepared_order(p_order_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.replace_order(p_order_id uuid, p_reason text, p_notes text, p_items jsonb) TO authenticated;

GRANT EXECUTE ON FUNCTION public.request_consumption_close(p_consumption_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.set_order_notification_preference(p_order_id uuid, p_channel_code text, p_target text, p_is_active boolean) TO authenticated;

GRANT EXECUTE ON FUNCTION public.set_order_notification_preference_updated_at() TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.start_order_station_preparation(p_order_id uuid, p_station_id uuid) TO authenticated;
