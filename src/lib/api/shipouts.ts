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
  // deleted_at IS NULL 인 out 로그를 shipout_id 기준으로 가져옴
  let q = supabase
    .from('inventory_logs')
    .select('*, items(id, name_ko, nickname, categories(id, name))')
    .eq('factory_id', factoryId)
    .eq('log_type', 'out')
    .is('deleted_at', null)
    .not('shipout_id', 'is', null)
    .gte('processed_at', `${fromDate}T00:00:00.000Z`)
    .lte('processed_at', `${toDate}T23:59:59.999Z`)
    .order('processed_at', { ascending: false });

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
