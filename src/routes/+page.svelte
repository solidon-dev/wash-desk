<script lang="ts">
  import Icon from '@iconify/svelte';
  import { goto } from '$app/navigation';

  // ── 타입 인라인 ──────────────────────────────────────────────────
  type ClientType = 'hotel' | 'pension' | 'resort' | 'etc';
  type LaundryCategory = 'towel' | 'sheet' | 'uniform' | 'all';
  type LaundryItemStatus = 'received' | 'washing' | 'completed' | 'stock' | 'shipped';
  type LaundryStatusCounts = Record<LaundryItemStatus, number>;
  interface LaundryItem { id: string; clientId: string; category: string; name: string; alias?: string; counts: LaundryStatusCounts; updatedAt: string; }
  interface Client { id: string; name: string; type: ClientType; address: string; phone?: string; businessNo?: string; ownerName?: string; managerName?: string; managerPhone?: string; memo?: string; createdAt: string; }
  interface Driver { id: string; name: string; phone: string; }
  interface ShipmentItem { laundryItemId: string; itemName: string; category: Exclude<LaundryCategory,'all'>; quantity: number; }
  interface Shipment { id: string; clientId: string; items: ShipmentItem[]; driverId: string; memo?: string; shippedAt: string; createdAt: string; }
  interface CompletedLogEntry { id: string; laundryItemId: string; clientId: string; itemName: string; category: Exclude<LaundryCategory,'all'>; actionType: 'add'|'set'; delta: number; before: number; after: number; createdAt: string; date: string; }

  // ── 상수 인라인 ──────────────────────────────────────────────────
  const CATEGORY_LABELS: Record<LaundryCategory, string> = { towel:'타올', sheet:'시트', uniform:'유니폼', all:'전체' };

  // ── 유틸 ─────────────────────────────────────────────────────────
  function genId() { return Math.random().toString(36).slice(2,10) + Date.now().toString(36); }
  function todayYMD() { const d=new Date(); const p=(n:number)=>String(n).padStart(2,'0'); return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}`; }
  function calcStock(c:number){return c;}
  function zeroCounts():LaundryStatusCounts{return{received:0,washing:0,completed:0,stock:0,shipped:0};}
  function randN(a:number,b:number){return Math.floor(Math.random()*(b-a+1))+a;}
  function randomCounts():LaundryStatusCounts{const c=randN(10,60);return{received:0,washing:0,completed:c,stock:c,shipped:randN(10,60)};}

  // ── 초기 데이터 ──────────────────────────────────────────────────
  const _clients: Client[] = [
    {id:'client-001',name:'그랜드호텔',type:'hotel',address:'서울특별시 강남구 테헤란로 123',phone:'02-1234-5678',businessNo:'123-45-67890',ownerName:'김대표',managerName:'박매니저',managerPhone:'010-1234-5678',memo:'VIP 거래처',createdAt:'2024-01-10T09:00:00.000Z'},
    {id:'client-002',name:'씨뷰펜션',type:'pension',address:'강원도 강릉시 해안로 456',phone:'033-456-7890',businessNo:'234-56-78901',ownerName:'이사장',managerName:'최담당',managerPhone:'010-2345-6789',memo:'주말 수거',createdAt:'2024-02-15T09:00:00.000Z'},
    {id:'client-003',name:'파크리조트',type:'resort',address:'경기도 가평군 청평면 789',phone:'031-789-0123',businessNo:'345-67-89012',ownerName:'정오너',managerName:'한실장',managerPhone:'010-3456-7890',memo:'월 2회 정기 수거',createdAt:'2024-03-01T09:00:00.000Z'},
    {id:'client-004',name:'스카이호텔',type:'hotel',address:'부산광역시 해운대구 마린시티로 321',phone:'051-321-6540',businessNo:'456-78-90123',ownerName:'조회장',managerName:'윤팀장',managerPhone:'010-4567-8901',memo:'이틀 전 예약 필수',createdAt:'2024-03-20T09:00:00.000Z'},
    {id:'client-005',name:'오션펜션',type:'pension',address:'제주특별자치도 서귀포시 중문관광로 654',phone:'064-654-9870',businessNo:'567-89-01234',ownerName:'강대표',managerName:'임담당',managerPhone:'010-5678-9012',createdAt:'2024-04-05T09:00:00.000Z'},
  ];
  const _towelNames=['대타올','중타올','소타올','목욕가운','슬리퍼타올','핸드타올','페이스타올','풀타올','짐타올','비치타올'];
  const _sheetNames=['시트S','시트D','시트Q','시트K','두베커버S','두베커버D','두베커버Q','두베커버K','베개커버','베개커버L','매트리스커버S','매트리스커버D','매트리스커버K'];
  const _uniformNames=['상의','하의','앞치마','조끼','모자','주방복상의','주방복하의','청소복','객실복','벨복','안전조끼'];
  const _catItems: Record<Exclude<LaundryCategory,'all'>,string[]> = {towel:_towelNames,sheet:_sheetNames,uniform:_uniformNames};
  function buildItems():LaundryItem[]{
    const items:LaundryItem[]=[]; const now=new Date().toISOString();
    for(const c of _clients){
      for(const [cat,names] of Object.entries(_catItems) as [Exclude<LaundryCategory,'all'>,string[]][])
        for(const name of names)
          items.push({id:`${c.id}__${name}`,clientId:c.id,category:cat,name,counts:randomCounts(),updatedAt:now});
    } return items;
  }

  // ── 공유 상태 ($state) ───────────────────────────────────────────
  let clients = $state<Client[]>(_clients);
  let laundryItems = $state<LaundryItem[]>(buildItems());
  let shipments = $state<Shipment[]>([]);
  let completedLogs = $state<CompletedLogEntry[]>([]);
  let selectedClientId = $state<string|null>(_clients[0]?.id ?? null);

  // ── 헬퍼 함수들 ──────────────────────────────────────────────────
  function getItemsByCategory(clientId:string, cat:LaundryCategory):LaundryItem[]{
    const items=laundryItems.filter(i=>i.clientId===clientId);
    return cat==='all' ? items : items.filter(i=>i.category===cat);
  }
  function getTotalCompleted(clientId:string):number{
    return laundryItems.filter(i=>i.clientId===clientId).reduce((s,i)=>s+i.counts.completed,0);
  }
  function selectClient(id:string|null){selectedClientId=id;}
  function addCompleted(clientId:string,itemId:string,delta:number){
    const item=laundryItems.find(i=>i.id===itemId&&i.clientId===clientId); if(!item)return;
    const before=item.counts.completed; const after=Math.max(0,before+delta); const actualDelta=after-before;
    laundryItems=laundryItems.map(i=>{if(i.id!==itemId||i.clientId!==clientId)return i;
      const c={...i.counts,completed:after}; c.stock=calcStock(c.completed); return{...i,counts:c,updatedAt:new Date().toISOString()};});
    completedLogs=[...completedLogs,{id:`log-${genId()}`,laundryItemId:itemId,clientId,itemName:item.name,category:item.category as Exclude<LaundryCategory,'all'>,actionType:'add',delta:actualDelta,before,after,createdAt:new Date().toISOString(),date:todayYMD()}];
  }
  function setCompleted(clientId:string,itemId:string,value:number){
    const item=laundryItems.find(i=>i.id===itemId&&i.clientId===clientId); if(!item)return;
    const before=item.counts.completed; const after=Math.max(0,value); const delta=after-before;
    laundryItems=laundryItems.map(i=>{if(i.id!==itemId||i.clientId!==clientId)return i;
      const c={...i.counts,completed:after}; c.stock=calcStock(c.completed); return{...i,counts:c,updatedAt:new Date().toISOString()};});
    completedLogs=[...completedLogs,{id:`log-${genId()}`,laundryItemId:itemId,clientId,itemName:item.name,category:item.category as Exclude<LaundryCategory,'all'>,actionType:'set',delta,before,after,createdAt:new Date().toISOString(),date:todayYMD()}];
  }
  function addLaundryItemType(clientId:string,cat:string,name:string){
    if(laundryItems.some(i=>i.clientId===clientId&&i.name===name&&i.category===cat))return;
    laundryItems=[...laundryItems,{id:`${clientId}__${name}`,clientId,category:cat,name,counts:zeroCounts(),updatedAt:new Date().toISOString()}];
  }
  function addLaundryItemTypeToAll(cat:string,name:string){
    const now=new Date().toISOString(); const added:LaundryItem[]=[];
    for(const c of clients){
      if(!laundryItems.some(i=>i.clientId===c.id&&i.name===name&&i.category===cat))
        added.push({id:`${c.id}__${name}`,clientId:c.id,category:cat,name,counts:zeroCounts(),updatedAt:now});
    } if(added.length>0)laundryItems=[...laundryItems,...added];
  }
  function getCompletedLogsByClient(clientId:string){return completedLogs.filter(l=>l.clientId===clientId);}

  // ── 타입 ─────────────────────────────────────────────────────────
  type CategoryKey = LaundryCategory;
  type EditMode = 'add' | 'set';

  // ── 상태 ─────────────────────────────────────────────────────────
  let activeCategory = $state<CategoryKey>('all');
  let selectedItemId = $state<string | null>(null);
  let editMode = $state<EditMode>('add');
  let inputValue = $state('');

  // 품목 추가 모달
  let showAddModal = $state(false);
  let modalCategory = $state<'towel' | 'sheet' | 'uniform'>('towel');
  let modalItemName = $state('');
  let modalScope = $state<'this' | 'all'>('this');

  // 기록 드로어
  let showLogDrawer = $state(false);
  let logTargetItem = $state<LaundryItem | null>(null);

  // ── 상수 ─────────────────────────────────────────────────────────
  const categories: { key: CategoryKey; label: string; icon: string }[] = [
    { key: 'all',     label: '전체',   icon: '📋' },
    { key: 'towel',   label: '타올',   icon: '🛁' },
    { key: 'sheet',   label: '시트',   icon: '🛏' },
    { key: 'uniform', label: '유니폼', icon: '👔' },
  ];

  const navItems = [
    { path: '/',        icon: 'heroicons:inbox-stack',            label: '세탁물' },
    { path: '/shipout', icon: 'heroicons:archive-box-arrow-down', label: '출고'   },
    { path: '/history', icon: 'heroicons:chart-bar',              label: '현황'   },
  ];

  const currentPath = '/';

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
    hotel: '호텔', pension: '펜션', resort: '리조트', etc: '기타',
  };

  // ── 파생값 ───────────────────────────────────────────────────────
  let filteredItems = $derived(
    selectedClientId
      ? getItemsByCategory(selectedClientId, activeCategory)
      : []
  );

  let selectedItem = $derived(
    selectedItemId
      ? (laundryItems.find((i) => i.id === selectedItemId) ?? null)
      : null
  );

  let currentCompleted = $derived(selectedItem?.counts.completed ?? 0);

  let inputNum = $derived(inputValue !== '' ? parseInt(inputValue, 10) : null);

  let previewResult = $derived(() => {
    if (inputNum === null || isNaN(inputNum)) return null;
    if (editMode === 'add') return currentCompleted + inputNum;
    return inputNum;
  });

  // 기록 드로어: 오늘 날짜 필터
  let todayStr = $derived(() => {
    const d = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  });

  let logEntries = $derived((): CompletedLogEntry[] => {
  if (!logTargetItem) return [];
  return getCompletedLogsByClient(logTargetItem.clientId)
    .filter((e) => e.laundryItemId === logTargetItem!.id && e.date === todayStr());
});

  // ── 조작 함수 ────────────────────────────────────────────────────
  function selectCategory(cat: CategoryKey) {
    activeCategory = cat;
    selectedItemId = null;
    inputValue = '';
  }

  function toggleItem(itemId: string) {
    if (selectedItemId === itemId) {
      selectedItemId = null;
      inputValue = '';
    } else {
      selectedItemId = itemId;
      inputValue = '';
    }
  }

  function setEditMode(mode: EditMode) {
    editMode = mode;
    inputValue = '';
  }

  function applyInput() {
    const num = inputNum;
    if (num === null || isNaN(num) || num < 0) return;
    if (!selectedClientId || !selectedItem) return;
    if (editMode === 'add') {
      addCompleted(selectedClientId, selectedItem.id, num);
    } else {
      setCompleted(selectedClientId, selectedItem.id, num);
    }
    inputValue = '';
  }

  function openLogDrawer(item: LaundryItem) {
    logTargetItem = item;
    showLogDrawer = true;
  }

  function closeLogDrawer() {
    showLogDrawer = false;
    logTargetItem = null;
  }

  function openAddModal() {
    modalCategory = 'towel';
    modalItemName = '';
    modalScope = 'this';
    showAddModal = true;
  }

  function closeAddModal() {
    showAddModal = false;
  }

  function submitAddItem() {
    const name = modalItemName.trim();
    if (!name) return;
    if (modalScope === 'this') {
      if (!selectedClientId) return;
      addLaundryItemType(selectedClientId, modalCategory, name);
    } else {
      addLaundryItemTypeToAll(modalCategory, name);
    }
    closeAddModal();
  }

  function navTo(path: string) { void goto(path); }

  function formatTime(isoStr: string): string {
    const d = new Date(isoStr);
    const h = String(d.getHours()).padStart(2, '0');
    const m = String(d.getMinutes()).padStart(2, '0');
    const s = String(d.getSeconds()).padStart(2, '0');
    return `${h}:${m}:${s}`;
  }
</script>

<svelte:head>
  <title>세탁물 관리</title>
</svelte:head>

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- 메인 레이아웃                                                   -->
<!-- ═══════════════════════════════════════════════════════════════ -->
<div class="flex h-screen bg-slate-50 overflow-hidden select-none">

  <!-- ① 아이콘 사이드바 -->
  <nav class="w-16 bg-sky-700 flex flex-col items-center py-3 gap-0.5 shrink-0 shadow-lg z-10">
    <!-- 로고 -->
    <div class="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center mb-3 shrink-0">
      <Icon icon="heroicons:archive-box" class="w-6 h-6 text-white" />
    </div>

    {#each navItems as nav (nav.label)}
      {@const isActive = nav.path === currentPath}
      <button
        type="button"
        class="w-12 h-14 rounded-xl flex flex-col items-center justify-center gap-0.5 transition-all duration-150
          {isActive
            ? 'bg-white/25 text-white shadow-inner'
            : 'text-sky-200 hover:bg-white/10 hover:text-white'}"
        onclick={() => navTo(nav.path)}
        aria-label={nav.label}
      >
        <Icon icon={nav.icon} class="w-5 h-5" />
        <span class="text-[9px] font-bold">{nav.label}</span>
      </button>
    {/each}
  </nav>

  <!-- ② 거래처 목록 패널 -->
  <aside class="w-60 bg-white border-r border-sky-100 flex flex-col shrink-0 overflow-hidden">
    <div class="px-3 py-3 border-b border-sky-100 shrink-0">
      <h2 class="text-base font-extrabold text-slate-700 tracking-wide">거래처</h2>
      <p class="text-[10px] text-slate-400 mt-0.5">{clients.length}개 등록됨</p>
    </div>

    <div class="flex-1 overflow-y-auto">
      {#each clients as client (client.id)}
        {@const isSel = selectedClientId === client.id}
        {@const completedCnt = getTotalCompleted(client.id)}
        <button
          type="button"
          class="w-full flex items-center gap-2.5 px-3 py-3 border-b border-slate-50 transition-all duration-150 text-left
            {isSel
              ? 'bg-sky-50 border-l-4 border-l-sky-500'
              : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
          onclick={() => { selectClient(client.id); selectedItemId = null; inputValue = ''; }}
        >
          <span class="text-2xl shrink-0">{clientTypeIcon[client.type] ?? '🏢'}</span>
          <div class="flex-1 min-w-0">
            <p class="text-base font-bold truncate {isSel ? 'text-sky-700' : 'text-slate-800'}">
              {client.name}
            </p>
            <div class="flex items-center gap-1 mt-0.5">
              <span class="text-[10px] px-1.5 py-0.5 rounded-full font-bold whitespace-nowrap {clientTypeBadge[client.type] ?? 'bg-slate-100 text-slate-600'}">
                {clientTypeLabel[client.type] ?? '기타'}
              </span>
            </div>
          </div>
          <div class="shrink-0 text-right">
            <p class="text-base font-extrabold {isSel ? 'text-sky-600' : 'text-slate-500'}">
              {completedCnt}
            </p>
            <p class="text-[9px] text-slate-400">완료</p>
          </div>
        </button>
      {/each}
    </div>
  </aside>

  <!-- ③ 카테고리 탭 패널 -->
  <div class="w-24 bg-sky-50 border-r border-sky-100 flex flex-col shrink-0 py-3 gap-1.5 px-2">
    <p class="text-[10px] font-bold text-sky-400 uppercase tracking-widest text-center mb-1">카테고리</p>
    {#each categories as cat (cat.key)}
      {@const isActive = activeCategory === cat.key}
      <button
        type="button"
        class="w-full rounded-2xl py-3 flex flex-col items-center gap-1 transition-all duration-150
          {isActive
            ? 'bg-sky-600 text-white shadow-md'
            : 'bg-white text-slate-600 hover:bg-sky-100 border border-sky-100'}"
        onclick={() => selectCategory(cat.key)}
      >
        <span class="text-3xl">{cat.icon}</span>
        <span class="text-sm font-bold">{cat.label}</span>
      </button>
    {/each}
  </div>

  <!-- ④ 품목 목록 (메인 영역) -->
  <div class="flex-1 flex flex-col overflow-hidden">
    <!-- 상단 헤더 -->
    <div class="bg-white border-b border-sky-100 px-5 py-3 shrink-0 flex items-center justify-between shadow-sm">
      <div class="flex items-center gap-3">
        {#if selectedClientId}
          <h1 class="text-xl font-extrabold text-slate-800">{clients.find(c=>c.id===selectedClientId)?.name}</h1>
          <span class="px-2.5 py-1 bg-sky-100 text-sky-700 rounded-full text-sm font-bold">
            {CATEGORY_LABELS[activeCategory]}
          </span>
          <span class="text-sm text-slate-400">
            {filteredItems.length}개 품목
          </span>
        {:else}
          <h1 class="text-xl font-extrabold text-slate-400">거래처를 선택하세요</h1>
        {/if}
      </div>
      {#if selectedItemId && selectedItem}
        <span class="px-3 py-1.5 bg-sky-100 text-sky-700 rounded-full text-sm font-bold">
          선택됨: {selectedItem.name}
        </span>
      {/if}
    </div>

    <!-- 컬럼 헤더 -->
    {#if selectedClientId && filteredItems.length > 0}
      <div class="bg-slate-100 border-b border-slate-200 px-4 shrink-0">
        <div class="flex items-center h-11">
          <div class="w-10 shrink-0"></div>
          <div class="flex-1 min-w-0 pl-2">
            <span class="text-xs font-bold text-slate-500 uppercase tracking-wide">품목명</span>
          </div>
          <div class="w-8 shrink-0"></div><!-- 기록보기 버튼 자리 -->
          <div class="w-32 text-center shrink-0">
            <span class="text-xs font-bold text-slate-500">세탁완료</span>
          </div>
        </div>
      </div>
    {/if}

    <!-- 품목 리스트 -->
    <div class="flex-1 overflow-y-auto">
      {#if !selectedClientId}
        <div class="flex flex-col items-center justify-center h-full text-slate-400 gap-4">
          <div class="w-20 h-20 rounded-3xl bg-slate-100 flex items-center justify-center">
            <Icon icon="heroicons:building-office-2" class="w-10 h-10 opacity-30" />
          </div>
          <p class="text-lg font-semibold">거래처를 선택하세요</p>
        </div>

      {:else if filteredItems.length === 0}
        <div class="flex flex-col items-center justify-center h-full text-slate-400 gap-3">
          <p class="text-base font-medium">해당 카테고리의 품목이 없습니다.</p>
          <button
            type="button"
            class="px-4 py-2 bg-sky-100 text-sky-700 rounded-xl font-bold text-sm hover:bg-sky-200 transition-colors flex items-center gap-1.5"
            onclick={openAddModal}
          >
            <Icon icon="heroicons:plus" class="w-4 h-4" />
            품목 추가
          </button>
        </div>

      {:else}
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemId === item.id}
          <div
            class="w-full flex items-center gap-0 border-b border-slate-100 transition-all duration-150
              {isSel
                ? 'bg-sky-50 border-l-4 border-l-sky-500'
                : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
          >
            <!-- 선택 가능한 메인 영역 (클릭 시 선택) -->
            <button
              type="button"
              class="flex items-center flex-1 min-w-0 px-4 py-3.5 text-left"
              onclick={() => toggleItem(item.id)}
            >
              <!-- 선택 인디케이터 -->
              <div class="w-10 shrink-0 flex items-center justify-center">
                <div class="w-6 h-6 rounded-full border-2 transition-all duration-150 flex items-center justify-center
                  {isSel ? 'bg-sky-500 border-sky-500' : 'border-slate-300'}">
                  {#if isSel}
                    <Icon icon="heroicons:check" class="w-3.5 h-3.5 text-white" />
                  {/if}
                </div>
              </div>

              <!-- 품목명 + 카테고리 배지 -->
              <div class="flex-1 min-w-0 pl-2 flex items-center gap-2">
                <span class="text-lg font-bold {isSel ? 'text-sky-700' : 'text-slate-800'} truncate">
                  {item.name}
                </span>
                <span class="text-[10px] px-2 py-0.5 rounded-full font-bold shrink-0
                  {item.category === 'towel'   ? 'bg-blue-100 text-blue-700'
                  : item.category === 'sheet'  ? 'bg-violet-100 text-violet-700'
                                                : 'bg-amber-100 text-amber-700'}">
                  {CATEGORY_LABELS[item.category as LaundryCategory]}
                </span>
              </div>
            </button>

            <!-- 기록보기 버튼 (별도 영역) -->
            <div class="w-10 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="w-7 h-7 rounded-lg flex items-center justify-center transition-colors
                  {isSel ? 'bg-sky-100 text-sky-600 hover:bg-sky-200' : 'bg-slate-100 text-slate-400 hover:bg-slate-200'}"
                title="기록보기"
                onclick={() => openLogDrawer(item)}
              >
                <Icon icon="heroicons:clock" class="w-3.5 h-3.5" />
              </button>
            </div>

            <!-- 세탁완료 수치 -->
            <div class="w-32 flex justify-center shrink-0 py-3.5">
              <span class="px-3 py-1.5 rounded-xl text-xl font-extrabold min-w-12 text-center
                {item.counts.completed > 0
                  ? 'bg-emerald-100 text-emerald-700'
                  : 'bg-slate-100 text-slate-400'}">
                {item.counts.completed}
              </span>
            </div>


          </div>
        {/each}

        <!-- 품목 추가 버튼 -->
        <button
          type="button"
          class="w-full flex items-center justify-center gap-2 py-4 text-sky-500 hover:bg-sky-50 transition-colors border-b border-slate-100"
          onclick={openAddModal}
        >
          <Icon icon="heroicons:plus" class="w-5 h-5" />
          <span class="text-sm font-bold">품목 추가</span>
        </button>
      {/if}
    </div>
  </div>

  <!-- ⑤ 오른쪽 패널 -->
  <aside class="w-80 bg-white border-l border-sky-100 flex flex-col shrink-0 overflow-hidden shadow-xl">
    <!-- 패널 헤더 -->
    <div class="px-5 py-4 border-b border-sky-100 bg-sky-700 shrink-0">
      <h2 class="text-lg font-extrabold text-white">수정 패널</h2>
      {#if selectedItem}
        <p class="text-xs text-sky-200 mt-0.5 truncate">
          {selectedItem.name}
          <span class="ml-1 opacity-75">({CATEGORY_LABELS[selectedItem.category as LaundryCategory]})</span>
        </p>
      {:else}
        <p class="text-xs text-sky-300 mt-0.5">품목을 선택하세요</p>
      {/if}
    </div>

    <div class="flex-1 overflow-y-auto flex flex-col">
      {#if selectedItem}

        <!-- 선택된 품목 표시 -->
        <div class="px-4 pt-3 pb-2 border-b border-slate-100 shrink-0">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">선택 품목</p>
          <div class="rounded-xl bg-sky-50 border border-sky-200 px-3 py-2 flex items-center justify-between">
            <div class="flex-1 min-w-0">
              <span class="text-sm font-bold text-slate-700 truncate block">{selectedItem.name}</span>
              <div class="flex items-center gap-2 mt-0.5">
                <span class="text-[10px] text-slate-400">세탁완료</span>
                <span class="text-sm font-extrabold text-emerald-600">{selectedItem.counts.completed}</span>
              </div>
            </div>
            <button
              type="button"
              class="w-6 h-6 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center shrink-0 ml-2"
              aria-label="선택 해제"
              onclick={() => { selectedItemId = null; inputValue = ''; }}
            >
              <Icon icon="heroicons:x-mark" class="w-3 h-3 text-slate-500" />
            </button>
          </div>
        </div>

        <!-- 편집 모드 탭 -->
        <div class="px-4 py-3 border-b border-slate-100 shrink-0">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">수정 모드</p>
          <div class="grid grid-cols-2 gap-2">
            <button
              type="button"
              class="py-2.5 rounded-xl font-bold text-sm border transition-all duration-150
                {editMode === 'add'
                  ? 'bg-emerald-500 text-white border-emerald-500 shadow-md'
                  : 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'}"
              onclick={() => setEditMode('add')}
            >
              수량 추가
            </button>
            <button
              type="button"
              class="py-2.5 rounded-xl font-bold text-sm border transition-all duration-150
                {editMode === 'set'
                  ? 'bg-sky-500 text-white border-sky-500 shadow-md'
                  : 'bg-sky-50 text-sky-700 border-sky-200 hover:bg-sky-100'}"
              onclick={() => setEditMode('set')}
            >
              수량 변경
            </button>
          </div>
        </div>

        <!-- 미리보기 -->
        <div class="px-4 pt-3 pb-1 shrink-0">
          <div class="h-16 rounded-xl bg-slate-50 border-2 {editMode === 'add' ? 'border-emerald-300' : 'border-sky-300'} flex items-center px-4">
            {#if inputNum !== null && !isNaN(inputNum)}
              {#if editMode === 'add'}
                <span class="text-xs font-bold text-emerald-500 mr-2 shrink-0">현재</span>
                <span class="text-lg font-extrabold text-slate-600">{currentCompleted}</span>
                <span class="text-sm text-slate-400 mx-2">+</span>
                <span class="text-lg font-extrabold text-emerald-600">{inputNum}</span>
                <span class="text-sm text-slate-400 mx-2">=</span>
                <span class="text-2xl font-extrabold text-emerald-700 ml-auto">{previewResult()}</span>
              {:else}
                <span class="text-xs font-bold text-sky-500 mr-2 shrink-0">현재</span>
                <span class="text-lg font-extrabold text-slate-600">{currentCompleted}</span>
                <span class="text-sm text-slate-400 mx-2">→</span>
                <span class="text-2xl font-extrabold text-sky-700 ml-auto">{inputNum}</span>
              {/if}
            {:else}
              <span class="text-[11px] font-bold text-slate-400 mr-2">입력</span>
              <span class="text-4xl font-extrabold text-slate-300 flex-1 text-right tracking-widest">
                {inputValue !== '' ? inputValue : '0'}
              </span>
              <span class="text-sm text-slate-300 ml-2">개</span>
            {/if}
          </div>
        </div>

        <!-- NumPad -->
        <div class="px-4 py-3 shrink-0">
          <!-- NumPad 인라인 -->
          <div class="grid grid-cols-3 gap-2 select-none">
            {#each (['7','8','9','4','5','6','1','2','3','0','back','clear'] as const) as key, i (i)}
              {#if key === 'clear'}
                <button type="button"
                  class="h-14 rounded-xl font-bold text-base transition-all duration-150 active:scale-95 bg-red-100 hover:bg-red-200 text-red-600 border border-red-200"
                  onclick={() => { inputValue = ''; }}
                >전체삭제</button>
              {:else if key === 'back'}
                <button type="button"
                  class="h-14 rounded-xl font-bold text-base transition-all duration-150 active:scale-95 bg-slate-100 hover:bg-slate-200 text-slate-600 border border-slate-200 flex items-center justify-center gap-1"
                  onclick={() => { inputValue = inputValue.slice(0, -1); }}
                >
                  <Icon icon="heroicons:backspace" class="w-5 h-5" />
                  지우기
                </button>
              {:else}
                <button type="button"
                  class="h-14 rounded-xl font-bold text-xl transition-all duration-150 active:scale-95 bg-white hover:bg-slate-50 text-slate-800 border border-slate-200 shadow-sm"
                  onclick={() => { if (inputValue.length < 6) inputValue = inputValue + key; }}
                >{key}</button>
              {/if}
            {/each}
          </div>
        </div>

        <!-- 적용 버튼 -->
        <div class="px-4 pb-3 shrink-0">
          <button
            type="button"
            class="w-full py-4 rounded-2xl font-extrabold text-base transition-all duration-150 shadow-md
              {editMode === 'add'
                ? 'bg-emerald-500 hover:bg-emerald-600 text-white active:scale-95'
                : 'bg-sky-500 hover:bg-sky-600 text-white active:scale-95'}
              {inputValue === '' ? 'opacity-50 cursor-not-allowed' : ''}"
            onclick={applyInput}
            disabled={inputValue === ''}
          >
            {editMode === 'add' ? '추가 적용' : '변경 적용'}
            {#if inputValue !== '' && inputNum !== null && !isNaN(inputNum)}
              <span class="text-xs font-normal opacity-80 ml-1">
                ({editMode === 'add' ? `+${inputNum} → ${previewResult()}` : `→ ${inputNum}`})
              </span>
            {/if}
          </button>
        </div>

      {:else}
        <!-- 선택 안 됨 빈 상태 -->
        <div class="flex flex-col items-center justify-center flex-1 text-slate-300 gap-3 px-6">
          <Icon icon="heroicons:cursor-arrow-rays" class="w-16 h-16 opacity-30" />
          <p class="text-sm font-semibold text-center">품목 목록에서<br/>항목을 선택하세요</p>
        </div>
      {/if}

      <!-- 하단 이동 버튼 -->
      <div class="px-4 py-3 border-t border-slate-100 space-y-2 mt-auto shrink-0">
        <button
          type="button"
          class="w-full py-3 rounded-xl font-bold text-sm bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors flex items-center justify-center gap-2"
          onclick={() => navTo('/shipout')}
        >
          <Icon icon="heroicons:archive-box-arrow-down" class="w-4 h-4" />
          출고 페이지로
        </button>
        <button
          type="button"
          class="w-full py-3 rounded-xl font-bold text-sm bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors flex items-center justify-center gap-2"
          onclick={() => navTo('/history')}
        >
          <Icon icon="heroicons:chart-bar" class="w-4 h-4" />
          현황 페이지로
        </button>
      </div>
    </div>
  </aside>
</div>


<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- 품목 추가 모달                                                  -->
<!-- ═══════════════════════════════════════════════════════════════ -->
{#if showAddModal}
  <!-- 오버레이 -->
  <div
    class="fixed inset-0 bg-black/50 z-40 flex items-center justify-center p-4"
    role="button"
    tabindex="-1"
    onclick={closeAddModal}
    onkeydown={(e) => e.key === 'Escape' && closeAddModal()}
    aria-label="모달 닫기"
  >
    <!-- 모달 패널 -->
    <div
      class="bg-white rounded-3xl shadow-2xl w-full max-w-md p-6 relative z-50"
      role="dialog"
      tabindex="-1"
      aria-modal="true"
      aria-label="품목 추가"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
    >
      <!-- 헤더 -->
      <div class="flex items-center justify-between mb-5">
        <h3 class="text-xl font-extrabold text-slate-800">품목 추가</h3>
        <button
          type="button"
          class="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center transition-colors"
          aria-label="모달 닫기"
          onclick={closeAddModal}
        >
          <Icon icon="heroicons:x-mark" class="w-4 h-4 text-slate-500" />
        </button>
      </div>

      <!-- 카테고리 선택 -->
      <div class="mb-4">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-2">카테고리</p>
        <div class="grid grid-cols-3 gap-2">
          {#each ([['towel', '🛁', '타올'], ['sheet', '🛏', '시트'], ['uniform', '👔', '유니폼']] as const) as [cat, icon, label] (cat)}
            <button
              type="button"
              class="py-3 rounded-xl font-bold text-sm border flex flex-col items-center gap-1 transition-all duration-150
                {modalCategory === cat
                  ? 'bg-sky-500 text-white border-sky-500 shadow-md'
                  : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-sky-50 hover:border-sky-300'}"
              onclick={() => { modalCategory = cat; }}
            >
              <span class="text-2xl">{icon}</span>
              <span>{label}</span>
            </button>
          {/each}
        </div>
      </div>

      <!-- 품목명 입력 -->
      <div class="mb-4">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-2">품목명</p>
        <input
          type="text"
          class="w-full px-4 py-3 rounded-xl border-2 border-slate-200 focus:border-sky-400 focus:outline-none text-base font-bold text-slate-800 placeholder-slate-300 transition-colors"
          placeholder="품목명을 입력하세요"
          bind:value={modalItemName}
          onkeydown={(e) => e.key === 'Enter' && submitAddItem()}
        />
      </div>

      <!-- 적용 범위 -->
      <div class="mb-6">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-2">적용 범위</p>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="py-3 rounded-xl font-bold text-sm border transition-all duration-150
              {modalScope === 'this'
                ? 'bg-sky-500 text-white border-sky-500 shadow-md'
                : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-sky-50 hover:border-sky-300'}"
            onclick={() => { modalScope = 'this'; }}
          >
            🏢 이 거래처만
          </button>
          <button
            type="button"
            class="py-3 rounded-xl font-bold text-sm border transition-all duration-150
              {modalScope === 'all'
                ? 'bg-emerald-500 text-white border-emerald-500 shadow-md'
                : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-emerald-50 hover:border-emerald-300'}"
            onclick={() => { modalScope = 'all'; }}
          >
            🌐 전체 거래처
          </button>
        </div>
        {#if modalScope === 'all'}
          <p class="text-[10px] text-amber-600 mt-1.5 font-bold">⚠ 모든 거래처에 해당 품목이 추가됩니다.</p>
        {/if}
      </div>

      <!-- 추가 버튼 -->
      <button
        type="button"
        class="w-full py-4 rounded-2xl font-extrabold text-base transition-all duration-150 active:scale-95
          {modalItemName.trim()
            ? 'bg-sky-600 hover:bg-sky-700 text-white shadow-md'
            : 'bg-slate-100 text-slate-400 cursor-not-allowed'}"
        onclick={submitAddItem}
        disabled={!modalItemName.trim()}
      >
        추가하기
      </button>
    </div>
  </div>
{/if}


<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- 기록 드로어 (우측 슬라이드인)                                   -->
<!-- ═══════════════════════════════════════════════════════════════ -->
{#if showLogDrawer}
  <!-- 오버레이 -->
  <div
    class="fixed inset-0 bg-black/40 z-40"
    role="button"
    tabindex="-1"
    onclick={closeLogDrawer}
    onkeydown={(e) => e.key === 'Escape' && closeLogDrawer()}
    aria-label="드로어 닫기"
  ></div>

  <!-- 드로어 패널 -->
  <div class="fixed top-0 right-0 h-full w-96 bg-white shadow-2xl z-50 flex flex-col animate-slide-in">
    <!-- 드로어 헤더 -->
    <div class="px-5 py-4 bg-sky-700 shrink-0 flex items-start justify-between">
      <div class="flex-1 min-w-0 mr-3">
        <h3 class="text-base font-extrabold text-white truncate">
          {logTargetItem?.name ?? ''} 세탁완료 수정 이력
        </h3>
        <p class="text-xs text-sky-200 mt-0.5">오늘 날짜 기준 · {todayStr()}</p>
      </div>
      <button
        type="button"
        class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center shrink-0 transition-colors"
        aria-label="드로어 닫기"
        onclick={closeLogDrawer}
      >
        <Icon icon="heroicons:x-mark" class="w-4 h-4 text-white" />
      </button>
    </div>

    <!-- 안내 텍스트 -->
    <div class="px-5 py-2.5 bg-amber-50 border-b border-amber-100 shrink-0">
      <p class="text-[10px] text-amber-700 font-bold">
        ℹ 출고 후 이력은 자동 삭제됩니다. 오늘의 수정 이력만 표시됩니다.
      </p>
    </div>

    <!-- 테이블 헤더 -->
    <div class="px-4 py-2.5 bg-slate-100 border-b border-slate-200 shrink-0">
      <div class="grid grid-cols-5 gap-1 text-[10px] font-bold text-slate-500 uppercase tracking-wide">
        <div class="col-span-2">시각</div>
        <div class="text-center">유형</div>
        <div class="text-center">이전값</div>
        <div class="text-center">결과값</div>
      </div>
    </div>

    <!-- 기록 목록 -->
    <div class="flex-1 overflow-y-auto">
      {#if logEntries().length === 0}
        <div class="flex flex-col items-center justify-center h-full text-slate-300 gap-3">
          <Icon icon="heroicons:clock" class="w-14 h-14 opacity-40 text-slate-300" />
          <p class="text-sm font-semibold">오늘의 이력이 없습니다.</p>
        </div>
      {:else}
        {#each logEntries() as entry (entry.id)}
          <div class="px-4 py-3 border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <div class="grid grid-cols-5 gap-1 items-center">
              <!-- 시각 -->
              <div class="col-span-2">
                <span class="text-xs font-bold text-slate-600">{formatTime(entry.createdAt)}</span>
              </div>
              <!-- 유형 -->
              <div class="text-center">
                <span class="text-[10px] px-1.5 py-0.5 rounded-full font-bold
                  {entry.actionType === 'add'
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-sky-100 text-sky-700'}">
                  {entry.actionType === 'add' ? '추가' : '변경'}
                </span>
              </div>
              <!-- 이전값 -->
              <div class="text-center">
                <span class="text-sm font-extrabold text-slate-500">{entry.before}</span>
              </div>
              <!-- 결과값 -->
              <div class="text-center">
                <span class="text-sm font-extrabold
                  {entry.actionType === 'add' ? 'text-emerald-600' : 'text-sky-600'}">
                  {entry.after}
                </span>
              </div>
            </div>
            <!-- 변경량 표시 -->
            {#if entry.actionType === 'add'}
              <p class="text-[10px] text-slate-400 mt-0.5 ml-0">
                {entry.before} + {entry.delta} = {entry.after}
              </p>
            {:else}
              <p class="text-[10px] text-slate-400 mt-0.5">
                {entry.before} → {entry.after}
                {#if entry.delta !== 0}
                  <span class="{entry.delta > 0 ? 'text-emerald-500' : 'text-red-500'}">
                    ({entry.delta > 0 ? '+' : ''}{entry.delta})
                  </span>
                {/if}
              </p>
            {/if}
          </div>
        {/each}
      {/if}
    </div>

    <!-- 드로어 푸터 -->
    <div class="px-4 py-3 border-t border-slate-100 shrink-0">
      <button
        type="button"
        class="w-full py-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-sm transition-colors"
        onclick={closeLogDrawer}
      >
        닫기
      </button>
    </div>
  </div>
{/if}

<style>
  @keyframes slide-in {
    from { transform: translateX(100%); opacity: 0; }
    to   { transform: translateX(0);    opacity: 1; }
  }
  .animate-slide-in {
    animation: slide-in 0.22s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
</style>
