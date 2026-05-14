import { supabase } from '$lib/supabase/client';

export async function getInventory(factoryId: string, clientId: string) {
  return supabase
    .from('inventory')
    .select('*')
    .eq('factory_id', factoryId)
    .eq('client_id', clientId);
}

/**
 * 재고를 원자적으로 delta만큼 변경한다.
 * delta > 0 → 입고, delta < 0 → 출고
 * 출고 시 재고 부족이면 error.code === 'INSUFFICIENT_STOCK' 로 에러 반환.
 * DB의 process_inventory_delta RPC를 사용하므로 동시 요청 충돌 안전.
 */
export async function processInventoryDelta(
  factoryId: string,
  clientId: string,
  itemId: string,
  delta: number,
  createdBy: string
): Promise<{ data: { id: string; old_qty: number; new_qty: number } | null; error: { code: string; message: string } | null }> {
  const { data, error } = await supabase.rpc('process_inventory_delta', {
    p_factory_id: factoryId,
    p_client_id: clientId,
    p_item_id: itemId,
    p_delta: delta,
  });

  if (error) {
    // Supabase는 RAISE EXCEPTION 메시지를 error.message에 담는다
    const code = (error.message ?? '').includes('INSUFFICIENT_STOCK') ? 'INSUFFICIENT_STOCK' : 'UNKNOWN';
    return { data: null, error: { code, message: error.message ?? '알 수 없는 오류' } };
  }

  return { data: data as { id: string; old_qty: number; new_qty: number }, error: null };
}

/** 하위 호환 – laundry/shipout 페이지가 아직 upsertInventory를 쓰는 경우 대비 */
export async function upsertInventory(
  factoryId: string,
  clientId: string,
  itemId: string,
  addQuantity: number,
  createdBy: string
) {
  return processInventoryDelta(factoryId, clientId, itemId, addQuantity, createdBy);
}
