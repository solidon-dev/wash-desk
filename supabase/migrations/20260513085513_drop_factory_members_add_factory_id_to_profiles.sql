-- ================================================================
-- factory_members 중간 테이블 제거
-- profiles.factory_id 직접 할당 구조로 변경
--
-- 변경 이유:
--   유저는 공장 하나에만 소속됨.
--   중간 테이블(factory_members)은 과도한 복잡도.
--   profiles.factory_id (nullable) 로 단순화.
--   super_admin → factory_id = NULL (전체 관리)
--   factory_admin / worker → factory_id 필수
-- ================================================================

-- ── 1. factory_members 에 의존하는 RLS 정책 전부 DROP ──────────────

DROP POLICY IF EXISTS "factory_members_select" ON public.factory_members;
DROP POLICY IF EXISTS "factory_members_insert" ON public.factory_members;
DROP POLICY IF EXISTS "factory_members_delete" ON public.factory_members;

DROP POLICY IF EXISTS "factories_select"  ON public.factories;
DROP POLICY IF EXISTS "factories_insert"  ON public.factories;
DROP POLICY IF EXISTS "factories_update"  ON public.factories;
DROP POLICY IF EXISTS "factories_delete"  ON public.factories;

DROP POLICY IF EXISTS "clients_select"  ON public.clients;
DROP POLICY IF EXISTS "clients_insert"  ON public.clients;
DROP POLICY IF EXISTS "clients_update"  ON public.clients;
DROP POLICY IF EXISTS "clients_delete"  ON public.clients;

DROP POLICY IF EXISTS "categories_select"  ON public.categories;
DROP POLICY IF EXISTS "categories_insert"  ON public.categories;
DROP POLICY IF EXISTS "categories_update"  ON public.categories;
DROP POLICY IF EXISTS "categories_delete"  ON public.categories;

DROP POLICY IF EXISTS "items_select"  ON public.items;
DROP POLICY IF EXISTS "items_insert"  ON public.items;
DROP POLICY IF EXISTS "items_update"  ON public.items;
DROP POLICY IF EXISTS "items_delete"  ON public.items;

DROP POLICY IF EXISTS "item_prices_select"  ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_insert"  ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_update"  ON public.item_prices;

DROP POLICY IF EXISTS "inventory_select"  ON public.inventory;
DROP POLICY IF EXISTS "inventory_insert"  ON public.inventory;
DROP POLICY IF EXISTS "inventory_update"  ON public.inventory;

DROP POLICY IF EXISTS "inventory_logs_select"  ON public.inventory_logs;
DROP POLICY IF EXISTS "inventory_logs_insert"  ON public.inventory_logs;

DROP POLICY IF EXISTS "invoices_select"  ON public.invoices;
DROP POLICY IF EXISTS "invoices_insert"  ON public.invoices;
DROP POLICY IF EXISTS "invoices_update"  ON public.invoices;

DROP POLICY IF EXISTS "invoice_items_select"  ON public.invoice_items;
DROP POLICY IF EXISTS "invoice_items_insert"  ON public.invoice_items;

DROP POLICY IF EXISTS "invoice_memos_select"  ON public.invoice_memos;
DROP POLICY IF EXISTS "invoice_memos_insert"  ON public.invoice_memos;

DROP POLICY IF EXISTS "invoice_attachments_select"  ON public.invoice_attachments;
DROP POLICY IF EXISTS "invoice_attachments_insert"  ON public.invoice_attachments;

-- ── 2. is_factory_member() 함수 DROP (factory_members 기반이라 불필요) ──

DROP FUNCTION IF EXISTS public.is_factory_member(uuid);

-- ── 3. factory_members 테이블 DROP ────────────────────────────────

DROP TABLE IF EXISTS public.factory_members;

-- ── 4. profiles 에 factory_id 컬럼 추가 ──────────────────────────
--   super_admin 은 NULL, factory_admin / worker 는 공장 ID 설정

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS factory_id uuid REFERENCES public.factories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS profiles_factory_id_idx ON public.profiles(factory_id);

-- ── 5. my_factory_id() 헬퍼 함수 (RLS 에서 재사용) ───────────────

CREATE OR REPLACE FUNCTION public.my_factory_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT factory_id FROM public.profiles WHERE id = auth.uid();
$$;

-- ── 6. RLS 재생성 (factory_members → profiles.factory_id 기반) ────

-- profiles
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (
    id = auth.uid()
    OR my_role() = 'super_admin'::public.user_role
    OR (my_factory_id() IS NOT NULL AND factory_id = my_factory_id())
  );

DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
CREATE POLICY "profiles_update_self" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

-- factories
--   super_admin: 전체
--   factory_admin / worker: 자기 공장만
CREATE POLICY "factories_select" ON public.factories
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR id = my_factory_id()
  );

CREATE POLICY "factories_insert" ON public.factories
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role);

CREATE POLICY "factories_update" ON public.factories
  FOR UPDATE USING (my_role() = 'super_admin'::public.user_role);

CREATE POLICY "factories_delete" ON public.factories
  FOR DELETE USING (my_role() = 'super_admin'::public.user_role);

-- clients
CREATE POLICY "clients_select" ON public.clients
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "clients_insert" ON public.clients
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "clients_update" ON public.clients
  FOR UPDATE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "clients_delete" ON public.clients
  FOR DELETE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

-- categories
CREATE POLICY "categories_select" ON public.categories
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "categories_insert" ON public.categories
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "categories_update" ON public.categories
  FOR UPDATE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "categories_delete" ON public.categories
  FOR DELETE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

-- items
CREATE POLICY "items_select" ON public.items
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "items_insert" ON public.items
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "items_update" ON public.items
  FOR UPDATE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "items_delete" ON public.items
  FOR DELETE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

-- item_prices (items 를 통해 factory 판별)
CREATE POLICY "item_prices_select" ON public.item_prices
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR EXISTS (
      SELECT 1 FROM public.items i
      WHERE i.id = item_prices.item_id
        AND i.factory_id = my_factory_id()
    )
  );

CREATE POLICY "item_prices_insert" ON public.item_prices
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR (
      my_role() = 'factory_admin'::public.user_role
      AND EXISTS (
        SELECT 1 FROM public.items i
        WHERE i.id = item_prices.item_id
          AND i.factory_id = my_factory_id()
      )
    )
  );

CREATE POLICY "item_prices_update" ON public.item_prices
  FOR UPDATE USING (
    my_role() = 'super_admin'::public.user_role
    OR (
      my_role() = 'factory_admin'::public.user_role
      AND EXISTS (
        SELECT 1 FROM public.items i
        WHERE i.id = item_prices.item_id
          AND i.factory_id = my_factory_id()
      )
    )
  );

-- inventory
CREATE POLICY "inventory_select" ON public.inventory
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "inventory_insert" ON public.inventory
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "inventory_update" ON public.inventory
  FOR UPDATE USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

-- inventory_logs
CREATE POLICY "inventory_logs_select" ON public.inventory_logs
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "inventory_logs_insert" ON public.inventory_logs
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

-- invoices
CREATE POLICY "invoices_select" ON public.invoices
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR factory_id = my_factory_id()
  );

CREATE POLICY "invoices_insert" ON public.invoices
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

CREATE POLICY "invoices_update" ON public.invoices
  FOR UPDATE USING (
    my_role() = 'super_admin'::public.user_role
    OR (my_role() = 'factory_admin'::public.user_role AND factory_id = my_factory_id())
  );

-- invoice_items (invoices 통해 factory 판별)
CREATE POLICY "invoice_items_select" ON public.invoice_items
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.id = invoice_items.invoice_id
        AND inv.factory_id = my_factory_id()
    )
  );

CREATE POLICY "invoice_items_insert" ON public.invoice_items
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.id = invoice_items.invoice_id
        AND inv.factory_id = my_factory_id()
    )
  );

-- invoice_memos
CREATE POLICY "invoice_memos_select" ON public.invoice_memos
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.id = invoice_memos.invoice_id
        AND inv.factory_id = my_factory_id()
    )
  );

CREATE POLICY "invoice_memos_insert" ON public.invoice_memos
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.id = invoice_memos.invoice_id
        AND inv.factory_id = my_factory_id()
    )
  );

-- invoice_attachments
CREATE POLICY "invoice_attachments_select" ON public.invoice_attachments
  FOR SELECT USING (
    my_role() = 'super_admin'::public.user_role
    OR EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.id = invoice_attachments.invoice_id
        AND inv.factory_id = my_factory_id()
    )
  );

CREATE POLICY "invoice_attachments_insert" ON public.invoice_attachments
  FOR INSERT WITH CHECK (
    my_role() = 'super_admin'::public.user_role
    OR (
      my_role() = 'factory_admin'::public.user_role
      AND EXISTS (
        SELECT 1 FROM public.invoices inv
        WHERE inv.id = invoice_attachments.invoice_id
          AND inv.factory_id = my_factory_id()
      )
    )
  );
