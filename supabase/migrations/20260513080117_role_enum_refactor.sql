-- ================================================================
-- 순서: RLS 전체 DROP → my_role() DROP → enum 생성 → 콼럼 변경 → 함수 재생성 → RLS 재생성
-- ================================================================

-- 1. 기존 RLS 정책 전체 DROP (나중에 재생성)
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
DROP POLICY IF EXISTS "factories_select" ON public.factories;
DROP POLICY IF EXISTS "factories_insert" ON public.factories;
DROP POLICY IF EXISTS "factories_update" ON public.factories;
DROP POLICY IF EXISTS "factories_delete" ON public.factories;
DROP POLICY IF EXISTS "factory_members_select" ON public.factory_members;
DROP POLICY IF EXISTS "factory_members_insert" ON public.factory_members;
DROP POLICY IF EXISTS "factory_members_delete" ON public.factory_members;
DROP POLICY IF EXISTS "clients_select" ON public.clients;
DROP POLICY IF EXISTS "clients_insert" ON public.clients;
DROP POLICY IF EXISTS "clients_update" ON public.clients;
DROP POLICY IF EXISTS "clients_delete" ON public.clients;
DROP POLICY IF EXISTS "categories_select" ON public.categories;
DROP POLICY IF EXISTS "categories_insert" ON public.categories;
DROP POLICY IF EXISTS "categories_update" ON public.categories;
DROP POLICY IF EXISTS "categories_delete" ON public.categories;
DROP POLICY IF EXISTS "items_select" ON public.items;
DROP POLICY IF EXISTS "items_insert" ON public.items;
DROP POLICY IF EXISTS "items_update" ON public.items;
DROP POLICY IF EXISTS "items_delete" ON public.items;
DROP POLICY IF EXISTS "item_prices_select" ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_insert" ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_update" ON public.item_prices;
DROP POLICY IF EXISTS "inventory_select" ON public.inventory;
DROP POLICY IF EXISTS "inventory_insert" ON public.inventory;
DROP POLICY IF EXISTS "inventory_update" ON public.inventory;
DROP POLICY IF EXISTS "inventory_logs_select" ON public.inventory_logs;
DROP POLICY IF EXISTS "inventory_logs_insert" ON public.inventory_logs;
DROP POLICY IF EXISTS "invoices_select" ON public.invoices;
DROP POLICY IF EXISTS "invoices_insert" ON public.invoices;
DROP POLICY IF EXISTS "invoices_update" ON public.invoices;
DROP POLICY IF EXISTS "invoice_items_select" ON public.invoice_items;
DROP POLICY IF EXISTS "invoice_items_insert" ON public.invoice_items;
DROP POLICY IF EXISTS "invoice_memos_select" ON public.invoice_memos;
DROP POLICY IF EXISTS "invoice_memos_insert" ON public.invoice_memos;
DROP POLICY IF EXISTS "invoice_attachments_select" ON public.invoice_attachments;
DROP POLICY IF EXISTS "invoice_attachments_insert" ON public.invoice_attachments;

-- 2. my_role() 함수 DROP (반환 타입 변경은 DROP 후 재생성 필요)
DROP FUNCTION IF EXISTS public.my_role();

-- 3. user_role enum 생성
CREATE TYPE IF NOT EXISTS public.user_role AS ENUM ('super_admin', 'factory_admin', 'worker');

-- 4. profiles.role 콼럼 타입 변경 (text → user_role)
ALTER TABLE public.profiles
  ALTER COLUMN role DROP DEFAULT,
  ALTER COLUMN role TYPE public.user_role USING role::text::public.user_role,
  ALTER COLUMN role SET DEFAULT 'worker'::public.user_role;

-- 5. CHECK 제약 제거 (enum이 대신 보장함)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- 6. my_role() 함수 재생성 (user_role 반환)
CREATE FUNCTION public.my_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 5. handle_new_user() 트리거 함수도 enum 타입으로 업데이트
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    'worker'::public.user_role
  );
  RETURN NEW;
END;
$$;

-- 6. RLS 정책 재생성 (my_role() 반환값이 user_role enum이므로 캐스트 불필요)

-- profiles
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (id = auth.uid() OR my_role() = 'super_admin'::public.user_role);

DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
CREATE POLICY "profiles_update_self" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

-- factories
DROP POLICY IF EXISTS "factories_select" ON public.factories;
CREATE POLICY "factories_select" ON public.factories
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(id));

DROP POLICY IF EXISTS "factories_insert" ON public.factories;
CREATE POLICY "factories_insert" ON public.factories
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role);

DROP POLICY IF EXISTS "factories_update" ON public.factories;
CREATE POLICY "factories_update" ON public.factories
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role);

DROP POLICY IF EXISTS "factories_delete" ON public.factories;
CREATE POLICY "factories_delete" ON public.factories
  FOR DELETE USING (my_role() = 'super_admin'::public.user_role);

-- factory_members
DROP POLICY IF EXISTS "factory_members_select" ON public.factory_members;
CREATE POLICY "factory_members_select" ON public.factory_members
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR user_id = auth.uid());

DROP POLICY IF EXISTS "factory_members_insert" ON public.factory_members;
CREATE POLICY "factory_members_insert" ON public.factory_members
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role);

