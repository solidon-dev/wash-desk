<script lang="ts">
  import Icon from '@iconify/svelte';
  import {
    store, selectClient, getItemsByCategory, getTotalCompleted,
    addCompleted, setCompleted, addLaundryItemType, addLaundryItemTypeToAll,
    CATEGORY_LABELS, genId, todayYMD,
    type LaundryItem, type LaundryCategory, type CompletedLogEntry,
  } from '$lib/store.svelte';

  // ── 타입 ─────────────────────────────────────────────────────────
  type CategoryKey = LaundryCategory;
  // ── 상태 ─────────────────────────────────────────────────────────
  let activeCategory = $state<CategoryKey>('all');
  let selectedItemId = $state<string | null>(null);
  let inputValue = $state('');

  // 품목 추가 모달
  let showAddModal = $state(false);
  let modalCategory = $state<'towel' | 'sheet' | 'uniform'>('towel');
  let modalScope = $state<'this' | 'all'>('this');

  // 카테고리별 세부 품목 목록
  const ITEM_NAMES: Record<'towel' | 'sheet' | 'uniform', string[]> = {
    towel:   ['대타올','중타올','소타올','목욕가운','핸드타올','페이스타올','풀타올','짐타올','비치타올','슬리퍼타올','발매트','헤어타올','키즈타올','스포츠타올','냉감타올'],
    sheet:   ['시트S','시트D','시트Q','시트K','두베커버S','두베커버D','두베커버Q','두베커버K','베개커버','베개커버L','매트리스커버S','매트리스커버D','매트리스커버K','패드커버S','패드커버D'],
    uniform: ['상의','하의','앞치마','조끼','모자','주방복상의','주방복하의','청소복','객실복','벨복','안전조끼','방수복상의','방수복하의','반팔상의','반팔하의'],
  };

  // 선택된 세부 품목명 (없으면 자동생성)
  let modalSelectedName = $state<string | null>(null);

  // 자동생성 품목명: 카테고리 한글 + genId 앞 4자리
  function generateItemName(cat: 'towel' | 'sheet' | 'uniform'): string {
    const prefix = { towel: '타올', sheet: '시트', uniform: '유니폼' }[cat];
    return `${prefix}-${genId().slice(0, 4).toUpperCase()}`;
  }

  // 최종 품목명: 선택했으면 선택값, 아니면 자동생성
  let resolvedItemName = $derived(
    modalSelectedName ?? generateItemName(modalCategory)
  );

  // 기록 드로어
  let showLogDrawer = $state(false);
  let logTargetItem = $state<LaundryItem | null>(null);

  // ── 상수 ─────────────────────────────────────────────────────────
  const categories: { key: CategoryKey; label: string }[] = [
    { key: 'all',     label: '전체' },
    { key: 'towel',   label: '타올' },
    { key: 'sheet',   label: '시트' },
    { key: 'uniform', label: '유니폼' },
  ];

  // ── 파생값 ───────────────────────────────────────────────────────
  let filteredItems = $derived(
    store.selectedClientId
      ? getItemsByCategory(store.selectedClientId, activeCategory)
      : []
  );

  let selectedItem = $derived(
    selectedItemId
      ? (store.laundryItems.find((i: LaundryItem) => i.id === selectedItemId) ?? null)
      : null
  );

  let currentCompleted = $derived(selectedItem?.counts.completed ?? 0);

  let inputNum = $derived(inputValue !== '' ? parseInt(inputValue, 10) : null);

  let previewResult = $derived(() => {
    if (inputNum === null || isNaN(inputNum)) return null;
    return currentCompleted + inputNum;
  });

  // 기록 드로어: 오늘 날짜 필터
  let todayStr = $derived(() => {
    const d = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  });

  // 기록 드로어: 전체 기록 최신순, 무한스크롤
  const LOG_PAGE_SIZE = 20;
  let logVisibleCount = $state(LOG_PAGE_SIZE);

  let allLogEntries = $derived((): CompletedLogEntry[] => {
    if (!logTargetItem) return [];
    return store.completedLogs
      .filter((e: CompletedLogEntry) => e.laundryItemId === logTargetItem!.id)
      .sort((a: CompletedLogEntry, b: CompletedLogEntry) => b.createdAt.localeCompare(a.createdAt));
  });

  let logEntries = $derived((): CompletedLogEntry[] => {
    return allLogEntries().slice(0, logVisibleCount);
  });

  let hasMoreLogs = $derived(logVisibleCount < allLogEntries().length);

  function loadMoreLogs() {
    logVisibleCount += LOG_PAGE_SIZE;
  }

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

  function applyInput() {
    const num = inputNum;
    if (num === null || isNaN(num) || num < 0) return;
    if (!store.selectedClientId || !selectedItem) return;
    addCompleted(store.selectedClientId, selectedItem.id, num);
    inputValue = '';
  }

  function openLogDrawer(item: LaundryItem) {
    logTargetItem = item;
    logVisibleCount = LOG_PAGE_SIZE;
    showLogDrawer = true;
  }

  function closeLogDrawer() {
    showLogDrawer = false;
    logTargetItem = null;
  }

  function openAddModal() {
    modalCategory = 'towel';
    modalSelectedName = null;
    modalScope = 'this';
    showAddModal = true;
  }

  function closeAddModal() {
    showAddModal = false;
  }

  function submitAddItem() {
    const name = resolvedItemName.trim();
    if (!name) return;
    if (modalScope === 'this') {
      if (!store.selectedClientId) return;
      addLaundryItemType(store.selectedClientId, modalCategory, name);
    } else {
      addLaundryItemTypeToAll(modalCategory, name);
    }
    closeAddModal();
  }

  function formatTime(isoStr: string): string {
    const d = new Date(isoStr);
    const h = String(d.getHours()).padStart(2, '0');
    const m = String(d.getMinutes()).padStart(2, '0');
    const s = String(d.getSeconds()).padStart(2, '0');
    return `${h}:${m}:${s}`;
  }
