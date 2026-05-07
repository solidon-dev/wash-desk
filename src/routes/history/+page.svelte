<script lang="ts">
  import Icon from '@iconify/svelte';
  import DatePicker from '$lib/components/DatePicker.svelte';
  import {
    store, selectClient, updateShipment, removeShipment,
    CLIENT_TYPE_BADGE, CLIENT_TYPE_LABEL, CLIENT_TYPE_ICON,
    type Client, type Shipment, type ShipmentItem, type LaundryCategory,
  } from '$lib/store.svelte';

  type QuickFilter = 'today' | 'week' | 'month' | 'custom';

  // Date utility functions
  function pad(n: number): string { return String(n).padStart(2, '0'); }

  function dateToYMD(d: Date): string {
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }

  function todayYMD(): string { return dateToYMD(new Date()); }

  function getWeekStart(): string {
    const now = new Date();
    const day = now.getDay();
    const ms = now.getTime() - day * 86400000;
    return dateToYMD(new Date(ms));
  }

  function getMonthStart(): string {
    const now = new Date();
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-01`;
  }

  // Component state
  let quickFilter = $state<QuickFilter>('today');
  let fromDate = $state(todayYMD());
  let toDate = $state(todayYMD());

  let editingShipmentId = $state<string | null>(null);
  let editPanelVisible = $state(false);
  let editItems = $state<ShipmentItem[]>([]);
  let editShippedAt = $state('');
  let deleteConfirming = $state(false);

  // 전표 출력
  let showSlipModal = $state(false);
  let slipShipment = $state<Shipment | null>(null);

  function openSlip(shipment: Shipment, e: MouseEvent) {
    e.stopPropagation();
    slipShipment = shipment;
    showSlipModal = true;
  }

  function printSlip() {
    showSlipModal = false;
  }

  // Constants
  const catColor: Record<string, string> = {
    towel:   'badge-primary',
    sheet:   'badge-secondary',
    uniform: 'badge-warning',
  };

  const quickFilters: { key: QuickFilter; label: string }[] = [
    { key: 'today', label: '오늘' },
    { key: 'week',  label: '이번 주' },
    { key: 'month', label: '이번 달' },
  ];

  // Helper functions
  function getClientById(id: string) { return store.clients.find((c: Client) => c.id === id); }

  function getShipmentsByDateRange(clientId: string | null, from: string, to: string): Shipment[] {
    const fromTs = new Date(from).getTime(); const toTs = new Date(to).getTime();
    return store.shipments.filter((s: Shipment) => {
      const ts = new Date(s.shippedAt).getTime();
      return ts >= fromTs && ts <= toTs && (clientId === null || s.clientId === clientId);
    });
  }

  // Quick filter logic
  function applyQuick(key: QuickFilter) {
    quickFilter = key;
    const today = todayYMD();
    if (key === 'today') {
      fromDate = today; toDate = today;
    } else if (key === 'week') {
      fromDate = getWeekStart(); toDate = today;
    } else if (key === 'month') {
      fromDate = getMonthStart(); toDate = today;
    }
  }

  function onDateInput() { quickFilter = 'custom'; }

  // Derived values
  let shipments = $derived(
    getShipmentsByDateRange(
      store.selectedClientId,
      `${fromDate}T00:00:00.000Z`,
      `${toDate}T23:59:59.999Z`
    ).sort((a, b) => new Date(b.shippedAt).getTime() - new Date(a.shippedAt).getTime())
  );

  let totalItemCount = $derived(
    shipments.reduce((s: number, sh: Shipment) => s + sh.items.reduce((a: number, i: ShipmentItem) => a + i.quantity, 0), 0)
  );

  let uniqueClientCount = $derived(
    new Set(shipments.map((s: Shipment) => s.clientId)).size
  );

  // Edit panel functions
  function toLocalDatetimeValue(isoStr: string): string {
    const d = new Date(isoStr);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function openEditPanel(shipment: { id: string; items: ShipmentItem[]; shippedAt: string }) {
    editingShipmentId = shipment.id;
    editItems = shipment.items.map((i) => ({ ...i }));
    editShippedAt = toLocalDatetimeValue(shipment.shippedAt);
    editPanelVisible = true;
    deleteConfirming = false;
  }

  function closeEditPanel() {
    editPanelVisible = false;
    editingShipmentId = null;
    deleteConfirming = false;
  }

  function adjustEditQty(idx: number, delta: number) {
    const item = editItems[idx];
    if (!item) return;
    const next = Math.max(0, item.quantity + delta);
    editItems = editItems.map((it, i) => i === idx ? { ...it, quantity: next } : it);
  }

  function saveEdit() {
    if (!editingShipmentId) return;
    updateShipment(editingShipmentId, {
      items: editItems.filter((i) => i.quantity > 0),
      shippedAt: new Date(editShippedAt).toISOString(),
    });
    closeEditPanel();
  }

  function deleteShipment() {
    if (!editingShipmentId) return;
    removeShipment(editingShipmentId);
    closeEditPanel();
  }

  function reprintSlip() {
    alert('Print slip feature is under development.');
  }

  // ── 날짜 피커 ─────────────────────────────────
  let showDatePicker = $state(false);
  let pickerTarget = $state<'from' | 'to'>('from');
  let showEditDatePicker = $state(false);

  function openPicker(target: 'from' | 'to') {
    pickerTarget = target;
    showDatePicker = true;
  }

  function handleDateSelect(_target: 'from' | 'to' | 'single', ymd: string) {
    if (pickerTarget === 'from') {
      fromDate = ymd;
      if (toDate < fromDate) toDate = fromDate;
    } else {
      toDate = ymd;
      if (fromDate > toDate) fromDate = toDate;
    }
    quickFilter = 'custom';
  }

  function formatDateLabel(ymd: string): string {
    const [y, m, d] = ymd.split('-');
    return `${y}.${m}.${d}`;
  }

  // Format functions
  function formatDate(isoStr: string): string {
    const d = new Date(isoStr);
    return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())}`;
  }

  function formatTime(isoStr: string): string {
    const d = new Date(isoStr);
    return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }
