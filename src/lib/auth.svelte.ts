import { supabase } from '$lib/supabase/client';
import type { User, Session } from '@supabase/supabase-js';

export const authStore = $state({
  user: null as User | null,
  session: null as Session | null,
  loading: true,
});

export async function initAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  authStore.session = session;
  authStore.user = session?.user ?? null;
  authStore.loading = false;

  supabase.auth.onAuthStateChange((_event, session) => {
    authStore.session = session;
    authStore.user = session?.user ?? null;
  });
}

export async function login(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function logout() {
  await supabase.auth.signOut();
}
