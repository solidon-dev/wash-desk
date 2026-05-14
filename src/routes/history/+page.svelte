<script lang="ts">
  import Icon from '@iconify/svelte';
  import DatePicker from '$lib/components/DatePicker.svelte';
  import { store } from '$lib/store.svelte';
  import { getShipouts, updateShipout, deleteShipout } from '$lib/api/shipouts';
  import { getSession } from '$lib/api/auth';

  type QuickFilter = 'today' | 'week' | 'month' | 'custom';

  // ── 날짜 유틸 ──────────────────────────────────────────────────
  function pad(n: number) { return String(n).padStart(2, '0'); }
  function dateToYMD(d: Date) { return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`; }
  function todayYMD() { return dateToYMD(new Date()); }
  function getWeekStart() {
    const now = new Date();
    return dateToYMD(new Date(now.getTime() - now.getDay() * 86400000));
  }
  function getMonthStart() {
    const now = new Date();
    return `${now.getFullYear()}-${pad(now.getMonth()+1)}-01`;
  }
  function formatDate(iso: string) {
    const d = new Date(iso);
    return `${d.getFullYear()}.${pad(d.getMonth()+1)}.${pad(d.getDate())}`;
  }
  function formatTime(iso: string) {
    const d = new Date(iso);
    return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }
  function formatDateLabel(ymd: string) {
    const [y,m,d] = ymd.split('-');
    return `${y}.${m}.${d}`;
  }
  function toLocalDatetimeValue(iso: string) {
    const d = new Date(iso);
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  // ── 타입 ──────────────────────────────────────────────────────
  type LogRow = {
    id: string;
    item_id: string;
    inventory_id: string;
    quantity: number;
    after_quantity: number | null;
    processed_at: string | null;
    items: { id: string; name_ko: string; nickname: string | null; categories: { id: string; name: string } | null } | null;
  };
  type ShipoutGroup = {
    id: string;           // shipouts.id
    factory_id: string;
    client_id: string;
    created_by: string | null;
    created_at: string;
    memo: string | null;
    inventory_logs: LogRow[];
  };

  // ── 필터 상태 ──────────────────────────────────────────────────
  let quickFilter = $state<QuickFilter>('today');
  let fromDate = $state(todayYMD());
  let toDate   = $state(todayYMD());

  const quickFilters: { key: QuickFilter; label: string }[] = [
    { key: 'today', label: '오늘' },
    { key: 'week',  label: '이번 주' },
    { key: 'month', label: '이번 달' },
  ];

  function applyQuick(key: QuickFilter) {
    quickFilter = key;
    const today = todayYMD();
    if (key === 'today')      { fromDate = today; toDate = today; }
    else if (key === 'week')  { fromDate = getWeekStart(); toDate = today; }
    else if (key === 'month') { fromDate = getMonthStart(); toDate = today; }
    loadShipouts();
  }

  // ── 데이터 ────────────────────────────────────────────────────
  let shipoutGroups = $state<ShipoutGroup[]>([]);
  let loading = $state(false);

  async function loadShipouts() {
    if (!store.factoryId) return;
    loading = true;
    const { data } = await getShipouts(
      store.factoryId,
      store.selectedClientId ?? null,
      fromDate, toDate
    );
    shipoutGroups = (data ?? []) as unknown as ShipoutGroup[];
    loading = false;
  }

  // 거래처/공장/날짜 변경 시 자동 로드
  $effect(() => {
    const _fid = store.factoryId;
    const _cid = store.selectedClientId;
    const _f = fromDate;
    const _t = toDate;
    if (_fid) loadShipouts();
  });

  let totalItemCount    = $derived(shipoutGroups.reduce((s, g) => s + g.inventory_logs.reduce((ss, l) => ss + l.quantity, 0), 0));
  let uniqueClientCount = $derived(new Set(shipoutGroups.map(g => g.client_id)).size);

  // ── 수정 패널 ─────────────────────────────────────────────────
  let editingShipoutId  = $state<string | null>(null);
  let editPanelVisible  = $state(false);
  let editItems         = $state<{ item_id: string; item_name: string; quantity: number; orig_qty: number }[]>([]);
  let deleteConfirming  = $state(false);
  let deleteRestoreInventory = $state(true); // 기본값: 재고 복구
  let saving            = $state(false);

  function openEditPanel(group: ShipoutGroup) {
    editingShipoutId = group.id;
    editItems = group.inventory_logs.map(l => ({
      item_id:   l.item_id,
      item_name: l.items?.nickname ?? l.items?.name_ko ?? l.item_id,
      quantity:  l.quantity,
      orig_qty:  l.quantity,
    }));
    deleteConfirming = false;
    deleteRestoreInventory = true;
    editPanelVisible = true;
  }

  function closeEditPanel() {
    editPanelVisible  = false;
    editingShipoutId  = null;
    deleteConfirming  = false;
  }

  function adjustEditQty(idx: number, delta: number) {
    editItems = editItems.map((it, i) =>
      i === idx ? { ...it, quantity: Math.max(0, it.quantity + delta) } : it
    );
  }

  async function saveEdit() {
    if (!editingShipoutId) return;
    saving = true;
    const session = await getSession();
    if (!session) { saving = false; return; }
    const payload = editItems.map(i => ({ item_id: i.item_id, new_quantity: i.quantity }));
    const { error } = await updateShipout(editingShipoutId, payload, session.user.id);
    saving = false;
    if (error) { alert('저장 실패: ' + error.message); return; }
    closeEditPanel();
    await loadShipouts();
  }

  async function doDeleteShipout() {
    if (!editingShipoutId) return;
    saving = true;
    const session = await getSession();
    if (!session) { saving = false; return; }
    const { error } = await deleteShipout(editingShipoutId, session.user.id, deleteRestoreInventory);
    saving = false;
    if (error) { alert('삭제 실패: ' + error.message); return; }
    closeEditPanel();
    await loadShipouts();
  }

  // ── 전표 모달 ─────────────────────────────────────────────────
  let showSlipModal  = $state(false);
  let slipGroup      = $state<ShipoutGroup | null>(null);

  function openSlip(group: ShipoutGroup, e: MouseEvent) {
    e.stopPropagation();
    slipGroup     = group;
    showSlipModal = true;
  }

  // ── 날짜 피커 ─────────────────────────────────────────────────
  let showDatePicker = $state(false);
  let pickerTarget   = $state<'from' | 'to'>('from');

  function openPicker(target: 'from' | 'to') {
    pickerTarget   = target;
    showDatePicker = true;
  }

  function handleDateSelect(_t: 'from' | 'to' | 'single', ymd: string) {
    if (pickerTarget === 'from') { fromDate = ymd; if (toDate < fromDate) toDate = fromDate; }
    else                         { toDate   = ymd; if (fromDate > toDate) fromDate = toDate; }
    quickFilter = 'custom';
    loadShipouts();
  }

  // ── 거래처 이름 헬퍼 ──────────────────────────────────────────
  function clientName(clientId: string) {
    return store.clients.find((c: {id:string;name:string}) => c.id === clientId)?.name ?? '미확인';
  }
</script>

<svelte:head><title>출고 현황</title></svelte:head>

<div class="flex-1 flex flex-col min-h-0 relative">

  <!-- 필터 헤더 -->
  <div class="bg-base-100 border-b border-base-300 px-6 pt-5 pb-5 shrink-0 space-y-4">
    <div class="flex items-center gap-3 flex-wrap">
      <div class="join">
        {#each quickFilters as { key, label } (key)}
          <button
            class="btn btn-sm join-item text-base font-black h-12 px-6
              {quickFilter === key ? 'btn-primary' : 'btn-ghost border border-base-300'}"
            onclick={() => applyQuick(key)}
          >{label}</button>
        {/each}
      </div>
      <div class="flex items-center gap-2">
        <button type="button"
          class="h-12 px-5 rounded-xl border border-base-300 bg-base-100 text-lg font-bold text-base-content hover:bg-base-200 transition-colors"
          onclick={() => openPicker('from')}
        >{formatDateLabel(fromDate)}</button>
        <span class="text-base-content/30 text-xl font-bold">—</span>
        <button type="button"
          class="h-12 px-5 rounded-xl border border-base-300 bg-base-100 text-lg font-bold text-base-content hover:bg-base-200 transition-colors"
          onclick={() => openPicker('to')}
        >{formatDateLabel(toDate)}</button>
      </div>
    </div>

    <!-- 요약 카드 -->
    <div class="grid grid-cols-3 gap-3">
      <div class="bg-base-200 rounded-2xl px-4 py-4 text-center">
        <p class="text-sm font-bold text-base-content/40 mb-1">출고</p>
        <p class="text-4xl font-black text-base-content">{shipoutGroups.length}<span class="text-base font-bold text-base-content/40 ml-1">건</span></p>
      </div>
      <div class="bg-base-200 rounded-2xl px-4 py-4 text-center">
        <p class="text-sm font-bold text-base-content/40 mb-1">수량</p>
        <p class="text-4xl font-black text-base-content">{totalItemCount}<span class="text-base font-bold text-base-content/40 ml-1">개</span></p>
      </div>
      <div class="bg-base-200 rounded-2xl px-4 py-4 text-center">
        <p class="text-sm font-bold text-base-content/40 mb-1">거래처</p>
        <p class="text-4xl font-black text-base-content">{uniqueClientCount}<span class="text-base font-bold text-base-content/40 ml-1">곳</span></p>
      </div>
    </div>
  </div>

  <!-- 테이블 헤더 -->
  {#if shipoutGroups.length > 0}
    <div class="h-14 bg-base-200 border-b border-base-300 px-6 shrink-0 flex items-center">
      <div class="w-44 shrink-0"><span class="text-xs font-black text-base-content/40 uppercase tracking-wider">일시</span></div>
      <div class="w-40 shrink-0"><span class="text-xs font-black text-base-content/40 uppercase tracking-wider">거래처</span></div>
      <div class="flex-1 min-w-0"><span class="text-xs font-black text-base-content/40 uppercase tracking-wider">품목</span></div>
      <div class="w-16 shrink-0"></div>
      <div class="w-16 shrink-0"></div>
    </div>
  {/if}

  <!-- 목록 -->
  <div class="flex-1 overflow-y-auto min-h-0">
    {#if loading}
      <div class="flex items-center justify-center h-40">
        <span class="loading loading-spinner loading-lg"></span>
      </div>
    {:else if shipoutGroups.length === 0}
      <div class="flex flex-col items-center justify-center h-full gap-3">
        <div class="w-14 h-14 rounded-2xl bg-base-200 flex items-center justify-center">
          <Icon icon="heroicons:clipboard-document-list" class="w-7 h-7 text-base-content/20" />
        </div>
        <p class="text-sm font-semibold text-base-content/50">출고 기록이 없습니다</p>
        <p class="text-xs text-base-content/30">날짜 범위를 변경하거나 출고를 추가하세요</p>
      </div>
    {:else}
      {#each shipoutGroups as group (group.id)}
        {@const isEditing = editingShipoutId === group.id && editPanelVisible}
        {@const shipTotal = group.inventory_logs.reduce((s, l) => s + l.quantity, 0)}
        <div
          role="button" tabindex="0"
          class="flex items-center min-h-24 px-6 border-b border-base-200 cursor-pointer transition-colors
            {isEditing ? 'bg-primary/5 border-l-4 border-l-primary' : 'hover:bg-base-200/60 border-l-4 border-l-transparent'}"
          onclick={() => isEditing ? closeEditPanel() : openEditPanel(group)}
          onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (isEditing ? closeEditPanel() : openEditPanel(group))}
        >
          <div class="w-44 shrink-0">
            <p class="text-lg font-bold text-base-content tabular-nums">
              {formatDate(group.created_at)}<br/>
              <span class="text-base font-bold text-base-content/50">{formatTime(group.created_at)}</span>
            </p>
          </div>
          <div class="w-40 shrink-0 pr-2">
            <p class="text-xl font-black text-base-content truncate">{clientName(group.client_id)}</p>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-base text-base-content/60">
              {group.inventory_logs.length}종 · <span class="font-black text-xl text-base-content">{shipTotal}개</span>
            </p>
            <p class="text-xs text-base-content/30 truncate mt-0.5">
              {group.inventory_logs.map(l => l.items?.nickname ?? l.items?.name_ko ?? '').filter(Boolean).join(', ')}
            </p>
          </div>
          <div class="w-16 flex justify-center shrink-0">
            <button
              aria-label="수정"
              class="btn btn-md btn-square {isEditing ? 'btn-primary' : 'btn-ghost text-base-content/40 hover:text-base-content'}"
              onclick={(e) => { e.stopPropagation(); isEditing ? closeEditPanel() : openEditPanel(group); }}
            ><Icon icon="heroicons:pencil-square" class="w-6 h-6" /></button>
          </div>
          <div class="w-16 flex justify-center shrink-0">
            <button
              aria-label="전표"
              class="btn btn-md btn-square btn-ghost text-base-content/40 hover:text-base-content"
              onclick={(e) => openSlip(group, e)}
            ><Icon icon="heroicons:printer" class="w-6 h-6" /></button>
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <!-- 수정 슬라이드 패널 -->
  {#if editingShipoutId !== null}
    <button class="absolute inset-0 bg-black/10 z-10 cursor-default" onclick={closeEditPanel} aria-label="닫기"></button>
    <div class="absolute right-0 top-0 bottom-0 w-120 bg-base-100 shadow-2xl z-20 flex flex-col transition-transform duration-300
      {editPanelVisible ? 'translate-x-0' : 'translate-x-full'}">

      <div class="px-6 h-20 border-b border-base-200 flex items-center justify-between shrink-0">
        <div>
          <h3 class="text-xl font-black text-base-content">출고 수정</h3>
          {#each shipoutGroups.filter(g => g.id === editingShipoutId) as g}
              <p class="text-sm font-bold text-base-content/40 mt-0.5">{formatDate(g.created_at)} {formatTime(g.created_at)}</p>
          {/each}
        </div>
        <button class="btn btn-md btn-square btn-ghost text-base-content/50" onclick={closeEditPanel} aria-label="닫기">
          <Icon icon="heroicons:x-mark" class="w-6 h-6" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto min-h-0">
        <div class="px-6 py-5 border-b border-base-200">
          <p class="text-sm font-black text-base-content/40 uppercase tracking-wider mb-3">품목 수량</p>
          <div class="space-y-2">
            {#each editItems as item, idx (item.item_id)}
              <div class="flex items-center gap-3 min-h-20 rounded-xl border border-base-200 px-4">
                <div class="flex-1 min-w-0">
                  <p class="text-xl font-bold text-base-content truncate">{item.item_name}</p>
                  {#if item.quantity === 0}
                    <p class="text-xs text-error font-bold mt-0.5">0개 → 저장 시 삭제됩니다</p>
                  {/if}
                </div>
                <div class="flex items-center gap-2 shrink-0">
                  <button aria-label="감소" class="btn btn-md btn-square btn-ghost border border-base-300 font-black text-2xl"
                    onclick={() => adjustEditQty(idx, -1)}>−</button>
                  <span class="w-14 text-center text-3xl font-black {item.quantity === 0 ? 'text-error' : 'text-primary'} tabular-nums">{item.quantity}</span>
                  <button aria-label="증가" class="btn btn-md btn-square btn-primary font-black text-2xl"
                    onclick={() => adjustEditQty(idx, 1)}>+</button>
                </div>
              </div>
            {/each}
          </div>
          <div class="mt-3 flex items-center justify-between px-4 py-3 bg-base-200 rounded-xl">
            <span class="text-sm font-black text-base-content/40 uppercase tracking-wider">합계</span>
            <span class="text-3xl font-black text-primary tabular-nums">
              {editItems.reduce((s, i) => s + i.quantity, 0)}<span class="text-base font-bold text-primary/60 ml-1">개</span>
            </span>
          </div>
        </div>

      </div>

      <div class="px-6 py-5 border-t border-base-200 flex gap-3 shrink-0">
        <button class="btn btn-primary flex-1 h-16 font-black text-xl" onclick={saveEdit} disabled={saving}>
          {#if saving}<span class="loading loading-spinner loading-sm"></span>{:else}저장{/if}
        </button>
        <button class="btn btn-outline btn-error h-16 px-6 font-black text-xl" onclick={() => deleteConfirming = !deleteConfirming}>
          <Icon icon="heroicons:trash" class="w-6 h-6" />
        </button>
      </div>
    </div>
  {/if}
</div>

<!-- 삭제 확인 모달 -->
{#if deleteConfirming}
  <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => deleteConfirming = false}
    onkeydown={(e) => e.key === 'Escape' && (deleteConfirming = false)}
    aria-label="닫기"
  >
    <div class="bg-base-100 rounded-2xl shadow-2xl max-w-sm w-full p-6 flex flex-col gap-4"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="flex items-center gap-3">
        <span class="w-10 h-10 rounded-full bg-error/15 flex items-center justify-center shrink-0">
          <Icon icon="heroicons:trash" class="w-5 h-5 text-error" />
        </span>
        <h3 class="text-lg font-black text-base-content">출고 삭제</h3>
      </div>
      <p class="text-sm text-base-content/70 leading-relaxed">
        이 출고 기록을 삭제하시겠습니까?
      </p>
      <div class="flex flex-col gap-2">
        <button
          type="button"
          class="flex items-center gap-3 rounded-xl border-2 px-4 py-3 text-left transition-colors {deleteRestoreInventory ? 'border-primary bg-primary/5' : 'border-base-300 bg-base-100'}"
          onclick={() => deleteRestoreInventory = true}
        >
          <span class="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 {deleteRestoreInventory ? 'border-primary' : 'border-base-300'}">
            {#if deleteRestoreInventory}<span class="w-2.5 h-2.5 rounded-full bg-primary"></span>{/if}
          </span>
          <div>
            <p class="text-sm font-black text-base-content">재고 복구 후 삭제</p>
            <p class="text-xs text-base-content/50">출고된 수량을 재고에 다시 더합니다</p>
          </div>
        </button>
        <button
          type="button"
          class="flex items-center gap-3 rounded-xl border-2 px-4 py-3 text-left transition-colors {!deleteRestoreInventory ? 'border-error bg-error/5' : 'border-base-300 bg-base-100'}"
          onclick={() => deleteRestoreInventory = false}
        >
          <span class="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 {!deleteRestoreInventory ? 'border-error' : 'border-base-300'}">
            {#if !deleteRestoreInventory}<span class="w-2.5 h-2.5 rounded-full bg-error"></span>{/if}
          </span>
          <div>
            <p class="text-sm font-black text-base-content">재고 유지 후 삭제</p>
            <p class="text-xs text-base-content/50">재고는 그대로 두고 기록만 삭제합니다</p>
          </div>
        </button>
      </div>
      <div class="flex gap-2">
        <button class="btn btn-ghost flex-1 font-bold border border-base-300" onclick={() => deleteConfirming = false}>취소</button>
        <button class="btn btn-error flex-1 font-black" onclick={doDeleteShipout} disabled={saving}>
          {#if saving}<span class="loading loading-spinner loading-sm"></span>{:else}삭제 확인{/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- 전표 모달 -->
{#if showSlipModal && slipGroup}
  {@const slipTotal = slipGroup.inventory_logs.reduce((s, l) => s + l.quantity, 0)}
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
        <span class="text-sm font-bold">전표 미리보기</span>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" onclick={() => showSlipModal = false}>
          <Icon icon="heroicons:x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>
      <div class="px-6 py-5 space-y-4 flex-1 overflow-y-auto">
        <div class="text-center border-b border-base-200 pb-4">
          <p class="text-lg font-black">출고 전표</p>
          <p class="text-xs text-base-content/40 mt-1">{formatDate(slipGroup.created_at)} {formatTime(slipGroup.created_at)}</p>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-base-content/50">거래처</span>
          <span class="font-bold">{clientName(slipGroup.client_id)}</span>
        </div>
        <div class="border-t border-base-200 pt-3 space-y-2">
          {#each slipGroup.inventory_logs as log (log.id)}
            <div class="flex justify-between text-sm">
              <span>{log.items?.nickname ?? log.items?.name_ko ?? log.item_id}</span>
              <span class="font-bold tabular-nums">{log.quantity}개</span>
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
        <button class="btn btn-primary flex-1 font-bold" onclick={() => showSlipModal = false}>
          <Icon icon="heroicons:printer" class="w-4 h-4" />출력
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- 날짜 피커 -->
<DatePicker
  show={showDatePicker}
  target={pickerTarget}
  {fromDate}
  {toDate}
  onselect={handleDateSelect}
  onclose={() => showDatePicker = false}
/>
