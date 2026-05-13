-- ============================================================
-- RPC: create_item_with_price
--
-- items INSERT + item_prices INSERT 를 단일 트랜잭션으로 처리.
-- trg_item_has_price (DEFERRABLE INITIALLY DEFERRED) 트리거가
-- 커밋 직전에 price 존재 여부를 검사하므로,
-- 두 INSERT 가 같은 트랜잭션 안에 있어야 정상 동작함.
--
-- Args:
--   p_category_id    uuid         -- 카테고리
--   p_factory_id     uuid         -- 공장
--   p_name_ko        text         -- 품목명(한국어) — NOT NULL
--   p_name_en        text         -- 품목명(영어)   — nullable
--   p_name_zh        text         -- 품목명(중국어) — nullable
--   p_nickname       text         -- 별칭            — nullable
--   p_sort_order     int          -- 정렬 순서
--   p_client_id      uuid         -- 거래처 (item_prices.client_id)
--   p_unit_price     int          -- 단가 (> 0)
--   p_effective_from date         -- 단가 적용일
--
-- Returns:
--   json  { id, sort_order }      -- 생성된 item 의 id 와 sort_order
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_item_with_price(
  p_category_id    uuid,
  p_factory_id     uuid,
  p_name_ko        text,
  p_name_en        text,
  p_name_zh        text,
  p_nickname       text,
  p_sort_order     integer,
  p_client_id      uuid,
  p_unit_price     integer,
  p_effective_from date
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item_id    uuid;
  v_sort_order integer;
BEGIN
  -- 유효성 검사
  IF p_unit_price <= 0 THEN
    RAISE EXCEPTION 'unit_price must be greater than 0';
  END IF;

  -- 1. items INSERT
  INSERT INTO public.items (
    category_id,
    factory_id,
    name_ko,
    name_en,
    name_zh,
    nickname,
    sort_order
  ) VALUES (
    p_category_id,
    p_factory_id,
    p_name_ko,
    NULLIF(p_name_en, ''),
    NULLIF(p_name_zh, ''),
    NULLIF(p_nickname, ''),
    p_sort_order
  )
  RETURNING id, sort_order INTO v_item_id, v_sort_order;

  -- 2. item_prices INSERT (같은 트랜잭션 — trg_item_has_price 만족)
  INSERT INTO public.item_prices (
    item_id,
    client_id,
    unit_price,
    effective_from
  ) VALUES (
    v_item_id,
    p_client_id,
    p_unit_price,
    p_effective_from
  );

  -- 3. 생성된 item id 반환
  RETURN json_build_object(
    'id',         v_item_id,
    'sort_order', v_sort_order
  );
END;
$$;

-- RLS 우회 함수이므로 일반 유저에게 EXECUTE 권한 부여
-- (RLS 는 각 테이블에서 이미 적용 중 — SECURITY DEFINER 로 실행되므로
--  서버 액션에서 service_role 키 혹은 인증된 유저로 호출)
GRANT EXECUTE ON FUNCTION public.create_item_with_price(
  uuid, uuid, text, text, text, text, integer, uuid, integer, date
) TO authenticated;
