<script lang="ts">
  import Icon from '@iconify/svelte';
  import { fly } from 'svelte/transition';
  import { onMount } from 'svelte';
  import { store, loadData, updateInventoryItem, type ItemWithCategory } from '$lib/store.svelte';
  import { processInventoryDelta, getInventoryItem } from '$lib/api/inventory';
  import { addInventoryLog, getInventoryLogs, cancelInventoryLog } from '$lib/api/inventory_logs';
  import { deleteShipout } from '$lib/api/shipouts';
  import { getSession } from '$lib/api/auth';
  import type { InventoryLog } from '$lib/supabase/types';

  // ── 상태 ─────────────────────────────────────────────────────────
  let activeCategoryId = $state<string | 'all'>('all');
  let selectedItemId = $state<string | null>(null);
  let inputValue = $state('');
  let applying = $state(false);

  // ── 외부 변경 확인 모달 ──────────────────────────────────────
  let showExternalChangeModal = $state(false);
  let externalChangeInfo = $state<{ localQty: number; liveQty: number; delta: number } | null>(null);
  let _resolveExternalChange: ((confirmed: boolean) => void) | null = null;

  function askExternalChange(localQty: number, liveQty: number, delta: number): Promise<boolean> {
    externalChangeInfo = { localQty, liveQty, delta };
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

  // ── 60초 자동 갱신 ───────────────────────────────────────────────
  onMount(() => {
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

  // ── 공장/거래처 변경 시 UI 초기화 ─────────────────────────────────
  $effect(() => {
    store.factoryId;
    store.selectedClientId;
    activeCategoryId = 'all';
    selectedItemId   = null;
    inputValue       = '';
  });

  // ── 파생값 ──────────────────────────────────────────────────────
  let filteredItems = $derived(
    activeCategoryId === 'all'
      ? store.items
      : store.items.filter(i => i.category_id === activeCategoryId)
  );

  let selectedItem = $derived(
    store.items.find(i => i.id === selectedItemId) ?? null
  );

  let currentQuantity = $derived(
    selectedItemId ? (store.inventoryMap[selectedItemId] ?? 0) : 0
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

    const session = await getSession();
    if (!session) { applying = false; return; }

    // ── RPC 실행 전: 서버 현재값 단건 조회 ────────────────────────────
    const localQty = store.inventoryMap[selectedItemId] ?? 0;
    const { data: liveRow } = await getInventoryItem(
      store.factoryId, store.selectedClientId, selectedItemId
    );
    const liveQty = liveRow?.quantity ?? localQty;

    if (liveQty !== localQty) {
      // 외부 변경 감지: 로컬 먼저 동기화 후 모달로 확인 요청
      updateInventoryItem(selectedItemId, liveQty);
      applying = false; // 모달 표시 중 스피너 끄기

      const confirmed = await askExternalChange(localQty, liveQty, num);
      if (!confirmed) return; // 취소: 로컬은 이미 liveQty로 동기화됨

      applying = true; // 확인 후 다시 스피너
    }

    // ── RPC 실행 ────────────────────────────────────────────────────
    try {
      const { data: inv, error: invErr } = await processInventoryDelta(
        store.factoryId,
        store.selectedClientId,
        selectedItemId,
        num,
        session.user.id
      );

      if (invErr) {
        await loadData(store.factoryId, store.selectedClientId);
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

      updateInventoryItem(selectedItemId, inv.new_qty);
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

  // ── 로그 취소 (출고 되돌리기) ────────────────────────────────────
  let logCancelTarget = $state<InventoryLog | null>(null);
  let logCancelRestore = $state(true);
  let logCancelling = $state(false);

  function openLogCancel(e: MouseEvent, log: InventoryLog) {
    e.stopPropagation();
    logCancelTarget = log;
    logCancelRestore = true;
  }

  async function doLogCancel() {
    if (!logCancelTarget) return;
    logCancelling = true;
    const session = await getSession();
    if (!session) { logCancelling = false; return; }

    if (logCancelTarget.shipout_id) {
      // 출고 취소 → delete_shipout RPC (항상 재고 복구)
      const { error } = await deleteShipout(logCancelTarget.shipout_id, session.user.id, true);
      if (error) { logCancelling = false; alert('취소 실패: ' + error.message); return; }
    } else {
      // 입고 취소 → cancel_inventory_log RPC (트랜잭션: 재고 복구 + 로그 하드딜리트 원자적 처리)
      const { error } = await cancelInventoryLog(logCancelTarget.id, session.user.id);
      if (error) { logCancelling = false; alert('취소 실패: ' + error.message); return; }
    }

    logCancelling = false;
    logCancelTarget = null;
    // 드로어 로그 새로고침
    if (logTargetItem && store.factoryId && store.selectedClientId) {
      logsLoading = true;
      const { data } = await getInventoryLogs(store.factoryId, store.selectedClientId, logTargetItem.id);
      logs = data ?? [];
      logsLoading = false;
    }
    // 재고 스토어 갱신
    if (store.factoryId && store.selectedClientId) {
      loadData(store.factoryId, store.selectedClientId);
    }
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
      {#each store.categories as cat (cat.id)}
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
          {@const qty = store.inventoryMap[item.id] ?? 0}
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

  <div class="fixed top-0 right-0 h-full w-full max-w-2xl bg-base-100 shadow-2xl z-50 flex flex-col" transition:fly={{ x: 400, duration: 200 }}>
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
      <div class="w-20 shrink-0"></div>
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
          <div class="px-6 py-4 border-b border-base-200 hover:bg-base-50 transition-colors flex items-center gap-2">
            <div class="flex-1 grid grid-cols-3 gap-2 items-center">
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
            <div class="w-20 shrink-0 flex justify-end">
              <button
                type="button"
                class="btn btn-sm btn-outline btn-error font-black gap-1"
                onclick={(e) => openLogCancel(e, log)}
              >
                <Icon icon="heroicons:x-circle" class="w-4 h-4" />
                취소
              </button>
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

<!-- 로그 취소 확인 모달 -->
{#if logCancelTarget !== null}
  <div class="fixed inset-0 bg-black/50 z-[60] flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => logCancelTarget = null}
    onkeydown={(e) => e.key === 'Escape' && (logCancelTarget = null)}
    aria-label="닫기"
  >
    <div class="bg-base-100 rounded-2xl shadow-2xl max-w-sm w-full p-6 flex flex-col gap-4"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="flex items-center gap-3">
        <span class="w-10 h-10 rounded-full bg-warning/15 flex items-center justify-center shrink-0">
          <Icon icon="heroicons:arrow-uturn-left" class="w-5 h-5 text-warning" />
        </span>
        <div>
          <h3 class="text-lg font-black text-base-content">{logCancelTarget.shipout_id ? '출고' : '입고'} 취소</h3>
          <p class="text-xs text-base-content/40 mt-0.5">{formatDate(logCancelTarget.processed_at)} {formatTime(logCancelTarget.processed_at)} · {logCancelTarget.quantity}개</p>
        </div>
      </div>
      <p class="text-sm text-base-content/70 leading-relaxed">
        이 {logCancelTarget.shipout_id ? '출고' : '입고'} 기록을 취소하면 <strong>재고가 복구</strong>되고 기록은 <strong>완전히 삭제</strong>됩니다.
      </p>
      <div class="flex gap-2">
        <button class="btn btn-ghost flex-1 font-bold border border-base-300" onclick={() => logCancelTarget = null}>닫기</button>
        <button class="btn btn-warning flex-1 font-black" onclick={doLogCancel} disabled={logCancelling}>
          {#if logCancelling}<span class="loading loading-spinner loading-sm"></span>{:else}취소 확인{/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- 외부 변경 확인 모달: 다른 기기에서 재고가 바뀐 경우 추가 여부 확인 -->
{#if showExternalChangeModal && externalChangeInfo}
  <div class="fixed inset-0 bg-black/50 z-100 flex items-center justify-center p-4">
    <div class="bg-base-100 rounded-2xl shadow-2xl max-w-sm w-full p-6 flex flex-col gap-4">
      <div class="flex items-center gap-3">
        <span class="w-10 h-10 rounded-full bg-warning/15 flex items-center justify-center shrink-0">
          <Icon icon="heroicons:exclamation-triangle" class="w-5 h-5 text-warning" />
        </span>
        <h3 class="text-lg font-black text-base-content">다른 기기에서 재고 변경됨</h3>
      </div>

      <div class="rounded-xl bg-base-200 p-4 flex flex-col gap-2 text-sm">
        <div class="flex justify-between">
          <span class="text-base-content/50">화면에 표시된 재고</span>
          <span class="font-bold">{externalChangeInfo.localQty}개</span>
        </div>
        <div class="flex justify-between font-bold text-warning">
          <span>실제 현재 재고</span>
          <span>
            {externalChangeInfo.liveQty}개
            ({externalChangeInfo.liveQty - externalChangeInfo.localQty >= 0 ? '+' : ''}{externalChangeInfo.liveQty - externalChangeInfo.localQty})
          </span>
        </div>
        <div class="border-t border-base-300 mt-1 pt-2 flex justify-between">
          <span class="text-base-content/50">내가 추가할 수량</span>
          <span class="font-bold text-primary">+{externalChangeInfo.delta}개</span>
        </div>
        <div class="flex justify-between font-black">
          <span>추가 후 최종 재고</span>
          <span class="text-primary">{externalChangeInfo.liveQty + externalChangeInfo.delta}개</span>
        </div>
      </div>

      <p class="text-sm text-base-content/70">
        실제 재고 <strong>{externalChangeInfo.liveQty}개</strong>에
        <strong>{externalChangeInfo.delta}개</strong>를 추가하시겠습니까?
      </p>

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
        >추가하기</button>
      </div>
    </div>
  </div>
{/if}

