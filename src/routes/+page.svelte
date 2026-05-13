<script lang="ts">
  import { goto } from '$app/navigation';
  import { login, authStore } from '$lib/auth.svelte';
  import { onMount } from 'svelte';

  let id = $state('');
  let password = $state('');
  let errorMsg = $state('');
  let loading = $state(false);

  onMount(() => {
    if (authStore.user) goto('/laundry');
  });

  async function handleLogin(e: Event) {
    e.preventDefault();
    errorMsg = '';
    loading = true;
    try {
      await login(id + '@mail.com', password);
      goto('/laundry');
    } catch {
      errorMsg = '아이디 또는 비밀번호가 올바르지 않습니다.';
    } finally {
      loading = false;
    }
  }
</script>

<div class="min-h-screen bg-zinc-950 flex items-center justify-center p-4">
  <div class="w-full max-w-xs flex flex-col gap-8">

    <div class="flex flex-col gap-1">
      <h1 class="text-2xl font-bold text-white tracking-tight">WashDesk</h1>
      <p class="text-sm text-zinc-500">계정 정보를 입력하세요</p>
    </div>

    <form class="flex flex-col gap-4" onsubmit={handleLogin}>
      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-zinc-400 uppercase tracking-wider" for="id">아이디</label>
        <input
          id="id"
          type="text"
          class="w-full bg-zinc-900 border border-zinc-800 text-white rounded-lg px-4 py-3 text-sm outline-none focus:border-zinc-600 transition-colors placeholder:text-zinc-600"
          placeholder="아이디 입력"
          bind:value={id}
          autocomplete="username"
          required
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label class="text-xs font-medium text-zinc-400 uppercase tracking-wider" for="password">비밀번호</label>
        <input
          id="password"
          type="password"
          class="w-full bg-zinc-900 border border-zinc-800 text-white rounded-lg px-4 py-3 text-sm outline-none focus:border-zinc-600 transition-colors placeholder:text-zinc-600"
          placeholder="비밀번호 입력"
          bind:value={password}
          autocomplete="current-password"
          required
        />
      </div>

      {#if errorMsg}
        <p class="text-xs text-red-400 font-medium">{errorMsg}</p>
      {/if}

      <button
        type="submit"
        class="w-full bg-white hover:bg-zinc-100 active:bg-zinc-200 text-zinc-950 font-semibold rounded-lg px-4 py-3 text-sm transition-colors mt-1 disabled:opacity-40 flex items-center justify-center gap-2"
        disabled={loading}
      >
        {#if loading}
          <span class="w-4 h-4 border-2 border-zinc-400 border-t-zinc-950 rounded-full animate-spin"></span>
        {:else}
          로그인
        {/if}
      </button>
    </form>

  </div>
</div>
