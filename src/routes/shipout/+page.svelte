<script lang="ts">
  import { goto } from '$app/navigation';
  import Icon from '@iconify/svelte';
  import { SvelteMap, SvelteSet } from 'svelte/reactivity';

  // ── 타입 인라인 ──────────────────────────────────────────────────
  type ClientType = 'hotel' | 'pension' | 'resort' | 'etc';
  type LaundryCategory = 'towel' | 'sheet' | 'uniform' | 'all';
  type LaundryItemStatus = 'received' | 'washing' | 'completed' | 'stock' | 'shipped';
  type LaundryStatusCounts = Record<LaundryItemStatus, number>;
  interface LaundryItem { id: string; clientId: string; category: string; name: string; counts: LaundryStatusCounts; updatedAt: string; }
  interface Client { id: string; name: string; type: ClientType; address: string; phone?: string; createdAt: string; }
  interface ShipmentItem { laundryItemId: string; itemName: string; category: Exclude<LaundryCategory,'all'>; quantity: number; }
  interface Shipment { id: string; clientId: string; items: ShipmentItem[]; driverId: string; memo?: string; shippedAt: string; createdAt: string; }

  // ── 상수 인라인 ──────────────────────────────────────────────────
  const CATEGORY_LABELS: Record<LaundryCategory, string> = { towel:'타올', sheet:'시트', uniform:'유니폼', all:'전체' };

  // ── 유틸 ─────────────────────────────────────────────────────────
  function genId() { return Math.random().toString(36).slice(2,10) + Date.now().toString(36); }
  function calcStock(c:number){return c;}
  function zeroCounts():LaundryStatusCounts{return{received:0,washing:0,completed:0,stock:0,shipped:0};}
  function randN(a:number,b:number){return Math.floor(Math.random()*(b-a+1))+a;}
  function randomCounts():LaundryStatusCounts{const c=randN(10,60);return{received:0,washing:0,completed:c,stock:c,shipped:randN(10,60)};}

  // ── 초기 데이터 ──────────────────────────────────────────────────
  const _clients: Client[] = [
    {id:'client-001',name:'그랜드호텔',type:'hotel',address:'서울특별시 강남구 테헤란로 123',createdAt:'2024-01-10T09:00:00.000Z'},
    {id:'client-002',name:'씨뷰펜션',type:'pension',address:'강원도 강릉시 해안로 456',createdAt:'2024-02-15T09:00:00.000Z'},
    {id:'client-003',name:'파크리조트',type:'resort',address:'경기도 가평군 청평면 789',createdAt:'2024-03-01T09:00:00.000Z'},
    {id:'client-004',name:'스카이호텔',type:'hotel',address:'부산광역시 해운대구 마린시티로 321',createdAt:'2024-03-20T09:00:00.000Z'},
    {id:'client-005',name:'오션펜션',type:'pension',address:'제주특별자치도 서귀포시 중문관광로 654',createdAt:'2024-04-05T09:00:00.000Z'},
  ];
  const _towelNames=['대타올','중타올','소타올','목욕가운','슬리퍼타올','핸드타올','페이스타올','풀타올','짐타올','비치타올'];
  const _sheetNames=['시트S','시트D','시트Q','시트K','두베커버S','두베커버D','두베커버Q','두베커버K','베개커버','베개커버L','매트리스커버S','매트리스커버D','매트리스커버K'];
  const _uniformNames=['상의','하의','앞치마','조끼','모자','주방복상의','주방복하의','청소복','객실복','벨복','안전조끼'];
  const _catItems: Record<Exclude<LaundryCategory,'all'>,string[]> = {towel:_towelNames,sheet:_sheetNames,uniform:_uniformNames};
  function buildItems():LaundryItem[]{
    const items:LaundryItem[]=[]; const now=new Date().toISOString();
    for(const c of _clients)
      for(const [cat,names] of Object.entries(_catItems) as [Exclude<LaundryCategory,'all'>,string[]][])
        for(const name of names)
          items.push({id:`${c.id}__${name}`,clientId:c.id,category:cat,name,counts:randomCounts(),updatedAt:now});
    return items;
  }

  // ── 공유 상태 ($state) ───────────────────────────────────────────
  let clients = $state<Client[]>(_clients);
  let laundryItems = $state<LaundryItem[]>(buildItems());
  let shipments = $state<Shipment[]>([]);
  let selectedClientId = $state<string|null>(_clients[0]?.id ?? null);

  // ── 헬퍼 함수들 ──────────────────────────────────────────────────
  function selectClient(id:string|null){selectedClientId=id;}
  function getItemsByCategory(clientId:string,cat:LaundryCategory):LaundryItem[]{
    const items=laundryItems.filter(i=>i.clientId===clientId);
    return cat==='all'?items:items.filter(i=>i.category===cat);
  }
  function addShipment(s:Omit<Shipment,'id'|'createdAt'>):Shipment{
    const n:Shipment={...s,id:`ship-${genId()}`,createdAt:new Date().toISOString()};
    shipments=[n,...shipments]; return n;
  }
  function applyShipout(clientId:string,items:{itemId:string;quantity:number}[]){
    for(const{itemId,quantity}of items){
      laundryItems=laundryItems.map(item=>{
        if(item.id!==itemId||item.clientId!==clientId)return item;
        const nc=Math.max(0,item.counts.completed-quantity);
        const ns=item.counts.shipped+quantity;
        const c={...item.counts,completed:nc,shipped:ns}; c.stock=calcStock(c.completed);
        return{...item,counts:c,updatedAt:new Date().toISOString()};
      });
    }
  }

  // ?�?� ?�태 ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
  let activeCategory = $state<CategoryKey>('all');
  let selectedItemIds = new SvelteSet<string>();
  let quantities = new SvelteMap<string, number>();
  let editingItemId = $state<string | null>(null);
  let numpadValue = $state('');

  function toLocalDatetimeValue(d: Date): string {
    const p = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
  }
  let shippedAtLocal = $state(toLocalDatetimeValue(new Date()));

  type CategoryKey = LaundryCategory;

  const categories: { key: CategoryKey; label: string }[] = [
    { key: 'all',     label: 'All' },
    { key: 'towel',   label: 'Towel' },
    { key: 'sheet',   label: 'Sheet' },
    { key: 'uniform', label: 'Uniform' },
  ];

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

  const navItems = [
    { path: '/',        icon: 'heroicons:inbox-stack',            label: '세탁물' },
    { path: '/shipout', icon: 'heroicons:archive-box-arrow-down', label: '출고'   },
    { path: '/history', icon: 'heroicons:chart-bar',              label: '현황'   },
  ];
  const currentPath = '/shipout';

  let filteredItems = $derived(
    selectedClientId ? getItemsByCategory(selectedClientId, activeCategory) : []
  );
  let isAllSelected = $derived(
    filteredItems.length > 0 && filteredItems.every(item => selectedItemIds.has(item.id))
  );
  let selectedEntries = $derived(
    [...selectedItemIds].flatMap(itemId => {
      const item = filteredItems.find(i=>i.id===itemId) ?? laundryItems.find(i=>i.id===itemId);
      if(!item)return[];
      const qty=quantities.get(itemId)??item.counts.completed;
      return[{itemId,itemName:item.name,category:item.category,quantity:qty}];
    })
  );
  let totalSelectedQty = $derived(selectedEntries.reduce((s,e)=>s+e.quantity,0));

  function selectCategory(cat: CategoryKey) {
    activeCategory = cat;
    selectedItemIds.clear();
    quantities.clear();
    editingItemId = null;
    numpadValue = '';
  }

  function toggleItem(itemId: string, completed: number) {
    if (selectedItemIds.has(itemId)) {
      selectedItemIds.delete(itemId);
      quantities.delete(itemId);
      if (editingItemId === itemId) {
        editingItemId = null;
        numpadValue = '';
      }
    } else {
      selectedItemIds.add(itemId);
      quantities.set(itemId, completed);
    }
  }

  function toggleSelectAll() {
    if (isAllSelected) {
      selectedItemIds.clear();
      quantities.clear();
      editingItemId = null;
      numpadValue = '';
    } else {
      for (const item of filteredItems) {
        selectedItemIds.add(item.id);
        quantities.set(item.id, item.counts.completed);
      }
    }
  }

  function removeEntry(itemId: string) {
    selectedItemIds.delete(itemId);
    quantities.delete(itemId);
    if (editingItemId === itemId) {
      editingItemId = null;
      numpadValue = '';
    }
  }

  function adjustQty(itemId:string,delta:number){
    const item=laundryItems.find(i=>i.id===itemId); if(!item)return;
    const max=item.counts.completed; const cur=quantities.get(itemId)??item.counts.completed;
    const next=Math.max(0,Math.min(max,cur+delta));
    if(next===0){selectedItemIds.delete(itemId);quantities.delete(itemId);if(editingItemId===itemId){editingItemId=null;numpadValue='';}}
    else quantities.set(itemId,next);
  }

  function openNumpad(itemId: string) {
    editingItemId = itemId;
    numpadValue = String(quantities.get(itemId) ?? 0);
  }

  function handleNumpadConfirm(val:string){
    if(!editingItemId)return;
    const n=parseInt(val,10);
    if(isNaN(n)||n<0){editingItemId=null;numpadValue='';return;}
    const item=laundryItems.find(i=>i.id===editingItemId);
    const clamped=Math.min(n,item?.counts.completed??0);
    if(clamped===0){selectedItemIds.delete(editingItemId);quantities.delete(editingItemId);}
    else quantities.set(editingItemId,clamped);
    editingItemId=null;numpadValue='';
  }

  function confirmShipout(){
    if(!selectedClientId||selectedEntries.length===0)return;
    const shippedAt=new Date(shippedAtLocal).toISOString();
    const shipItems=selectedEntries.map(e=>({laundryItemId:e.itemId,itemName:e.itemName,category:e.category as Exclude<LaundryCategory,'all'>,quantity:e.quantity}));
    addShipment({clientId:selectedClientId,items:shipItems,driverId:'system',memo:undefined,shippedAt});
    applyShipout(selectedClientId,selectedEntries.map(e=>({itemId:e.itemId,quantity:e.quantity})));
  }
