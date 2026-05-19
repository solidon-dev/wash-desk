<script lang="ts">
  import Icon from '@iconify/svelte';
  import { fly } from 'svelte/transition';
  import { onMount } from 'svelte';
  import { store, loadData, updateInventoryItem, switchClient, type ItemWithCategory } from '$lib/store.svelte';
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

  // ── 60초 자동 갱신 + 탭 진입 시 즉시 갱신 ────────────────────────
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
    console.log('[applyInput] start', { num, factoryId: store.factoryId, clientId: store.selectedClientId, itemId: selectedItemId });
    if (!num || isNaN(num) || num <= 0) { console.log('[applyInput] early return: invalid num'); return; }
    if (!store.factoryId || !store.selectedClientId || !selectedItemId) { console.log('[applyInput] early return: missing ids'); return; }

    applying = true;

    const session = await getSession();
    if (!session) { console.log('[applyInput] early return: no session'); applying = false; return; }
    console.log('[applyInput] session ok:', session.user.id);

    // ── RPC 실행 전: 서버 현재값 단건 조회 ────────────────────────────
    const localQty = store.inventoryMap[selectedItemId] ?? 0;
    const { data: liveRow, error: liveErr } = await getInventoryItem(
      store.factoryId, store.selectedClientId, selectedItemId
    );
    console.log('[applyInput] liveRow:', liveRow, 'liveErr:', liveErr);
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
      console.log('[applyInput] calling processInventoryDelta with delta:', num);
      const { data: inv, error: invErr } = await processInventoryDelta(
        store.factoryId,
        store.selectedClientId,
        selectedItemId,
        num,
        session.user.id
      );
      console.log('[applyInput] RPC result:', { inv, invErr });

      if (invErr) {
        console.error('[applyInput] RPC error:', invErr);
        alert('재고 추가 오류: ' + invErr.message);
        await loadData(store.factoryId, store.selectedClientId);
        return;
      }
      if (!inv) { console.log('[applyInput] no inv data'); return; }

      const logResult = await addInventoryLog(
        store.factoryId,
        store.selectedClientId,
        selectedItemId,
        inv.id,
        num,
        session.user.id,
        'in',
        inv.new_qty
      );
      console.log('[applyInput] addInventoryLog result:', logResult);

      updateInventoryItem(selectedItemId, inv.new_qty);
      console.log('[applyInput] done, new_qty:', inv.new_qty);
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

<!-- ══════════════════════════════════════════════════════════
     3단 레이아웃: 왼쪽 사이드바 | 중앙 품목 리스트 | 오른쪽 패널
     ══════════════════════════════════════════════════════════ -->
