-- ================================================================
-- cancel_inventory_log: 입고 로그 취소 (재고 복구 + 로그 하드딜리트)
-- 트랜잭션 내에서 원자적으로 처리
-- ================================================================

CREATE OR REPLACE FUNCTION public.cancel_inventory_log(
  p_log_id uuid,
  p_cancelled_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log       RECORD;
  v_new_qty   integer;
BEGIN
  -- 로그 조회 (FOR UPDATE 로 동시 취소 방지)
  SELECT id, inventory_id, item_id, quantity, log_type, shipout_id
    INTO v_log
    FROM inventory_logs
   WHERE id = p_log_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'LOG_NOT_FOUND'
      USING DETAIL = format('log_id:%s 존재하지 않음', p_log_id);
  END IF;

  -- 출고 로그는 이 RPC로 취소하지 않음 (delete_shipout 사용)
  IF v_log.shipout_id IS NOT NULL THEN
    RAISE EXCEPTION 'USE_DELETE_SHIPOUT'
      USING DETAIL = format('log_id:%s 는 출고 로그입니다. delete_shipout RPC를 사용하세요.', p_log_id);
  END IF;

  -- 재고 복구: 입고(in)면 다시 빼고, 출고(out)면 다시 더함
  UPDATE inventory
     SET quantity   = CASE
                        WHEN v_log.log_type = 'in'  THEN quantity - v_log.quantity
                        ELSE                              quantity + v_log.quantity
                      END,
         updated_at = now()
   WHERE id = v_log.inventory_id
   RETURNING quantity INTO v_new_qty;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVENTORY_NOT_FOUND'
      USING DETAIL = format('inventory_id:%s 존재하지 않음', v_log.inventory_id);
  END IF;

  IF v_new_qty < 0 THEN
    RAISE EXCEPTION 'INSUFFICIENT_STOCK'
      USING DETAIL = format('재고가 부족합니다. 현재 복구 후 수량: %s', v_new_qty);
  END IF;

  -- 로그 하드딜리트
  DELETE FROM inventory_logs WHERE id = p_log_id;

  RETURN jsonb_build_object(
    'log_id',        p_log_id,
    'inventory_id',  v_log.inventory_id,
    'restored_qty',  v_new_qty,
    'ok',            true
  );
END;
$$;
