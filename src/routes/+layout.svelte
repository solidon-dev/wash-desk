<script lang="ts">
  import '../app.css';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import Icon from '@iconify/svelte';
  import { store, initializeStore, applyFactory, switchClient, resetStore, loadData, NAV_ITEMS } from '$lib/store.svelte';
  import { supabase } from '$lib/supabase/client';

  let { children } = $props();
  const currentPath = $derived($page.url.pathname);
  let showClientModal  = $state(false);
  let showFactoryModal = $state(false);
  let appLoading = $state(true);

  onMount(async () => {
    try {
      const ok = await initializeStore();
      if (!ok && currentPath !== '/') goto('/');
    } finally {
      appLoading = false;
    }
  });

  async function pickFactory(id: string) {
    showFactoryModal = false;
    await applyFactory(id);
  }

  async function pickClient(id: string) {
    showClientModal = false;
    await switchClient(id);
  }

  async function refresh() {
    if (store.factoryId && store.selectedClientId) {
      await loadData(store.factoryId, store.selectedClientId);
    }
  }

  async function handleLogout() {
    await supabase.auth.signOut();
    resetStore();
    goto('/');
  }

  const selectedClient  = $derived(store.clients.find(c => c.id === store.selectedClientId) ?? null);
  const selectedFactory = $derived(store.factories.find(f => f.id === store.factoryId) ?? null);
</script>

<div class="flex flex-col h-screen bg-base-200 overflow-hidden select-none">
  {#if currentPath !== '/'}
    <header class="h-16 bg-primary flex items-center shrink-0 z-10 px-2">

      <!-- 거래처 버튼 -->
      <button
        type="button"
        class="flex items-center gap-2 px-6 h-full hover:bg-white/10 transition-colors shrink-0"
        onclick={() => showClientModal = true}
      >
        <span class="text-xl font-black text-white truncate max-w-48">
          {selectedClient?.name ?? '거래처 선택'}
        </span>
        <Icon icon="heroicons:chevron-down" class="w-5 h-5 text-white/50 shrink-0" />
      </button>

      <div class="w-px h-8 bg-white/20 mx-1 shrink-0"></div>

      <!-- 탭 네비 -->
      <nav class="flex h-full flex-1">
        {#each NAV_ITEMS as nav}
          {@const isActive = currentPath === nav.path}
          <button
            type="button"
            class="px-8 h-full text-base font-black transition-colors
              {isActive ? 'bg-white text-primary' : 'text-white/60 hover:text-white hover:bg-white/10'}"
            onclick={() => void goto(nav.path)}
          >{nav.label}</button>
        {/each}
      </nav>

      <!-- super_admin 공장 셀렉터 -->
      {#if store.isSuperAdmin}
        <button
          type="button"
          class="flex items-center gap-2 px-5 h-full hover:bg-white/10 transition-colors shrink-0 border-l border-white/20"
          onclick={() => showFactoryModal = true}
        >
          <Icon icon="heroicons:building-office-2" class="w-5 h-5 text-white/60 shrink-0" />
          <span class="text-sm font-bold text-white/80 truncate max-w-36">
            {selectedFactory?.name ?? '공장 선택'}
          </span>
          <Icon icon="heroicons:chevron-down" class="w-4 h-4 text-white/40 shrink-0" />
        </button>
      {/if}

      <!-- 새로고침 버튼 -->
      <button
        type="button"
        class="flex items-center justify-center w-12 h-full hover:bg-white/10 transition-colors shrink-0 border-l border-white/20"
        onclick={refresh}
        title="새로고침"
      >
        {#if store.dataLoading || appLoading}
          <span class="loading loading-spinner loading-sm text-white/60"></span>
        {:else}
          <Icon icon="heroicons:arrow-path" class="w-5 h-5 text-white/60" />
        {/if}
      </button>

      <!-- 로그아웃 버튼 -->
      <button
        type="button"
        class="flex items-center justify-center w-12 h-full hover:bg-red-500/20 transition-colors shrink-0 border-l border-white/20"
        onclick={handleLogout}
        title="로그아웃"
      >
        <Icon icon="heroicons:arrow-right-on-rectangle" class="w-5 h-5 text-white/60" />
      </button>

    </header>
  {/if}
  <div class="flex-1 min-h-0 min-w-0 flex flex-col">
    {#if appLoading}
      <div class="flex flex-col items-center justify-center flex-1 gap-3 text-base-content/30">
        <span class="loading loading-spinner loading-lg"></span>
      </div>
    {:else}
      {@render children()}
    {/if}
  </div>
</div>

<!-- 거래처 모달 -->
{#if showClientModal}
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => showClientModal = false}
    onkeydown={(e) => e.key === 'Escape' && (showClientModal = false)}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-2xl shadow-2xl w-full max-w-xs overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
        <span class="text-lg font-bold text-base-content">거래처 선택</span>
        <button type="button" class="btn btn-ghost btn-sm btn-circle" onclick={() => showClientModal = false}>
          <Icon icon="heroicons:x-mark" class="w-5 h-5" />
        </button>
      </div>
      <ul class="overflow-y-auto max-h-96">
        {#each store.clients as client (client.id)}
          {@const isSel = store.selectedClientId === client.id}
          <li>
            <button
              type="button"
              class="w-full flex items-center justify-between px-6 py-4 text-left transition-colors border-b border-base-100 last:border-0
                {isSel ? 'bg-primary/10 text-primary' : 'hover:bg-base-200 text-base-content'}"
              onclick={() => pickClient(client.id)}
            >
              <span class="text-lg font-bold truncate">{client.name}</span>
              {#if isSel}
                <Icon icon="heroicons:check" class="w-5 h-5 text-primary shrink-0 ml-2" />
              {/if}
            </button>
          </li>
        {/each}
      </ul>
    </div>
  </div>
{/if}

<!-- 공장 선택 모달 (super_admin 전용) -->
{#if showFactoryModal}
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => showFactoryModal = false}
    onkeydown={(e) => e.key === 'Escape' && (showFactoryModal = false)}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-2xl shadow-2xl w-full max-w-xs overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
        <span class="text-lg font-bold text-base-content">공장 선택</span>
        <button type="button" class="btn btn-ghost btn-sm btn-circle" onclick={() => showFactoryModal = false}>
          <Icon icon="heroicons:x-mark" class="w-5 h-5" />
        </button>
      </div>
      <ul class="overflow-y-auto max-h-96">
        {#each store.factories as factory (factory.id)}
          {@const isSel = store.factoryId === factory.id}
          <li>
            <button
              type="button"
              class="w-full flex items-center justify-between px-6 py-4 text-left transition-colors border-b border-base-100 last:border-0
                {isSel ? 'bg-primary/10 text-primary' : 'hover:bg-base-200 text-base-content'}"
              onclick={() => pickFactory(factory.id)}
            >
              <span class="text-lg font-bold truncate">{factory.name}</span>
              {#if isSel}
                <Icon icon="heroicons:check" class="w-5 h-5 text-primary shrink-0 ml-2" />
              {/if}
            </button>
          </li>
        {/each}
      </ul>
    </div>
  </div>
{/if}
