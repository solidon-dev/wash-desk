import { supabase } from '$lib/supabase/client';

export async function initAuth() {
  const { data: { session } } = await supabase.auth.getSession();

  supabase.auth.onAuthStateChange(() => {});

  return session;
}

export async function login(username: string, password: string) {
  const email = `${username}@mail.com`;
  return supabase.auth.signInWithPassword({ email, password });
}

export async function logout() {
  return supabase.auth.signOut();
}

export async function getSession() {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}
