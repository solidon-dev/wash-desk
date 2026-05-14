<script lang="ts">
  import Icon from '@iconify/svelte';
  import { fly } from 'svelte/transition';
  import { store, selectClient } from '$lib/store.svelte';
  import { getItemsByClient } from '$lib/api/items';
  import { getCategories } from '$lib/api/categories';
  import { getInventory, processInventoryDelta } from '$lib/api/inventory';
  import { addInventoryLog, getInventoryLogs } from '$lib/api/inventory_logs';
  import { getSession } from '$lib/api/auth';
  import type { Item, Category, InventoryLog } from '$lib/supabase/types';

  // ── 타입 ─────────────────────────────────────────────────────────
  type ItemWithCategory = Item & { categories: { id: string; name: string } | null };
  type InventoryMap = Record<string, number>;   // item_id → quantity
  type InventoryIdMap = Record<string, string>; // item_id → inventory.id

  // ── 상태 ─────────────────────────────────────────────────────────
  let categories = $state<Category[]>([]);
  let items = $state<ItemWithCategory[]>([]);
  let inventoryMap = $state<InventoryMap>({});
  let inventoryIdMap = $state<InventoryIdMap>({});

  let activeCategoryId = $state<string | 'all'>('all');
  let selectedItemId = $state<string | null>(null);
  let inputValue = $state('');
  let applying = $state(false);

  // ── 충돌 모달 ────────────────────────────────────────────────────
  let showConflictModal = $state(false);
  function closeConflictModal() { showConflictModal = false; }

  // ── 60초 자동 갱신 ───────────────────────────────────────────────
  $effect(() => {
    const interval = setInterval(() => {
      if (store.factoryId && store.selectedClientId) {
        loadData(store.factoryId, store.selectedClientId);
      }
    }, 60_000);
    return () => clearInterval(interval);
  });

  // 기록 드로어
  let showLogDrawer = $state(false);
  let logTargetItem = $state<ItemWithCategory | null>(null);
  let logs = $state<InventoryLog[]>([]);
  let logsLoading = $state(false);
  const LOG_PAGE_SIZE = 20;
  let logVisibleCount = $state(LOG_PAGE_SIZE);

  // ── 데이터 로드 ──────────────────────────────────────────────────
  async function loadData(factoryId: string, clientId: string) {
    const [catRes, itemRes, invRes] = await Promise.all([
      getCategories(clientId),
      getItemsByClient(clientId),
      getInventory(factoryId, clientId),
    ]);

    categories = catRes.data ?? [];

    const iMap: InventoryMap = {};
    const idMap: InventoryIdMap = {};
    for (const row of invRes.data ?? []) {
      iMap[row.item_id] = row.quantity;
      idMap[row.item_id] = row.id;
    }
    inventoryMap = iMap;
    inventoryIdMap = idMap;

    // 재고 많은 순으로 정렬
    const rawItems = (itemRes.data ?? []) as ItemWithCategory[];
    items = rawItems.slice().sort((a, b) => {
      const qa = iMap[a.id] ?? 0;
      const qb = iMap[b.id] ?? 0;
      return qb - qa;
    });
  }

  // ── 거래처/공장 변경 감지 ────────────────────────────────────────
  $effect(() => {
    const fid = store.factoryId;
    const cid = store.selectedClientId;
    if (fid && cid) {
      selectedItemId = null;
      inputValue = '';
      loadData(fid, cid);
    }
  });

  // ── 파생값 ──────────────────────────────────────────────────────
  let filteredItems = $derived(
    activeCategoryId === 'all'
      ? items
      : items.filter(i => i.category_id === activeCategoryId)
  );

  let selectedItem = $derived(
    items.find(i => i.id === selectedItemId) ?? null
  );

  let currentQuantity = $derived(
    selectedItemId ? (inventoryMap[selectedItemId] ?? 0) : 0
  );

  let inputNum = $derived(inputValue !== '' ? parseInt(inputValue, 10) : null);

  // ── 조작 함수 ────────────────────────────────────────────────────
  function selectCategory(id: string | 'all') {
    activeCategoryId = id;
    selectedItemId = null;
    inputValue = '';
  }

  function toggleItem(id: string) {
    selectedItemId = selectedItemId === id ? null : id;
    inputValue = '';
  }

  async function applyInput() {
    const num = inputNum;
    if (!num || isNaN(num) || num <= 0) return;
    if (!store.factoryId || !store.selectedClientId || !selectedItemId) return;

    applying = true;
    try {
      const session = await getSession();
      if (!session) return;

      const { data: inv, error: invErr } = await processInventoryDelta(
        store.factoryId,
        store.selectedClientId,
        selectedItemId,
        num,
        session.user.id
      );

      if (invErr) {
        // 충돌(재고 부족) → 최신 데이터로 갱신 후 모달
        await loadData(store.factoryId, store.selectedClientId);
        showConflictModal = true;
        return;
      }
      if (!inv) return;

      await addInventoryLog(
        store.factoryId,
        store.selectedClientId,
        selectedItemId,
        inv.id,
        num,
        session.user.id,
        'in',
        inv.new_qty
      );

      // 로컬 상태 즉시 반영
      inventoryMap = { ...inventoryMap, [selectedItemId]: inv.new_qty };
      // 재정렬
      items = items.slice().sort((a, b) => (inventoryMap[b.id] ?? 0) - (inventoryMap[a.id] ?? 0));
      inputValue = '';
    } finally {
      applying = false;
    }
  }

  async function openLogDrawer(item: ItemWithCategory) {
    logTargetItem = item;
    logVisibleCount = LOG_PAGE_SIZE;
    showLogDrawer = true;
    logsLoading = true;
    if (store.factoryId && store.selectedClientId) {
      const { data } = await getInventoryLogs(store.factoryId, store.selectedClientId, item.id);
      logs = data ?? [];
    }
    logsLoading = false;
  }

  function closeLogDrawer() {
    showLogDrawer = false;
    logTargetItem = null;
    logs = [];
  }

  function formatTime(isoStr: string) {
    const d = new Date(isoStr);
    const p = (n: number) => String(n).padStart(2, '0');
    return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
  }

  function formatDate(isoStr: string) {
    const d = new Date(isoStr);
    const p = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}`;
  }
</script>

<div class="flex flex-1 min-h-0 min-w-0">

  <!-- ── 왼쪽: 품목 리스트 ─────────────────────────────────────── -->
  <div class="flex-1 flex flex-col min-h-0 min-w-0 bg-base-100">

    <!-- 카테고리 탭 -->
    <div class="h-16 bg-base-100 border-b border-base-300 px-2 shrink-0 flex items-center gap-1 overflow-x-auto scrollbar-none">
      <button
        type="button"
        class="shrink-0 px-6 h-full text-base font-black transition-colors
          {activeCategoryId === 'all' ? 'bg-primary text-primary-content' : 'text-base-content/50 hover:bg-base-200'}"
        onclick={() => selectCategory('all')}
      >전체</button>
      {#each categories as cat (cat.id)}
        <button
          type="button"
          class="shrink-0 px-6 h-full text-base font-black transition-colors
            {activeCategoryId === cat.id ? 'bg-primary text-primary-content' : 'text-base-content/50 hover:bg-base-200'}"
          onclick={() => selectCategory(cat.id)}
        >{cat.name}</button>
      {/each}
    </div>



    <!-- 컬럼 헤더 -->
    {#if filteredItems.length > 0}
      <div class="h-12 bg-base-200 border-b border-base-300 px-6 shrink-0 flex items-center">
        <div class="flex-1 min-w-0">
          <span class="text-xs font-black text-base-content/40 uppercase tracking-wider">품목명</span>
        </div>
        <div class="w-10 shrink-0"></div>
        <div class="w-32 text-center shrink-0">
          <span class="text-xs font-black text-base-content/40 uppercase tracking-wider">수량</span>
        </div>
        <div class="w-14 shrink-0"></div>
      </div>
    {/if}

    <!-- 품목 리스트 -->
    <div class="flex-1 overflow-y-auto min-h-0 flex flex-col">
      {#if !store.selectedClientId}
        <div class="flex flex-col items-center justify-center flex-1 gap-2 text-base-content/30">
          <Icon icon="heroicons:building-storefront" class="w-10 h-10 opacity-30" />
          <p class="text-sm font-semibold">거래처를 선택해 주세요</p>
        </div>
      {:else if filteredItems.length === 0}
        <div class="flex flex-col items-center justify-center flex-1 gap-2 text-base-content/30">
          <Icon icon="heroicons:inbox" class="w-10 h-10 opacity-30" />
          <p class="text-sm font-semibold">등록된 품목이 없습니다</p>
        </div>
      {:else}
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemId === item.id}
          {@const qty = inventoryMap[item.id] ?? 0}
          <div
            class="flex items-center min-h-20 px-6 py-3 border-b border-base-200 transition-colors border-l-4
              {isSel ? 'bg-primary/5 border-l-primary' : 'border-l-transparent hover:bg-base-50'}"
          >
            <button
              type="button"
              class="flex-1 py-2 text-left min-w-0"
              onclick={() => toggleItem(item.id)}
            >
              <span class="text-xl font-bold truncate block {isSel ? 'text-primary' : 'text-base-content'}">
                {item.nickname ?? item.name_ko}
              </span>
              <span class="text-xs text-base-content/30">{item.categories?.name ?? ''}</span>
            </button>

            <!-- 기록 버튼 -->
            <div class="w-10 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="btn btn-ghost btn-sm btn-square text-base-content/30 hover:text-base-content/60"
                onclick={(e) => { e.stopPropagation(); openLogDrawer(item); }}
              >
                <Icon icon="heroicons:clock" class="w-5 h-5" />
              </button>
            </div>

            <!-- 수량 -->
            <div class="w-32 flex justify-center items-center shrink-0">
              <span class="text-4xl font-black {qty === 0 ? 'text-base-content/20' : 'text-primary'}">
                {qty}
              </span>
            </div>

            <!-- 선택 인디케이터 -->
            <div class="w-14 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="w-9 h-9 rounded-full border-2 transition-all flex items-center justify-center
                  {isSel ? 'bg-primary border-primary' : 'border-base-300 hover:border-primary'}"
                onclick={() => toggleItem(item.id)}
              >
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-5 h-5 text-primary-content" />
                {/if}
              </button>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>

  <!-- ── 오른쪽 패널 ────────────────────────────────────────────── -->
  <aside class="hidden md:flex w-2/5 bg-base-100 border-l border-base-300 flex-col shrink-0 min-h-0">
    <div class="flex-1 flex flex-col min-h-0">
      {#if selectedItem}
        <div class="flex flex-col flex-1 gap-4 px-6 py-6 justify-center">

          <!-- 현재 입력값 표시 -->
          <div class="rounded-2xl bg-base-200 flex items-center justify-center" style="height: 8rem;">
            <span class="text-8xl font-black tabular-nums {inputNum !== null && !isNaN(inputNum) ? 'text-primary' : 'text-base-content/20'}">{inputValue || '0'}</span>
          </div>

          <!-- 숫자패드 -->
          <div class="grid grid-cols-3 gap-2 select-none">
            {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
              {#if key === 'clear'}
                <button type="button" class="h-20 rounded-xl font-black text-xl btn btn-error btn-outline active:scale-95"
                  onclick={() => { inputValue = ''; }}>C</button>
              {:else if key === 'back'}
                <button type="button" class="h-20 rounded-xl btn btn-ghost bg-base-200 border border-base-300 flex items-center justify-center active:scale-95"
                  onclick={() => { inputValue = inputValue.slice(0, -1); }}>
                  <Icon icon="heroicons:backspace" class="w-7 h-7" />
                </button>
              {:else}
                <button type="button" class="h-20 rounded-xl font-black text-2xl btn btn-ghost bg-base-100 border border-base-300 shadow-sm active:scale-95"
                  onclick={() => { const v = (inputValue + key).replace(/^0+(?=\d)/, ''); if (v.length <= 6) inputValue = v; }}>{key}</button>
              {/if}
            {/each}
          </div>

          <!-- 적용 버튼 -->
          <button
            type="button"
            class="btn btn-success w-full h-16 text-xl font-black"
            disabled={inputNum === null || isNaN(inputNum ?? NaN) || applying}
            onclick={applyInput}
          >
            {#if applying}
              <span class="loading loading-spinner loading-sm"></span>
            {:else}
              추가하기
            {/if}
          </button>

        </div>
      {:else}
        <div class="flex flex-col items-center justify-center flex-1 gap-3 text-base-content/20">
          <Icon icon="heroicons:hand-raised" class="w-10 h-10" />
          <p class="text-sm font-semibold">품목을 선택하세요</p>
        </div>
      {/if}
    </div>
  </aside>
</div>

<!-- ── 모바일 Bottom Sheet ──────────────────────────────────────── -->
{#if selectedItemId && selectedItem}
  <div
    class="fixed inset-0 bg-black/30 z-30 md:hidden"
    role="button" tabindex="-1"
    onclick={() => { selectedItemId = null; inputValue = ''; }}
    onkeydown={(e) => e.key === 'Escape' && (selectedItemId = null)}
    aria-label="닫기"
  ></div>

  <div class="fixed bottom-0 left-0 right-0 z-40 md:hidden bg-base-100 rounded-t-2xl shadow-2xl flex flex-col max-h-[80vh]">
    <div class="flex justify-center pt-3 pb-1 shrink-0">
      <div class="w-10 h-1 rounded-full bg-base-300"></div>
    </div>
    <div class="px-4 py-3 border-b border-base-200 shrink-0 flex items-center justify-between">
      <div>
        <p class="text-sm font-bold text-base-content">{selectedItem.nickname ?? selectedItem.name_ko}</p>
        <p class="text-xs text-base-content/40">현재 {currentQuantity}개</p>
      </div>
      <button type="button" class="btn btn-ghost btn-sm btn-circle"
        onclick={() => { selectedItemId = null; inputValue = ''; }}>
        <Icon icon="heroicons:x-mark" class="w-4 h-4" />
      </button>
    </div>

    <div class="overflow-y-auto flex flex-col">
      <div class="px-4 pt-3 pb-1 shrink-0">
        <div class="h-14 rounded-xl bg-base-200 flex items-center justify-center">
          <span class="text-4xl font-black tabular-nums {inputNum !== null && !isNaN(inputNum) ? 'text-primary' : 'text-base-content/20'}">{inputValue || '0'}</span>
        </div>
      </div>

      <div class="px-4 py-3 shrink-0">
        <div class="grid grid-cols-3 gap-2 select-none">
          {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
            {#if key === 'clear'}
              <button type="button" class="h-16 rounded-lg font-black text-xl btn btn-error btn-outline active:scale-95"
                onclick={() => { inputValue = ''; }}>C</button>
            {:else if key === 'back'}
              <button type="button" class="h-16 rounded-lg btn btn-ghost bg-base-200 border border-base-300 flex items-center justify-center active:scale-95"
                onclick={() => { inputValue = inputValue.slice(0, -1); }}>
                <Icon icon="heroicons:backspace" class="w-6 h-6" />
              </button>
            {:else}
              <button type="button" class="h-16 rounded-lg font-black text-xl btn btn-ghost bg-base-100 border border-base-300 active:scale-95"
                onclick={() => { const v = (inputValue + key).replace(/^0+(?=\d)/, ''); if (v.length <= 6) inputValue = v; }}>{key}</button>
            {/if}
          {/each}
        </div>
      </div>

      <div class="px-4 pb-4 shrink-0">
        <button
          type="button"
          class="btn btn-success w-full h-12 font-bold"
          disabled={inputNum === null || isNaN(inputNum ?? NaN) || applying}
          onclick={applyInput}
        >
          {#if applying}
            <span class="loading loading-spinner loading-sm"></span>
          {:else}
            추가하기
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ── 기록 드로어 ────────────────────────────────────────────────── -->
{#if showLogDrawer}
  <div class="fixed inset-0 bg-black/40 z-40"
    role="button" tabindex="-1"
    onclick={closeLogDrawer}
    onkeydown={(e) => e.key === 'Escape' && closeLogDrawer()}
    aria-label="닫기"
  ></div>

  <div class="fixed top-0 right-0 h-full w-full max-w-md bg-base-100 shadow-2xl z-50 flex flex-col" transition:fly={{ x: 400, duration: 200 }}>
    <div class="px-6 py-5 bg-primary shrink-0 flex items-center justify-between">
      <h3 class="text-xl font-black text-primary-content truncate">
        {logTargetItem?.nickname ?? logTargetItem?.name_ko ?? ''} 기록
      </h3>
      <button type="button" class="btn btn-ghost btn-circle text-primary-content/70" onclick={closeLogDrawer}>
        <Icon icon="heroicons:x-mark" class="w-6 h-6" />
      </button>
    </div>

    <div class="h-12 bg-base-200 border-b border-base-300 shrink-0 flex items-center px-6">
      <div class="flex-1 grid grid-cols-3 gap-2 text-xs font-black text-base-content/40 uppercase tracking-wider">
        <div>시각</div>
        <div class="text-center">입출고</div>
        <div class="text-center text-primary">수량</div>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto">
      {#if logsLoading}
        <div class="flex items-center justify-center h-40">
          <span class="loading loading-spinner loading-md"></span>
        </div>
      {:else if logs.length === 0}
        <div class="flex flex-col items-center justify-center h-full text-base-content/20 gap-3">
          <Icon icon="heroicons:clock" class="w-14 h-14 opacity-40" />
          <p class="text-base font-bold">기록이 없습니다</p>
        </div>
      {:else}
        {#each logs.slice(0, logVisibleCount) as log (log.id)}
          <div class="px-6 py-4 border-b border-base-200 hover:bg-base-50 transition-colors">
            <div class="grid grid-cols-3 gap-2 items-center">
              <div>
                <span class="text-base font-black tabular-nums block">{formatTime(log.processed_at)}</span>
                <span class="text-xs text-base-content/30">{formatDate(log.processed_at)}</span>
              </div>
              <div class="text-center">
                {#if log.log_type === 'in'}
                  <span class="text-3xl font-black text-success tabular-nums">+{log.quantity}</span>
                {:else}
                  <span class="text-3xl font-black text-error tabular-nums">-{log.quantity}</span>
                {/if}
              </div>
              <div class="text-right">
                <span class="text-2xl font-black text-primary tabular-nums">{log.after_quantity ?? '—'}</span>
              </div>
            </div>
          </div>
        {/each}
        {#if logVisibleCount < logs.length}
          <div class="px-6 py-4">
            <button type="button" class="btn btn-ghost w-full border border-base-300"
              onclick={() => logVisibleCount += LOG_PAGE_SIZE}>
              더 보기 ({logs.length - logVisibleCount}건)
            </button>
          </div>
        {/if}
      {/if}
    </div>
  </div>
{/if}

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
        다른 기기에서 이미 재고를 수정하여 반영할 수 없습니다.<br/>
        최신 재고로 새로고침했으니 다시 확인 후 입력해 주세요.
      </p>
      <button
        type="button"
        class="btn btn-warning w-full font-black"
        onclick={closeConflictModal}
      >확인</button>
    </div>
  </div>
{/if}

