-- ================================================================
-- 품목/카테고리를 공장 단위 → 거래처 단위로 재설계
--
-- 변경 내용:
--   categories : factory_id 제거, client_id 추가, RLS 재작성
--   items       : factory_id 제거, client_id 추가, RLS 재작성
--   item_prices : client_id 제거, RLS 재작성
--   RPC         : create_item_with_price 재작성
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- 0. 헬퍼: 현재 사용자의 거래처 목록 반환 (factory 기준)
--    categories/items는 이제 client 기준이므로
--    "내 공장의 거래처" 여부로 접근 제어
-- ────────────────────────────────────────────────────────────────


-- ────────────────────────────────────────────────────────────────
-- 1. categories 테이블
-- ────────────────────────────────────────────────────────────────

-- 1-1. 기존 RLS 정책 삭제 (factory_id 참조 때문에 컬럼 삭제 전 먼저 제거)
DROP POLICY IF EXISTS categories_select ON categories;
DROP POLICY IF EXISTS categories_insert ON categories;
DROP POLICY IF EXISTS categories_update ON categories;
DROP POLICY IF EXISTS categories_delete ON categories;

-- 1-2. client_id 컬럼 추가
ALTER TABLE categories ADD COLUMN IF NOT EXISTS client_id uuid REFERENCES clients(id) ON DELETE CASCADE;

-- 1-3. 기존 데이터 마이그레이션: items → item_prices 경로로 client_id 역추적
UPDATE categories cat
SET client_id = sub.client_id
FROM (
  SELECT DISTINCT i.category_id, ip.client_id
  FROM items i
  JOIN item_prices ip ON ip.item_id = i.id
  WHERE ip.client_id IS NOT NULL
) sub
WHERE cat.id = sub.category_id
  AND cat.client_id IS NULL;

-- 1-4. 고아 카테고리 삭제
DELETE FROM categories WHERE client_id IS NULL;

-- 1-5. NOT NULL
ALTER TABLE categories ALTER COLUMN client_id SET NOT NULL;

-- 1-6. unique 제약 교체
ALTER TABLE categories DROP CONSTRAINT IF EXISTS categories_factory_name_uniq;
ALTER TABLE categories ADD CONSTRAINT categories_client_name_uniq UNIQUE (client_id, name);

-- 1-7. factory_id 컬럼 제거
ALTER TABLE categories DROP COLUMN IF EXISTS factory_id;

-- 1-8. 새 RLS 정책: 내 공장 소속 거래처의 카테고리만 접근
CREATE POLICY categories_select ON categories FOR SELECT
  USING (
    (my_role() = 'super_admin')
    OR EXISTS (
      SELECT 1 FROM clients c
      WHERE c.id = categories.client_id
        AND c.factory_id = my_factory_id()
    )
  );

CREATE POLICY categories_insert ON categories FOR INSERT
  WITH CHECK (true);

CREATE POLICY categories_update ON categories FOR UPDATE
  USING (
    (my_role() = 'super_admin')
    OR (
      my_role() = 'factory_admin'
      AND EXISTS (
        SELECT 1 FROM clients c
        WHERE c.id = categories.client_id
          AND c.factory_id = my_factory_id()
      )
    )
  );

CREATE POLICY categories_delete ON categories FOR DELETE
  USING (
    (my_role() = 'super_admin')
    OR (
      my_role() = 'factory_admin'
      AND EXISTS (
        SELECT 1 FROM clients c
        WHERE c.id = categories.client_id
          AND c.factory_id = my_factory_id()
      )
    )
  );


-- ────────────────────────────────────────────────────────────────
-- 2. items 테이블
-- ────────────────────────────────────────────────────────────────

-- 2-1. 기존 RLS 정책 삭제
DROP POLICY IF EXISTS items_select ON items;
DROP POLICY IF EXISTS items_insert ON items;
DROP POLICY IF EXISTS items_update ON items;
DROP POLICY IF EXISTS items_delete ON items;

-- 2-2. client_id 컬럼 추가
ALTER TABLE items ADD COLUMN IF NOT EXISTS client_id uuid REFERENCES clients(id) ON DELETE CASCADE;

-- 2-3. 기존 데이터 마이그레이션
UPDATE items i
SET client_id = ip.client_id
FROM item_prices ip
WHERE ip.item_id = i.id
  AND i.client_id IS NULL;

-- 2-4. 고아 items 삭제
DELETE FROM items WHERE client_id IS NULL;

-- 2-5. NOT NULL
ALTER TABLE items ALTER COLUMN client_id SET NOT NULL;

-- 2-6. unique 제약 교체
ALTER TABLE items DROP CONSTRAINT IF EXISTS items_category_name_ko_uniq;
ALTER TABLE items ADD CONSTRAINT items_client_category_name_ko_uniq UNIQUE (client_id, category_id, name_ko);

-- 2-7. factory_id 컬럼 제거
ALTER TABLE items DROP COLUMN IF EXISTS factory_id;

