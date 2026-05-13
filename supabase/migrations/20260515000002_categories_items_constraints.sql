-- ============================================================
-- 1. 기존 데이터 전체 삭제
--    item_prices → items → categories 순서로 cascade 처리
-- ============================================================
DELETE FROM public.item_prices;
DELETE FROM public.items;
DELETE FROM public.categories;

-- ============================================================
-- 2. categories.name unique (공장 내 카테고리명 중복 방지)
--    같은 factory_id 안에서 name이 유일해야 한다
-- ============================================================
ALTER TABLE public.categories
  ADD CONSTRAINT categories_factory_name_uniq
  UNIQUE (factory_id, name);

-- ============================================================
-- 3. items.name_ko unique (카테고리 내 품목명 중복 방지)
--    같은 category_id 안에서 name_ko가 유일해야 한다
-- ============================================================
ALTER TABLE public.items
  ADD CONSTRAINT items_category_name_ko_uniq
  UNIQUE (category_id, name_ko);

-- ============================================================
-- 4. item_prices.unit_price > 0 CHECK 제약
-- ============================================================
ALTER TABLE public.item_prices
  ADD CONSTRAINT item_prices_unit_price_positive
  CHECK (unit_price > 0);

-- ============================================================
-- 5. 품목(items) 생성 후 item_prices가 1개 이상 존재하는지
--    DEFERRABLE 제약 트리거로 강제
--
--    구현 전략:
--      - AFTER INSERT OR UPDATE ON items (DEFERRABLE INITIALLY DEFERRED)
--        → 트랜잭션 커밋 직전에 검사
--      - AFTER DELETE ON item_prices
--        → 삭제 후 해당 item에 가격이 0개면 오류
-- ============================================================

-- 5-a. items INSERT/UPDATE 후 가격 존재 검사 함수
CREATE OR REPLACE FUNCTION public.check_item_has_price()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.item_prices WHERE item_id = NEW.id
  ) THEN
    RAISE EXCEPTION
      'item(id=%) must have at least one price in item_prices', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

-- 5-b. item_prices DELETE 후 해당 품목에 가격이 남아있는지 검사 함수
CREATE OR REPLACE FUNCTION public.check_item_prices_not_empty()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.item_prices WHERE item_id = OLD.item_id
  ) THEN
    RAISE EXCEPTION
      'item(id=%) must have at least one price. Cannot delete the last price.', OLD.item_id;
  END IF;
  RETURN OLD;
END;
$$;

-- 5-c. items에 DEFERRABLE 트리거 부착
--      INSERT 직후가 아닌 트랜잭션 커밋 직전에 실행되어
--      "INSERT item → INSERT item_price" 를 한 트랜잭션 안에서 처리 가능
DROP TRIGGER IF EXISTS trg_item_has_price ON public.items;
CREATE CONSTRAINT TRIGGER trg_item_has_price
  AFTER INSERT OR UPDATE ON public.items
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.check_item_has_price();

-- 5-d. item_prices 마지막 가격 삭제 방지 트리거
DROP TRIGGER IF EXISTS trg_item_prices_not_empty ON public.item_prices;
CREATE CONSTRAINT TRIGGER trg_item_prices_not_empty
  AFTER DELETE ON public.item_prices
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.check_item_prices_not_empty();
