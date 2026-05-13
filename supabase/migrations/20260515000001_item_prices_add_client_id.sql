-- ============================================================
-- item_prices: client_id 추가 (거래처별 단가 구조)
-- ============================================================
-- 변경 내용:
--   1. item_prices.client_id (uuid, nullable) 추가
--      - NULL이면 공통 단가(fallback)로 해석 가능하나,
--        현재 운영 방침상 거래처별 단가만 사용 → NOT NULL로 변경 예정
--      - 기존 데이터가 없으면 바로 NOT NULL로 처리
--   2. unique 제약: (item_id, client_id, effective_from)
--   3. FK: client_id → clients(id) ON DELETE CASCADE
--   4. index 추가
--   5. RLS 정책 재작성 (client_id 기반)
-- ============================================================

-- 1. client_id 컬럼 추가
ALTER TABLE public.item_prices
  ADD COLUMN "client_id" uuid NOT NULL
    REFERENCES public.clients(id) ON DELETE CASCADE;

-- 2. 기존 unique index 제거 (item_id, effective_from 단순 index였음)
--    (unique 제약이 아닌 일반 index였으므로 drop)
DROP INDEX IF EXISTS public.item_prices_item_id_effective_from_idx;

-- 3. 새 index: (client_id, item_id, effective_from DESC)
CREATE INDEX item_prices_client_item_effective_idx
  ON public.item_prices (client_id, item_id, effective_from DESC);

-- 4. 새 unique 제약: 같은 거래처+품목+시작일 중복 방지
ALTER TABLE public.item_prices
  ADD CONSTRAINT item_prices_client_item_effective_uniq
  UNIQUE (client_id, item_id, effective_from);

-- ============================================================
-- RLS 정책 재작성 (my_factory_id() / my_role() 패턴 사용)
-- ============================================================

-- 기존 정책 제거
DROP POLICY IF EXISTS "item_prices_insert" ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_select" ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_update" ON public.item_prices;
DROP POLICY IF EXISTS "item_prices_delete" ON public.item_prices;

-- SELECT: super_admin 전체, 그 외는 자기 공장 품목 + 자기 공장 거래처 단가만
CREATE POLICY "item_prices_select" ON public.item_prices
  FOR SELECT USING (
    public.my_role() = 'super_admin'::public.user_role
    OR (
      EXISTS (
        SELECT 1 FROM public.items i
        WHERE i.id = item_prices.item_id
          AND i.factory_id = public.my_factory_id()
      )
      AND EXISTS (
        SELECT 1 FROM public.clients c
        WHERE c.id = item_prices.client_id
          AND c.factory_id = public.my_factory_id()
      )
    )
  );

-- INSERT: super_admin 또는 factory_admin (자기 공장 품목 + 자기 공장 거래처)
CREATE POLICY "item_prices_insert" ON public.item_prices
  FOR INSERT WITH CHECK (
    public.my_role() = 'super_admin'::public.user_role
    OR (
      public.my_role() = 'factory_admin'::public.user_role
      AND EXISTS (
        SELECT 1 FROM public.items i
        WHERE i.id = item_prices.item_id
          AND i.factory_id = public.my_factory_id()
      )
      AND EXISTS (
        SELECT 1 FROM public.clients c
        WHERE c.id = item_prices.client_id
          AND c.factory_id = public.my_factory_id()
      )
    )
  );

-- UPDATE
CREATE POLICY "item_prices_update" ON public.item_prices
  FOR UPDATE USING (
    public.my_role() = 'super_admin'::public.user_role
    OR (
      public.my_role() = 'factory_admin'::public.user_role
      AND EXISTS (
        SELECT 1 FROM public.items i
        WHERE i.id = item_prices.item_id
          AND i.factory_id = public.my_factory_id()
      )
      AND EXISTS (
        SELECT 1 FROM public.clients c
        WHERE c.id = item_prices.client_id
          AND c.factory_id = public.my_factory_id()
      )
    )
  );

-- DELETE
CREATE POLICY "item_prices_delete" ON public.item_prices
  FOR DELETE USING (
    public.my_role() = 'super_admin'::public.user_role
    OR (
      public.my_role() = 'factory_admin'::public.user_role
      AND EXISTS (
        SELECT 1 FROM public.items i
        WHERE i.id = item_prices.item_id
          AND i.factory_id = public.my_factory_id()
      )
      AND EXISTS (
        SELECT 1 FROM public.clients c
        WHERE c.id = item_prices.client_id
          AND c.factory_id = public.my_factory_id()
      )
    )
  );
