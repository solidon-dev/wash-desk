-- ============================================================
-- item_prices: effective_from 단조 증가 제약
--
-- 같은 (client_id, item_id) 조합에 대해
-- 새로 INSERT / UPDATE 하는 effective_from은
-- 기존 최대 적용일보다 반드시 커야 한다.
--
-- 구현: BEFORE INSERT OR UPDATE 트리거
--   - 현재 행을 제외한 같은 (client_id, item_id)의 MAX(effective_from) 조회
--   - NEW.effective_from <= MAX 이면 오류
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_item_price_date_monotonic()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  max_date date;
BEGIN
  SELECT MAX(effective_from)
    INTO max_date
    FROM public.item_prices
   WHERE client_id = NEW.client_id
     AND item_id   = NEW.item_id
     AND id        <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

  IF max_date IS NOT NULL AND NEW.effective_from <= max_date THEN
    RAISE EXCEPTION
      'effective_from(%) must be after the current latest date(%) for this item and client.',
      NEW.effective_from, max_date;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_item_price_date_monotonic ON public.item_prices;
CREATE TRIGGER trg_item_price_date_monotonic
  BEFORE INSERT OR UPDATE ON public.item_prices
  FOR EACH ROW
  EXECUTE FUNCTION public.check_item_price_date_monotonic();
