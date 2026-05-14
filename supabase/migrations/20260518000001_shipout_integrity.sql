-- ============================================================
-- 출고 무결성 보강
-- 1. (shipout_id, item_id) 중복 방지 — PARTIAL UNIQUE INDEX
--    shipout_id IS NOT NULL 인 행에만 적용 (입고 로그 영향 없음)
-- 2. execute_shipout — 같은 출고건에 동일 아이템 중복 삽입 방어
-- 3. update_shipout  — log 조회 시 FOR UPDATE SKIP LOCKED 제거,
--                      중복 행이 있으면 RAISE EXCEPTION 으로 명시적 차단
-- ============================================================

-- 1. PARTIAL UNIQUE INDEX
CREATE UNIQUE INDEX IF NOT EXISTS inventory_logs_shipout_item_unique
  ON inventory_logs (shipout_id, item_id)
  WHERE shipout_id IS NOT NULL AND deleted_at IS NULL;

-- 2. execute_shipout: 중복 아이템 방어 추가
CREATE OR REPLACE FUNCTION public.execute_shipout(
  p_factory_id uuid,
  p_client_id  uuid,
  p_items      jsonb,
  p_created_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shipout_id  uuid := gen_random_uuid();
  v_item        jsonb;
  v_item_id     uuid;
  v_quantity    integer;
  v_inv_id      uuid;
  v_old_qty     integer;
  v_new_qty     integer;
  v_results     jsonb := '[]'::jsonb;
  v_seen_items  uuid[] := '{}';
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id  := (v_item->>'item_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;

    -- 같은 출고 요청 내 동일 아이템 중복 방어
    IF v_item_id = ANY(v_seen_items) THEN
      RAISE EXCEPTION 'DUPLICATE_ITEM'
        USING DETAIL = format('item_id:%s 동일 출고에 중복', v_item_id),
              HINT   = format('item_id:%s', v_item_id);
    END IF;
    v_seen_items := array_append(v_seen_items, v_item_id);

    SELECT id, quantity
      INTO v_inv_id, v_old_qty
      FROM inventory
     WHERE factory_id = p_factory_id
       AND client_id  = p_client_id
       AND item_id    = v_item_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK'
        USING DETAIL = format('item_id:%s 재고 없음', v_item_id),
              HINT   = 'current_qty:0';
    END IF;

    v_new_qty := v_old_qty - v_quantity;
    IF v_new_qty < 0 THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK'
        USING DETAIL = format('item_id:%s 재고 부족. 현재:%s', v_item_id, v_old_qty),
              HINT   = format('current_qty:%s', v_old_qty);
    END IF;

    UPDATE inventory
       SET quantity = v_new_qty, updated_at = now()
     WHERE id = v_inv_id;

    INSERT INTO inventory_logs (
      factory_id, client_id, item_id, inventory_id,
      log_type, quantity, after_quantity,
      shipout_id, created_by
    ) VALUES (
      p_factory_id, p_client_id, v_item_id, v_inv_id,
      'out', v_quantity, v_new_qty,
      v_shipout_id, p_created_by
    );

    v_results := v_results || jsonb_build_object(
      'item_id', v_item_id,
      'old_qty', v_old_qty,
      'new_qty', v_new_qty
    );
  END LOOP;

  RETURN jsonb_build_object(
    'shipout_id', v_shipout_id,
    'items', v_results
  );
END;
$$;

-- 3. update_shipout: 중복 행 존재 시 명시적 에러 + id 기반 잠금
CREATE OR REPLACE FUNCTION public.update_shipout(
  p_shipout_id uuid,
  p_items      jsonb,
  p_updated_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item        jsonb;
  v_item_id     uuid;
  v_new_qty     integer;
  v_log_id      uuid;
  v_old_log_qty integer;
  v_inv_id      uuid;
  v_inv_qty     integer;
  v_delta       integer;
  v_after_qty   integer;
  v_dup_count   integer;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_item->>'item_id')::uuid;
    v_new_qty := (v_item->>'new_quantity')::integer;

    -- 중복 행 존재 여부 선제 확인
    SELECT COUNT(*) INTO v_dup_count
      FROM inventory_logs
     WHERE shipout_id = p_shipout_id
       AND item_id    = v_item_id
       AND deleted_at IS NULL;

    IF v_dup_count > 1 THEN
      RAISE EXCEPTION 'DATA_INTEGRITY_ERROR'
        USING DETAIL = format('shipout_id:%s item_id:%s 에 중복 로그 행 존재', p_shipout_id, v_item_id),
              HINT   = 'DB 관리자에게 문의하세요';
    END IF;

    SELECT id, quantity, inventory_id
      INTO v_log_id, v_old_log_qty, v_inv_id
      FROM inventory_logs
     WHERE shipout_id = p_shipout_id
       AND item_id    = v_item_id
       AND deleted_at IS NULL
     FOR UPDATE;

    IF NOT FOUND THEN CONTINUE; END IF;

    v_delta := v_old_log_qty - v_new_qty;

    SELECT quantity INTO v_inv_qty
      FROM inventory
     WHERE id = v_inv_id
     FOR UPDATE;

    v_after_qty := v_inv_qty + v_delta;
    IF v_after_qty < 0 THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK'
        USING DETAIL = format('item_id:%s 재고 부족', v_item_id),
              HINT   = format('current_qty:%s', v_inv_qty);
    END IF;

    UPDATE inventory
       SET quantity = v_after_qty, updated_at = now()
     WHERE id = v_inv_id;

    IF v_new_qty = 0 THEN
      UPDATE inventory_logs
         SET deleted_at = now()
       WHERE id = v_log_id;
    ELSE
      UPDATE inventory_logs
         SET quantity = v_new_qty, after_quantity = v_after_qty
       WHERE id = v_log_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('shipout_id', p_shipout_id, 'ok', true);
END;
$$;
