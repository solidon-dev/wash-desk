<script lang="ts">
  import { goto } from '$app/navigation';
  import Icon from '@iconify/svelte';

  // ── 타입 인라인 ──────────────────────────────────────────────────
  type ClientType = 'hotel' | 'pension' | 'resort' | 'etc';
  type LaundryCategory = 'towel' | 'sheet' | 'uniform' | 'all';
  interface Client { id: string; name: string; type: ClientType; address: string; createdAt: string; }
  interface ShipmentItem { laundryItemId: string; itemName: string; category: Exclude<LaundryCategory,'all'>; quantity: number; }
  interface Shipment { id: string; clientId: string; items: ShipmentItem[]; driverId: string; memo?: string; shippedAt: string; createdAt: string; }

  // ── 유틸 ─────────────────────────────────────────────────────────
  function genId() { return Math.random().toString(36).slice(2,10) + Date.now().toString(36); }

  // ── 초기 데이터 ──────────────────────────────────────────────────
  const _clients: Client[] = [
    {id:'client-001',name:'그랜드호텔',type:'hotel',address:'서울특별시 강남구 테헤란로 123',createdAt:'2024-01-10T09:00:00.000Z'},
    {id:'client-002',name:'씨뷰펜션',type:'pension',address:'강원도 강릉시 해안로 456',createdAt:'2024-02-15T09:00:00.000Z'},
    {id:'client-003',name:'파크리조트',type:'resort',address:'경기도 가평군 청평면 789',createdAt:'2024-03-01T09:00:00.000Z'},
    {id:'client-004',name:'스카이호텔',type:'hotel',address:'부산광역시 해운대구 마린시티로 321',createdAt:'2024-03-20T09:00:00.000Z'},
    {id:'client-005',name:'오션펜션',type:'pension',address:'제주특별자치도 서귀포시 중문관광로 654',createdAt:'2024-04-05T09:00:00.000Z'},
  ];

  // ── 공유 상태 ($state) ───────────────────────────────────────────
  let clients = $state<Client[]>(_clients);
  let shipments_all = $state<Shipment[]>([]);
  let selectedClientId = $state<string|null>(null);

  // ── 헬퍼 함수들 ──────────────────────────────────────────────────
  function selectClient(id:string|null){selectedClientId=id;}
  function getClientById(id:string){return clients.find(c=>c.id===id);}
  function getShipmentsByDateRange(clientId:string|null,from:string,to:string):Shipment[]{
    const fromTs=new Date(from).getTime(); const toTs=new Date(to).getTime();
    return shipments_all.filter(s=>{
      const ts=new Date(s.shippedAt).getTime();
      return ts>=fromTs&&ts<=toTs&&(clientId===null||s.clientId===clientId);
    });
  }
  function updateShipment(id:string,updates:Partial<Omit<Shipment,'id'|'createdAt'>>){
    shipments_all=shipments_all.map(s=>s.id===id?{...s,...updates}:s);
  }
  function removeShipment(id:string){shipments_all=shipments_all.filter(s=>s.id!==id);}

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

  // Constants
  const clientTypeIcon: Record<string, string> = {
    hotel: '🏨', pension: '🏡', resort: '🌴', etc: '🏢',
  };
  const clientTypeBadge: Record<string, string> = {
    hotel: 'bg-sky-100 text-sky-700',
    pension: 'bg-emerald-100 text-emerald-700',
    resort: 'bg-amber-100 text-amber-700',
    etc: 'bg-slate-100 text-slate-600',
  };
  const clientTypeLabel: Record<string, string> = {
    hotel: 'Hotel', pension: 'Pension', resort: 'Resort', etc: 'Etc',
  };

  const catColor: Record<string, string> = {
    towel:   'bg-sky-100 text-sky-700',
    sheet:   'bg-indigo-100 text-indigo-700',
    uniform: 'bg-amber-100 text-amber-700',
  };

  const quickFilters: { key: QuickFilter; label: string }[] = [
    { key: 'today', label: 'Today' },
    { key: 'week',  label: 'This Week' },
    { key: 'month', label: 'This Month' },
  ];

  const navItems = [
    { path: '/',        icon: 'heroicons:inbox-stack',            label: '세탁물' },
    { path: '/shipout', icon: 'heroicons:archive-box-arrow-down', label: '출고'   },
    { path: '/history', icon: 'heroicons:chart-bar',              label: '현황'   },
  ];
  const currentPath = '/history';

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
      selectedClientId,
      `${fromDate}T00:00:00.000Z`,
      `${toDate}T23:59:59.999Z`
    ).sort((a, b) => new Date(b.shippedAt).getTime() - new Date(a.shippedAt).getTime())
  );

  let totalItemCount = $derived(
    shipments.reduce((s, sh) => s + sh.items.reduce((a, i) => a + i.quantity, 0), 0)
  );

  let uniqueClientCount = $derived(
    new Set(shipments.map((s) => s.clientId)).size
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

<svelte:head><title>Shipment History</title></svelte:head>

<div class="flex h-screen bg-slate-50 overflow-hidden select-none">

  <!-- Side Navigation -->
  <nav class="w-16 bg-sky-700 flex flex-col items-center py-3 gap-0.5 shrink-0 shadow-lg z-10">
    <div class="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center mb-3 shrink-0">
      <Icon icon="heroicons:archive-box" class="w-6 h-6 text-white" />
    </div>
    {#each navItems as nav (nav.label)}
      <button
        class="w-12 h-14 rounded-xl flex flex-col items-center justify-center gap-0.5 transition-all duration-150
          {currentPath === nav.path ? 'bg-sky-500 text-white' : 'text-sky-200 hover:bg-white/10'}"
        aria-label={nav.label}
        onclick={() => void goto(nav.path)}
      >
        <Icon icon={nav.icon} class="w-5 h-5" />
        <span class="text-[9px] font-bold">{nav.label}</span>
      </button>
    {/each}
  </nav>

  <!-- Client Panel (includes All) -->
  <aside class="w-52 bg-white border-r border-sky-100 flex flex-col shrink-0 overflow-hidden">
    <div class="px-3 py-3 border-b border-sky-100 shrink-0">
      <h2 class="text-sm font-extrabold text-slate-700 tracking-wide">Clients</h2>
      <p class="text-[10px] text-slate-400 mt-0.5">{clients.length} clients</p>
    </div>
    <div class="flex-1 overflow-y-auto">

      <!-- All button -->
      {#if true}
        {@const isAllSel = selectedClientId === null}
        <button
          class="w-full flex items-center gap-2 px-3 py-4 transition-all duration-150 border-b border-slate-100
            {isAllSel ? 'bg-sky-50 border-l-4 border-l-sky-500' : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
          style="min-height:64px"
          onclick={() => selectClient(null)}
        >
          <span class="text-2xl shrink-0">🏢</span>
          <div class="flex-1 min-w-0 text-left">
            <p class="text-base font-bold {isAllSel ? 'text-sky-700' : 'text-slate-700'}">All</p>
            <span class="text-[10px] px-1.5 py-0.5 rounded-full font-bold bg-slate-100 text-slate-500">
              All Clients
            </span>
          </div>
          {#if isAllSel}
            <span class="text-[10px] px-1.5 py-0.5 rounded-full bg-sky-100 text-sky-600 font-bold shrink-0">Selected</span>
          {/if}
        </button>
      {/if}

      {#each clients as client (client.id)}
        {@const isSel = selectedClientId === client.id}
        <button
          class="w-full flex items-center gap-2 px-3 py-4 transition-all duration-150 border-b border-slate-50
            {isSel ? 'bg-sky-50 border-l-4 border-l-sky-500' : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
          style="min-height:64px"
          onclick={() => selectClient(client.id)}
        >
          <span class="text-2xl shrink-0">{clientTypeIcon[client.type] ?? '🏢'}</span>
          <div class="flex-1 min-w-0 text-left">
            <p class="text-base font-bold truncate {isSel ? 'text-sky-700' : 'text-slate-800'}">{client.name}</p>
            <span class="text-[10px] px-1.5 py-0.5 rounded-full font-bold {clientTypeBadge[client.type] ?? 'bg-slate-100 text-slate-600'}">
              {clientTypeLabel[client.type] ?? client.type}
            </span>
          </div>
        </button>
      {/each}
    </div>
  </aside>

  <!-- Main Area -->
  <div class="flex-1 flex flex-col overflow-hidden relative">

    <!-- ?�터 �?-->
    <div class="bg-white border-b border-sky-100 px-5 py-3 shrink-0 shadow-sm">
      <div class="flex items-center justify-between gap-4 flex-wrap">

        <!-- Title + Client -->
        <div class="flex items-center gap-3">
          <h1 class="text-lg font-extrabold text-slate-800">Shipment History</h1>
          {#if selectedClientId}
            <span class="px-2.5 py-1 bg-sky-100 text-sky-700 rounded-full text-xs font-bold">
              {clients.find(c=>c.id===selectedClientId)?.name}
            </span>
          {:else}
            <span class="px-2.5 py-1 bg-slate-100 text-slate-500 rounded-full text-xs font-bold">All</span>
          {/if}
        </div>

        <!-- 빠른?�택 + ?�짜 범위 -->
        <div class="flex items-center gap-3 flex-wrap">
          <!-- Quick filter buttons -->
          <div class="flex gap-3">
            {#each quickFilters as { key, label } (key)}
              <button
                class="px-6 py-3 text-base font-bold rounded-xl transition-all duration-150
                  {quickFilter === key
                    ? 'bg-sky-600 text-white shadow-md'
                    : 'bg-white text-slate-600 border border-slate-200 hover:bg-sky-50'}"
                onclick={() => applyQuick(key)}
              >{label}</button>
            {/each}
          </div>

          <!-- Date range input -->
          <div class="flex items-center gap-1.5">
            <input
              type="date"
              bind:value={fromDate}
              oninput={onDateInput}
              class="h-11 px-3 rounded-xl border border-slate-200 text-base font-bold text-slate-700
                focus:outline-none focus:border-sky-400 transition-all"
            />
            <span class="text-slate-400 text-sm font-bold">~</span>
            <input
              type="date"
              bind:value={toDate}
              oninput={onDateInput}
              class="h-11 px-3 rounded-xl border border-slate-200 text-base font-bold text-slate-700
                focus:outline-none focus:border-sky-400 transition-all"
            />
          </div>

          <span class="text-xs text-slate-400 font-medium">
            Total: <span class="font-extrabold text-slate-700">{shipments.length}</span> records /
            <span class="font-extrabold text-slate-700">{totalItemCount}</span> items
          </span>
        </div>
      </div>

      <!-- Summary cards -->
      <div class="grid grid-cols-3 gap-3 mt-3">
        <div class="rounded-xl bg-sky-50 border border-sky-200 px-6 py-4">
          <p class="text-xs font-bold text-sky-600 mb-0.5">Total Shipments</p>
          <p class="text-3xl font-extrabold text-sky-700">
            {shipments.length}<span class="text-sm font-bold ml-1">records</span>
          </p>
        </div>
        <div class="rounded-xl bg-indigo-50 border border-indigo-200 px-6 py-4">
          <p class="text-xs font-bold text-indigo-600 mb-0.5">Total Items</p>
          <p class="text-3xl font-extrabold text-indigo-700">
            {totalItemCount}<span class="text-sm font-bold ml-1">items</span>
          </p>
        </div>
        <div class="rounded-xl bg-teal-50 border border-teal-200 px-6 py-4">
          <p class="text-xs font-bold text-teal-600 mb-0.5">Clients</p>
          <p class="text-3xl font-extrabold text-teal-700">
            {uniqueClientCount}<span class="text-sm font-bold ml-1">clients</span>
          </p>
        </div>
      </div>
    </div>

    <!-- Table header -->
    {#if shipments.length > 0}
      <div class="bg-slate-100 border-b border-slate-200 px-4 shrink-0">
        <div class="flex items-center h-10">
          <div class="w-36 shrink-0">
            <span class="text-xs font-bold text-slate-500 uppercase tracking-wide">Date/Time</span>
          </div>
          <div class="w-36 shrink-0">
            <span class="text-xs font-bold text-slate-500">Client</span>
          </div>
          <div class="flex-1 min-w-0">
            <span class="text-xs font-bold text-slate-500">Item</span>
          </div>
          <div class="w-24 text-center shrink-0">
            <span class="text-xs font-bold text-slate-500">Total Qty</span>
          </div>
          <div class="w-16 text-center shrink-0">
            <span class="text-xs font-bold text-slate-500">Edit</span>
          </div>
        </div>
      </div>
    {/if}

    <!-- 출고 기록 목록 -->
    <div class="flex-1 overflow-y-auto">
      {#if shipments.length === 0}
        <div class="flex flex-col items-center justify-center h-full text-slate-400 gap-3">
          <div class="w-16 h-16 rounded-2xl bg-slate-100 flex items-center justify-center">
            <Icon icon="heroicons:clipboard-document-list" class="w-8 h-8 opacity-40" />
          </div>
          <p class="text-base font-medium">No shipments in this period</p>
          <p class="text-sm text-slate-300">Change the date range or add shipments</p>
        </div>
      {:else}
        {#each shipments as shipment (shipment.id)}
          {@const client = getClientById(shipment.clientId)}
          {@const shipTotal = shipment.items.reduce((a, i) => a + i.quantity, 0)}
          {@const isEditing = editingShipmentId === shipment.id && editPanelVisible}
          <!-- Row (click to edit) -->
          <div
            role="button"
            tabindex="0"
            class="flex items-center px-4 border-b border-slate-100 transition-all duration-150 cursor-pointer
              {isEditing
                ? 'bg-sky-50 border-l-4 border-l-sky-500'
                : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
            style="min-height:64px"
            onclick={() => openEditPanel(shipment)}
            onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') openEditPanel(shipment); }}
          >
            <!-- Date/Time -->
            <div class="w-36 shrink-0 py-2">
              <p class="text-sm font-bold text-slate-700">{formatDate(shipment.shippedAt)}</p>
              <p class="text-xs text-slate-400 mt-0.5">{formatTime(shipment.shippedAt)}</p>
            </div>

            <!-- Client -->
            <div class="w-36 shrink-0 py-2">
              {#if client}
                <p class="text-base font-bold text-slate-700 truncate">{client.name}</p>
                <span class="text-[10px] px-1.5 py-0.5 rounded-full font-bold {clientTypeBadge[client.type] ?? 'bg-slate-100 text-slate-600'}">
                  {clientTypeLabel[client.type] ?? client.type}
                </span>
              {:else}
                <p class="text-sm text-slate-400">Unknown</p>
              {/if}
            </div>

            <!-- Item chips -->
            <div class="flex-1 min-w-0 py-2 flex flex-wrap gap-1 overflow-hidden">
              {#each shipment.items as item (item.laundryItemId)}
                <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-xs font-bold
                  {catColor[item.category] ?? 'bg-slate-100 text-slate-600'}">
                  {item.itemName}
                  <span class="font-extrabold">{item.quantity}</span>
                </span>
              {/each}
              {#if shipment.memo}
                <span class="text-xs text-slate-400 italic self-center truncate max-w-24">{shipment.memo}</span>
              {/if}
            </div>

            <!-- Total Qty -->
            <div class="w-24 text-center shrink-0 py-2">
              <span class="text-2xl font-extrabold text-sky-700">{shipTotal}</span>
              <span class="text-xs text-slate-400 ml-0.5">items</span>
            </div>

            <!-- Edit button -->
            <div class="w-16 flex justify-center shrink-0 py-2">
              <button
                aria-label="Edit shipment"
                class="w-12 h-12 rounded-xl flex items-center justify-center transition-all duration-150
                  {isEditing ? 'bg-sky-500 text-white' : 'bg-slate-100 hover:bg-sky-100 text-slate-500 hover:text-sky-600'}"
                onclick={(e) => { e.stopPropagation(); if (isEditing) { closeEditPanel(); } else { openEditPanel(shipment); } }}
              >
                <Icon icon="heroicons:pencil-square" class="w-5 h-5" />
              </button>
            </div>
          </div>
        {/each}
      {/if}
    </div>

    <!-- Edit Slide Panel -->
    {#if editingShipmentId !== null}
      <!-- Background overlay (click to close panel) -->
      <button
        class="absolute inset-0 bg-black/10 z-10 cursor-default"
        onclick={closeEditPanel}
        aria-label="Close edit panel"
      ></button>

      <!-- ?�로???�널 -->
      <div
        class="absolute right-0 top-0 bottom-0 w-[520px] bg-white shadow-2xl z-20 flex flex-col
          transition-transform duration-300
          {editPanelVisible ? 'translate-x-0' : 'translate-x-full'}"
      >
        <!-- Panel header -->
        <div class="px-6 py-5 bg-sky-700 flex items-start justify-between shrink-0">
          <div>
            <h3 class="text-lg font-black text-white">Edit Shipment</h3>
            {#each shipments_all.filter(sh => sh.id === editingShipmentId) as s (s.id)}
              <p class="text-sm text-sky-200 mt-0.5">{formatDate(s.shippedAt)} {formatTime(s.shippedAt)}</p>
            {/each}
          </div>
          <button
            aria-label="Close"
            class="w-9 h-9 rounded-xl bg-white/20 hover:bg-white/30 flex items-center justify-center transition-all shrink-0"
            onclick={closeEditPanel}
          >
            <Icon icon="heroicons:x-mark" class="w-5 h-5 text-white" />
          </button>
        </div>

        <div class="flex-1 overflow-y-auto">

          <!-- Edit Item Qty -->
          <div class="px-5 py-4 border-b border-slate-100">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-3">Item Qty</p>
            <div class="space-y-2">
              {#each editItems as item, idx (item.laundryItemId)}
                <div class="flex items-center gap-3 rounded-xl bg-slate-50 border border-slate-200 px-4 py-3" style="min-height:56px">
                  <div class="flex-1 min-w-0">
                    <p class="text-base font-bold text-slate-800 truncate">{item.itemName}</p>
                    <span class="inline-block text-[10px] px-1.5 py-0.5 rounded-full mt-0.5 font-bold
                      {catColor[item.category] ?? 'bg-slate-100 text-slate-600'}">
                      {item.category}
                    </span>
                  </div>
                  <div class="flex items-center gap-2 shrink-0">
                    <button
                      aria-label="Decrease qty"
                      class="w-10 h-10 rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold
                        flex items-center justify-center text-xl transition-all active:scale-95"
                      onclick={() => adjustEditQty(idx, -1)}
                    >-</button>
                    <span class="w-12 text-center text-xl font-extrabold text-sky-700">{item.quantity}</span>
                    <button
                      aria-label="Increase qty"
                      class="w-10 h-10 rounded-lg bg-sky-500 hover:bg-sky-600 text-white font-bold
                        flex items-center justify-center text-xl transition-all active:scale-95"
                      onclick={() => adjustEditQty(idx, 1)}
                    >+</button>
                  </div>
                </div>
              {/each}
            </div>
            <!-- Total -->
            <div class="mt-3 flex items-center justify-between px-4 py-3 bg-sky-50 rounded-xl border border-sky-200">
              <span class="text-sm font-bold text-slate-500">Total Qty</span>
              <span class="text-lg font-extrabold text-sky-700">
                {editItems.reduce((s, i) => s + i.quantity, 0)}<span class="text-sm font-bold ml-1">items</span>
              </span>
            </div>
          </div>

          <!-- Edit Shipment Date -->
          <div class="px-5 py-4 border-b border-slate-100">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Edit Shipment Date</p>
            <input
              type="datetime-local"
              bind:value={editShippedAt}
              class="w-full h-11 px-3 rounded-xl border-2 border-slate-200 text-sm font-bold text-slate-700
                focus:outline-none focus:border-sky-400 transition-all"
            />
          </div>

          <!-- Confirm Delete area -->
          {#if deleteConfirming}
            <div class="px-5 py-4 bg-red-50 border-b border-red-100">
              <p class="text-sm font-bold text-red-700 mb-3">Really delete this shipment?</p>
              <div class="flex gap-2">
                <button
                  class="flex-1 h-11 rounded-xl bg-red-500 hover:bg-red-600 text-white font-bold text-sm
                    transition-all active:scale-95"
                  onclick={deleteShipment}
                >Delete</button>
                <button
                  class="flex-1 h-11 rounded-xl bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold text-sm
                    transition-all"
                  onclick={() => (deleteConfirming = false)}
                >Cancel</button>
              </div>
            </div>
          {/if}

        </div>

        <!-- Panel footer buttons -->
        <div class="px-5 py-4 border-t border-slate-100 space-y-2 shrink-0">
          <!-- Save -->
          <button
            class="w-full h-14 rounded-xl bg-sky-500 hover:bg-sky-600 text-white text-base font-bold
              transition-all duration-150 active:scale-[0.98] shadow-md shadow-sky-200"
            onclick={saveEdit}
          >Save</button>

          <!-- Print Slip -->
          <button
            class="w-full h-12 rounded-xl text-sm font-bold bg-teal-600 hover:bg-teal-700 text-white
              transition-all duration-150 active:scale-[0.98]"
            onclick={reprintSlip}
          >Print Slip</button>

          <!-- Delete toggle -->
          <button
            class="w-full h-12 rounded-xl font-bold text-sm transition-all duration-150 border
              {deleteConfirming
                ? 'bg-red-50 border-red-300 text-red-600 hover:bg-red-100'
                : 'bg-white border-red-200 text-red-500 hover:bg-red-50'}"
            onclick={() => (deleteConfirming = !deleteConfirming)}
          >
            {deleteConfirming ? 'Cancel Delete' : 'Delete'}
          </button>
        </div>
      </div>
    {/if}

  </div>

</div>
