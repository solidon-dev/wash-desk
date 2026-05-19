<script lang="ts">
  import Icon from '@iconify/svelte';
  import DatePicker from '$lib/components/DatePicker.svelte';
  import { SvelteMap, SvelteSet } from 'svelte/reactivity';
  import { onMount } from 'svelte';
  import { store, loadData, bulkUpdateInventory, type ItemWithCategory } from '$lib/store.svelte';
  import { executeShipout as executeShipoutRPC } from '$lib/api/shipouts';
  import { getInventory } from '$lib/api/inventory';
  import { getSession } from '$lib/api/auth';

  // ── UI 상태 ──────────────────────────────────────────────────────
  let activeCategoryId = $state<string | 'all'>('all');
  let selectedItemIds = new SvelteSet<string>();
  let quantities = new SvelteMap<string, number>();
  let editingItemId = $state<string | null>(null);
  let numpadValue = $state('');
  let numpadClamped = $state(false);
  let showNumpadModal = $state(false);
  let showMobilePanel = $state(false);
  let showSlipModal = $state(false);
  let applying = $state(false);
  let showShippedAtPicker = $state(false);

  // ── 충돌 모달 (실제 재고 부족 레이스컨디션 대비) ───────────────
  let showConflictModal = $state(false);
  let conflictItemName = $state('');
  function closeConflictModal() { showConflictModal = false; }

  // ── 외부 변경 확인 모달 ──────────────────────────────────────
  type ExternalChangeEntry = {
    itemId:   string;
    itemName: string;
    localQty: number;
    liveQty:  number;
    shipQty:  number;
  };
  let showExternalChangeModal = $state(false);
  let externalChangeEntries = $state<ExternalChangeEntry[]>([]);
  let _resolveExternalChange: ((confirmed: boolean) => void) | null = null;

  function askExternalChange(entries: ExternalChangeEntry[]): Promise<boolean> {
    externalChangeEntries = entries;
    showExternalChangeModal = true;
    return new Promise(resolve => { _resolveExternalChange = resolve; });
  }
  function confirmExternalChange() {
    showExternalChangeModal = false;
    _resolveExternalChange?.(true);
    _resolveExternalChange = null;
  }
  function cancelExternalChange() {
    showExternalChangeModal = false;
    _resolveExternalChange?.(false);
    _resolveExternalChange = null;
  }

  // ── 60초 자동 갱신 + 탭 진입 시 즉시 갱신 ──────────────────────
  onMount(() => {
    if (store.factoryId && store.selectedClientId) {
      loadData(store.factoryId, store.selectedClientId);
    }
    const interval = setInterval(() => {
      if (store.factoryId && store.selectedClientId) {
        loadData(store.factoryId, store.selectedClientId);
      }
    }, 60_000);
    return () => clearInterval(interval);
  });

  function toLocalDatetimeValue(d: Date) {
    const p = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
  }
  let shippedAtLocal = $state(toLocalDatetimeValue(new Date()));

  // ── 공장/거래처 변경 시 UI 초기화 ─────────────────────────────────
  $effect(() => {
    store.factoryId;
    store.selectedClientId;
    activeCategoryId = 'all';
    selectedItemIds.clear();
    quantities.clear();
    editingItemId = null;
    numpadValue = '';
  });

  // ── 파생값 ──────────────────────────────────────────────────────
  let filteredItems = $derived(
    activeCategoryId === 'all'
      ? store.items
      : store.items.filter(i => i.category_id === activeCategoryId)
  );

  let isAllSelected = $derived(
    filteredItems.length > 0 &&
    filteredItems.filter(i => (store.inventoryMap[i.id] ?? 0) > 0).length > 0 &&
    filteredItems.filter(i => (store.inventoryMap[i.id] ?? 0) > 0).every(i => selectedItemIds.has(i.id))
  );

  let selectedEntries = $derived(
    [...selectedItemIds].flatMap(itemId => {
      const item = store.items.find(i => i.id === itemId);
      if (!item) return [];
      const qty = quantities.get(itemId) ?? (store.inventoryMap[itemId] ?? 0);
      return [{ itemId, itemName: item.nickname ?? item.name_ko, categoryName: item.categories?.name ?? '', quantity: qty }];
    })
  );

  let totalSelectedQty = $derived(selectedEntries.reduce((s, e) => s + e.quantity, 0));

  // ── 조작 함수 ────────────────────────────────────────────────────
  function selectCategory(id: string | 'all') {
    activeCategoryId = id;
    selectedItemIds.clear();
    quantities.clear();
    editingItemId = null;
    numpadValue = '';
  }

  function toggleItem(itemId: string) {
    const available = store.inventoryMap[itemId] ?? 0;
    if (available === 0) return;
    if (selectedItemIds.has(itemId)) {
      selectedItemIds.delete(itemId);
      quantities.delete(itemId);
    } else {
      selectedItemIds.add(itemId);
      quantities.set(itemId, available);
    }
  }

  function toggleSelectAll() {
    const available = filteredItems.filter(i => (store.inventoryMap[i.id] ?? 0) > 0);
    if (isAllSelected) {
      selectedItemIds.clear();
      quantities.clear();
    } else {
      for (const item of available) {
        selectedItemIds.add(item.id);
        quantities.set(item.id, store.inventoryMap[item.id] ?? 0);
      }
    }
  }

  function removeEntry(itemId: string) {
    selectedItemIds.delete(itemId);
    quantities.delete(itemId);
  }

  function adjustQty(itemId: string, delta: number) {
    const max = store.inventoryMap[itemId] ?? 0;
    const cur = quantities.get(itemId) ?? max;
    const next = Math.max(0, Math.min(max, cur + delta));
    if (next === 0) { selectedItemIds.delete(itemId); quantities.delete(itemId); }
    else quantities.set(itemId, next);
  }

  function openNumpad(itemId: string) {
    editingItemId = itemId;
    numpadValue = '';
    numpadClamped = false;
    showNumpadModal = true;
  }

  function closeNumpadModal() {
    showNumpadModal = false;
    editingItemId = null;
    numpadValue = '';
    numpadClamped = false;
  }

  function handleNumpadConfirm(val: string) {
    if (!editingItemId) return;
    const n = parseInt(val, 10);
    if (isNaN(n) || n <= 0) { closeNumpadModal(); return; }
    const max = store.inventoryMap[editingItemId] ?? 0;
    const clamped = Math.min(n, max);
    quantities.set(editingItemId, clamped);
    closeNumpadModal();
  }

  async function executeShipout() {
    if (!store.factoryId || !store.selectedClientId || selectedEntries.length === 0) return;
    applying = true;

    const session = await getSession();
    if (!session) { applying = false; return; }

    // RPC 실행 전: 서버 현재값 전체 조회
    const { data: liveInv } = await getInventory(store.factoryId, store.selectedClientId);
    const liveMap: Record<string, number> = {};
    for (const row of liveInv ?? []) liveMap[row.item_id] = row.quantity;

    const changed: ExternalChangeEntry[] = [];
    for (const entry of selectedEntries) {
      const localQty = store.inventoryMap[entry.itemId] ?? 0;
      const liveQty  = liveMap[entry.itemId] ?? 0;
      if (liveQty !== localQty) {
        changed.push({ itemId: entry.itemId, itemName: entry.itemName, localQty, liveQty, shipQty: entry.quantity });
      }
    }

    if (changed.length > 0) {
      bulkUpdateInventory(changed.map(c => ({ item_id: c.itemId, new_qty: c.liveQty })));
      applying = false;
      const confirmed = await askExternalChange(changed);
      if (!confirmed) return;
      applying = true;
    }

    try {
      const itemsPayload = selectedEntries.map(e => ({ item_id: e.itemId, quantity: e.quantity }));
      const { data, error } = await executeShipoutRPC(
        store.factoryId, store.selectedClientId, itemsPayload, session.user.id
      );

      if (error) {
        const isConflict = (error.message ?? '').includes('INSUFFICIENT_STOCK');
        if (isConflict) {
          // 충돌 품목명 파싱
          const match = (error.message ?? '').match(/item_id:([\w-]+)/);
          if (match) {
            const conflictItem = store.items.find(i => i.id === match[1]);
            conflictItemName = conflictItem?.nickname ?? conflictItem?.name_ko ?? '알 수 없음';
          } else {
            conflictItemName = '일부 품목';
          }
          loadData(store.factoryId, store.selectedClientId);
          showSlipModal = false;
          showMobilePanel = false;
          showConflictModal = true;
        }
        return;
      }

      // 재고 로컬 반영
      if (data && typeof data === 'object' && 'items' in data) {
        bulkUpdateInventory((data as { items: { item_id: string; new_qty: number }[] }).items);
      }

      selectedItemIds.clear();
      quantities.clear();
      showSlipModal = false;
      showMobilePanel = false;
    } finally {
      applying = false;
    }
  }

  function p(n: number) { return String(n).padStart(2, '0'); }
  function formatDate(iso: string) { const d = new Date(iso); return `${d.getFullYear()}.${p(d.getMonth()+1)}.${p(d.getDate())}`; }
  function formatTime(iso: string) { const d = new Date(iso); return `${p(d.getHours())}:${p(d.getMinutes())}`; }