-- 2-8. 새 RLS 정책
CREATE POLICY items_select ON items FOR SELECT
  USING (
    (my_role() = 'super_admin')
    OR EXISTS (
      SELECT 1 FROM clients c
      WHERE c.id = items.client_id
        AND c.factory_id = my_factory_id()
    )
  );

CREATE POLICY items_insert ON items FOR INSERT
  WITH CHECK (true);

CREATE POLICY items_update ON items FOR UPDATE
  USING (
    (my_role() = 'super_admin')
    OR (
      my_role() = 'factory_admin'
      AND EXISTS (
        SELECT 1 FROM clients c
        WHERE c.id = items.client_id
          AND c.factory_id = my_factory_id()
      )
    )
  );

CREATE POLICY items_delete ON items FOR DELETE
  USING (
    (my_role() = 'super_admin')
    OR (
      my_role() = 'factory_admin'
      AND EXISTS (
        SELECT 1 FROM clients c
        WHERE c.id = items.client_id
          AND c.factory_id = my_factory_id()
      )
    )
  );


-- ────────────────────────────────────────────────────────────────
-- 3. item_prices — client_id 제거, RLS 재작성
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS item_prices_select ON item_prices;
DROP POLICY IF EXISTS item_prices_insert ON item_prices;
DROP POLICY IF EXISTS item_prices_update ON item_prices;
DROP POLICY IF EXISTS item_prices_delete ON item_prices;

-- 3-1. 기존 unique/FK 제약 제거
ALTER TABLE item_prices DROP CONSTRAINT IF EXISTS item_prices_client_item_effective_uniq;
ALTER TABLE item_prices DROP CONSTRAINT IF EXISTS item_prices_client_id_fkey;

-- 3-2. client_id 컬럼 제거
ALTER TABLE item_prices DROP COLUMN IF EXISTS client_id;

-- 3-3. 새 unique
ALTER TABLE item_prices ADD CONSTRAINT item_prices_item_effective_uniq UNIQUE (item_id, effective_from);

-- 3-4. 새 RLS: item → client → factory 경로로 접근 제어
CREATE POLICY item_prices_select ON item_prices FOR SELECT
  USING (
    (my_role() = 'super_admin')
    OR EXISTS (
      SELECT 1 FROM items i
      JOIN clients c ON c.id = i.client_id
      WHERE i.id = item_prices.item_id
        AND c.factory_id = my_factory_id()
    )
  );

CREATE POLICY item_prices_insert ON item_prices FOR INSERT
  WITH CHECK (true);

CREATE POLICY item_prices_update ON item_prices FOR UPDATE
  USING (
    (my_role() = 'super_admin')
    OR (
      my_role() = 'factory_admin'
      AND EXISTS (
        SELECT 1 FROM items i
        JOIN clients c ON c.id = i.client_id
        WHERE i.id = item_prices.item_id
          AND c.factory_id = my_factory_id()
      )
    )
  );

CREATE POLICY item_prices_delete ON item_prices FOR DELETE
  USING (
    (my_role() = 'super_admin')
    OR (
      my_role() = 'factory_admin'
      AND EXISTS (
        SELECT 1 FROM items i
        JOIN clients c ON c.id = i.client_id
        WHERE i.id = item_prices.item_id
          AND c.factory_id = my_factory_id()
      )
    )
  );


-- ────────────────────────────────────────────────────────────────
-- 4. RPC: create_item_with_price 재작성
-- ────────────────────────────────────────────────────────────────

-- 기존 함수 시그니처가 다르므로 DROP 후 재생성
DROP FUNCTION IF EXISTS public.create_item_with_price(uuid, uuid, uuid, text, integer);
DROP FUNCTION IF EXISTS public.create_item_with_price(uuid, uuid, text, integer);

CREATE OR REPLACE FUNCTION public.create_item_with_price(
  p_client_id   uuid,
  p_category_id uuid,
  p_name_ko     text,
  p_unit_price  integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item_id uuid;
BEGIN
  INSERT INTO items (client_id, category_id, name_ko, sort_order)
  VALUES (p_client_id, p_category_id, p_name_ko, 0)
  ON CONFLICT (client_id, category_id, name_ko) DO NOTHING
  RETURNING id INTO v_item_id;

  IF v_item_id IS NULL THEN
    SELECT id INTO v_item_id
    FROM items
    WHERE client_id = p_client_id
      AND category_id = p_category_id
      AND name_ko = p_name_ko;
  END IF;

  INSERT INTO item_prices (item_id, unit_price, effective_from)
  VALUES (v_item_id, p_unit_price, CURRENT_DATE)
  ON CONFLICT (item_id, effective_from) DO UPDATE
    SET unit_price = EXCLUDED.unit_price;

  RETURN jsonb_build_object('item_id', v_item_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_item_with_price(uuid, uuid, text, integer) TO anon, authenticated;
