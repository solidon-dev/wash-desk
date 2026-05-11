<script lang="ts">
  import '../app.css';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import Icon from '@iconify/svelte';
  import { store, selectClient, NAV_ITEMS } from '$lib/store.svelte';

  let { children } = $props();
  const currentPath = $derived($page.url.pathname);
  let showClientModal = $state(false);

  function pickClient(id: string) {
    selectClient(id);
    showClientModal = false;
  }

  const selectedClient = $derived(
    store.clients.find(c => c.id === store.selectedClientId) ?? null
  );
</script>

<div class="flex flex-col h-screen bg-base-200 overflow-hidden select-none">
  <header class="h-20 bg-primary flex items-center shrink-0 z-10">
    <!-- 거래처 버튼 -->
    <button
      type="button"
      class="flex items-center gap-2 px-8 h-full hover:bg-white/10 transition-colors shrink-0"
      onclick={() => showClientModal = true}
    >
      <span class="text-2xl font-black text-white/90 truncate max-w-64">
        {selectedClient?.name ?? '거래처 선택'}
      </span>
      <Icon icon="heroicons:chevron-down" class="w-6 h-6 text-white/50 shrink-0" />
    </button>
    <div class="w-px h-9 bg-white/20 mx-2 shrink-0"></div>
    <!-- 탭 네비 -->
    <nav class="flex h-full">
      {#each NAV_ITEMS as nav}
        {@const isActive = currentPath === nav.path}
        <button
          type="button"
          class="px-10 h-full text-xl font-black transition-colors
            {isActive
              ? 'bg-white text-primary'
              : 'text-white/60 hover:text-white hover:bg-white/10'}"
          onclick={() => void goto(nav.path)}
        >{nav.label}</button>
      {/each}
    </nav>
  </header>
  <div class="flex-1 min-h-0 min-w-0 flex flex-col">
    {@render children()}
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
              class="w-full flex items-center justify-between px-6 py-5 text-left transition-colors border-b border-base-100 last:border-0
                {isSel ? 'bg-primary/8 text-primary' : 'hover:bg-base-50 text-base-content'}"
              onclick={() => pickClient(client.id)}
            >
              <span class="text-xl font-bold truncate">{client.name}</span>
              {#if isSel}
                <Icon icon="heroicons:check" class="w-6 h-6 text-primary shrink-0 ml-2" />
              {/if}
            </button>
          </li>
        {/each}
      </ul>
    </div>
  </div>
{/if}
