<script lang="ts">
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { login } from '$lib/api/auth';
  import { initializeStore } from '$lib/store.svelte';

  let id = $state('');
  let password = $state('');
  let errorMsg = $state('');
  let loading = $state(false);

  onMount(async () => {
    const ok = await initializeStore();
    if (ok) goto('/laundry');
  });

  async function handleLogin(e: Event) {
    e.preventDefault();
    errorMsg = '';
    loading = true;
    try {
      const { error } = await login(id, password);
      if (error) { errorMsg = '아이디 또는 비밀번호가 올바르지 않습니다.'; return; }
      await initializeStore();
      goto('/laundry');
    } catch {
      errorMsg = '아이디 또는 비밀번호가 올바르지 않습니다.';
    } finally {
      loading = false;
    }
  }
</script>

<div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
  <div class="w-full max-w-xs flex flex-col gap-8">

    <div class="flex flex-col gap-1">
      <h1 class="text-2xl font-bold text-base-content tracking-tight">WashDesk</h1>
      <p class="text-sm text-base-content/40">계정 정보를 입력하세요</p>
    </div>

    <form class="flex flex-col gap-4" onsubmit={handleLogin}>
      <label class="form-control w-full gap-1">
        <span class="label-text text-xs font-medium text-base-content/50 uppercase tracking-wider">아이디</span>
        <input
          type="text"
          class="input input-bordered w-full"
          placeholder="아이디 입력"
          bind:value={id}
          autocomplete="username"
          required
        />
      </label>

      <label class="form-control w-full gap-1">
        <span class="label-text text-xs font-medium text-base-content/50 uppercase tracking-wider">비밀번호</span>
        <input
          type="password"
          class="input input-bordered w-full"
          placeholder="비밀번호 입력"
          bind:value={password}
          autocomplete="current-password"
          required
        />
      </label>

      {#if errorMsg}
        <p class="text-error text-xs font-medium">{errorMsg}</p>
      {/if}

      <button
        type="submit"
        class="btn btn-primary w-full mt-1"
        disabled={loading}
      >
        {#if loading}
          <span class="loading loading-spinner loading-sm"></span>
        {:else}
          로그인
        {/if}
      </button>
    </form>

  </div>
</div>
