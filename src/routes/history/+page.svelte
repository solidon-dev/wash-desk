<script lang="ts">
  import Icon from '@iconify/svelte';
  import DatePicker from '$lib/components/DatePicker.svelte';
  import { store, loadData, switchClient } from '$lib/store.svelte';
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

  // ── 인라인 취소 확인 ──────────────────────────────────────────
  let cancelConfirmId   = $state<string | null>(null);
  let cancelRestore     = $state(true);

  function openCancelConfirm(e: MouseEvent, groupId: string) {
    e.stopPropagation();
    cancelConfirmId = groupId;
    cancelRestore   = true;
    closeEditPanel();
  }

  async function doCancelShipout() {
    if (!cancelConfirmId) return;
    saving = true;
    const session = await getSession();
    if (!session) { saving = false; return; }
    const { error } = await deleteShipout(cancelConfirmId, session.user.id, cancelRestore);
    saving = false;
    if (error) { alert('취소 실패: ' + error.message); return; }
    cancelConfirmId = null;
    await loadShipouts();
    if (store.factoryId && store.selectedClientId) loadData(store.factoryId, store.selectedClientId);
  }

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
    if (store.factoryId && store.selectedClientId) loadData(store.factoryId, store.selectedClientId);
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
    if (store.factoryId && store.selectedClientId) loadData(store.factoryId, store.selectedClientId);
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