</script>

<!-- ══════════════════════════════════════════════════════════════════
     메인 레이아웃
═══════════════════════════════════════════════════════════════════ -->
<div class="flex flex-1 min-h-0 min-w-0">

  <!-- ── 왼쪽: 품목 리스트 ─────────────────────────────────────── -->
  <div class="flex-1 flex flex-col min-h-0 min-w-0 bg-base-100">

    <!-- 카테고리 탭 바 -->
    <div class="h-20 bg-base-100 border-b border-base-300 px-2 shrink-0 flex items-center gap-1">
      {#each categories as cat (cat.key)}
        {@const isActive = activeCategory === cat.key}
        <button
          type="button"
          class="px-8 h-full text-xl font-black transition-colors rounded-none
            {isActive
              ? 'bg-primary text-white'
              : 'text-base-content/50 hover:bg-base-200 hover:text-base-content'}"
          onclick={() => selectCategory(cat.key)}
        >{cat.label}</button>
      {/each}
    </div>

    <!-- 컬럼 헤더 -->
    <!-- 품목 추가 버튼 -->
    {#if store.selectedClientId}
      <button
        type="button"
        class="w-full h-18 flex items-center justify-center gap-3 px-4 bg-primary/5 hover:bg-primary/10 text-primary transition-colors border-b border-primary/10 shrink-0 py-5"
        onclick={openAddModal}
      >
        <Icon icon="heroicons:plus-circle" class="w-7 h-7" />
        <span class="text-xl font-black">품목 추가</span>
      </button>
    {/if}

    {#if filteredItems.length > 0}
      <div class="h-16 bg-base-200 border-b border-base-300 px-6 shrink-0 flex items-center">
        <div class="flex-1 min-w-0">
          <span class="text-sm font-black text-base-content/40 uppercase tracking-wider">품목명</span>
        </div>
        <div class="w-10 shrink-0"></div>
        <div class="w-36 text-center shrink-0">
          <span class="text-sm font-black text-base-content/40 uppercase tracking-wider">세탁완료</span>
        </div>
        <div class="w-14 shrink-0"></div>
      </div>
    {/if}

    <!-- 품목 리스트 -->
    <div class="flex-1 overflow-y-auto min-h-0 flex flex-col">
      {#if filteredItems.length === 0}
        <!-- 빈 상태 -->
        <div class="flex flex-col items-center justify-center flex-1 text-base-content/30 gap-3">
          <Icon icon="heroicons:inbox" class="w-12 h-12 opacity-30" />
          <p class="text-sm font-semibold text-base-content/40">
            {store.selectedClientId ? '등록된 품목이 없습니다' : '거래처를 선택해 주세요'}
          </p>
          <p class="text-xs text-base-content/30">
            {store.selectedClientId ? '품목 추가 버튼을 눌러 시작하세요' : '상단 거래처 버튼을 눌러 선택하세요'}
          </p>
          {#if store.selectedClientId}
            <button
              type="button"
              class="btn btn-sm btn-ghost border border-base-300"
              onclick={openAddModal}
            >
              <Icon icon="heroicons:plus" class="w-4 h-4" />
              품목 추가
            </button>
          {/if}
        </div>
      {:else}
        <!-- 품목 행 목록 -->
        {#each filteredItems as item (item.id)}
          {@const isSel = selectedItemId === item.id}
          {@const completed = item.counts.completed}
          <div
            class="flex items-center min-h-28 px-6 py-4 border-b border-base-200 transition-colors border-l-2
              {isSel ? 'bg-primary/5 border-l-primary' : 'border-l-transparent hover:bg-base-200/60'}"
          >
            <!-- 품목명 클릭 영역 -->
            <button
              type="button"
              class="flex-1 py-2 text-left min-w-0 h-full"
              onclick={() => toggleItem(item.id)}
            >
              <span class="text-2xl font-bold truncate block
                {isSel ? 'text-primary' : 'text-base-content'}">
                {item.name}
              </span>
            </button>

            <!-- 기록(시계) 버튼 -->
            <div class="w-14 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="btn btn-ghost w-12 h-12 btn-md p-0 rounded-lg text-base-content/30 hover:text-base-content/70"
                onclick={(e) => { e.stopPropagation(); openLogDrawer(item); }}
                title="기록 보기"
              >
                <Icon icon="heroicons:clock" class="w-6 h-6" />
              </button>
            </div>

            <!-- 세탁완료 수 -->
            <div class="w-36 flex justify-center items-center shrink-0">
              <span class="text-4xl font-black
                {completed === 0 ? 'text-base-content/20' : 'text-success'}">
                {completed}
              </span>
            </div>

            <!-- 체크 인디케이터 -->
            <div class="w-14 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="w-10 h-10 rounded-full border-2 transition-all duration-150 flex items-center justify-center
                  {isSel
                    ? 'bg-primary border-primary'
                    : 'border-base-300 bg-base-100 hover:border-primary'}"
                onclick={() => toggleItem(item.id)}
              >
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-6 h-6 text-primary-content" />
                {/if}
              </button>
            </div>
          </div>
        {/each}

      {/if}
    </div>
  </div>

  <!-- ── 오른쪽 패널 (데스크탑) ─────────────────────────────────── -->
  <aside class="hidden md:flex w-2/5 bg-base-100 border-l border-base-300 flex-col shrink-0 min-h-0">

    <div class="flex-1 overflow-y-auto flex flex-col min-h-0">
      {#if selectedItem}
        <div class="flex flex-col justify-center flex-1 gap-4 px-6 py-6">

          <!-- 현재 수량 + 입력 미리보기 2쫬럼 -->
          <div class="grid grid-cols-2 gap-3 h-28">
            <!-- 왼쪽: 현재 수량 -->
            <div class="rounded-2xl bg-base-200 flex flex-col items-center justify-center gap-1">
              <span class="text-xs font-bold text-base-content/40 uppercase tracking-wider">현재 수량</span>
              <span class="text-5xl font-black text-base-content">{currentCompleted}</span>
              <span class="text-sm font-bold text-base-content/30">개</span>
            </div>
            <!-- 오른쪽: 입력값 표시 -->
            <div class="rounded-2xl border-2 border-success/60 bg-success/5 flex flex-col items-center justify-center gap-1">
              <span class="text-xs font-bold text-base-content/30 uppercase tracking-wider">입력</span>
              <span class="text-5xl font-black {inputValue ? 'text-success' : 'text-base-content/20'} tracking-widest">{inputValue || '—'}</span>
              <span class="text-sm font-bold text-base-content/20">개</span>
            </div>
          </div>

          <!-- 숫자패드 -->
          <div class="grid grid-cols-3 gap-2 select-none">
            {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
              {#if key === 'clear'}
                <button
                  type="button"
                  class="h-24 rounded-xl font-black text-2xl btn btn-error btn-outline active:scale-95"
                  onclick={() => { inputValue = ''; }}
                >C</button>
              {:else if key === 'back'}
                <button
                  type="button"
                  class="h-24 rounded-xl font-black btn btn-ghost bg-base-200 border border-base-300 flex items-center justify-center active:scale-95"
                  onclick={() => { inputValue = inputValue.slice(0, -1); }}
                >
                  <Icon icon="heroicons:backspace" class="w-8 h-8" />
                </button>
              {:else}
                <button
                  type="button"
                  class="h-24 rounded-xl font-black text-3xl btn btn-ghost bg-base-100 border border-base-300 shadow-sm text-base-content active:scale-95"
                  onclick={() => { const v = (inputValue + key).replace(/^0+(?=\d)/, ''); if (v.length <= 6) inputValue = v; }}
                >{key}</button>
              {/if}
            {/each}
          </div>

          <!-- 적용 버튼 -->
          <button
            type="button"
            class="btn btn-success w-full h-20 text-2xl font-black
              {(inputNum === null || isNaN(inputNum ?? NaN)) ? 'opacity-40' : ''}"
            disabled={inputNum === null || isNaN(inputNum ?? NaN)}
            onclick={applyInput}
          >
            +추가 적용
          </button>

        </div>

      {:else}
        <!-- 품목 미선택 상태 -->
        <div class="flex flex-col items-center justify-center flex-1 gap-3 px-6 py-8">
          <div class="w-16 h-16 rounded-2xl bg-base-200 flex items-center justify-center">
            <Icon icon="heroicons:hand-raised" class="w-8 h-8 text-base-content/20" />
          </div>
          <p class="text-sm font-semibold text-base-content/30">품목 미선택</p>
          <p class="text-xs text-base-content/20 text-center">왼쪽 목록에서<br/>품목을 탭 하세요</p>
        </div>
      {/if}


    </div>
  </aside>
</div>

<!-- ══════════════════════════════════════════════════════════════════
     모바일 Bottom Sheet (md:hidden)
═══════════════════════════════════════════════════════════════════ -->
{#if selectedItemId && selectedItem}
  <!-- 딤 배경 -->
  <div
    class="fixed inset-0 bg-black/30 z-30 md:hidden"
    role="button" tabindex="-1"
    onclick={() => { selectedItemId = null; inputValue = ''; }}
    onkeydown={(e) => e.key === 'Escape' && (selectedItemId = null)}
    aria-label="닫기"
  ></div>

  <!-- 시트 -->
  <div class="fixed bottom-0 left-0 right-0 z-40 md:hidden bg-base-100 rounded-t-2xl shadow-2xl flex flex-col max-h-[80vh]">
    <!-- 드래그 핸들 -->
    <div class="flex justify-center pt-3 pb-1 shrink-0">
      <div class="w-10 h-1 rounded-full bg-base-300"></div>
    </div>

    <!-- 시트 헤더 -->
    <div class="px-4 py-3 border-b border-base-200 shrink-0 flex items-center justify-between">
      <div>
        <p class="text-sm font-bold text-base-content">{selectedItem.name}</p>
        <p class="text-xs text-base-content/40">현재 {currentCompleted}개</p>
      </div>
      <button
        type="button"
        class="btn btn-ghost btn-sm btn-circle text-base-content/40"
        onclick={() => { selectedItemId = null; inputValue = ''; }}
      >
        <Icon icon="heroicons:x-mark" class="w-4 h-4" />
      </button>
    </div>

    <div class="overflow-y-auto flex flex-col">
      <!-- 미리보기 박스 -->
      <div class="px-4 pt-3 pb-1 shrink-0">
        <div class="h-14 rounded-xl bg-base-200 border-2 border-success/50 flex items-center px-4">
          {#if inputNum !== null && !isNaN(inputNum)}
            <span class="text-xs font-bold text-success mr-2 shrink-0">+</span>
            <span class="text-lg font-bold text-base-content">{currentCompleted}</span>
            <span class="text-sm text-base-content/40 mx-2">+</span>
            <span class="text-lg font-bold text-success">{inputNum}</span>
            <span class="text-sm text-base-content/40 mx-2">=</span>
            <span class="text-2xl font-black text-success ml-auto">{previewResult()}</span>
          {:else}
            <span class="text-xs font-bold text-base-content/30 mr-2">입력</span>
            <span class="text-4xl font-black text-base-content/20 flex-1 text-right tracking-widest">
              {inputValue || '—'}
            </span>
            <span class="text-sm text-base-content/20 ml-2">개</span>
          {/if}
        </div>
      </div>

      <!-- 숫자패드 -->
      <div class="px-4 py-3 shrink-0">
        <div class="grid grid-cols-3 gap-2 select-none">
          {#each (['1','2','3','4','5','6','7','8','9','back','0','clear'] as const) as key, i (i)}
            {#if key === 'clear'}
              <button type="button" class="h-16 rounded-lg font-black text-2xl btn btn-error btn-outline active:scale-95" onclick={() => { inputValue = ''; }}>C</button>
            {:else if key === 'back'}
              <button type="button" class="h-16 rounded-lg font-black text-2xl btn btn-ghost bg-base-200 border border-base-300 flex items-center justify-center active:scale-95" onclick={() => { inputValue = inputValue.slice(0, -1); }}>
                <Icon icon="heroicons:backspace" class="w-6 h-6" />
              </button>
            {:else}
              <button type="button" class="h-16 rounded-lg font-black text-2xl btn btn-ghost bg-base-100 border border-base-300 shadow-sm text-base-content active:scale-95" onclick={() => { const v = (inputValue + key).replace(/^0+(?=\d)/, ''); if (v.length <= 6) inputValue = v; }}>{key}</button>
            {/if}
          {/each}
        </div>
      </div>

      <!-- 적용 버튼 -->
      <div class="px-4 pb-4 shrink-0">
        <button
          type="button"
          class="btn w-full h-12 font-bold btn-success
            {(inputNum === null || isNaN(inputNum ?? NaN)) ? 'opacity-40' : ''}"
          disabled={inputNum === null || isNaN(inputNum ?? NaN)}
          onclick={applyInput}
        >
          추가 적용
          {#if inputValue !== '' && inputNum !== null && !isNaN(inputNum)}
            <span class="text-xs font-normal opacity-80 ml-1">→ {previewResult()}개</span>
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ══════════════════════════════════════════════════════════════════
     품목 추가 모달
═══════════════════════════════════════════════════════════════════ -->
{#if showAddModal}
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={closeAddModal}
    onkeydown={(e) => e.key === 'Escape' && closeAddModal()}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <!-- 헤더 -->
      <div class="px-6 py-5 bg-primary flex items-center justify-between">
        <span class="text-2xl font-black text-primary-content">품목 추가</span>
        <button type="button" class="btn btn-ghost btn-circle text-primary-content/70" onclick={closeAddModal}>
          <Icon icon="heroicons:x-mark" class="w-6 h-6" />
        </button>
      </div>

      <div class="p-6 space-y-6">

        <!-- 카테고리 탭 -->
        <div>
          <p class="text-sm font-black text-base-content/40 uppercase tracking-wider mb-3">카테고리</p>
          <div class="flex gap-2">
            {#each ([['towel', '타올'], ['sheet', '시트'], ['uniform', '유니폼']] as const) as [cat, label] (cat)}
              <button
                type="button"
                class="flex-1 h-14 rounded-xl border-2 font-black text-lg transition-all
                  {modalCategory === cat
                    ? 'border-primary bg-primary text-primary-content'
                    : 'border-base-300 bg-base-100 text-base-content/50 hover:border-primary/50'}"
                onclick={() => { modalCategory = cat; modalSelectedName = null; }}
              >{label}</button>
            {/each}
          </div>
        </div>

        <!-- 품목명 선택 (스크롤) -->
        <div>
          <p class="text-sm font-black text-base-content/40 uppercase tracking-wider mb-3">품목명 선택</p>
          <div class="h-52 overflow-y-auto rounded-xl border border-base-300 flex flex-col">
            {#each ITEM_NAMES[modalCategory] as name (name)}
              {@const alreadyExists = store.selectedClientId
                ? store.laundryItems.some(i => i.clientId === store.selectedClientId && i.name === name && i.category === modalCategory)
                : false}
              <button
                type="button"
                class="px-5 py-4 text-left text-lg font-bold border-b border-base-200 last:border-b-0 transition-all
                  {modalSelectedName === name
                    ? 'bg-primary text-primary-content'
                    : alreadyExists
                      ? 'bg-base-200 text-base-content/30 cursor-not-allowed'
                      : 'hover:bg-base-200 text-base-content'}"
                disabled={alreadyExists}
                onclick={() => { modalSelectedName = modalSelectedName === name ? null : name; }}
              >
                <span>{name}</span>
                {#if alreadyExists}
                  <span class="text-xs font-bold ml-2 opacity-60">이미 등록됨</span>
                {/if}
              </button>
            {/each}
          </div>
          <p class="text-xs text-base-content/30 mt-2 font-bold">선택하지 않으면 자동으로 유니크한 이름이 부여됩니다</p>
        </div>

        <!-- 미리보기 -->
        <div class="rounded-xl bg-base-200 px-5 py-4 flex items-center gap-3">
          <span class="text-sm font-black text-base-content/40 shrink-0">등록될 품목명</span>
          <span class="text-xl font-black text-primary truncate">{resolvedItemName}</span>
          {#if !modalSelectedName}
            <span class="text-xs font-bold text-base-content/30 shrink-0 ml-auto">자동생성</span>
          {/if}
        </div>

        <!-- 적용 범위 -->
        <div>
          <p class="text-sm font-black text-base-content/40 uppercase tracking-wider mb-3">적용 범위</p>
          <div class="grid grid-cols-2 gap-3">
            <button
              type="button"
              class="h-14 rounded-xl border-2 font-black text-lg transition-all
                {modalScope === 'this' ? 'border-primary bg-primary text-primary-content' : 'border-base-300 bg-base-100 text-base-content/50 hover:border-primary/50'}"
              onclick={() => { modalScope = 'this'; }}
            >이 거래처만</button>
            <button
              type="button"
              class="h-14 rounded-xl border-2 font-black text-lg transition-all
                {modalScope === 'all' ? 'border-warning bg-warning text-warning-content' : 'border-base-300 bg-base-100 text-base-content/50 hover:border-warning/50'}"
              onclick={() => { modalScope = 'all'; }}
            >모든 거래처</button>
          </div>
          {#if modalScope === 'all'}
            <p class="text-sm text-warning font-bold mt-2">⚠ 모든 거래처에 동일하게 추가됩니다</p>
          {/if}
        </div>

        <!-- 추가 버튼 -->
        <button
          type="button"
          class="btn btn-primary w-full h-16 text-xl font-black"
          onclick={submitAddItem}
        >품목 추가하기</button>
      </div>
    </div>
  </div>
{/if}

<!-- ══════════════════════════════════════════════════════════════════
     기록 드로어
═══════════════════════════════════════════════════════════════════ -->
{#if showLogDrawer}
  <!-- 딤 배경 -->
  <div
    class="fixed inset-0 bg-black/40 z-40"
    role="button" tabindex="-1"
    onclick={closeLogDrawer}
    onkeydown={(e) => e.key === 'Escape' && closeLogDrawer()}
    aria-label="닫기"
  ></div>

  <!-- 드로어 패널 -->
  <div class="fixed top-0 right-0 h-full w-1/2 bg-base-100 shadow-2xl z-50 flex flex-col animate-slide-in">
    <!-- 드로어 헤더 -->
    <div class="px-8 py-6 bg-primary shrink-0 flex items-center justify-between">
      <h3 class="text-2xl font-black text-primary-content truncate">
        {logTargetItem?.name ?? ''} 기록
      </h3>
      <button
        type="button"
        class="btn btn-ghost btn-md btn-circle text-primary-content/70 hover:text-primary-content"
        onclick={closeLogDrawer}
      >
        <Icon icon="heroicons:x-mark" class="w-6 h-6" />
      </button>
    </div>

    <!-- 컨럼 헤더 -->
    <div class="h-16 bg-base-200 border-b border-base-300 shrink-0 flex items-center px-8">
      <div class="flex-1 grid grid-cols-4 gap-2 text-sm font-black text-base-content/40 uppercase tracking-wider">
        <div class="col-span-1">시각</div>
        <div class="text-center text-base-content/40">이전</div>
        <div class="text-center">변동</div>
        <div class="text-center text-primary">결과</div>
      </div>
    </div>

    <!-- 기록 목록 -->
    <div class="flex-1 overflow-y-auto">
      {#if allLogEntries().length === 0}
        <div class="flex flex-col items-center justify-center h-full text-base-content/20 gap-3">
          <Icon icon="heroicons:clock" class="w-16 h-16 opacity-40" />
          <p class="text-xl font-bold">기록이 없습니다</p>
        </div>
      {:else}
        <!-- 전체 건수 -->
        <div class="px-8 py-3 bg-base-200/50 border-b border-base-300">
          <p class="text-sm font-bold text-base-content/40">전체 {allLogEntries().length}건 · 최근 {logEntries().length}건 표시</p>
        </div>
        {#each logEntries() as entry (entry.id)}
          <div class="px-8 py-5 border-b border-base-200 hover:bg-base-200/40 transition-colors">
            <div class="grid grid-cols-4 gap-2 items-center">
              <!-- 시각 -->
              <div>
                <span class="text-lg font-black text-base-content tabular-nums block">{formatTime(entry.createdAt)}</span>
                <span class="text-xs font-bold text-base-content/30 tabular-nums">{entry.date}</span>
              </div>
              <!-- 이전 -->
              <div class="text-center">
                <span class="text-4xl font-black text-base-content/40 tabular-nums">{entry.before}</span>
              </div>
              <!-- 변동 -->
              <div class="text-center">
                {#if entry.delta < 0}
                  <span class="text-4xl font-black text-error tabular-nums">{entry.delta}</span>
                {:else}
                  <span class="text-4xl font-black text-success tabular-nums">+{entry.delta}</span>
                {/if}
              </div>
              <!-- 결과 -->
              <div class="text-center">
                <span class="text-4xl font-black text-primary tabular-nums">{entry.after}</span>
              </div>
            </div>
          </div>
        {/each}
        <!-- 더보기 -->
        {#if hasMoreLogs}
          <div class="px-8 py-6">
            <button
              type="button"
              class="btn btn-ghost w-full h-16 text-lg font-black border border-base-300 text-base-content/50"
              onclick={loadMoreLogs}
            >
              <Icon icon="heroicons:arrow-down" class="w-5 h-5" />
              더 보기 ({allLogEntries().length - logVisibleCount}건 더)
            </button>
          </div>
        {:else if allLogEntries().length > LOG_PAGE_SIZE}
          <div class="px-8 py-5 text-center">
            <p class="text-sm font-bold text-base-content/30">전체 {allLogEntries().length}건 모두 표시되었습니다</p>
          </div>
        {/if}
      {/if}
    </div>
  </div>
{/if}

<style>
  @keyframes slide-in {
    from { transform: translateX(100%); }
    to   { transform: translateX(0); }
  }
  .animate-slide-in {
    animation: slide-in 0.22s cubic-bezier(0.4, 0, 0.2, 1);
  }
</style>
