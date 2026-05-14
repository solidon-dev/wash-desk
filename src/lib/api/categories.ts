import { supabase } from '$lib/supabase/client';

export async function getCategories(clientId: string) {
  return supabase
    .from('categories')
    .select('*')
    .eq('client_id', clientId)
    .order('sort_order');
}