<div class="flex flex-1 min-h-0 min-w-0 relative" style="background:#080d1a;">

  <!-- ── 왼쪽 거래처 사이드바 ── -->
  <aside class="hidden md:flex flex-col shrink-0 min-h-0" style="width:17rem; background:#0d1328; border-right:1px solid rgba(99,179,237,0.12);">
    <div class="shrink-0 px-3 pt-4 pb-1">
      <p class="text-xs font-black uppercase tracking-widest px-1 mb-2" style="color:rgba(148,163,184,0.35); letter-spacing:0.12em;">거래처</p>
    </div>
    <div class="flex-1 overflow-y-auto min-h-0 px-2 pb-3">
      <!-- 전체 버튼 -->
      <button
        type="button"
        class="w-full text-left px-4 py-4 rounded-lg mb-1.5 flex items-center gap-3 transition-all"
        style="
          min-height:3.2rem;
          background:{store.selectedClientId === null ? 'rgba(59,130,246,0.18)' : 'rgba(255,255,255,0.02)'};
          border:1px solid {store.selectedClientId === null ? 'rgba(59,130,246,0.35)' : 'rgba(99,179,237,0.07)'};
          color:{store.selectedClientId === null ? '#93c5fd' : 'rgba(226,232,240,0.65)'};
        "
        onclick={() => { store.selectedClientId = null; loadShipouts(); }}
      >
        <span class="shrink-0 rounded-full" style="width:8px; height:8px; background:{store.selectedClientId === null ? '#3b82f6' : 'rgba(148,163,184,0.15)'}; box-shadow:{store.selectedClientId === null ? '0 0 8px rgba(59,130,246,0.8)' : 'none'};"></span>
        <span class="text-base font-bold truncate">전체</span>
      </button>
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
          <span class="shrink-0 rounded-full" style="width:8px; height:8px; background:{isActive ? '#3b82f6' : 'rgba(148,163,184,0.15)'}; box-shadow:{isActive ? '0 0 8px rgba(59,130,246,0.8)' : 'none'};"></span>
          <span class="text-base font-bold truncate">{client.name}</span>
        </button>
      {/each}
    </div>
  </aside>

  <!-- ── 오른쪽 메인 영역 ── -->
  <div class="flex-1 flex flex-col min-h-0 relative">

  <!-- 필터 헤더 -->
  <div class="bg-base-100 border-b border-base-300 px-6 pt-5 pb-5 shrink-0 space-y-4" style="background:#0d1328; border-bottom:1px solid rgba(99,179,237,0.12);">
    <div class="flex items-center gap-3 flex-wrap">
      <div class="join">
        {#each quickFilters as { key, label } (key)}
          <button
            class="btn btn-sm join-item text-base font-black h-12 px-6
              {quickFilter === key ? 'btn-primary' : 'btn-ghost border border-base-300'}"
            style={quickFilter === key ? 'background:rgba(139,92,246,0.18); color:#c4b5fd; border-color:rgba(139,92,246,0.35);' : 'background:transparent; color:rgba(226,232,240,0.6); border-color:rgba(99,179,237,0.2);'}
            onclick={() => applyQuick(key)}
          >{label}</button>
        {/each}
      </div>
      <div class="flex items-center gap-2">
        <button type="button"
          class="h-12 px-5 rounded-xl border border-base-300 bg-base-100 text-lg font-bold text-base-content hover:bg-base-200 transition-colors"
          style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.2); color:#e2e8f0;"
          onclick={() => openPicker('from')}
        >{formatDateLabel(fromDate)}</button>
        <span class="text-base-content/30 text-xl font-bold">—</span>
        <button type="button"
          class="h-12 px-5 rounded-xl border border-base-300 bg-base-100 text-lg font-bold text-base-content hover:bg-base-200 transition-colors"
          style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.2); color:#e2e8f0;"
          onclick={() => openPicker('to')}
        >{formatDateLabel(toDate)}</button>
      </div>
    </div>

    <!-- 요약 카드 -->
    <div class="grid grid-cols-3 gap-3">
      <div class="bg-base-200 rounded-2xl px-4 py-4 text-center" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);">
        <p class="text-sm font-bold text-base-content/40 mb-1" style="color:rgba(148,163,184,0.4);">출고</p>
        <p class="text-4xl font-black text-base-content" style="color:#e2e8f0;">{shipoutGroups.length}<span class="text-base font-bold text-base-content/40 ml-1" style="color:rgba(148,163,184,0.4);">건</span></p>
      </div>
      <div class="bg-base-200 rounded-2xl px-4 py-4 text-center" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);">
        <p class="text-sm font-bold text-base-content/40 mb-1" style="color:rgba(148,163,184,0.4);">수량</p>
        <p class="text-4xl font-black text-base-content" style="color:#e2e8f0;">{totalItemCount}<span class="text-base font-bold text-base-content/40 ml-1" style="color:rgba(148,163,184,0.4);">개</span></p>
      </div>
      <div class="bg-base-200 rounded-2xl px-4 py-4 text-center" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);">
        <p class="text-sm font-bold text-base-content/40 mb-1" style="color:rgba(148,163,184,0.4);">거래처</p>
        <p class="text-4xl font-black text-base-content" style="color:#e2e8f0;">{uniqueClientCount}<span class="text-base font-bold text-base-content/40 ml-1" style="color:rgba(148,163,184,0.4);">곳</span></p>
      </div>
    </div>
  </div>

  <!-- 테이블 헤더 -->
  {#if shipoutGroups.length > 0}
    <div class="h-14 bg-base-200 border-b border-base-300 px-6 shrink-0 flex items-center" style="background:#0d1328; border-bottom:1px solid rgba(99,179,237,0.12);">
      <div class="w-52 shrink-0"><span class="text-xs font-black text-base-content/40 uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">일시</span></div>
      <div class="w-52 shrink-0"><span class="text-xs font-black text-base-content/40 uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">거래처</span></div>
      <div class="flex-1 min-w-0"><span class="text-xs font-black text-base-content/40 uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">품목</span></div>
      <div class="w-20 shrink-0"></div>
      <div class="w-20 shrink-0"></div>
      <div class="w-24 shrink-0"></div>
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
        <div class="w-14 h-14 rounded-2xl bg-base-200 flex items-center justify-center" style="background:rgba(99,179,237,0.06); border:1px solid rgba(99,179,237,0.12);">
          <Icon icon="heroicons:clipboard-document-list" class="w-7 h-7 text-base-content/20" />
        </div>
        <p class="text-sm font-semibold text-base-content/50" style="color:rgba(148,163,184,0.4);">출고 기록이 없습니다</p>
        <p class="text-xs text-base-content/30" style="color:rgba(148,163,184,0.25);">날짜 범위를 변경하거나 출고를 추가하세요</p>
      </div>
    {:else}
      {#each shipoutGroups as group (group.id)}
        {@const isEditing = editingShipoutId === group.id && editPanelVisible}
        {@const shipTotal = group.inventory_logs.reduce((s, l) => s + l.quantity, 0)}
        <div
          role="button" tabindex="0"
          class="flex items-center min-h-24 px-6 border-b border-base-200 cursor-pointer transition-colors
            {isEditing ? 'bg-primary/5 border-l-4 border-l-primary' : 'hover:bg-base-200/60 border-l-4 border-l-transparent'}"
          style="border-bottom:1px solid rgba(99,179,237,0.07); {isEditing ? 'background:rgba(59,130,246,0.07); border-left-color:#3b82f6;' : 'border-left-color:transparent;'}"
          onclick={() => isEditing ? closeEditPanel() : openEditPanel(group)}
          onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (isEditing ? closeEditPanel() : openEditPanel(group))}
        >
          <div class="w-52 shrink-0">
            <p class="text-lg font-bold text-base-content tabular-nums" style="color:#e2e8f0;">
              {formatDate(group.created_at)}<br/>
              <span class="text-base font-bold text-base-content/50" style="color:rgba(148,163,184,0.5);">{formatTime(group.created_at)}</span>
            </p>
          </div>
          <div class="w-52 shrink-0 pr-2">
            <p class="text-xl font-black text-base-content truncate" style="color:#e2e8f0;">{clientName(group.client_id)}</p>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-base font-bold" style="color:#e2e8f0;">
              {group.inventory_logs.length}종 · <span class="font-black text-xl" style="color:#38bdf8;">{shipTotal}개</span>
            </p>
            <p class="text-xs truncate mt-0.5" style="color:rgba(148,163,184,0.65);">
              {group.inventory_logs.map(l => l.items?.nickname ?? l.items?.name_ko ?? '').filter(Boolean).join(', ')}
            </p>
          </div>
          <div class="w-20 flex justify-center shrink-0">
            <button
              aria-label="수정"
              class="btn btn-square {isEditing ? 'btn-primary' : 'btn-ghost'}"
              style="width:3.2rem; height:3.2rem; {isEditing ? '' : 'color:#e2e8f0;'}"
              onclick={(e) => { e.stopPropagation(); isEditing ? closeEditPanel() : openEditPanel(group); }}
            ><Icon icon="heroicons:pencil-square" class="w-7 h-7" /></button>
          </div>
          <div class="w-20 flex justify-center shrink-0">
            <button
              aria-label="전표"
              class="btn btn-square btn-ghost"
              style="width:3.2rem; height:3.2rem; color:#e2e8f0;"
              onclick={(e) => openSlip(group, e)}
            ><Icon icon="heroicons:printer" class="w-7 h-7" /></button>
          </div>
          <div class="w-24 flex justify-center shrink-0">
            <button
              aria-label="출고 취소"
              class="btn btn-sm btn-outline btn-error font-black gap-1"
              onclick={(e) => openCancelConfirm(e, group.id)}
            >
              <Icon icon="heroicons:x-circle" class="w-4 h-4" />
              취소
            </button>
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <!-- 수정 슬라이드 패널 -->
  {#if editingShipoutId !== null}
    <button class="absolute inset-0 bg-black/10 z-10 cursor-default" onclick={closeEditPanel} aria-label="닫기"></button>
    <div class="absolute right-0 top-0 bottom-0 w-120 bg-base-100 shadow-2xl z-20 flex flex-col transition-transform duration-300
      {editPanelVisible ? 'translate-x-0' : 'translate-x-full'}"
      style="background:#0d1328; border-left:1px solid rgba(99,179,237,0.15);">

      <div class="px-6 h-20 border-b border-base-200 flex items-center justify-between shrink-0" style="border-bottom:1px solid rgba(99,179,237,0.12);">
        <div>
          <h3 class="text-xl font-black text-base-content" style="color:#e2e8f0;">출고 수정</h3>
          {#each shipoutGroups.filter(g => g.id === editingShipoutId) as g}
              <p class="text-sm font-bold text-base-content/40 mt-0.5" style="color:rgba(148,163,184,0.4);">{formatDate(g.created_at)} {formatTime(g.created_at)}</p>
          {/each}
        </div>
        <button class="btn btn-md btn-square btn-ghost text-base-content/50" onclick={closeEditPanel} aria-label="닫기">
          <Icon icon="heroicons:x-mark" class="w-6 h-6" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto min-h-0">
        <div class="px-6 py-5 border-b border-base-200" style="border-bottom:1px solid rgba(99,179,237,0.12);">
          <p class="text-sm font-black text-base-content/40 uppercase tracking-wider mb-3">품목 수량</p>
          <div class="space-y-2">
            {#each editItems as item, idx (item.item_id)}
              <div class="flex items-center gap-3 min-h-20 rounded-xl border border-base-200 px-4" style="border:1px solid rgba(99,179,237,0.12); background:rgba(17,24,39,0.6);">
                <div class="flex-1 min-w-0">
                  <p class="text-xl font-bold text-base-content truncate" style="color:#e2e8f0;">{item.item_name}</p>
                  {#if item.quantity === 0}
                    <p class="text-xs text-error font-bold mt-0.5">0개 → 저장 시 삭제됩니다</p>
                  {/if}
                </div>
                <div class="flex items-center gap-2 shrink-0">
                  <button aria-label="감소" class="btn btn-md btn-square btn-ghost border border-base-300 font-black text-2xl" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.2); color:#e2e8f0;"
                    onclick={() => adjustEditQty(idx, -1)}>−</button>
                  <span class="w-14 text-center text-3xl font-black {item.quantity === 0 ? 'text-error' : 'text-primary'} tabular-nums" style={item.quantity === 0 ? '' : 'color:#3b82f6;'}>{item.quantity}</span>
                  <button aria-label="증가" class="btn btn-md btn-square btn-primary font-black text-2xl"
                    onclick={() => adjustEditQty(idx, 1)}>+</button>
                </div>
              </div>
            {/each}
          </div>
          <div class="mt-3 flex items-center justify-between px-4 py-3 bg-base-200 rounded-xl" style="background:rgba(17,24,39,0.8); border:1px solid rgba(99,179,237,0.12);">
            <span class="text-sm font-black text-base-content/40 uppercase tracking-wider" style="color:rgba(148,163,184,0.4);">합계</span>
            <span class="text-3xl font-black text-primary tabular-nums" style="color:#3b82f6; text-shadow:0 0 8px rgba(59,130,246,0.2);">
              {editItems.reduce((s, i) => s + i.quantity, 0)}<span class="text-base font-bold text-primary/60 ml-1">개</span>
            </span>
          </div>
        </div>

      </div>

      <div class="px-6 py-5 border-t border-base-200 flex gap-3 shrink-0" style="border-top:1px solid rgba(99,179,237,0.12);">
        <button class="btn btn-primary flex-1 h-16 font-black text-xl" style="background:linear-gradient(135deg,#1d4ed8,#1e40af); border:1px solid rgba(59,130,246,0.5);" onclick={saveEdit} disabled={saving}>
          {#if saving}<span class="loading loading-spinner loading-sm"></span>{:else}저장{/if}
        </button>
        <button class="btn btn-outline btn-error h-16 px-6 font-black text-xl" onclick={() => deleteConfirming = !deleteConfirming}>
          <Icon icon="heroicons:trash" class="w-6 h-6" />
        </button>
      </div>
    </div>
  {/if}
  </div>
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

<!-- 출고 취소 확인 모달 -->
{#if cancelConfirmId !== null}
  {@const cancelGroup = shipoutGroups.find(g => g.id === cancelConfirmId)}
  <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={() => cancelConfirmId = null}
    onkeydown={(e) => e.key === 'Escape' && (cancelConfirmId = null)}
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
          <h3 class="text-lg font-black text-base-content">출고 취소</h3>
          {#if cancelGroup}
            <p class="text-xs text-base-content/40 mt-0.5">{clientName(cancelGroup.client_id)} · {formatDate(cancelGroup.created_at)} {formatTime(cancelGroup.created_at)}</p>
          {/if}
        </div>
      </div>
      <p class="text-sm text-base-content/70 leading-relaxed">
        이 출고를 취소하면 기록이 <strong>완전히 삭제</strong>됩니다. 재고 복구 여부를 선택하세요.
      </p>
      <div class="flex flex-col gap-2">
        <button
          type="button"
          class="flex items-center gap-3 rounded-xl border-2 px-4 py-3 text-left transition-colors {cancelRestore ? 'border-primary bg-primary/5' : 'border-base-300 bg-base-100'}"
          onclick={() => cancelRestore = true}
        >
          <span class="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 {cancelRestore ? 'border-primary' : 'border-base-300'}">
            {#if cancelRestore}<span class="w-2.5 h-2.5 rounded-full bg-primary"></span>{/if}
          </span>
          <div>
            <p class="text-sm font-black text-base-content">재고 복구 후 취소</p>
            <p class="text-xs text-base-content/50">출고된 수량을 재고에 다시 더하고 기록을 삭제합니다</p>
          </div>
        </button>
        <button
          type="button"
          class="flex items-center gap-3 rounded-xl border-2 px-4 py-3 text-left transition-colors {!cancelRestore ? 'border-error bg-error/5' : 'border-base-300 bg-base-100'}"
          onclick={() => cancelRestore = false}
        >
          <span class="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 {!cancelRestore ? 'border-error' : 'border-base-300'}">
            {#if !cancelRestore}<span class="w-2.5 h-2.5 rounded-full bg-error"></span>{/if}
          </span>
          <div>
            <p class="text-sm font-black text-base-content">재고 유지 후 취소</p>
            <p class="text-xs text-base-content/50">재고는 그대로 두고 기록만 삭제합니다</p>
          </div>
        </button>
      </div>
      <div class="flex gap-2">
        <button class="btn btn-ghost flex-1 font-bold border border-base-300" onclick={() => cancelConfirmId = null}>닫기</button>
        <button class="btn btn-warning flex-1 font-black" onclick={doCancelShipout} disabled={saving}>
          {#if saving}<span class="loading loading-spinner loading-sm"></span>{:else}취소 확인{/if}
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