</script>

<svelte:head><title>Shipout</title></svelte:head>

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
        onclick={() => void goto(nav.path)}
      >
        <Icon icon={nav.icon} class="w-5 h-5" />
        <span class="text-[9px] font-bold">{nav.label}</span>
      </button>
    {/each}
  </nav>

  <!-- Client panel -->
  <aside class="w-60 bg-white border-r border-sky-100 flex flex-col shrink-0 overflow-hidden">
    <div class="px-3 py-3 border-b border-sky-100 shrink-0">
      <h2 class="text-base font-extrabold text-slate-700 tracking-wide">Clients</h2>
      <p class="text-[10px] text-slate-400 mt-0.5">{clients.length} clients</p>
    </div>
    <div class="flex-1 overflow-y-auto">
      {#each clients as client (client.id)}
        {@const isSel = selectedClientId === client.id}
        <button
          class="w-full flex items-center gap-2 px-3 py-4 min-h-[68px] transition-all duration-150 border-b border-slate-50
            {isSel ? 'bg-sky-50 border-l-4 border-l-sky-500' : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
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

  <!-- Item selection area -->
  <div class="flex-1 flex flex-col overflow-hidden">

    <!-- Header -->
    <div class="bg-white border-b border-sky-100 px-5 py-3 shrink-0 shadow-sm flex items-center justify-between">
      <div class="flex items-center gap-3">
        <h1 class="text-xl font-extrabold text-slate-800">Shipout</h1>
        {#if selectedClientId}
          <span class="px-2.5 py-1 bg-sky-100 text-sky-700 rounded-full text-sm font-bold">
            {clients.find(c=>c.id===selectedClientId)?.name}
          </span>
        {:else}
          <span class="text-sm text-slate-400">Select a client</span>
        {/if}
      </div>
      {#if totalSelectedQty > 0}
        <span class="px-3 py-1.5 bg-sky-500 text-white rounded-full text-sm font-extrabold">
          {selectedEntries.length} items selected
        </span>
      {/if}
    </div>

    <!-- 카테고리 ??+ ?�체 ?�택 버튼 -->
    <div class="bg-white border-b border-slate-200 px-4 flex items-center gap-1 shrink-0">
      {#each categories as cat (cat.key)}
        <button
          class="px-4 py-3 text-sm font-bold transition-all duration-150
            {activeCategory === cat.key
              ? 'border-b-2 border-sky-500 text-sky-600'
              : 'text-slate-400 hover:text-slate-600'}"
          onclick={() => selectCategory(cat.key)}
        >
          {cat.label}
        </button>
      {/each}
      <div class="ml-auto">
        {#if selectedClientId && filteredItems.length > 0}
          <button
            class="px-4 py-2 rounded-lg bg-sky-100 text-sky-700 text-sm font-bold
              hover:bg-sky-200 transition-all duration-150 active:scale-95"
            onclick={toggleSelectAll}
          >
            {isAllSelected ? 'Deselect All' : 'Select All'}
          </button>
        {/if}
      </div>
    </div>

    <!-- Table header -->
    {#if selectedClientId && filteredItems.length > 0}
      <div class="bg-slate-100 border-b border-slate-200 px-4 shrink-0">
        <div class="flex items-center h-12">
          <div class="w-10 shrink-0"></div>
          <div class="flex-1 min-w-0 pl-2">
            <span class="text-sm font-bold text-slate-500 uppercase tracking-wide">Item</span>
          </div>
          <div class="w-36 text-center shrink-0">
            <span class="text-sm font-bold text-slate-500">Laundry Done</span>
          </div>
          <div class="w-44 text-center shrink-0">
            <span class="text-sm font-bold text-slate-500">Ship Qty</span>
          </div>
        </div>
      </div>
    {/if}

    <!-- ?�목 목록 -->
    <div class="flex-1 overflow-y-auto">
      {#if !selectedClientId}
        <div class="flex flex-col items-center justify-center h-full text-slate-400 gap-4">
          <div class="w-20 h-20 rounded-3xl bg-slate-100 flex items-center justify-center">
            <Icon icon="heroicons:archive-box-arrow-down" class="w-10 h-10 opacity-30" />
          </div>
          <p class="text-lg font-semibold">Select a client</p>
        </div>
      {:else if filteredItems.length === 0}
        <div class="flex items-center justify-center h-full text-slate-400">
          <p class="text-base font-medium">No items in this category</p>
        </div>
      {:else}
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemIds.has(item.id)}
          {@const qty = quantities.get(item.id) ?? item.counts.completed}
          <div
            role="button"
            tabindex="0"
            class="flex items-center px-4 border-b border-slate-100 cursor-pointer transition-all duration-150
              {isSel ? 'bg-sky-50 border-l-4 border-l-sky-500' : 'hover:bg-slate-50 border-l-4 border-l-transparent'}"
            style="min-height:72px"
            onclick={() => toggleItem(item.id, item.counts.completed)}
            onkeydown={(e) => e.key === 'Enter' && toggleItem(item.id, item.counts.completed)}
          >
            <!-- 체크 ??-->
            <div class="w-10 shrink-0 flex items-center justify-center">
              <div class="w-6 h-6 rounded-full border-2 transition-all duration-150 flex items-center justify-center
                {isSel ? 'bg-sky-500 border-sky-500' : 'border-slate-300'}">
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-3.5 h-3.5 text-white" />
                {/if}
              </div>
            </div>

            <!-- ?�목�?-->
            <div class="flex-1 min-w-0 pl-2">
              <span class="text-lg font-bold {isSel ? 'text-sky-700' : 'text-slate-800'}">{item.name}</span>
              <p class="text-[10px] text-slate-400 mt-0.5">{CATEGORY_LABELS[item.category as LaundryCategory]}</p>
            </div>

            <!-- ?�탁?�료 ?�량 -->
            <div class="w-36 flex justify-center shrink-0">
              <span class="text-2xl font-extrabold text-emerald-600">{item.counts.completed}</span>
            </div>

            <!-- 출고?�량 컨트�?-->
            <div class="w-44 flex items-center justify-center gap-2 shrink-0">
              {#if isSel}
                <button
                  aria-label="Decrease qty"
                    class="w-12 h-12 rounded-xl bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold text-xl
                    flex items-center justify-center transition-all duration-150 active:scale-95"
                  onclick={(e) => { e.stopPropagation(); adjustQty(item.id, -1); }}
                >-</button>
                <button
                  aria-label="Enter qty directly"
                    class="min-w-12 px-2 h-12 rounded-xl bg-white border-2 border-sky-300 text-sky-700
                    font-black text-2xl text-center transition-all duration-150 hover:bg-sky-50"
                  onclick={(e) => { e.stopPropagation(); openNumpad(item.id); }}
                >{qty}</button>
                <button
                  aria-label="Increase qty"
                    class="w-12 h-12 rounded-xl bg-sky-500 hover:bg-sky-600 text-white font-bold text-xl
                    flex items-center justify-center transition-all duration-150 active:scale-95"
                  onclick={(e) => { e.stopPropagation(); adjustQty(item.id, 1); }}
                >+</button>
              {:else}
                <span class="text-sm text-slate-300">-</span>
              {/if}
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>

  <!-- Shipout confirmation panel -->
  <aside class="w-96 bg-white border-l border-sky-100 flex flex-col shrink-0 overflow-hidden shadow-xl">

    <!-- Panel header -->
    <div class="px-5 py-5 bg-sky-700 shrink-0">
      <h2 class="text-lg font-black text-white">Shipout</h2>
      <p class="text-xs text-sky-200 mt-0.5">
        {#if selectedEntries.length > 0}
          {selectedEntries.length} items selected
        {:else}
          Select items
        {/if}
      </p>
    </div>

    <div class="flex-1 overflow-y-auto flex flex-col">

      <!-- Selected Items list -->
      {#if selectedEntries.length > 0}
        <div class="px-4 pt-4 pb-3 border-b border-slate-100 shrink-0">
          <p class="text[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Selected Items</p>
          <div class="space-y-1.5">
            {#each selectedEntries as entry (entry.itemId)}
              <div class="flex items-center justify-between px-3 py-3 rounded-xl bg-sky-50 border border-sky-100">
                <div class="flex-1 min-w-0">
                  <p class="text-base font-bold text-slate-700 truncate">{entry.itemName}</p>
                  <p class="text-[10px] text-slate-400">{CATEGORY_LABELS[entry.category as LaundryCategory]}</p>
                </div>
                <span class="text-xl font-extrabold text-sky-700 mx-3">{entry.quantity}</span>
                <button
                  aria-label="Remove item"
                  class="w-6 h-6 rounded-full bg-slate-200 hover:bg-red-100 flex items-center justify-center transition-all duration-150"
                  onclick={() => removeEntry(entry.itemId)}
                >
                  <Icon icon="heroicons:x-mark" class="w-3 h-3 text-slate-500" />
                </button>
              </div>
            {/each}
          </div>
          <div class="flex items-center justify-between mt-3 px-3 py-2 bg-sky-100 rounded-xl">
            <span class="text-xs font-bold text-sky-600">Total Qty</span>
            <span class="text-2xl font-extrabold text-sky-700">{totalSelectedQty}<span class="text-sm font-bold ml-1">items</span></span>
          </div>
        </div>
      {/if}

      <!-- Shipment Date -->
      <div class="px-4 py-4 border-b border-slate-100 shrink-0">
        <p class="text-sm font-bold text-slate-400 uppercase tracking-widest mb-2">Shipment Date</p>
        <input
          type="datetime-local"
          bind:value={shippedAtLocal}
          class="w-full h-11 px-3 rounded-xl border-2 border-slate-200 text-base font-bold text-slate-700
            focus:outline-none focus:border-sky-400 transition-all"
        />
      </div>

      <!-- Numpad area -->
      {#if editingItemId !== null}
        {@const editItem = laundryItems.find((i) => i.id === editingItemId)}
        <div class="px-4 py-3 border-b border-slate-100 shrink-0">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              Enter Qty — <span class="text-sky-600">{editItem?.name}</span>
            </p>
            <span class="text[10px] text-slate-400">max {editItem?.counts.completed ?? 0}</span>
          </div>
          <div class="h-14 rounded-xl bg-slate-50 border-2 border-sky-300 flex items-center px-4 mb-3">
            <span class="text-4xl font-extrabold text-slate-800 flex-1 text-right tracking-widest">
              {numpadValue === '' ? '0' : numpadValue}
            </span>
            <span class="text-sm text-slate-400 ml-2">ea</span>
          </div>
          <!-- NumPad inline -->
          <div class="grid grid-cols-3 gap-2 select-none">
            {#each (['7','8','9','4','5','6','1','2','3','0','back','clear'] as const) as key, i (i)}
              {#if key === 'clear'}
                <button type="button"
                  class="h-14 rounded-xl font-bold text-base transition-all duration-150 active:scale-95 bg-red-100 hover:bg-red-200 text-red-600 border border-red-200"
                  onclick={() => { numpadValue = ''; }}
                >Clear All</button>
              {:else if key === 'back'}
                <button type="button"
                  class="h-14 rounded-xl font-bold text-base transition-all duration-150 active:scale-95 bg-slate-100 hover:bg-slate-200 text-slate-600 border border-slate-200 flex items-center justify-center gap-1"
                  onclick={() => { numpadValue = numpadValue.slice(0, -1); }}
                >
                  <Icon icon="heroicons:backspace" class="w-5 h-5" />
                  지우기
                </button>
              {:else}
                <button type="button"
                  class="h-14 rounded-xl font-bold text-xl transition-all duration-150 active:scale-95 bg-white hover:bg-slate-50 text-slate-800 border border-slate-200 shadow-sm"
                  onclick={() => { if (numpadValue.length < 6) numpadValue = numpadValue + key; }}
                >{key}</button>
              {/if}
            {/each}
            <button type="button"
              class="col-span-3 h-14 rounded-xl font-bold text-base transition-all duration-150 active:scale-95 mt-1 bg-sky-500 hover:bg-sky-600 text-white shadow-md"
              onclick={() => handleNumpadConfirm(numpadValue)}
            >Confirm</button>
          </div>
        </div>
      {/if}

      <div class="mt-auto shrink-0"></div>
    </div>

    <!-- Button area -->
    <div class="px-4 py-4 border-t border-slate-100 space-y-2 shrink-0">
      <button
        class="w-full h-16 rounded-xl font-bold text-base transition-all duration-150 active:scale-[0.98]
          {selectedEntries.length > 0
            ? 'bg-sky-500 hover:bg-sky-600 text-white shadow-md shadow-sky-200'
            : 'bg-slate-100 text-slate-400 cursor-not-allowed'}"
        disabled={selectedEntries.length === 0}
        onclick={() => { confirmShipout(); void goto('/history'); }}
      >
        {#if selectedEntries.length > 0}
          Confirm Shipout ({totalSelectedQty} items)
        {:else}
          Confirm Shipout
        {/if}
      </button>
      <button
        class="w-full h-14 rounded-xl font-bold text-sm text-slate-500 hover:bg-slate-100
          transition-all duration-150 border border-slate-200"
        onclick={() => void goto('/')}
      >
        Cancel
      </button>
    </div>
  </aside>

</div>
