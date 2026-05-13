--
-- PostgreSQL database dump
--

\restrict Xb7SG4I4ncfWnt2QtcSvTyKzrkcobxE78eAyEqwfVpO9kPpX5GFmBfKESbw7Ney

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3 (Ubuntu 18.3-1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: get_unit_price(uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_unit_price(p_item_id uuid, p_date date) RETURNS integer
    LANGUAGE sql STABLE
    AS $$
  select unit_price
  from public.item_prices
  where item_id = p_item_id
    and effective_from <= p_date
  order by effective_from desc
  limit 1;
$$;


ALTER FUNCTION public.get_unit_price(p_item_id uuid, p_date date) OWNER TO postgres;

--
-- Name: is_factory_member(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_factory_member(p_factory_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select exists (
    select 1 from public.factory_members
    where factory_id = p_factory_id and user_id = auth.uid()
  );
$$;


ALTER FUNCTION public.is_factory_member(p_factory_id uuid) OWNER TO postgres;

--
-- Name: my_role(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.my_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select role from public.profiles where id = auth.uid();
$$;


ALTER FUNCTION public.my_role() OWNER TO postgres;

--
-- Name: process_inventory_out(uuid, integer, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_current_qty   int;
  v_factory_id    uuid;
  v_client_id     uuid;
  v_item_id       uuid;
begin
  -- 1. 해당 행을 잠금 (다른 트랜잭션은 여기서 대기)
  select quantity, factory_id, client_id, item_id
  into v_current_qty, v_factory_id, v_client_id, v_item_id
  from public.inventory
  where id = p_inventory_id
  for update;  -- 🔒 핵심

  -- 2. 재고 부족 체크
  if v_current_qty < p_quantity then
    raise exception '재고 부족: 현재 % 개, 요청 % 개', v_current_qty, p_quantity;
  end if;

  -- 3. 재고 차감
  update public.inventory
  set quantity   = quantity - p_quantity,
      updated_at = now()
  where id = p_inventory_id;

  -- 4. 로그 기록
  insert into public.inventory_logs (
    inventory_id, factory_id, client_id, item_id,
    log_type, quantity, created_by, note
  ) values (
    p_inventory_id, v_factory_id, v_client_id, v_item_id,
    'out', p_quantity, p_created_by, p_note
  );

  return json_build_object('success', true, 'remaining', v_current_qty - p_quantity);

exception
  when others then
    -- 트랜잭션 자동 롤백됨
    return json_build_object('success', false, 'error', sqlerrm);
end;
$$;


ALTER FUNCTION public.process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    factory_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    factory_id uuid NOT NULL,
    name text NOT NULL,
    business_number text,
    email text,
    manager_name text,
    manager_phone text,
    contract_start_date date,
    contract_end_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: factories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.factories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    phone text,
    address text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.factories OWNER TO postgres;

--
-- Name: factory_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.factory_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    factory_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.factory_members OWNER TO postgres;

--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    factory_id uuid NOT NULL,
    client_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.inventory OWNER TO postgres;

--
-- Name: inventory_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    inventory_id uuid NOT NULL,
    factory_id uuid NOT NULL,
    client_id uuid NOT NULL,
    item_id uuid NOT NULL,
    log_type text NOT NULL,
    quantity integer NOT NULL,
    processed_at timestamp with time zone DEFAULT now() NOT NULL,
    note text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT inventory_logs_log_type_check CHECK ((log_type = ANY (ARRAY['in'::text, 'out'::text]))),
    CONSTRAINT inventory_logs_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.inventory_logs OWNER TO postgres;

--
-- Name: invoice_attachments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    file_url text NOT NULL,
    file_name text,
    mime_type text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.invoice_attachments OWNER TO postgres;

--
-- Name: invoice_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    item_name_ko text NOT NULL,
    item_name_en text,
    item_name_zh text,
    category_name text,
    unit_price integer DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.invoice_items OWNER TO postgres;

--
-- Name: invoice_memos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_memos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    title text,
    content text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.invoice_memos OWNER TO postgres;

--
-- Name: invoices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    factory_id uuid NOT NULL,
    client_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    subtotal integer DEFAULT 0 NOT NULL,
    discount integer DEFAULT 0 NOT NULL,
    vat integer DEFAULT 0 NOT NULL,
    total integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    snapshot_factory jsonb,
    snapshot_client jsonb,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT invoices_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'sent'::text, 'paid'::text])))
);


ALTER TABLE public.invoices OWNER TO postgres;

--
-- Name: item_prices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.item_prices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    item_id uuid NOT NULL,
    unit_price integer DEFAULT 0 NOT NULL,
    effective_from date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.item_prices OWNER TO postgres;

--
-- Name: items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    factory_id uuid NOT NULL,
    name_ko text NOT NULL,
    name_en text,
    name_zh text,
    nickname text,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.items OWNER TO postgres;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    role text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['super_admin'::text, 'factory_admin'::text, 'worker'::text])))
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: factories factories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factories
    ADD CONSTRAINT factories_pkey PRIMARY KEY (id);


