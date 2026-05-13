<script lang="ts">
  import { goto } from '$app/navigation';
  import { login, authStore } from '$lib/auth.svelte';
  import { onMount } from 'svelte';

  const DOMAIN = '@mail.com';

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
      await login(id + DOMAIN, password);
      goto('/laundry');
    } catch (err: any) {
      errorMsg = '아이디 또는 비밀번호가 올바르지 않습니다.';
    } finally {
      loading = false;
    }
  }
</script>

<div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
  <div class="w-full max-w-sm">
    <div class="bg-base-100 rounded-2xl shadow-xl overflow-hidden">
      <div class="bg-primary px-8 py-10 flex flex-col items-center gap-2">
        <div class="w-16 h-16 bg-white/20 rounded-2xl flex items-center justify-center">
          <svg class="w-9 h-9 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M3 7a2 2 0 012-2h14a2 2 0 012 2v1a4 4 0 01-4 4H7a4 4 0 01-4-4V7z" />
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M3 12v5a2 2 0 002 2h14a2 2 0 002-2v-5" />
          </svg>
        </div>
        <h1 class="text-2xl font-black text-white mt-1">WashDesk</h1>
        <p class="text-white/60 text-sm font-medium">세탁 관리 시스템</p>
      </div>

      <form class="px-8 py-8 flex flex-col gap-5" onsubmit={handleLogin}>
        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-base-content/70" for="id">아이디</label>
          <div class="flex items-center input input-bordered w-full gap-0 pr-0">
            <input
              id="id"
              type="text"
              class="flex-1 bg-transparent outline-none min-w-0"
              placeholder="아이디"
              bind:value={id}
              autocomplete="username"
              required
            />
            <span class="text-sm font-semibold text-base-content/40 px-3 shrink-0">{DOMAIN}</span>
          </div>
        </div>
        <div class="flex flex-col gap-2">
          <label class="text-sm font-bold text-base-content/70" for="password">비밀번호</label>
          <input
            id="password"
            type="password"
            class="input input-bordered w-full"
            placeholder="비밀번호"
            bind:value={password}
            autocomplete="current-password"
            required
          />
        </div>

        {#if errorMsg}
          <div class="alert alert-error py-3 text-sm font-semibold">
            {errorMsg}
          </div>
        {/if}

        <button
          type="submit"
          class="btn btn-primary w-full text-base font-black"
          disabled={loading}
        >
          {#if loading}
            <span class="loading loading-spinner loading-sm"></span>
            로그인 중...
          {:else}
            로그인
          {/if}
        </button>
      </form>
    </div>
  </div>
</div>
