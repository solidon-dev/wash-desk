<script lang="ts">
  import { goto } from '$app/navigation';
  import Icon from '@iconify/svelte';
  import DatePicker from '$lib/components/DatePicker.svelte';
  import { SvelteMap, SvelteSet } from 'svelte/reactivity';
  import {
    store, selectClient, getItemsByCategory,
    addShipment, applyShipout,
    CATEGORY_LABELS,
    type LaundryItem, type LaundryCategory, type Shipment, type Client,
  } from '$lib/store.svelte';

  // ── UI 상태 ──────────────────────────────────────────────────────
  let activeCategory = $state<CategoryKey>('all');
  let selectedItemIds = new SvelteSet<string>();
  let quantities = new SvelteMap<string, number>();
  let editingItemId = $state<string | null>(null);
  let numpadValue = $state('');
  let numpadClamped = $state(false);
  let showNumpadModal = $state(false);

  function toLocalDatetimeValue(d: Date): string {
    const p = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
  }
  let shippedAtLocal = $state(toLocalDatetimeValue(new Date()));
  let showShippedAtPicker = $state(false);

  type CategoryKey = LaundryCategory;

  const categories: { key: CategoryKey; label: string }[] = [
    { key: 'all',     label: '전체' },
    { key: 'towel',   label: '타올' },
    { key: 'sheet',   label: '시트' },
    { key: 'uniform', label: '유니폼' },
  ];

  let filteredItems = $derived(
    store.selectedClientId ? getItemsByCategory(store.selectedClientId, activeCategory) : []
  );
  let isAllSelected = $derived(
    filteredItems.length > 0 && (filteredItems as LaundryItem[]).filter((i: LaundryItem) => i.counts.completed > 0).length > 0 &&
    (filteredItems as LaundryItem[]).filter((i: LaundryItem) => i.counts.completed > 0).every((item: LaundryItem) => selectedItemIds.has(item.id))
  );
  let selectedEntries = $derived(
    [...selectedItemIds].flatMap((itemId: string) => {
      const item = (filteredItems as LaundryItem[]).find((i: LaundryItem) => i.id === itemId) ?? store.laundryItems.find((i: LaundryItem) => i.id === itemId);
      if (!item) return [];
      const qty = quantities.get(itemId) ?? item.counts.completed;
      return [{ itemId, itemName: item.name, category: item.category, quantity: qty }];
    })
  );
  let totalSelectedQty = $derived(selectedEntries.reduce((s, e) => s + e.quantity, 0));

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
    const available = (filteredItems as LaundryItem[]).filter((i: LaundryItem) => i.counts.completed > 0);
    if (isAllSelected) {
      selectedItemIds.clear();
      quantities.clear();
      editingItemId = null;
      numpadValue = '';
    } else {
      for (const item of available) {
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

  function adjustQty(itemId: string, delta: number) {
    const item = store.laundryItems.find((i: LaundryItem) => i.id === itemId); if (!item) return;
    const max = item.counts.completed; const cur = quantities.get(itemId) ?? item.counts.completed;
    const next = Math.max(0, Math.min(max, cur + delta));
    if (next === 0) { selectedItemIds.delete(itemId); quantities.delete(itemId); if (editingItemId === itemId) { editingItemId = null; numpadValue = ''; } }
    else quantities.set(itemId, next);
  }

  function openNumpad(itemId: string) {
    editingItemId = itemId;
    numpadValue = String(quantities.get(itemId) ?? 0);
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
    if (isNaN(n) || n < 0) { editingItemId = null; numpadValue = ''; numpadClamped = false; return; }
    const item = store.laundryItems.find((i: LaundryItem) => i.id === editingItemId);
    const clamped = Math.min(n, item?.counts.completed ?? 0);
    if (clamped === 0) { selectedItemIds.delete(editingItemId); quantities.delete(editingItemId); }
    else quantities.set(editingItemId, clamped);
    editingItemId = null; numpadValue = ''; numpadClamped = false; showNumpadModal = false;
  }

  let showMobilePanel = $state(false);

  // 슬립 모달
  let showSlipModal = $state(false);
  let pendingShipment = $state<{ clientId: string; items: { laundryItemId: string; itemName: string; category: Exclude<LaundryCategory, 'all'>; quantity: number }[]; shippedAt: string } | null>(null);

  function openSlipModal() {
    if (!store.selectedClientId || selectedEntries.length === 0) return;
    const shippedAt = new Date(shippedAtLocal).toISOString();
    pendingShipment = {
      clientId: store.selectedClientId,
      items: selectedEntries.map(e => ({ laundryItemId: e.itemId, itemName: e.itemName, category: e.category as Exclude<LaundryCategory, 'all'>, quantity: e.quantity })),
      shippedAt,
    };
    showSlipModal = true;
  }

  function executeShipout() {
    if (!pendingShipment) return;
    addShipment({ clientId: pendingShipment.clientId, items: pendingShipment.items, driverId: 'system', memo: undefined, shippedAt: pendingShipment.shippedAt });
    applyShipout(pendingShipment.clientId, pendingShipment.items.map(i => ({ itemId: i.laundryItemId, quantity: i.quantity })));
    showSlipModal = false;
    pendingShipment = null;
  }

  function p(n: number) { return String(n).padStart(2, '0'); }
  function formatDate(iso: string) { const d = new Date(iso); return `${d.getFullYear()}.${p(d.getMonth()+1)}.${p(d.getDate())}`; }
  function formatTime(iso: string) { const d = new Date(iso); return `${p(d.getHours())}:${p(d.getMinutes())}`; }
</script>

<svelte:head><title>출고 확인</title></svelte:head>

<div class="flex flex-1 min-h-0 min-w-0">

  <!-- ── 품목 선택 영역 ── -->
  <div class="flex-1 flex flex-col min-h-0">

    <!-- 카테고리 탭 -->
    <div class="h-20 bg-base-100 border-b border-base-300 px-2 shrink-0 flex items-center gap-1">
      {#each categories as cat (cat.key)}
        <button
          type="button"
          class="px-8 h-full text-xl font-black transition-colors rounded-none
            {activeCategory === cat.key
              ? 'bg-primary text-white'
              : 'text-base-content/50 hover:bg-base-200 hover:text-base-content'}"
          onclick={() => selectCategory(cat.key)}
        >{cat.label}</button>
      {/each}
    </div>

    <!-- 컬럼 헤더 -->
    {#if filteredItems.length > 0}
      <div class="h-16 bg-base-200 border-b border-base-300 px-6 shrink-0 flex items-center">
        <div class="flex-1 min-w-0">
          <span class="text-sm font-black text-base-content/40 uppercase tracking-wider">품목명</span>
        </div>
        <div class="w-36 text-center shrink-0">
          <span class="text-sm font-black text-base-content/40 uppercase tracking-wider">세탁완료</span>
        </div>
        <div class="w-52 text-center shrink-0">
          <span class="text-sm font-black text-base-content/40 uppercase tracking-wider">출고수량</span>
        </div>
        <div class="w-14 shrink-0 flex items-center justify-center">
          <button
            type="button"
            class="w-10 h-10 rounded-full border-2 transition-all duration-150 flex items-center justify-center
              {isAllSelected ? 'bg-primary border-primary' : 'border-base-content/30 hover:border-primary'}"
            onclick={toggleSelectAll}
            title={isAllSelected ? '전체 해제' : '전체 선택'}
          >
            {#if isAllSelected}
              <Icon icon="heroicons:check" class="w-6 h-6 text-primary-content" />
            {/if}
          </button>
        </div>
      </div>
    {/if}

    <!-- 품목 리스트 -->
    <div class="flex-1 overflow-y-auto min-h-0 flex flex-col">
      {#if filteredItems.length === 0}
        <div class="flex flex-col items-center justify-center flex-1 text-base-content/30 gap-3">
          <Icon icon="heroicons:inbox" class="w-12 h-12 opacity-30" />
          <p class="text-sm font-semibold text-base-content/40">품목이 없습니다</p>
          <p class="text-xs text-base-content/30">세탁물 탭에서 품목을 먼저 추가하세요</p>
        </div>
      {:else}
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemIds.has(item.id)}
          {@const qty = quantities.get(item.id) ?? item.counts.completed}
          {@const isEmpty = item.counts.completed === 0}
          <div
            role="button"
            tabindex={isEmpty ? -1 : 0}
            class="flex items-center min-h-28 px-6 py-4 border-b border-base-200 transition-colors border-l-2
              {isEmpty
                ? 'opacity-40 cursor-not-allowed border-l-transparent'
                : isSel
                  ? 'bg-primary/5 border-l-primary cursor-pointer'
                  : 'hover:bg-base-200/60 border-l-transparent cursor-pointer'}"
            onclick={() => !isEmpty && toggleItem(item.id, item.counts.completed)}
            onkeydown={(e) => !isEmpty && e.key === 'Enter' && toggleItem(item.id, item.counts.completed)}
          >
            <!-- 품목명 -->
            <div class="flex-1 min-w-0">
              <p class="text-2xl font-bold {isSel ? 'text-primary' : 'text-base-content'}">{item.name}</p>
            </div>

            <!-- 세탁완료 수량 -->
            <div class="w-36 text-center shrink-0">
              <span class="text-4xl font-black {item.counts.completed === 0 ? 'text-base-content/20' : 'text-success'}">{item.counts.completed}</span>
            </div>

            <!-- 출고수량 컨트롤 -->
            <div class="w-52 flex items-center justify-center gap-1.5 shrink-0">
              {#if isSel}
                <button
                  aria-label="수량 감소"
                  class="btn btn-md btn-square text-2xl"
                  onclick={(e) => { e.stopPropagation(); adjustQty(item.id, -1); }}
                >−</button>
                <button
                  aria-label="수량 직접 입력"
                  class="min-w-20 px-3 h-14 rounded-lg border-2 border-primary text-primary font-black text-3xl text-center transition-colors hover:bg-primary/5"
                  onclick={(e) => { e.stopPropagation(); openNumpad(item.id); }}
                >{qty}</button>
                <button
                  aria-label="수량 증가"
                  class="btn btn-md btn-square btn-primary text-2xl"
                  onclick={(e) => { e.stopPropagation(); adjustQty(item.id, 1); }}
                >+</button>
              {:else}
                <span class="text-xs text-base-content/20">—</span>
              {/if}
            </div>

            <!-- 체크 서클 -->
            <div class="w-14 shrink-0 flex justify-center">
              <div class="w-10 h-10 rounded-full border-2 transition-all duration-150 flex items-center justify-center
                {isEmpty ? 'border-base-content/10' : isSel ? 'bg-primary border-primary' : 'border-base-content/30'}">
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-6 h-6 text-primary-content" />
                {/if}
              </div>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>

  <!-- ── 출고 확인 패널 (데스크탑) ── -->
  <aside class="hidden md:flex flex-col w-2/5 bg-base-100 border-l border-base-200 shrink-0 min-h-0">

    <!-- 요약 or 빈 상태 -->
    <div class="flex-1 flex flex-col min-h-0">
      {#if selectedEntries.length === 0}
        <div class="flex flex-col items-center justify-center flex-1 gap-4 px-6">
          <div class="w-20 h-20 rounded-2xl bg-base-200 flex items-center justify-center">
            <Icon icon="heroicons:clipboard-document-check" class="w-10 h-10 text-base-content/20" />
          </div>
          <p class="text-xl font-black text-base-content/30">품목 미선택</p>
          <p class="text-base text-base-content/20 text-center">왼쪽 목록에서<br/>출고할 품목을 켜세요</p>
        </div>
      {:else}
        <!-- 요약 카드 -->
        <div class="px-6 py-6 border-b border-base-200 shrink-0">
          <div class="grid grid-cols-2 gap-3 h-28">
            <div class="rounded-2xl bg-base-200 flex flex-col items-center justify-center gap-1">
              <span class="text-sm font-bold text-base-content/40">품목 수</span>
              <span class="text-5xl font-black text-base-content">{selectedEntries.length}</span>
              <span class="text-sm font-bold text-base-content/30">종</span>
            </div>
            <div class="rounded-2xl bg-primary/5 border-2 border-primary/30 flex flex-col items-center justify-center gap-1">
              <span class="text-sm font-bold text-primary/60">총 수량</span>
              <span class="text-5xl font-black text-primary">{totalSelectedQty}</span>
              <span class="text-sm font-bold text-primary/40">개</span>
            </div>
          </div>
        </div>
      {/if}
      <div class="mt-auto shrink-0"></div>
    </div>

    <!-- 하단 액션 버튼 -->
    <div class="px-6 pt-4 pb-5 border-t border-base-200 space-y-3 shrink-0">
      <div class="pb-3 border-b border-base-200">
        <p class="text-sm font-black text-base-content/40 uppercase tracking-wider mb-2">출고 일시</p>
        <button
          type="button"
          class="h-14 px-4 w-full rounded-xl border border-base-300 bg-base-100 text-lg font-bold text-base-content hover:bg-base-200 transition-colors text-left"
          onclick={() => showShippedAtPicker = true}
        >{shippedAtLocal.replace('T', ' ')}</button>
      </div>
      <button
        class="btn btn-primary w-full h-20 text-xl font-black
          {selectedEntries.length === 0 ? 'btn-disabled opacity-40' : 'shadow-sm'}"
        disabled={selectedEntries.length === 0}
        onclick={openSlipModal}
      >
        {#if selectedEntries.length > 0}
          <Icon icon="heroicons:archive-box-arrow-down" class="w-6 h-6" />
          출고 확인 ({totalSelectedQty}개)
        {:else}
          출고 확인
        {/if}
      </button>
      <button
        class="btn btn-ghost w-full h-12 font-bold text-base text-base-content/40 border border-base-200"
        onclick={() => void goto('/')}
      >취소</button>
    </div>
  </aside>

</div>

<!-- 모바일: 하단 고정 바 -->
{#if selectedEntries.length > 0}
  <div class="fixed bottom-0 left-0 right-0 z-30 md:hidden bg-base-100 border-t border-base-300 px-4 py-3 flex items-center gap-3 shadow-lg">
    <div class="flex-1 min-w-0">
      <p class="text-sm font-bold text-base-content">{selectedEntries.length}개 품목 선택</p>
      <p class="text-xs text-base-content/50">총 {totalSelectedQty}개</p>
    </div>
    <button
      class="btn btn-primary font-bold px-6"
      onclick={() => showMobilePanel = true}
    >출고 확인 →</button>
  </div>
{/if}

<!-- 모바일 bottom sheet -->
{#if showMobilePanel}
  <div
    class="fixed inset-0 bg-black/40 z-40 md:hidden"
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
      <p class="text-sm font-bold text-base-content">출고 확인</p>
      <button class="btn btn-ghost btn-sm btn-circle" onclick={() => showMobilePanel = false}>
        <Icon icon="heroicons:x-mark" class="w-4 h-4" />
      </button>
    </div>
    <div class="overflow-y-auto flex flex-col flex-1">
      <!-- 선택 품목 목록 -->
      <div class="px-4 py-3 border-b border-base-200 shrink-0">
        <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">선택 품목</p>
        <div class="space-y-1.5">
          {#each selectedEntries as entry (entry.itemId)}
            <div class="flex items-center px-3 py-2 rounded-lg bg-base-200 gap-2">
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-base-content truncate">{entry.itemName}</p>
                <p class="text-xs text-base-content/50">{CATEGORY_LABELS[entry.category as LaundryCategory]}</p>
              </div>
              <span class="text-xl font-bold text-primary shrink-0">{entry.quantity}</span>
              <button class="btn btn-xs btn-circle btn-ghost hover:btn-error shrink-0" onclick={() => removeEntry(entry.itemId)}>
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
      <!-- 출고 일시 -->
      <div class="px-4 py-3 border-b border-base-200 shrink-0">
        <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">출고 일시</p>
        <button
          type="button"
          class="h-9 px-3 w-full rounded-lg border border-base-300 bg-base-100 text-sm font-bold text-base-content hover:bg-base-200 transition-colors text-left"
          onclick={() => showShippedAtPicker = true}
        >{shippedAtLocal.replace('T', ' ')}</button>
      </div>
    </div>
    <!-- 하단 버튼 -->
    <div class="px-4 py-4 border-t border-base-200 space-y-2 shrink-0">
      <button
        class="btn btn-primary w-full h-12 font-bold shadow-sm"
        onclick={() => { showMobilePanel = false; openSlipModal(); }}
      >
        <Icon icon="heroicons:archive-box-arrow-down" class="w-5 h-5" />
        출고 확인 ({totalSelectedQty}개)
      </button>
      <button class="btn btn-ghost w-full font-bold text-sm text-base-content/40 border border-base-200" onclick={() => showMobilePanel = false}>
        취소
      </button>
    </div>
  </div>
{/if}

{#if showNumpadModal && editingItemId !== null}
  {@const modalItem = store.laundryItems.find((i: LaundryItem) => i.id === editingItemId)}
  {@const maxQty = modalItem?.counts.completed ?? 0}
  {@const numpadNum = numpadValue !== '' ? parseInt(numpadValue, 10) : null}
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={closeNumpadModal}
    onkeydown={(e) => e.key === 'Escape' && closeNumpadModal()}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-2xl shadow-2xl w-[480px] overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <div class="px-6 py-5 bg-primary flex items-center justify-between">
        <div>
          <p class="text-2xl font-black text-primary-content">{modalItem?.name}</p>
          <p class="text-sm text-primary-content/60 mt-0.5">출고가능 {modalItem?.counts.completed ?? 0}개</p>
        </div>
        <button type="button" class="btn btn-ghost btn-md btn-circle text-primary-content/70" onclick={closeNumpadModal}>
          <Icon icon="heroicons:x-mark" class="w-6 h-6" />
        </button>
      </div>
      <div class="p-6 flex flex-col gap-4">
        <div class="grid grid-cols-2 gap-3 h-28">
          <div class="rounded-2xl bg-base-200 flex flex-col items-center justify-center gap-1">
            <span class="text-xs font-bold text-base-content/40 uppercase tracking-wider">출고가능</span>
            <span class="text-5xl font-black text-base-content">{maxQty}</span>
            <span class="text-sm font-bold text-base-content/30">개</span>
          </div>
          <div class="rounded-2xl border-2 border-primary/60 bg-primary/5 flex flex-col items-center justify-center gap-1 relative">
            <span class="text-xs font-bold text-base-content/30 uppercase tracking-wider">입력</span>
            <span class="text-5xl font-black tracking-widest {numpadValue ? 'text-primary' : 'text-base-content/20'}">{numpadValue || '—'}</span>
            {#if numpadClamped}
              <span class="text-xs font-bold text-warning">⚠️ 최대 {maxQty}개로 조정됨</span>
            {:else}
              <span class="text-sm font-bold text-base-content/20">개</span>
            {/if}
          </div>
        </div>

        <div class="grid grid-cols-3 gap-2 select-none">
          {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
            {#if key === 'clear'}
              <button type="button"
                class="h-20 rounded-xl font-black text-2xl btn btn-error btn-outline active:scale-95"
                onclick={() => { numpadValue = ''; numpadClamped = false; }}
              >C</button>
            {:else if key === 'back'}
              <button type="button"
                class="h-20 rounded-xl font-black btn btn-ghost bg-base-200 border border-base-300 flex items-center justify-center active:scale-95"
                onclick={() => { numpadValue = numpadValue.slice(0, -1); }}
              >
                <Icon icon="heroicons:backspace" class="w-10 h-10" />
              </button>
            {:else}
              <button type="button"
                class="h-20 rounded-xl font-black text-3xl btn btn-ghost bg-base-100 border border-base-300 shadow-sm text-base-content active:scale-95"
                onclick={() => { const v = (numpadValue + key).replace(/^0+(?=\d)/, ''); const n = parseInt(v, 10); if (!isNaN(n) && n > maxQty) { numpadValue = String(maxQty); numpadClamped = true; } else if (v.length <= 6) { numpadValue = v; numpadClamped = false; } }}
              >{key}</button>
            {/if}
          {/each}
        </div>
        <button type="button"
          class="btn btn-primary w-full h-16 text-2xl font-black {numpadValue === '' ? 'opacity-40' : ''}"
          disabled={numpadValue === ''}
          onclick={() => handleNumpadConfirm(numpadValue)}
        >수량 확인</button>
      </div>
    </div>
  </div>
{/if}

{#if showSlipModal && pendingShipment}
  {@const sc = store.clients.find(c => c.id === pendingShipment!.clientId)}
  {@const slipTotal = pendingShipment.items.reduce((a, i) => a + i.quantity, 0)}
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
      <div class="px-5 py-4 border-b border-base-200 flex items-center justify-between">
        <span class="text-sm font-bold text-base-content">출고 전표 확인</span>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" onclick={() => showSlipModal = false}>
          <Icon icon="heroicons:x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>

      <div class="px-6 py-5 space-y-4 flex-1 overflow-y-auto" id="slip-print-area">
        <div class="text-center border-b border-base-200 pb-4">
          <p class="text-lg font-black text-base-content">출고 전표</p>
          <p class="text-xs text-base-content/40 mt-1">{formatDate(pendingShipment.shippedAt)} {formatTime(pendingShipment.shippedAt)}</p>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-base-content/50">거래처</span>
          <span class="font-bold text-base-content">{sc?.name ?? '미확인'}</span>
        </div>
        <div class="border-t border-base-200 pt-3 space-y-2">
          {#each pendingShipment.items as item (item.laundryItemId)}
            <div class="flex justify-between text-sm">
              <span class="text-base-content">{item.itemName}</span>
              <span class="font-bold tabular-nums">{item.quantity}개</span>
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
        <button class="btn btn-primary flex-1 font-bold" onclick={executeShipout}>
          <Icon icon="heroicons:archive-box-arrow-down" class="w-4 h-4" />
          출고 확인
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