--
-- Name: factory_members factory_members_factory_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factory_members
    ADD CONSTRAINT factory_members_factory_id_user_id_key UNIQUE (factory_id, user_id);


--
-- Name: factory_members factory_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factory_members
    ADD CONSTRAINT factory_members_pkey PRIMARY KEY (id);


--
-- Name: inventory inventory_factory_id_client_id_item_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_factory_id_client_id_item_id_key UNIQUE (factory_id, client_id, item_id);


--
-- Name: inventory_logs inventory_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_logs
    ADD CONSTRAINT inventory_logs_pkey PRIMARY KEY (id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);


--
-- Name: invoice_attachments invoice_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_attachments
    ADD CONSTRAINT invoice_attachments_pkey PRIMARY KEY (id);


--
-- Name: invoice_items invoice_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (id);


--
-- Name: invoice_memos invoice_memos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_memos
    ADD CONSTRAINT invoice_memos_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: item_prices item_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_prices
    ADD CONSTRAINT item_prices_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: categories_factory_id_sort_order_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX categories_factory_id_sort_order_idx ON public.categories USING btree (factory_id, sort_order);


--
-- Name: clients_factory_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX clients_factory_id_idx ON public.clients USING btree (factory_id);


--
-- Name: factories_deleted_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX factories_deleted_at_idx ON public.factories USING btree (deleted_at);


--
-- Name: factory_members_factory_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX factory_members_factory_id_idx ON public.factory_members USING btree (factory_id);


--
-- Name: factory_members_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX factory_members_user_id_idx ON public.factory_members USING btree (user_id);


--
-- Name: inventory_factory_id_client_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX inventory_factory_id_client_id_idx ON public.inventory USING btree (factory_id, client_id);


--
-- Name: inventory_logs_factory_id_processed_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX inventory_logs_factory_id_processed_at_idx ON public.inventory_logs USING btree (factory_id, processed_at);


--
-- Name: inventory_logs_inventory_id_processed_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX inventory_logs_inventory_id_processed_at_idx ON public.inventory_logs USING btree (inventory_id, processed_at);


--
-- Name: invoice_memos_invoice_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX invoice_memos_invoice_id_idx ON public.invoice_memos USING btree (invoice_id);


--
-- Name: invoices_factory_id_period_start_period_end_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX invoices_factory_id_period_start_period_end_idx ON public.invoices USING btree (factory_id, period_start, period_end);


--
-- Name: item_prices_item_id_effective_from_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX item_prices_item_id_effective_from_idx ON public.item_prices USING btree (item_id, effective_from DESC);


--
-- Name: items_category_id_sort_order_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX items_category_id_sort_order_idx ON public.items USING btree (category_id, sort_order);


--
-- Name: items_factory_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX items_factory_id_idx ON public.items USING btree (factory_id);


--
-- Name: categories categories_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: clients clients_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: factory_members factory_members_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factory_members
    ADD CONSTRAINT factory_members_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: factory_members factory_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factory_members
    ADD CONSTRAINT factory_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: inventory inventory_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: inventory inventory_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: inventory inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;


--
-- Name: inventory_logs inventory_logs_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_logs
    ADD CONSTRAINT inventory_logs_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: inventory_logs inventory_logs_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_logs
    ADD CONSTRAINT inventory_logs_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: inventory_logs inventory_logs_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_logs
    ADD CONSTRAINT inventory_logs_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: inventory_logs inventory_logs_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_logs
    ADD CONSTRAINT inventory_logs_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id) ON DELETE CASCADE;


--
-- Name: inventory_logs inventory_logs_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_logs
    ADD CONSTRAINT inventory_logs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;


--
-- Name: invoice_attachments invoice_attachments_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_attachments
    ADD CONSTRAINT invoice_attachments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;


