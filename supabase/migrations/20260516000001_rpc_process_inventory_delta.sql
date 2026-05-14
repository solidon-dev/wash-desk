-- ============================================================
-- RPC: process_inventory_delta
-- 재고를 원자적으로 delta만큼 변경한다.
-- delta > 0 → 입고, delta < 0 → 출고
-- 출고 시 재고 부족(결과가 음수)이면 에러를 발생시킨다.
-- 동시 요청 충돌을 방지하기 위해 SELECT ... FOR UPDATE 후 UPDATE.
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_inventory_delta(
  p_factory_id  uuid,
  p_client_id   uuid,
  p_item_id     uuid,
  p_delta       integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id          uuid;
  v_old_qty     integer;
  v_new_qty     integer;
BEGIN
  -- 행 잠금: 동시 요청이 같은 재고 행을 동시에 수정하지 못하도록
  SELECT id, quantity
    INTO v_id, v_old_qty
    FROM inventory
   WHERE factory_id = p_factory_id
     AND client_id  = p_client_id
     AND item_id    = p_item_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- 레코드 없음 → 신규 삽입 (출고인데 재고 없으면 에러)
    IF p_delta < 0 THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK'
        USING DETAIL = '재고가 없습니다.',
              HINT   = 'current_qty:0';
    END IF;

    INSERT INTO inventory (factory_id, client_id, item_id, quantity)
    VALUES (p_factory_id, p_client_id, p_item_id, p_delta)
    RETURNING id, quantity INTO v_id, v_new_qty;

    RETURN jsonb_build_object(
      'id',          v_id,
      'old_qty',     0,
      'new_qty',     v_new_qty
    );
  END IF;

  v_new_qty := v_old_qty + p_delta;

  IF v_new_qty < 0 THEN
    RAISE EXCEPTION 'INSUFFICIENT_STOCK'
      USING DETAIL = format('재고가 부족합니다. 현재 재고: %s', v_old_qty),
            HINT   = format('current_qty:%s', v_old_qty);
  END IF;

  UPDATE inventory
     SET quantity   = v_new_qty,
         updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object(
    'id',      v_id,
    'old_qty', v_old_qty,
    'new_qty', v_new_qty
  );
END;
$$;

-- anon / authenticated 모두 호출 가능 (RLS는 테이블 레벨에서 처리)
GRANT EXECUTE ON FUNCTION public.process_inventory_delta(uuid, uuid, uuid, integer) TO anon, authenticated;
