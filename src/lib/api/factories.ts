import { supabase } from '$lib/supabase/client';

export async function getFactories() {
  return supabase
    .from('factories')
    .select('*')
    .is('deleted_at', null)
    .order('name');
}