--
-- Name: invoice_items invoice_items_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;


--
-- Name: invoice_memos invoice_memos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_memos
    ADD CONSTRAINT invoice_memos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: invoice_memos invoice_memos_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_memos
    ADD CONSTRAINT invoice_memos_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;


--
-- Name: invoices invoices_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: invoices invoices_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: invoices invoices_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: item_prices item_prices_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_prices
    ADD CONSTRAINT item_prices_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;


--
-- Name: items items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: items items_factory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: categories categories_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_delete ON public.categories FOR DELETE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: categories categories_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_insert ON public.categories FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: categories categories_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_select ON public.categories FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: categories categories_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_update ON public.categories FOR UPDATE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: clients; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

--
-- Name: clients clients_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY clients_delete ON public.clients FOR DELETE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: clients clients_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY clients_insert ON public.clients FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: clients clients_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY clients_select ON public.clients FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: clients clients_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY clients_update ON public.clients FOR UPDATE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: factories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.factories ENABLE ROW LEVEL SECURITY;

--
-- Name: factories factories_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factories_delete ON public.factories FOR DELETE USING ((public.my_role() = 'super_admin'::text));


--
-- Name: factories factories_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factories_insert ON public.factories FOR INSERT WITH CHECK ((public.my_role() = 'super_admin'::text));


--
-- Name: factories factories_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factories_select ON public.factories FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(id)));


--
-- Name: factories factories_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factories_update ON public.factories FOR UPDATE USING ((public.my_role() = 'super_admin'::text));


--
-- Name: factory_members; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.factory_members ENABLE ROW LEVEL SECURITY;

--
-- Name: factory_members factory_members_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factory_members_delete ON public.factory_members FOR DELETE USING ((public.my_role() = 'super_admin'::text));


--
-- Name: factory_members factory_members_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factory_members_insert ON public.factory_members FOR INSERT WITH CHECK ((public.my_role() = 'super_admin'::text));


--
-- Name: factory_members factory_members_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY factory_members_select ON public.factory_members FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR (user_id = auth.uid())));


--
-- Name: inventory; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory inventory_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY inventory_insert ON public.inventory FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: inventory_logs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_logs inventory_logs_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY inventory_logs_insert ON public.inventory_logs FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: inventory_logs inventory_logs_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY inventory_logs_select ON public.inventory_logs FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: inventory inventory_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY inventory_select ON public.inventory FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: inventory inventory_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY inventory_update ON public.inventory FOR UPDATE USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: invoice_attachments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.invoice_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice_attachments invoice_attachments_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoice_attachments_insert ON public.invoice_attachments FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_attachments.invoice_id) AND (public.my_role() = 'factory_admin'::text) AND public.is_factory_member(inv.factory_id))))));


--
-- Name: invoice_attachments invoice_attachments_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoice_attachments_select ON public.invoice_attachments FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_attachments.invoice_id) AND public.is_factory_member(inv.factory_id))))));


--
-- Name: invoice_items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice_items invoice_items_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoice_items_insert ON public.invoice_items FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_items.invoice_id) AND public.is_factory_member(inv.factory_id))))));


--
-- Name: invoice_items invoice_items_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoice_items_select ON public.invoice_items FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_items.invoice_id) AND public.is_factory_member(inv.factory_id))))));


--
-- Name: invoice_memos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.invoice_memos ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice_memos invoice_memos_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoice_memos_insert ON public.invoice_memos FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices
  WHERE (invoices.id = invoice_memos.invoice_id))));


--
-- Name: invoice_memos invoice_memos_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoice_memos_select ON public.invoice_memos FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_memos.invoice_id) AND public.is_factory_member(inv.factory_id))))));


--
-- Name: invoices; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: invoices invoices_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoices_insert ON public.invoices FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: invoices invoices_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoices_select ON public.invoices FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: invoices invoices_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY invoices_update ON public.invoices FOR UPDATE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: item_prices; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.item_prices ENABLE ROW LEVEL SECURITY;

--
-- Name: item_prices item_prices_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY item_prices_insert ON public.item_prices FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.items i
  WHERE ((i.id = item_prices.item_id) AND (public.my_role() = 'factory_admin'::text) AND public.is_factory_member(i.factory_id))))));


--
-- Name: item_prices item_prices_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY item_prices_select ON public.item_prices FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.items i
  WHERE ((i.id = item_prices.item_id) AND public.is_factory_member(i.factory_id))))));


