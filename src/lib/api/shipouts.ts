import { supabase } from '$lib/supabase/client';

export async function executeShipout(
  factoryId: string,
  clientId: string,
  items: { item_id: string; quantity: number }[],
  createdBy: string
) {
  return supabase.rpc('execute_shipout', {
    p_factory_id: factoryId,
    p_client_id:  clientId,
    p_items:      items,
    p_created_by: createdBy,
  });
}

export async function getShipouts(
  factoryId: string,
  clientId: string | null,
  fromDate: string,   // 'YYYY-MM-DD'
  toDate:   string
) {
  // shipouts 테이블 기준 조회 (deleted_at IS NULL = 삭제 안 된 것)
  // inventory_logs 는 shipout_id FK 로 연결
  let q = supabase
    .from('shipouts')
    .select(`
      id,
      factory_id,
      client_id,
      created_by,
      created_at,
      memo,
      inventory_logs (
        id,
        item_id,
        inventory_id,
        quantity,
        after_quantity,
        processed_at,
        items ( id, name_ko, nickname, categories ( id, name ) )
      )
    `)
    .eq('factory_id', factoryId)
    .is('deleted_at', null)
    .gte('created_at', `${fromDate}T00:00:00.000Z`)
    .lte('created_at', `${toDate}T23:59:59.999Z`)
    .order('created_at', { ascending: false });

  if (clientId) q = q.eq('client_id', clientId);
  return q;
}

export async function updateShipout(
  shipoutId: string,
  items: { item_id: string; new_quantity: number }[],
  updatedBy: string
) {
  return supabase.rpc('update_shipout', {
    p_shipout_id: shipoutId,
    p_items:      items,
    p_updated_by: updatedBy,
  });
}

export async function deleteShipout(shipoutId: string, deletedBy: string, restoreInventory: boolean = true) {
  return supabase.rpc('delete_shipout', {
    p_shipout_id: shipoutId,
    p_deleted_by: deletedBy,
    p_restore_inventory: restoreInventory,
  });
}
