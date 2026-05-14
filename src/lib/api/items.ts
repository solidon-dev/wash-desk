import { supabase } from '$lib/supabase/client';

export async function getItemsByClient(clientId: string) {
  return supabase
    .from('items')
    .select('*, categories(id, name)')
    .eq('client_id', clientId)
    .order('sort_order');
}

export async function createTempItem(
  clientId: string,
  categoryId: string,
  nameKo: string
) {
  return supabase.rpc('create_item_with_price', {
    p_client_id: clientId,
    p_category_id: categoryId,
    p_name_ko: nameKo,
    p_unit_price: 1,
  });
}