<div class="flex flex-1 min-h-0 min-w-0" style="background:#080d1a;">

  <!-- ── 왼쪽 사이드바: 거래처 컬럼 + 카테고리 컬럼 나란히 ────────── -->
  <aside
    class="hidden md:flex flex-row shrink-0 min-h-0 overflow-hidden"
    style="width:30rem; border-right:1px solid rgba(99,179,237,0.12);"
  >
    <!-- 거래처 컬럼 -->
    <div
      class="flex flex-col min-h-0 overflow-hidden"
      style="width:17rem; background:#0d1328; border-right:1px solid rgba(99,179,237,0.08);"
    >
      <div class="shrink-0 px-3 pt-4 pb-1">
        <p
          class="text-xs font-black uppercase tracking-widest px-1 mb-2"
          style="color:rgba(148,163,184,0.35); letter-spacing:0.12em;"
        >거래처</p>
      </div>
      <div class="flex-1 overflow-y-auto min-h-0 px-2 pb-3">
        {#if store.clients.length === 0}
          <div class="flex items-center justify-center h-16">
            <span class="text-xs" style="color:rgba(148,163,184,0.3);">거래처 없음</span>
          </div>
        {:else}
          {#each store.clients as client (client.id)}
            {@const isActive = store.selectedClientId === client.id}
            <button
              type="button"
              class="w-full text-left px-4 py-4 rounded-lg mb-1.5 flex items-center gap-3 transition-all"
              style="
                min-height:3.2rem;
                background:{isActive ? 'rgba(59,130,246,0.18)' : 'rgba(255,255,255,0.02)'};
                border:1px solid {isActive ? 'rgba(59,130,246,0.35)' : 'rgba(99,179,237,0.07)'};
                color:{isActive ? '#93c5fd' : 'rgba(226,232,240,0.65)'};
              "
              onclick={() => switchClient(client.id)}
            >
              <span
                class="shrink-0 rounded-full"
                style="
                  width:8px; height:8px;
                  background:{isActive ? '#3b82f6' : 'rgba(148,163,184,0.15)'};
                  box-shadow:{isActive ? '0 0 6px rgba(59,130,246,0.35)' : 'none'};
                "
              ></span>
              <span class="text-base font-bold truncate">{client.name}</span>
            </button>
          {/each}
        {/if}
      </div>
    </div>

    <!-- 카테고리 컬럼 -->
    <div
      class="flex flex-col min-h-0 overflow-hidden"
      style="width:13rem; background:#0b1120;"
    >
      <div class="shrink-0 px-3 pt-4 pb-1">
        <p
          class="text-xs font-black uppercase tracking-widest px-1 mb-2"
          style="color:rgba(148,163,184,0.35); letter-spacing:0.12em;"
        >카테고리</p>
      </div>
      <div class="flex-1 overflow-y-auto min-h-0 px-2 pb-3">
        <!-- 전체 버튼 -->
        <button
          type="button"
          class="w-full text-left px-3 py-4 rounded-lg mb-1.5 flex items-center gap-2 transition-all"
          style="
            min-height:3.2rem;
            background:{activeCategoryId === 'all' ? 'rgba(139,92,246,0.18)' : 'rgba(255,255,255,0.02)'};
            border:1px solid {activeCategoryId === 'all' ? 'rgba(139,92,246,0.35)' : 'rgba(139,92,246,0.07)'};
            color:{activeCategoryId === 'all' ? '#c4b5fd' : 'rgba(226,232,240,0.65)'};
            box-shadow:{activeCategoryId === 'all' ? '0 0 8px rgba(139,92,246,0.08)' : 'none'};
          "
          onclick={() => selectCategory('all')}
        >
          <Icon icon="heroicons:squares-2x2" style="width:14px;height:14px;flex-shrink:0;" />
          <span class="text-sm font-bold">전체</span>
        </button>
        {#each store.categories as cat (cat.id)}
          {@const isCatActive = activeCategoryId === cat.id}
          <button
            type="button"
            class="w-full text-left px-3 py-4 rounded-lg mb-1.5 flex items-center gap-2 transition-all"
            style="
              min-height:3.2rem;
              background:{isCatActive ? 'rgba(139,92,246,0.18)' : 'rgba(255,255,255,0.02)'};
              border:1px solid {isCatActive ? 'rgba(139,92,246,0.35)' : 'rgba(139,92,246,0.07)'};
              color:{isCatActive ? '#c4b5fd' : 'rgba(226,232,240,0.65)'};
              box-shadow:{isCatActive ? '0 0 8px rgba(139,92,246,0.08)' : 'none'};
            "
            onclick={() => selectCategory(cat.id)}
          >
            <Icon icon="heroicons:tag" style="width:14px;height:14px;flex-shrink:0;" />
            <span class="text-sm font-bold truncate">{cat.name}</span>
          </button>
        {/each}
      </div>
    </div>
  </aside>

  <!-- ── 중앙: 품목 리스트 ──────────────────────────────────────── -->
  <div class="flex-1 flex flex-col min-h-0 min-w-0" style="background:#080d1a;">

    <!-- 컬럼 헤더 -->
    {#if filteredItems.length > 0}
      <div
        class="h-11 shrink-0 px-5 flex items-center"
        style="background:#0d1328; border-bottom:1px solid rgba(99,179,237,0.12);"
      >
        <div class="flex-1 min-w-0">
          <span
            class="text-xs font-black uppercase tracking-wider"
            style="color:rgba(148,163,184,0.4);"
          >품목명</span>
        </div>
        <div class="w-10 shrink-0"></div>
        <div class="w-28 text-center shrink-0">
          <span
            class="text-xs font-black uppercase tracking-wider"
            style="color:rgba(148,163,184,0.4);"
          >수량</span>
        </div>
        <div class="w-12 shrink-0"></div>
      </div>
    {/if}

    <!-- 품목 리스트 본체 -->
    <div class="flex-1 overflow-y-auto min-h-0 flex flex-col">
      {#if !store.selectedClientId}
        <div class="flex flex-col items-center justify-center flex-1 gap-3">
          <div
            class="w-16 h-16 rounded-2xl flex items-center justify-center"
            style="background:rgba(59,130,246,0.06); border:1px solid rgba(59,130,246,0.12);"
          >
            <Icon icon="heroicons:building-storefront" class="w-8 h-8" style="color:rgba(99,179,237,0.25);" />
          </div>
          <p class="text-sm font-semibold" style="color:rgba(148,163,184,0.35);">거래처를 선택해 주세요</p>
        </div>
      {:else if filteredItems.length === 0}
        <div class="flex flex-col items-center justify-center flex-1 gap-3">
          <div
            class="w-16 h-16 rounded-2xl flex items-center justify-center"
            style="background:rgba(99,179,237,0.06); border:1px solid rgba(99,179,237,0.12);"
          >
            <Icon icon="heroicons:inbox" class="w-8 h-8" style="color:rgba(99,179,237,0.2);" />
          </div>
          <p class="text-sm font-semibold" style="color:rgba(148,163,184,0.35);">등록된 품목이 없습니다</p>
        </div>
      {:else}
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemId === item.id}
          {@const qty = store.inventoryMap[item.id] ?? 0}
          <div
            class="flex items-center min-h-[4.5rem] px-5 py-2 transition-all border-l-4"
            style="
              background:{isSel ? 'rgba(59,130,246,0.07)' : 'transparent'};
              border-left-color:{isSel ? '#3b82f6' : 'transparent'};
              border-bottom:1px solid rgba(99,179,237,0.07);
            "
          >
            <!-- 품목명 버튼 -->
            <button
              type="button"
              class="flex-1 py-2 text-left min-w-0"
              onclick={() => toggleItem(item.id)}
            >
              <span
                class="text-lg font-bold truncate block"
                style="color:{isSel ? '#93c5fd' : '#e2e8f0'};"
              >{item.nickname ?? item.name_ko}</span>
              <span
                class="text-xs"
                style="color:rgba(148,163,184,0.4);"
              >{item.categories?.name ?? ''}</span>
            </button>

            <!-- 기록 버튼 -->
            <div class="w-12 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="w-10 h-10 rounded-xl flex items-center justify-center transition-all active:scale-95"
                style="
                  background:rgba(251,146,60,0.12);
                  border:1px solid rgba(251,146,60,0.3);
                  color:#fb923c;
                  box-shadow:0 0 6px rgba(251,146,60,0.08);
                "
                onclick={(e) => { e.stopPropagation(); openLogDrawer(item); }}
              >
                <Icon icon="heroicons:clock" class="w-5 h-5" />
              </button>
            </div>

            <!-- 수량 표시 -->
            <div class="w-28 flex justify-center items-center shrink-0">
              <span
                class="text-4xl font-black tabular-nums"
                style="
                  color:{qty === 0 ? 'rgba(148,163,184,0.18)' : '#38bdf8'};
                  text-shadow:{qty > 0 ? '0 0 8px rgba(56,189,248,0.12)' : 'none'};
                "
              >{qty}</span>
            </div>

            <!-- 선택 인디케이터 -->
            <div class="w-12 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="w-8 h-8 rounded-full flex items-center justify-center transition-all"
                style="
                  background:{isSel ? '#3b82f6' : 'transparent'};
                  border:2px solid {isSel ? '#3b82f6' : 'rgba(99,179,237,0.2)'};
                  box-shadow:{isSel ? '0 0 6px rgba(59,130,246,0.2)' : 'none'};
                "
                onclick={() => toggleItem(item.id)}
              >
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-4 h-4" style="color:#fff;" />
                {/if}
              </button>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>

  <!-- ── 오른쪽 패널 ────────────────────────────────────────────── -->
  <aside
    class="hidden md:flex flex-col shrink-0 min-h-0"
    style="width:28rem; border-left:1px solid rgba(99,179,237,0.12); background:#0d1328;"
  >
    <div class="flex-1 flex flex-col min-h-0">
      {#if selectedItem}
        <div class="flex flex-col flex-1 min-h-0 px-3 py-3 gap-2.5">

          <!-- 선택된 품목명 + 현재 재고 -->
          <div
            class="px-4 py-3 rounded-xl shrink-0"
            style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);"
          >
            <p
              class="text-xs font-black uppercase tracking-widest mb-0.5"
              style="color:rgba(148,163,184,0.4);"
            >선택 품목</p>
            <p
              class="text-base font-black truncate"
              style="color:#e2e8f0;"
            >{selectedItem.nickname ?? selectedItem.name_ko}</p>
            <p
              class="text-xs mt-0.5"
              style="color:rgba(147,197,253,0.5);"
            >현재 재고 {currentQuantity}개</p>
          </div>

          <!-- 입력값 표시 디스플레이 -->
          <div
            class="rounded-2xl flex items-center justify-center shrink-0"
            style="
              height:5rem;
              background:rgba(17,24,39,0.9);
              border:2px solid {inputNum !== null && !isNaN(inputNum) ? 'rgba(59,130,246,0.5)' : 'rgba(99,179,237,0.1)'};
              box-shadow:{inputNum !== null && !isNaN(inputNum) ? '0 0 8px rgba(59,130,246,0.06)' : 'none'};
            "
          >
            <span
              class="text-5xl font-black tabular-nums"
              style="
                color:{inputNum !== null && !isNaN(inputNum) ? '#93c5fd' : 'rgba(148,163,184,0.15)'};
                text-shadow:{inputNum !== null && !isNaN(inputNum) ? '0 0 8px rgba(59,130,246,0.15)' : 'none'};
              "
            >{inputValue || '0'}</span>
          </div>

          <!-- 숫자패드 -->
          <div class="grid grid-cols-3 gap-1.5 select-none flex-1 min-h-0">
            {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
              {#if key === 'clear'}
                <button
                  type="button"
                  class="rounded-xl font-black text-lg flex items-center justify-center transition-all active:scale-95"
                  style="background:rgba(239,68,68,0.12); border:1px solid rgba(239,68,68,0.3); color:#f87171;"
                  onclick={() => { inputValue = ''; }}
                >C</button>
              {:else if key === 'back'}
                <button
                  type="button"
                  class="rounded-xl flex items-center justify-center transition-all active:scale-95"
                  style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.15); color:rgba(148,163,184,0.7);"
                  onclick={() => { inputValue = inputValue.slice(0, -1); }}
                >
                  <Icon icon="heroicons:backspace" class="w-5 h-5" />
                </button>
              {:else}
                <button
                  type="button"
                  class="rounded-xl font-black text-xl flex items-center justify-center transition-all active:scale-95"
                  style="background:rgba(17,24,39,0.6); border:1px solid rgba(99,179,237,0.15); color:#e2e8f0;"
                  onclick={() => { const v = (inputValue + key).replace(/^0+(?=\d)/, ''); if (v.length <= 6) inputValue = v; }}
                >{key}</button>
              {/if}
            {/each}
          </div>

          <!-- 추가하기 버튼 -->
          <button
            type="button"
            class="w-full rounded-xl font-black text-lg flex items-center justify-center gap-2 transition-all shrink-0"
            style="
              height: 3.5rem;
              background: {inputNum === null || isNaN(inputNum ?? NaN) || applying ? 'rgba(34,197,94,0.08)' : 'linear-gradient(135deg,#16a34a,#15803d)'};
              color: {inputNum === null || isNaN(inputNum ?? NaN) || applying ? 'rgba(134,239,172,0.3)' : '#fff'};
              border: 1px solid {inputNum === null || isNaN(inputNum ?? NaN) || applying ? 'rgba(34,197,94,0.12)' : 'rgba(34,197,94,0.6)'};
              box-shadow: {inputNum === null || isNaN(inputNum ?? NaN) || applying ? 'none' : '0 0 8px rgba(34,197,94,0.1)'};
              cursor: {inputNum === null || isNaN(inputNum ?? NaN) || applying ? 'not-allowed' : 'pointer'};
            "
            disabled={inputNum === null || isNaN(inputNum ?? NaN) || applying}
            onclick={applyInput}
          >
            {#if applying}
              <span class="loading loading-spinner loading-sm"></span>
            {:else}
              <Icon icon="heroicons:plus-circle" class="w-5 h-5" />
              추가하기
            {/if}
          </button>

        </div>
      {:else}
        <!-- 품목 미선택 상태 -->
        <div class="flex flex-col items-center justify-center flex-1 gap-3 px-4">
          <div
            class="w-14 h-14 rounded-2xl flex items-center justify-center"
            style="background:rgba(99,179,237,0.06); border:1px solid rgba(99,179,237,0.12);"
          >
            <Icon icon="heroicons:hand-raised" class="w-7 h-7" style="color:rgba(99,179,237,0.25);" />
          </div>
          <div class="text-center">
            <p class="text-sm font-bold" style="color:rgba(148,163,184,0.5);">품목을 선택하세요</p>
            <p class="text-xs mt-1" style="color:rgba(148,163,184,0.25);">왼쪽 목록에서 품목을<br>탭하면 수량을 입력할 수 있습니다</p>
          </div>
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

  <div class="fixed top-0 right-0 h-full w-full max-w-2xl shadow-2xl z-50 flex flex-col" style="background:#0f1729; border-left:1px solid rgba(99,179,237,0.15);" transition:fly={{ x: 400, duration: 200 }}>
    <div class="px-6 py-5 shrink-0 flex items-center justify-between" style="background:linear-gradient(135deg,#0d1e3d,#0a1628); border-bottom:1px solid rgba(251,146,60,0.2);">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-lg flex items-center justify-center" style="background:rgba(251,146,60,0.15); border:1px solid rgba(251,146,60,0.3);">
          <Icon icon="heroicons:clock" class="w-4 h-4" style="color:#fb923c;" />
        </div>
        <h3 class="text-xl font-black truncate" style="color:#e2e8f0;">
          {logTargetItem?.nickname ?? logTargetItem?.name_ko ?? ''} 기록
        </h3>
      </div>
      <button type="button" class="w-9 h-9 rounded-lg flex items-center justify-center transition-all" style="background:rgba(255,255,255,0.05); color:rgba(148,163,184,0.6);" onclick={closeLogDrawer}>
        <Icon icon="heroicons:x-mark" class="w-5 h-5" />
      </button>
    </div>

    <div class="h-11 shrink-0 flex items-center px-6" style="background:#0d1328; border-bottom:1px solid rgba(99,179,237,0.1);">
      <div class="flex-1 grid grid-cols-3 gap-2 text-xs font-black uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">
        <div>시각</div>
        <div class="text-center">입출고</div>
        <div class="text-center" style="color:#34d399;">누적수량</div>
      </div>
      <div class="w-20 shrink-0"></div>
    </div>

    <div class="flex-1 overflow-y-auto">
      {#if logsLoading}
        <div class="flex items-center justify-center h-40">
          <span class="loading loading-spinner loading-md" style="color:#3b82f6;"></span>
        </div>
      {:else if logs.length === 0}
        <div class="flex flex-col items-center justify-center h-full gap-3">
          <Icon icon="heroicons:clock" class="w-14 h-14" style="color:rgba(148,163,184,0.15);" />
          <p class="text-base font-bold" style="color:rgba(148,163,184,0.3);">기록이 없습니다</p>
        </div>
      {:else}
        {#each logs.slice(0, logVisibleCount) as log (log.id)}
          <div class="px-6 py-4 flex items-center gap-2 transition-colors" style="border-bottom:1px solid rgba(99,179,237,0.07);">
            <div class="flex-1 grid grid-cols-3 gap-2 items-center">
              <div>
                <span class="text-base font-black tabular-nums block" style="color:#e2e8f0;">{formatTime(log.processed_at)}</span>
                <span class="text-xs" style="color:rgba(148,163,184,0.4);">{formatDate(log.processed_at)}</span>
              </div>
              <div class="text-center">
                {#if log.log_type === 'in'}
                  <span class="text-3xl font-black tabular-nums" style="color:#34d399; text-shadow:0 0 6px rgba(52,211,153,0.12);">+{log.quantity}</span>
                {:else}
                  <span class="text-3xl font-black tabular-nums" style="color:#f87171; text-shadow:0 0 6px rgba(248,113,113,0.12);">-{log.quantity}</span>
                {/if}
              </div>
              <div class="text-right">
                <span class="text-2xl font-black tabular-nums" style="color:#93c5fd;">{log.after_quantity ?? '—'}</span>
              </div>
            </div>
            <div class="w-20 shrink-0 flex justify-end">
              {#if log.log_type === 'in'}
                <button
                  type="button"
                  class="btn btn-sm font-black gap-1"
                  style="background:rgba(239,68,68,0.1); border:1px solid rgba(239,68,68,0.3); color:#f87171;"
                  onclick={(e) => openLogCancel(e, log)}
                >
                  <Icon icon="heroicons:x-circle" class="w-4 h-4" />
                  취소
                </button>
              {/if}
            </div>
          </div>
        {/each}
        {#if logVisibleCount < logs.length}
          <div class="px-6 py-4">
            <button type="button" class="w-full py-3 rounded-xl font-bold text-sm transition-all" style="background:rgba(99,179,237,0.06); border:1px solid rgba(99,179,237,0.15); color:rgba(148,163,184,0.6);"
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