</script>

<svelte:head><title>출고 확인</title></svelte:head>

<div class="flex flex-1 min-h-0 min-w-0" style="background:#080d1a;">

  <!-- ── 품목 선택 영역 ── -->
  <div class="flex-1 flex flex-col min-h-0">

    <!-- 카테고리 탭 -->
    <div class="h-16 px-2 shrink-0 flex items-center gap-1 overflow-x-auto scrollbar-none" style="background:#0d1328; border-bottom:1px solid rgba(99,179,237,0.12);">
      <button
        type="button"
        class="shrink-0 px-6 h-full text-base font-black transition-colors rounded-none"
        style={activeCategoryId === 'all' ? 'background:rgba(139,92,246,0.18); color:#c4b5fd; border:1px solid rgba(139,92,246,0.35);' : 'color:rgba(226,232,240,0.5); background:transparent; border:1px solid transparent;'}
        onclick={() => selectCategory('all')}
      >전체</button>
      {#each store.categories as cat (cat.id)}
        <button
          type="button"
          class="shrink-0 px-6 h-full text-base font-black transition-colors rounded-none"
          style={activeCategoryId === cat.id ? 'background:rgba(139,92,246,0.18); color:#c4b5fd; border:1px solid rgba(139,92,246,0.35);' : 'color:rgba(226,232,240,0.5); background:transparent; border:1px solid transparent;'}
          onclick={() => selectCategory(cat.id)}
        >{cat.name}</button>
      {/each}
    </div>

    <!-- 컬럼 헤더 -->
    {#if filteredItems.length > 0}
      <div class="h-12 px-6 shrink-0 flex items-center" style="background:#0d1328; border-bottom:1px solid rgba(99,179,237,0.12);">
        <div class="flex-1 min-w-0">
          <span class="text-xs font-black uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">품목명</span>
        </div>
        <div class="w-32 text-center shrink-0">
          <span class="text-xs font-black uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">재고</span>
        </div>
        <div class="w-52 text-center shrink-0">
          <span class="text-xs font-black uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">출고수량</span>
        </div>
        <div class="w-14 shrink-0 flex items-center justify-center">
          <button
            type="button"
            class="w-9 h-9 rounded-full border-2 transition-all flex items-center justify-center"
            style={isAllSelected ? 'background:#3b82f6; border-color:#3b82f6; box-shadow:0 0 12px rgba(59,130,246,0.5);' : 'border-color:rgba(99,179,237,0.2); background:transparent;'}
            onclick={toggleSelectAll}
          >
            {#if isAllSelected}
              <Icon icon="heroicons:check" class="w-5 h-5 text-primary-content" />
            {/if}
          </button>
        </div>
      </div>
    {/if}

    <!-- 품목 리스트 -->
    <div class="flex-1 overflow-y-auto min-h-0 flex flex-col">
      {#if !store.selectedClientId}
        <div class="flex flex-col items-center justify-center flex-1 gap-2" style="color:rgba(148,163,184,0.35);">
          <Icon icon="heroicons:building-storefront" class="w-10 h-10 opacity-30" />
          <p class="text-sm font-semibold">거래처를 선택해 주세요</p>
        </div>
      {:else if filteredItems.length === 0}
        <div class="flex flex-col items-center justify-center flex-1 gap-2" style="color:rgba(148,163,184,0.35);">
          <Icon icon="heroicons:inbox" class="w-10 h-10 opacity-30" />
          <p class="text-sm font-semibold">품목이 없습니다</p>
        </div>
      {:else}
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemIds.has(item.id)}
          {@const qty = quantities.get(item.id) ?? (store.inventoryMap[item.id] ?? 0)}
          {@const stock = store.inventoryMap[item.id] ?? 0}
          {@const isEmpty = stock === 0}
          <div
            role="button" tabindex={isEmpty ? -1 : 0}
            class="flex items-center min-h-20 px-6 py-3 transition-colors border-l-4"
            style="border-bottom:1px solid rgba(99,179,237,0.07); {isEmpty ? 'opacity:0.4; cursor:not-allowed; border-left-color:transparent;' : isSel ? 'background:rgba(59,130,246,0.07); border-left-color:#3b82f6; cursor:pointer;' : 'border-left-color:transparent; cursor:pointer;'}"
            onclick={() => !isEmpty && toggleItem(item.id)}
            onkeydown={(e) => !isEmpty && e.key === 'Enter' && toggleItem(item.id)}
          >
            <div class="flex-1 min-w-0">
              <p class="text-xl font-bold" style={isSel ? 'color:#93c5fd;' : 'color:#e2e8f0;'}>{item.nickname ?? item.name_ko}</p>
              <p class="text-xs" style="color:rgba(148,163,184,0.4);">{item.categories?.name ?? ''}</p>
            </div>
            <div class="w-32 text-center shrink-0">
              <span class="text-4xl font-black" style={stock === 0 ? 'color:rgba(148,163,184,0.18);' : 'color:#3b82f6; text-shadow:0 0 16px rgba(59,130,246,0.4);'}>{stock}</span>
            </div>
            <div class="w-52 flex items-center justify-center gap-1.5 shrink-0">
              {#if isSel}
                <button class="btn btn-md btn-square text-2xl" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.2); color:#e2e8f0;" onclick={(e) => { e.stopPropagation(); adjustQty(item.id, -1); }}>−</button>
                <button
                  class="min-w-16 px-3 h-12 rounded-lg font-black text-2xl text-center"
                  style="border:2px solid rgba(59,130,246,0.5); color:#93c5fd; background:rgba(59,130,246,0.07);"
                  onclick={(e) => { e.stopPropagation(); openNumpad(item.id); }}
                >{qty}</button>
                <button class="btn btn-md btn-square btn-primary text-2xl" onclick={(e) => { e.stopPropagation(); adjustQty(item.id, 1); }}>+</button>
              {:else}
                <span class="text-xs" style="color:rgba(148,163,184,0.18);">—</span>
              {/if}
            </div>
            <div class="w-14 shrink-0 flex justify-center">
              <div class="w-9 h-9 rounded-full border-2 flex items-center justify-center"
                style={isEmpty ? 'border-color:rgba(148,163,184,0.1);' : isSel ? 'background:#3b82f6; border-color:#3b82f6; box-shadow:0 0 12px rgba(59,130,246,0.5);' : 'border-color:rgba(99,179,237,0.2);'}>
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-5 h-5 text-primary-content" />
                {/if}
              </div>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>

  <!-- ── 출고 확인 패널 (데스크탑) ── -->
  <aside class="hidden md:flex flex-col shrink-0 min-h-0" style="width:22rem; background:#0d1328; border-left:1px solid rgba(99,179,237,0.12);">
    <div class="flex-1 flex flex-col min-h-0">
      {#if selectedEntries.length === 0}
        <div class="flex flex-col items-center justify-center flex-1 gap-4 px-6">
          <div class="w-16 h-16 rounded-2xl flex items-center justify-center" style="background:rgba(99,179,237,0.06); border:1px solid rgba(99,179,237,0.12);">
            <Icon icon="heroicons:clipboard-document-check" class="w-8 h-8" style="color:rgba(148,163,184,0.2);" />
          </div>
          <p class="text-base font-black" style="color:rgba(148,163,184,0.35);">품목을 선택하세요</p>
        </div>
      {:else}
        <div class="px-6 py-6 shrink-0" style="border-bottom:1px solid rgba(99,179,237,0.12);">
          <div class="grid grid-cols-2 gap-3 h-24">
            <div class="rounded-2xl flex flex-col items-center justify-center gap-1" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);">
              <span class="text-xs font-bold" style="color:rgba(148,163,184,0.4);">품목 수</span>
              <span class="text-5xl font-black" style="color:#e2e8f0;">{selectedEntries.length}</span>
              <span class="text-xs font-bold" style="color:rgba(148,163,184,0.3);">종</span>
            </div>
            <div class="rounded-2xl flex flex-col items-center justify-center gap-1" style="background:rgba(59,130,246,0.08); border:2px solid rgba(59,130,246,0.3);">
              <span class="text-xs font-bold" style="color:rgba(147,197,253,0.5);">총 수량</span>
              <span class="text-5xl font-black" style="color:#3b82f6; text-shadow:0 0 16px rgba(59,130,246,0.4);">{totalSelectedQty}</span>
              <span class="text-xs font-bold" style="color:rgba(147,197,253,0.35);">개</span>
            </div>
          </div>
        </div>
      {/if}
    </div>
    <div class="px-6 pt-4 pb-5 space-y-3 shrink-0" style="border-top:1px solid rgba(99,179,237,0.12);">
      <div class="pb-3" style="border-bottom:1px solid rgba(99,179,237,0.12);">
        <p class="text-xs font-black uppercase tracking-wider mb-2" style="color:rgba(148,163,184,0.4);">출고 일시</p>
        <button
          type="button"
          class="h-12 px-4 w-full rounded-xl text-base font-bold transition-colors text-left"
          style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.2); color:#e2e8f0;"
          onclick={() => showShippedAtPicker = true}
        >{shippedAtLocal.replace('T', ' ')}</button>
      </div>
      <button
        class="btn w-full h-16 text-xl font-black"
        style={selectedEntries.length === 0 || applying ? 'background:rgba(29,78,216,0.4); border:1px solid rgba(59,130,246,0.2); color:rgba(255,255,255,0.4); cursor:not-allowed;' : 'background:linear-gradient(135deg,#1d4ed8,#1e40af); border:1px solid rgba(59,130,246,0.5); box-shadow:0 0 20px rgba(59,130,246,0.3); color:#fff;'}
        disabled={selectedEntries.length === 0 || applying}
        onclick={() => showSlipModal = true}
      >
        {#if applying}
          <span class="loading loading-spinner loading-sm"></span>
        {:else}
          <Icon icon="heroicons:archive-box-arrow-down" class="w-6 h-6" />
          출고 확인 ({totalSelectedQty}개)
        {/if}
      </button>
    </div>
  </aside>
</div>

<!-- 모바일 하단 바 -->
{#if selectedEntries.length > 0}
  <div class="fixed bottom-0 left-0 right-0 z-30 md:hidden bg-base-100 border-t border-base-300 px-4 py-3 flex items-center gap-3 shadow-lg">
    <div class="flex-1 min-w-0">
      <p class="text-sm font-bold text-base-content">{selectedEntries.length}개 품목 선택</p>
      <p class="text-xs text-base-content/50">총 {totalSelectedQty}개</p>
    </div>
    <button class="btn btn-primary font-bold px-6" onclick={() => showMobilePanel = true}>출고 확인 →</button>
  </div>
{/if}

<!-- 모바일 bottom sheet -->
{#if showMobilePanel}
  <div class="fixed inset-0 bg-black/40 z-40 md:hidden"
    role="button" tabindex="-1"
    onclick={() => showMobilePanel = false}
    onkeydown={(e) => e.key === 'Escape' && (showMobilePanel = false)}
    aria-label="닫기"
  ></div>
  <div class="fixed bottom-0 left-0 right-0 z-50 md:hidden bg-base-100 rounded-t-2xl shadow-2xl flex flex-col max-h-[85vh]">
    <div class="flex justify-center pt-3 pb-1 shrink-0">
      <div class="w-10 h-1 rounded-full bg-base-300"></div>
    </div>
    <div class="px-4 py-3 border-b border-base-200 shrink-0 flex items-center justify-between">
      <p class="text-sm font-bold">출고 확인</p>
      <button class="btn btn-ghost btn-sm btn-circle" onclick={() => showMobilePanel = false}>
        <Icon icon="heroicons:x-mark" class="w-4 h-4" />
      </button>
    </div>
    <div class="overflow-y-auto flex flex-col flex-1">
      <div class="px-4 py-3 border-b border-base-200 shrink-0">
        <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">선택 품목</p>
        <div class="space-y-1.5">
          {#each selectedEntries as entry (entry.itemId)}
            <div class="flex items-center px-3 py-2 rounded-lg bg-base-200 gap-2">
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold truncate">{entry.itemName}</p>
                <p class="text-xs text-base-content/50">{entry.categoryName}</p>
              </div>
              <span class="text-xl font-bold text-primary shrink-0">{entry.quantity}</span>
              <button class="btn btn-xs btn-circle btn-ghost hover:btn-error" onclick={() => removeEntry(entry.itemId)}>
                <Icon icon="heroicons:x-mark" class="w-3 h-3" />
              </button>
            </div>
          {/each}
        </div>
        <div class="flex items-center justify-between mt-2 px-3 py-2 bg-primary/10 rounded-lg">
          <span class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">합계</span>
          <span class="text-2xl font-black text-primary">{totalSelectedQty}<span class="text-sm font-medium ml-1 text-primary/70">개</span></span>
        </div>
      </div>
      <div class="px-4 py-3 border-b border-base-200 shrink-0">
        <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">출고 일시</p>
        <button type="button"
          class="h-9 px-3 w-full rounded-lg border border-base-300 text-sm font-bold text-left hover:bg-base-200 transition-colors"
          onclick={() => showShippedAtPicker = true}
        >{shippedAtLocal.replace('T', ' ')}</button>
      </div>
    </div>
    <div class="px-4 py-4 border-t border-base-200 space-y-2 shrink-0">
      <button class="btn btn-primary w-full h-12 font-bold"
        onclick={() => { showMobilePanel = false; showSlipModal = true; }}>
        <Icon icon="heroicons:archive-box-arrow-down" class="w-5 h-5" />
        출고 확인 ({totalSelectedQty}개)
      </button>
      <button class="btn btn-ghost w-full font-bold text-sm text-base-content/40 border border-base-200"
        onclick={() => showMobilePanel = false}>취소</button>
    </div>
  </div>
{/if}

<!-- 숫자패드 모달 -->
{#if showNumpadModal && editingItemId !== null}
  {@const modalItem = store.items.find(i => i.id === editingItemId)}
  {@const maxQty = store.inventoryMap[editingItemId] ?? 0}
  {@const numpadNum = numpadValue !== '' ? parseInt(numpadValue, 10) : null}
  <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={closeNumpadModal}
    onkeydown={(e) => e.key === 'Escape' && closeNumpadModal()}
    aria-label="닫기"
  >
    <div class="rounded-2xl shadow-2xl w-[480px] overflow-hidden" style="background:#0d1328; border:1px solid rgba(99,179,237,0.2);"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="px-6 py-5 flex items-center justify-between" style="background:linear-gradient(135deg,#1d4ed8,#1e3a8a); border-bottom:1px solid rgba(99,179,237,0.15);">
        <div>
          <p class="text-xl font-black text-primary-content">{modalItem?.nickname ?? modalItem?.name_ko}</p>
          <p class="text-sm text-primary-content/60 mt-0.5">출고가능 {maxQty}개</p>
        </div>
        <button type="button" class="btn btn-ghost btn-circle text-primary-content/70" onclick={closeNumpadModal}>
          <Icon icon="heroicons:x-mark" class="w-6 h-6" />
        </button>
      </div>
      <div class="p-6 flex flex-col gap-4">
        <div class="grid grid-cols-2 gap-3 h-24">
          <div class="rounded-2xl flex flex-col items-center justify-center gap-1" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);">
            <span class="text-xs font-bold uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">출고가능</span>
            <span class="text-5xl font-black" style="color:#e2e8f0;">{maxQty}</span>
          </div>
          <div class="rounded-2xl flex flex-col items-center justify-center gap-1" style="background:rgba(59,130,246,0.08); border:2px solid rgba(59,130,246,0.4);">
            <span class="text-xs font-bold uppercase tracking-wider" style="color:rgba(148,163,184,0.3);">입력</span>
            <span class="text-5xl font-black tracking-widest" style={numpadValue ? 'color:#3b82f6;' : 'color:rgba(148,163,184,0.2);'}>{numpadValue || '0'}</span>
            {#if numpadClamped}
              <span class="text-xs font-bold text-warning">최대 {maxQty}개</span>
            {/if}
          </div>
        </div>
        <div class="grid grid-cols-3 gap-2 select-none">
          {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
            {#if key === 'clear'}
              <button type="button" class="h-20 rounded-xl font-black text-xl active:scale-95" style="background:rgba(239,68,68,0.12); border:1px solid rgba(239,68,68,0.3); color:#f87171;"
                onclick={() => { numpadValue = ''; numpadClamped = false; }}>C</button>
            {:else if key === 'back'}
              <button type="button" class="h-20 rounded-xl flex items-center justify-center active:scale-95" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.15); color:rgba(148,163,184,0.7);"
                onclick={() => { numpadValue = numpadValue.slice(0, -1); }}>
                <Icon icon="heroicons:backspace" class="w-8 h-8" />
              </button>
            {:else}
              <button type="button" class="h-20 rounded-xl font-black text-2xl active:scale-95" style="background:rgba(17,24,39,0.6); border:1px solid rgba(99,179,237,0.15); color:#e2e8f0;"
                onclick={() => { const v = (numpadValue + key).replace(/^0+(?=\d)/, ''); const n = parseInt(v,10); if (!isNaN(n) && n > maxQty) { numpadValue = String(maxQty); numpadClamped = true; } else if (v.length <= 6) { numpadValue = v; numpadClamped = false; } }}
              >{key}</button>
            {/if}
          {/each}
        </div>
        <button type="button"
          class="btn w-full h-14 text-xl font-black"
          style={numpadValue === '' ? 'background:rgba(22,163,74,0.3); border:1px solid rgba(34,197,94,0.2); color:rgba(255,255,255,0.4); cursor:not-allowed;' : 'background:linear-gradient(135deg,#16a34a,#15803d); border:1px solid rgba(34,197,94,0.5); box-shadow:0 0 16px rgba(34,197,94,0.3); color:#fff;'}
          disabled={numpadValue === ''}
          onclick={() => handleNumpadConfirm(numpadValue)}
        >수량 확인</button>
      </div>
    </div>
  </div>
{/if}

<!-- 출고 전표 확인 모달 -->
{#if showSlipModal}
  {@const sc = store.clients.find(c => c.id === store.selectedClientId)}
  {@const slipTotal = selectedEntries.reduce((a, i) => a + i.quantity, 0)}
  <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => showSlipModal = false}
    onkeydown={(e) => e.key === 'Escape' && (showSlipModal = false)}
    aria-label="닫기"
  >
    <div class="bg-base-100 rounded-2xl shadow-2xl w-96 flex flex-col max-h-[80vh] overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="px-5 py-4 border-b border-base-200 flex items-center justify-between">
        <span class="text-sm font-bold">출고 전표 확인</span>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" onclick={() => showSlipModal = false}>
          <Icon icon="heroicons:x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>
      <div class="px-6 py-5 space-y-4 flex-1 overflow-y-auto">
        <div class="text-center border-b border-base-200 pb-4">
          <p class="text-lg font-black">출고 전표</p>
          <p class="text-xs text-base-content/40 mt-1">{formatDate(new Date(shippedAtLocal).toISOString())} {formatTime(new Date(shippedAtLocal).toISOString())}</p>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-base-content/50">거래처</span>
          <span class="font-bold">{sc?.name ?? '미확인'}</span>
        </div>
        <div class="border-t border-base-200 pt-3 space-y-2">
          {#each selectedEntries as entry (entry.itemId)}
            <div class="flex justify-between text-sm">
              <span>{entry.itemName}</span>
              <span class="font-bold tabular-nums">{entry.quantity}개</span>
            </div>
          {/each}
        </div>
        <div class="border-t-2 border-base-content pt-3 flex justify-between">
          <span class="text-sm font-bold">합계</span>
          <span class="text-lg font-black tabular-nums">{slipTotal}개</span>
        </div>
      </div>
      <div class="px-5 py-4 border-t border-base-200 flex gap-2">
        <button class="btn btn-ghost flex-1 font-bold border border-base-300" onclick={() => showSlipModal = false}>취소</button>
        <button class="btn btn-primary flex-1 font-bold" disabled={applying} onclick={executeShipout}>
          {#if applying}
            <span class="loading loading-spinner loading-sm"></span>
          {:else}
            <Icon icon="heroicons:archive-box-arrow-down" class="w-4 h-4" />
            출고 확인
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<DatePicker
  show={showShippedAtPicker}
  target="single"
  mode="datetime"
  fromDate={shippedAtLocal.slice(0,10)}
  toDate={shippedAtLocal.slice(0,10)}
  datetimeValue={shippedAtLocal}
  onselect={() => {}}
  ondatetimeselect={(v) => { shippedAtLocal = v; }}
  onclose={() => showShippedAtPicker = false}
/>

<!-- 충돌 모달: 다른 기기에서 수정되어 재고가 업데이트됨 -->
{#if showConflictModal}
  <div class="fixed inset-0 bg-black/50 z-100 flex items-center justify-center p-4">
    <div class="bg-base-100 rounded-2xl shadow-2xl max-w-sm w-full p-6 flex flex-col gap-4">
      <div class="flex items-center gap-3">
        <span class="w-10 h-10 rounded-full bg-warning/15 flex items-center justify-center shrink-0">
          <Icon icon="heroicons:exclamation-triangle" class="w-5 h-5 text-warning" />
        </span>
        <h3 class="text-lg font-black text-base-content">재고 변경 충돌</h3>
      </div>
      <p class="text-sm text-base-content/70 leading-relaxed">
        <strong class="text-base-content">{conflictItemName}</strong> 항목의 재고가 다른 기기에서 수정되어 처리할 수 없습니다.<br/>
        최신 재고로 새로고침했으니 다시 확인 후 출고해 주세요.
      </p>
      <button
        type="button"
        class="btn btn-warning w-full font-black"
        onclick={closeConflictModal}
      >확인</button>
    </div>
  </div>
{/if}

<!-- 외부 변경 확인 모달: 다른 기기에서 재고가 바뀐 경우 출고 여부 확인 -->
{#if showExternalChangeModal && externalChangeEntries.length > 0}
  <div class="fixed inset-0 bg-black/50 z-100 flex items-center justify-center p-4">
    <div class="bg-base-100 rounded-2xl shadow-2xl max-w-sm w-full p-6 flex flex-col gap-4">
      <div class="flex items-center gap-3">
        <span class="w-10 h-10 rounded-full bg-warning/15 flex items-center justify-center shrink-0">
          <Icon icon="heroicons:exclamation-triangle" class="w-5 h-5 text-warning" />
        </span>
        <h3 class="text-lg font-black text-base-content">다른 기기에서 재고 변경됨</h3>
      </div>

      <div class="flex flex-col gap-2 max-h-64 overflow-y-auto">
        {#each externalChangeEntries as e (e.itemId)}
          <div class="rounded-xl bg-base-200 p-3 text-sm flex flex-col gap-1.5">
            <p class="font-black text-base-content truncate">{e.itemName}</p>
            <div class="flex justify-between text-base-content/50">
              <span>표시된 재고</span>
              <span class="font-bold">{e.localQty}개</span>
            </div>
            <div class="flex justify-between font-bold text-warning">
              <span>실제 현재 재고</span>
              <span>
                {e.liveQty}개
                ({e.liveQty - e.localQty >= 0 ? '+' : ''}{e.liveQty - e.localQty})
              </span>
            </div>
            <div class="flex justify-between border-t border-base-300 pt-1.5 text-base-content/50">
              <span>출고 수량</span>
              <span class="font-bold text-error">-{e.shipQty}개</span>
            </div>
            {#if e.liveQty < e.shipQty}
              <p class="text-xs font-bold text-error">⚠️ 재고 부족 — 현재 {e.liveQty}개, 출고 요청 {e.shipQty}개</p>
            {:else}
              <div class="flex justify-between font-black">
                <span>출고 후 재고</span>
                <span class="text-primary">{e.liveQty - e.shipQty}개</span>
              </div>
            {/if}
          </div>
        {/each}
      </div>

      <p class="text-sm text-base-content/70">계속 출고를 진행하시겠습니까?</p>

      <div class="flex gap-2">
        <button
          type="button"
          class="btn btn-ghost flex-1 border border-base-300 font-bold"
          onclick={cancelExternalChange}
        >취소</button>
        <button
          type="button"
          class="btn btn-primary flex-1 font-bold"
          onclick={confirmExternalChange}
        >출고하기</button>
      </div>
    </div>
  </div>
{/if}