</script>

<svelte:head><title>출고 현황</title></svelte:head>

<div class="flex-1 flex flex-col min-h-0 relative">

  <!-- ── 필터 헤더 ── -->
  <div class="bg-base-100 border-b border-base-300 px-4 pt-3 pb-3 shrink-0 space-y-3">

    <!-- 퀵필터 + 날짜 범위 한 줄 -->
    <div class="flex items-center gap-2 flex-wrap">
      <div class="join">
        {#each quickFilters as { key, label } (key)}
          <button
            class="btn btn-xs join-item font-semibold
              {quickFilter === key ? 'btn-primary' : 'btn-ghost border border-base-300'}"
            onclick={() => applyQuick(key)}
          >{label}</button>
        {/each}
      </div>

      <div class="flex items-center gap-1.5">
        <button
          type="button"
          class="h-7 px-3 rounded-lg border border-base-300 bg-base-100 text-sm font-bold text-base-content hover:bg-base-200 transition-colors"
          onclick={() => openPicker('from')}
        >{formatDateLabel(fromDate)}</button>
        <span class="text-base-content/30 text-xs">—</span>
        <button
          type="button"
          class="h-7 px-3 rounded-lg border border-base-300 bg-base-100 text-sm font-bold text-base-content hover:bg-base-200 transition-colors"
          onclick={() => openPicker('to')}
        >{formatDateLabel(toDate)}</button>
      </div>

    </div>

    <!-- 요약 카드 3개 -->
    <div class="grid grid-cols-3 gap-2">
      <div class="bg-base-200 rounded-lg px-3 py-2 text-center">
        <p class="text-[10px] text-base-content/40 mb-0.5">출고</p>
        <p class="text-lg font-black text-base-content">{shipments.length}<span class="text-[10px] font-medium text-base-content/40 ml-0.5">건</span></p>
      </div>
      <div class="bg-base-200 rounded-lg px-3 py-2 text-center">
        <p class="text-[10px] text-base-content/40 mb-0.5">수량</p>
        <p class="text-lg font-black text-base-content">{totalItemCount}<span class="text-[10px] font-medium text-base-content/40 ml-0.5">개</span></p>
      </div>
      <div class="bg-base-200 rounded-lg px-3 py-2 text-center">
        <p class="text-[10px] text-base-content/40 mb-0.5">거래처</p>
        <p class="text-lg font-black text-base-content">{uniqueClientCount}<span class="text-[10px] font-medium text-base-content/40 ml-0.5">곳</span></p>
      </div>
    </div>

  </div>

  <!-- ── 테이블 헤더 ── -->
  {#if shipments.length > 0}
    <div class="h-10 bg-base-200 border-b border-base-300 px-4 shrink-0 flex items-center">
      <div class="w-36 shrink-0">
        <span class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">일시</span>
      </div>
      <div class="w-32 shrink-0">
        <span class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">거래처</span>
      </div>
      <div class="flex-1 min-w-0">
        <span class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">품목</span>
      </div>
      <div class="w-12 shrink-0"></div>
      <div class="w-12 shrink-0"></div>
    </div>
  {/if}

  <!-- ── 출고 기록 목록 ── -->
  <div class="flex-1 overflow-y-auto min-h-0">
    {#if shipments.length === 0}
      <div class="flex flex-col items-center justify-center h-full gap-3">
        <div class="w-14 h-14 rounded-2xl bg-base-200 flex items-center justify-center">
          <Icon icon="heroicons:clipboard-document-list" class="w-7 h-7 text-base-content/20" />
        </div>
        <p class="text-sm font-semibold text-base-content/50">출고 기록이 없습니다</p>
        <p class="text-xs text-base-content/30">날짜 범위를 변경하거나 출고를 추가하세요</p>
      </div>
    {:else}
      {#each shipments as shipment (shipment.id)}
        {@const client = getClientById(shipment.clientId)}
        {@const shipTotal = shipment.items.reduce((a: number, i: ShipmentItem) => a + i.quantity, 0)}
        {@const isEditing = editingShipmentId === shipment.id && editPanelVisible}
        <div
          role="button"
          tabindex="0"
          class="flex items-center min-h-14 px-4 border-b border-base-200 transition-colors cursor-pointer
            {isEditing
              ? 'bg-primary/5 border-l-2 border-l-primary'
              : 'hover:bg-base-200/60 border-l-2 border-l-transparent'}"
          onclick={() => openEditPanel(shipment)}
          onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') openEditPanel(shipment); }}
        >
          <!-- 날짜/시간 -->
          <div class="w-36 shrink-0">
            <p class="text-sm font-bold text-base-content tabular-nums">
              {formatDate(shipment.shippedAt)} {formatTime(shipment.shippedAt)}
            </p>
          </div>

          <!-- 거래처 -->
          <div class="w-32 shrink-0 pr-2">
            {#if client}
              <p class="text-sm font-semibold text-base-content truncate">{client.name}</p>
            {:else}
              <p class="text-sm text-base-content/30">미확인</p>
            {/if}
          </div>

          <!-- 품목 요약 -->
          <div class="flex-1 min-w-0">
            <p class="text-sm text-base-content/60">{shipment.items.length}종 · <span class="font-bold text-base-content">{shipTotal}개</span></p>
          </div>

          <!-- 편집 버튼 -->
          <div class="w-12 flex justify-center shrink-0">
            <button
              aria-label="출고 수정"
              class="btn btn-sm btn-square
                {isEditing ? 'btn-primary' : 'btn-ghost text-base-content/40 hover:text-base-content'}"
              onclick={(e) => { e.stopPropagation(); if (isEditing) { closeEditPanel(); } else { openEditPanel(shipment); } }}
            >
              <Icon icon="heroicons:pencil-square" class="w-4 h-4" />
            </button>
          </div>

          <!-- 전표 버튼 -->
          <div class="w-12 flex justify-center shrink-0">
            <button
              aria-label="전표 출력"
              class="btn btn-sm btn-square btn-ghost text-base-content/40 hover:text-base-content"
              onclick={(e) => openSlip(shipment, e)}
            >
              <Icon icon="heroicons:printer" class="w-4 h-4" />
            </button>
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <!-- ── 수정 슬라이드 패널 ── -->
  {#if editingShipmentId !== null}
    <!-- 백드롭 -->
    <button
      class="absolute inset-0 bg-black/10 z-10 cursor-default"
      onclick={closeEditPanel}
      aria-label="패널 닫기"
    ></button>

    <!-- 슬라이드 패널 -->
    <div
      class="absolute right-0 top-0 bottom-0 w-110 bg-base-100 shadow-2xl z-20 flex flex-col
        transition-transform duration-300
        {editPanelVisible ? 'translate-x-0' : 'translate-x-full'}"
    >
      <!-- 패널 헤더 -->
      <div class="px-4 h-14 border-b border-base-200 flex items-center justify-between shrink-0">
        <div>
          <h3 class="text-sm font-bold text-base-content">출고 수정</h3>
          {#each store.shipments.filter((sh: Shipment) => sh.id === editingShipmentId) as s (s.id)}
            <p class="text-xs text-base-content/40 mt-0.5">{formatDate(s.shippedAt)} {formatTime(s.shippedAt)}</p>
          {/each}
        </div>
        <button
          aria-label="닫기"
          class="btn btn-sm btn-square btn-ghost text-base-content/50"
          onclick={closeEditPanel}
        >
          <Icon icon="heroicons:x-mark" class="w-4 h-4" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto min-h-0">

        <!-- 품목 수량 수정 -->
        <div class="px-4 py-3 border-b border-base-200">
          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">품목 수량</p>
          <div class="space-y-1.5">
            {#each editItems as item, idx (item.laundryItemId)}
              <div class="flex items-center gap-3 min-h-14 rounded-lg border border-base-200 px-3">
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-base-content truncate">{item.itemName}</p>
                </div>
                <div class="flex items-center gap-1.5 shrink-0">
                  <button
                    aria-label="수량 감소"
                    class="btn btn-sm btn-square btn-ghost border border-base-300 font-bold text-base"
                    onclick={() => adjustEditQty(idx, -1)}
                  >−</button>
                  <span class="w-10 text-center text-lg font-black text-primary tabular-nums">{item.quantity}</span>
                  <button
                    aria-label="수량 증가"
                    class="btn btn-sm btn-square btn-primary font-bold text-base"
                    onclick={() => adjustEditQty(idx, 1)}
                  >+</button>
                </div>
              </div>
            {/each}
          </div>
          <!-- 합계 -->
          <div class="mt-2 flex items-center justify-between px-3 py-2 bg-base-200 rounded-lg">
            <span class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">합계</span>
            <span class="text-lg font-black text-primary tabular-nums">
              {editItems.reduce((s, i) => s + i.quantity, 0)}<span class="text-xs font-semibold text-primary/60 ml-1">개</span>
            </span>
          </div>
        </div>

        <!-- 출고 일시 -->
        <div class="px-4 py-3 border-b border-base-200">
          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">출고 일시</p>
          <button
            type="button"
            class="h-9 px-3 w-full rounded-lg border border-base-300 bg-base-100 text-sm font-bold text-base-content hover:bg-base-200 transition-colors text-left"
            onclick={() => showEditDatePicker = true}
          >{editShippedAt.replace('T', ' ')}</button>
        </div>

        <!-- 삭제 확인 인라인 -->
        {#if deleteConfirming}
          <div class="px-4 py-3 bg-error/8 border-b border-error/15">
            <p class="text-xs font-semibold text-error mb-2">이 출고 기록을 삭제하시겠습니까?</p>
            <div class="flex gap-2">
              <button
                class="btn btn-error btn-sm flex-1 font-bold"
                onclick={deleteShipment}
              >삭제 확인</button>
              <button
                class="btn btn-ghost btn-sm flex-1 font-bold border border-base-300"
                onclick={() => (deleteConfirming = false)}
              >취소</button>
            </div>
          </div>
        {/if}

      </div>

      <!-- 패널 하단 버튼 -->
      <div class="px-4 py-4 border-t border-base-200 flex gap-2 shrink-0">
        <button
          class="btn btn-primary flex-1 h-12 font-bold"
          onclick={saveEdit}
        >저장</button>
        <button
          class="btn btn-outline btn-error h-12 px-4 font-bold"
          onclick={() => (deleteConfirming = !deleteConfirming)}
        >
          <Icon icon="heroicons:trash" class="w-4 h-4" />
        </button>
      </div>
    </div>
  {/if}

</div>

<!-- 전표 출력 모달 -->
{#if showSlipModal && slipShipment}
  {@const sc = getClientById(slipShipment.clientId)}
  {@const slipTotal = slipShipment.items.reduce((a: number, i: ShipmentItem) => a + i.quantity, 0)}
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => showSlipModal = false}
    onkeydown={(e) => e.key === 'Escape' && (showSlipModal = false)}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-2xl shadow-2xl w-96 flex flex-col max-h-[80vh] overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <!-- 모달 헤더 -->
      <div class="px-5 py-4 border-b border-base-200 flex items-center justify-between">
        <span class="text-sm font-bold text-base-content">전표 미리보기</span>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" onclick={() => showSlipModal = false}>
          <Icon icon="heroicons:x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>

      <!-- 전표 내용 (print-area) -->
      <div class="px-6 py-5 space-y-4 flex-1 overflow-y-auto" id="slip-print-area">
        <!-- 타이틀 -->
        <div class="text-center border-b border-base-200 pb-4">
          <p class="text-lg font-black text-base-content">출고 전표</p>
          <p class="text-xs text-base-content/40 mt-1">{formatDate(slipShipment.shippedAt)} {formatTime(slipShipment.shippedAt)}</p>
        </div>

        <!-- 거래처 -->
        <div class="flex justify-between text-sm">
          <span class="text-base-content/50">거래처</span>
          <span class="font-bold text-base-content">{sc?.name ?? '미확인'}</span>
        </div>

        <!-- 품목 목록 -->
        <div class="border-t border-base-200 pt-3 space-y-2">
          {#each slipShipment.items as item (item.laundryItemId)}
            <div class="flex justify-between text-sm">
              <span class="text-base-content">{item.itemName}</span>
              <span class="font-bold tabular-nums">{item.quantity}개</span>
            </div>
          {/each}
        </div>

        <!-- 합계 -->
        <div class="border-t-2 border-base-content pt-3 flex justify-between">
          <span class="text-sm font-bold">합계</span>
          <span class="text-lg font-black tabular-nums">{slipTotal}개</span>
        </div>

        {#if slipShipment.memo}
          <p class="text-xs text-base-content/40 border-t border-base-200 pt-2">메모: {slipShipment.memo}</p>
        {/if}
      </div>

      <!-- 버튼 -->
      <div class="px-5 py-4 border-t border-base-200 flex gap-2">
        <button
          class="btn btn-ghost flex-1 font-bold border border-base-300"
          onclick={() => showSlipModal = false}
        >취소</button>
        <button
          class="btn btn-primary flex-1 font-bold"
          onclick={printSlip}
        >
          <Icon icon="heroicons:printer" class="w-4 h-4" />
          출력
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- 날짜 피커 (필터용) -->
<DatePicker
  show={showDatePicker}
  target={pickerTarget}
  {fromDate}
  {toDate}
  onselect={handleDateSelect}
  onclose={() => showDatePicker = false}
/>

<!-- 날짜 피커 (수정 패널용 datetime) -->
<DatePicker
  show={showEditDatePicker}
  target="single"
  mode="datetime"
  fromDate={editShippedAt.slice(0,10)}
  toDate={editShippedAt.slice(0,10)}
  datetimeValue={editShippedAt}
  onselect={() => {}}
  ondatetimeselect={(v) => { editShippedAt = v; }}
  onclose={() => showEditDatePicker = false}
/>