--
-- Name: item_prices item_prices_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY item_prices_update ON public.item_prices FOR UPDATE USING (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.items i
  WHERE ((i.id = item_prices.item_id) AND (public.my_role() = 'factory_admin'::text) AND public.is_factory_member(i.factory_id))))));


--
-- Name: items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

--
-- Name: items items_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY items_delete ON public.items FOR DELETE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: items items_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY items_insert ON public.items FOR INSERT WITH CHECK (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: items items_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY items_select ON public.items FOR SELECT USING (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));


--
-- Name: items items_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY items_update ON public.items FOR UPDATE USING (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_select ON public.profiles FOR SELECT USING (((id = auth.uid()) OR (public.my_role() = 'super_admin'::text)));


--
-- Name: profiles profiles_update_self; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE USING ((id = auth.uid()));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION get_unit_price(p_item_id uuid, p_date date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_unit_price(p_item_id uuid, p_date date) TO anon;
GRANT ALL ON FUNCTION public.get_unit_price(p_item_id uuid, p_date date) TO authenticated;
GRANT ALL ON FUNCTION public.get_unit_price(p_item_id uuid, p_date date) TO service_role;


--
-- Name: FUNCTION is_factory_member(p_factory_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.is_factory_member(p_factory_id uuid) TO anon;
GRANT ALL ON FUNCTION public.is_factory_member(p_factory_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_factory_member(p_factory_id uuid) TO service_role;


--
-- Name: FUNCTION my_role(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.my_role() TO anon;
GRANT ALL ON FUNCTION public.my_role() TO authenticated;
GRANT ALL ON FUNCTION public.my_role() TO service_role;


--
-- Name: FUNCTION process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text) TO anon;
GRANT ALL ON FUNCTION public.process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text) TO authenticated;
GRANT ALL ON FUNCTION public.process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text) TO service_role;


--
-- Name: TABLE categories; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.categories TO anon;
GRANT ALL ON TABLE public.categories TO authenticated;
GRANT ALL ON TABLE public.categories TO service_role;


--
-- Name: TABLE clients; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.clients TO anon;
GRANT ALL ON TABLE public.clients TO authenticated;
GRANT ALL ON TABLE public.clients TO service_role;


--
-- Name: TABLE factories; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.factories TO anon;
GRANT ALL ON TABLE public.factories TO authenticated;
GRANT ALL ON TABLE public.factories TO service_role;


--
-- Name: TABLE factory_members; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.factory_members TO anon;
GRANT ALL ON TABLE public.factory_members TO authenticated;
GRANT ALL ON TABLE public.factory_members TO service_role;


--
-- Name: TABLE inventory; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventory TO anon;
GRANT ALL ON TABLE public.inventory TO authenticated;
GRANT ALL ON TABLE public.inventory TO service_role;


--
-- Name: TABLE inventory_logs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventory_logs TO anon;
GRANT ALL ON TABLE public.inventory_logs TO authenticated;
GRANT ALL ON TABLE public.inventory_logs TO service_role;


--
-- Name: TABLE invoice_attachments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invoice_attachments TO anon;
GRANT ALL ON TABLE public.invoice_attachments TO authenticated;
GRANT ALL ON TABLE public.invoice_attachments TO service_role;


--
-- Name: TABLE invoice_items; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invoice_items TO anon;
GRANT ALL ON TABLE public.invoice_items TO authenticated;
GRANT ALL ON TABLE public.invoice_items TO service_role;


--
-- Name: TABLE invoice_memos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invoice_memos TO anon;
GRANT ALL ON TABLE public.invoice_memos TO authenticated;
GRANT ALL ON TABLE public.invoice_memos TO service_role;


--
-- Name: TABLE invoices; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invoices TO anon;
GRANT ALL ON TABLE public.invoices TO authenticated;
GRANT ALL ON TABLE public.invoices TO service_role;


--
-- Name: TABLE item_prices; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.item_prices TO anon;
GRANT ALL ON TABLE public.item_prices TO authenticated;
GRANT ALL ON TABLE public.item_prices TO service_role;


--
-- Name: TABLE items; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.items TO anon;
GRANT ALL ON TABLE public.items TO authenticated;
GRANT ALL ON TABLE public.items TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict Xb7SG4I4ncfWnt2QtcSvTyKzrkcobxE78eAyEqwfVpO9kPpX5GFmBfKESbw7Ney

