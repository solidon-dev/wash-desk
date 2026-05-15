import { supabase } from '$lib/supabase/client';

export async function deleteInventoryLog(logId: string) {
  return supabase.from('inventory_logs').delete().eq('id', logId);
}

export async function cancelInventoryLog(logId: string, cancelledBy: string) {
  return supabase.rpc('cancel_inventory_log', {
    p_log_id: logId,
    p_cancelled_by: cancelledBy,
  });
}

export async function addInventoryLog(
  factoryId: string,
  clientId: string,
  itemId: string,
  inventoryId: string,
  quantity: number,
  createdBy: string,
  logType: 'in' | 'out' = 'in',
  afterQuantity?: number,
  note?: string
) {
  return supabase.from('inventory_logs').insert({
    factory_id: factoryId,
    client_id: clientId,
    item_id: itemId,
    inventory_id: inventoryId,
    log_type: logType,
    quantity,
    after_quantity: afterQuantity ?? null,
    created_by: createdBy,
    note: note ?? null,
  });
}

export async function getInventoryLogs(factoryId: string, clientId: string, itemId: string) {
  return supabase
    .from('inventory_logs')
    .select('*')
    .eq('factory_id', factoryId)
    .eq('client_id', clientId)
    .eq('item_id', itemId)
    .order('processed_at', { ascending: false });
}
