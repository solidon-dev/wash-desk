-- ================================================================
-- 스키마 전면 재설계: shipouts 테이블 분리 + 데이터 초기화
-- ================================================================

BEGIN;

-- ── 1. 기존 데이터 전체 초기화 ────────────────────────────────
TRUNCATE inventory_logs, inventory RESTART IDENTITY CASCADE;

-- ── 2. 기존 RPC 제거 ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.execute_shipout(uuid, uuid, jsonb, uuid);
DROP FUNCTION IF EXISTS public.update_shipout(uuid, jsonb, uuid);
DROP FUNCTION IF EXISTS public.delete_shipout(uuid, uuid);
DROP FUNCTION IF EXISTS public.delete_shipout(uuid, uuid, boolean);

-- ── 3. 기존 inventory_logs 컬럼 정리 ─────────────────────────
-- shipout_id 는 아직 놔둠 (FK 걸기 전에 컬럼 먼저 쓸 거라)
DROP INDEX IF EXISTS inventory_logs_shipout_item_unique;
DROP INDEX IF EXISTS inventory_logs_shipout_id_idx;

ALTER TABLE inventory_logs
  DROP COLUMN IF EXISTS deleted_at;

-- processed_at → created_at 으로 통일 (이미 created_at 있으면 스킵)
-- note, created_by 는 그대로 유지
-- after_quantity 그대로 유지

-- ── 4. shipouts 테이블 생성 ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shipouts (
  id          uuid        NOT NULL DEFAULT gen_random_uuid(),
  factory_id  uuid        NOT NULL REFERENCES factories(id)  ON DELETE CASCADE,
  client_id   uuid        NOT NULL REFERENCES clients(id)    ON DELETE CASCADE,
  created_by  uuid                 REFERENCES profiles(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  memo        text,
  deleted_at  timestamptz,         -- soft delete
  CONSTRAINT shipouts_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS shipouts_factory_client_idx
  ON shipouts (factory_id, client_id);

CREATE INDEX IF NOT EXISTS shipouts_deleted_at_idx
  ON shipouts (deleted_at) WHERE deleted_at IS NULL;

-- RLS
ALTER TABLE public.shipouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shipouts_select" ON public.shipouts FOR SELECT
  USING (
    my_role() = 'super_admin'
    OR factory_id = my_factory_id()
  );

CREATE POLICY "shipouts_insert" ON public.shipouts FOR INSERT
  WITH CHECK (
    my_role() = 'super_admin'
    OR factory_id = my_factory_id()
  );

CREATE POLICY "shipouts_update" ON public.shipouts FOR UPDATE
  USING (
    my_role() = 'super_admin'
    OR factory_id = my_factory_id()
  );

-- ── 5. inventory_logs.shipout_id → shipouts.id FK ─────────────
-- 기존 shipout_id 컬럼(uuid)이 있으므로 FK만 추가
ALTER TABLE inventory_logs
  ADD CONSTRAINT inventory_logs_shipout_id_fkey
  FOREIGN KEY (shipout_id) REFERENCES shipouts(id) ON DELETE CASCADE;

-- (shipout_id, item_id) PARTIAL UNIQUE — out 로그 중복 방지
CREATE UNIQUE INDEX inventory_logs_shipout_item_unique
  ON inventory_logs (shipout_id, item_id)
  WHERE shipout_id IS NOT NULL;

CREATE INDEX inventory_logs_shipout_id_idx
  ON inventory_logs (shipout_id)
  WHERE shipout_id IS NOT NULL;

-- ── 6. execute_shipout 재작성 ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.execute_shipout(
  p_factory_id uuid,
  p_client_id  uuid,
  p_items      jsonb,
  p_created_by uuid,
  p_memo       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shipout_id  uuid;
  v_item        jsonb;
  v_item_id     uuid;
  v_quantity    integer;
  v_inv_id      uuid;
  v_old_qty     integer;
  v_new_qty     integer;
  v_results     jsonb := '[]'::jsonb;
  v_seen_items  uuid[] := '{}';
BEGIN
  -- shipouts 행 먼저 생성
  INSERT INTO shipouts (factory_id, client_id, created_by, memo)
  VALUES (p_factory_id, p_client_id, p_created_by, p_memo)
  RETURNING id INTO v_shipout_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id  := (v_item->>'item_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;

    -- 동일 출고건 내 아이템 중복 방어
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

-- ── 7. update_shipout 재작성 ──────────────────────────────────
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
  -- 삭제된 출고건 수정 불가
  IF EXISTS (SELECT 1 FROM shipouts WHERE id = p_shipout_id AND deleted_at IS NOT NULL) THEN
    RAISE EXCEPTION 'SHIPOUT_DELETED'
      USING DETAIL = format('shipout_id:%s 는 이미 삭제된 출고건', p_shipout_id);
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_item->>'item_id')::uuid;
    v_new_qty := (v_item->>'new_quantity')::integer;

    -- 중복 행 선제 확인 (데이터 이상 감지)
    SELECT COUNT(*) INTO v_dup_count
      FROM inventory_logs
     WHERE shipout_id = p_shipout_id
       AND item_id    = v_item_id;

    IF v_dup_count > 1 THEN
      RAISE EXCEPTION 'DATA_INTEGRITY_ERROR'
        USING DETAIL = format('shipout_id:%s item_id:%s 중복 로그 존재', p_shipout_id, v_item_id);
    END IF;

    SELECT id, quantity, inventory_id
      INTO v_log_id, v_old_log_qty, v_inv_id
      FROM inventory_logs
     WHERE shipout_id = p_shipout_id
       AND item_id    = v_item_id
     FOR UPDATE;

    IF NOT FOUND THEN CONTINUE; END IF;

    v_delta := v_old_log_qty - v_new_qty;  -- 양수면 재고 복구, 음수면 추가 차감

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
      -- 수량 0 → 해당 로그 행 삭제 (soft delete 아닌 진짜 삭제, shipout은 남음)
      DELETE FROM inventory_logs WHERE id = v_log_id;
    ELSE
      UPDATE inventory_logs
         SET quantity = v_new_qty, after_quantity = v_after_qty
       WHERE id = v_log_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('shipout_id', p_shipout_id, 'ok', true);
END;
$$;

-- ── 8. delete_shipout 재작성 ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_shipout(
  p_shipout_id        uuid,
  p_deleted_by        uuid,
  p_restore_inventory boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log RECORD;
BEGIN
  -- 이미 삭제된 건 재삭제 방지
  IF EXISTS (SELECT 1 FROM shipouts WHERE id = p_shipout_id AND deleted_at IS NOT NULL) THEN
    RAISE EXCEPTION 'SHIPOUT_ALREADY_DELETED'
      USING DETAIL = format('shipout_id:%s 이미 삭제됨', p_shipout_id);
  END IF;

  IF p_restore_inventory THEN
    FOR v_log IN
      SELECT id, inventory_id, quantity
        FROM inventory_logs
       WHERE shipout_id = p_shipout_id
       FOR UPDATE
    LOOP
      UPDATE inventory
         SET quantity   = quantity + v_log.quantity,
             updated_at = now()
       WHERE id = v_log.inventory_id;
    END LOOP;
  END IF;

  -- shipouts soft delete (logs는 FK CASCADE 없이 유지 — 기록은 남김)
  UPDATE shipouts
     SET deleted_at = now()
   WHERE id = p_shipout_id;

  RETURN jsonb_build_object('shipout_id', p_shipout_id, 'ok', true);
END;
$$;

COMMIT;