DROP POLICY IF EXISTS "factory_members_delete" ON public.factory_members;
CREATE POLICY "factory_members_delete" ON public.factory_members
  FOR DELETE USING (my_role() = 'super_admin'::public.user_role);

-- clients
DROP POLICY IF EXISTS "clients_select" ON public.clients;
CREATE POLICY "clients_select" ON public.clients
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "clients_insert" ON public.clients;
CREATE POLICY "clients_insert" ON public.clients
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "clients_update" ON public.clients;
CREATE POLICY "clients_update" ON public.clients
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "clients_delete" ON public.clients;
CREATE POLICY "clients_delete" ON public.clients
  FOR DELETE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

-- categories
DROP POLICY IF EXISTS "categories_select" ON public.categories;
CREATE POLICY "categories_select" ON public.categories
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "categories_insert" ON public.categories;
CREATE POLICY "categories_insert" ON public.categories
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "categories_update" ON public.categories;
CREATE POLICY "categories_update" ON public.categories
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "categories_delete" ON public.categories;
CREATE POLICY "categories_delete" ON public.categories
  FOR DELETE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

-- items
DROP POLICY IF EXISTS "items_select" ON public.items;
CREATE POLICY "items_select" ON public.items
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "items_insert" ON public.items;
CREATE POLICY "items_insert" ON public.items
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "items_update" ON public.items;
CREATE POLICY "items_update" ON public.items
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "items_delete" ON public.items;
CREATE POLICY "items_delete" ON public.items
  FOR DELETE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

-- item_prices
DROP POLICY IF EXISTS "item_prices_select" ON public.item_prices;
CREATE POLICY "item_prices_select" ON public.item_prices
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM items i WHERE i.id = item_prices.item_id AND is_factory_member(i.factory_id)));

DROP POLICY IF EXISTS "item_prices_insert" ON public.item_prices;
CREATE POLICY "item_prices_insert" ON public.item_prices
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM items i WHERE i.id = item_prices.item_id AND my_role() = 'factory_admin'::public.user_role AND is_factory_member(i.factory_id)));

DROP POLICY IF EXISTS "item_prices_update" ON public.item_prices;
CREATE POLICY "item_prices_update" ON public.item_prices
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM items i WHERE i.id = item_prices.item_id AND my_role() = 'factory_admin'::public.user_role AND is_factory_member(i.factory_id)));

-- inventory
DROP POLICY IF EXISTS "inventory_select" ON public.inventory;
CREATE POLICY "inventory_select" ON public.inventory
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "inventory_insert" ON public.inventory;
CREATE POLICY "inventory_insert" ON public.inventory
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "inventory_update" ON public.inventory;
CREATE POLICY "inventory_update" ON public.inventory
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

-- inventory_logs
DROP POLICY IF EXISTS "inventory_logs_select" ON public.inventory_logs;
CREATE POLICY "inventory_logs_select" ON public.inventory_logs
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "inventory_logs_insert" ON public.inventory_logs;
CREATE POLICY "inventory_logs_insert" ON public.inventory_logs
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

-- invoices
DROP POLICY IF EXISTS "invoices_select" ON public.invoices;
CREATE POLICY "invoices_select" ON public.invoices
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR is_factory_member(factory_id));

DROP POLICY IF EXISTS "invoices_insert" ON public.invoices;
CREATE POLICY "invoices_insert" ON public.invoices
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

DROP POLICY IF EXISTS "invoices_update" ON public.invoices;
CREATE POLICY "invoices_update" ON public.invoices
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role OR (my_role() = 'factory_admin'::public.user_role AND is_factory_member(factory_id)));

-- invoice_items
DROP POLICY IF EXISTS "invoice_items_select" ON public.invoice_items;
CREATE POLICY "invoice_items_select" ON public.invoice_items
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM invoices inv WHERE inv.id = invoice_items.invoice_id AND is_factory_member(inv.factory_id)));

DROP POLICY IF EXISTS "invoice_items_insert" ON public.invoice_items;
CREATE POLICY "invoice_items_insert" ON public.invoice_items
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM invoices inv WHERE inv.id = invoice_items.invoice_id AND is_factory_member(inv.factory_id)));

-- invoice_memos
DROP POLICY IF EXISTS "invoice_memos_select" ON public.invoice_memos;
CREATE POLICY "invoice_memos_select" ON public.invoice_memos
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM invoices inv WHERE inv.id = invoice_memos.invoice_id AND is_factory_member(inv.factory_id)));

DROP POLICY IF EXISTS "invoice_memos_insert" ON public.invoice_memos;
CREATE POLICY "invoice_memos_insert" ON public.invoice_memos
  FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM invoices WHERE invoices.id = invoice_memos.invoice_id));

-- invoice_attachments
DROP POLICY IF EXISTS "invoice_attachments_select" ON public.invoice_attachments;
CREATE POLICY "invoice_attachments_select" ON public.invoice_attachments
  FOR SELECT USING (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM invoices inv WHERE inv.id = invoice_attachments.invoice_id AND is_factory_member(inv.factory_id)));

DROP POLICY IF EXISTS "invoice_attachments_insert" ON public.invoice_attachments;
CREATE POLICY "invoice_attachments_insert" ON public.invoice_attachments
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role OR EXISTS (SELECT 1 FROM invoices inv WHERE inv.id = invoice_attachments.invoice_id AND my_role() = 'factory_admin'::public.user_role AND is_factory_member(inv.factory_id)));
