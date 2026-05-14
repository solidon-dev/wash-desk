import { supabase } from '$lib/supabase/client';
import type { Client, ClientInsert, ClientUpdate } from '$lib/supabase/types';

export async function getClients(factoryId: string) {
  return supabase
    .from('clients')
    .select('*')
    .eq('factory_id', factoryId)
    .is('deleted_at', null)
    .order('name');
}
