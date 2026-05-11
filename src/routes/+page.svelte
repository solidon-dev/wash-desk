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
  let modalItemName = $state('');
  let modalScope = $state<'this' | 'all'>('this');

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

  let logEntries = $derived((): CompletedLogEntry[] => {
    if (!logTargetItem) return [];
    return store.completedLogs
      .filter((l: CompletedLogEntry) => l.clientId === logTargetItem!.clientId)
      .filter((e: CompletedLogEntry) => e.laundryItemId === logTargetItem!.id && e.date === todayStr());
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

  function applyInput() {
    const num = inputNum;
    if (num === null || isNaN(num) || num < 0) return;
    if (!store.selectedClientId || !selectedItem) return;
    addCompleted(store.selectedClientId, selectedItem.id, num);
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
    <div class="h-14 bg-base-100 border-b border-base-300 px-2 shrink-0 flex items-center gap-1">
      {#each categories as cat (cat.key)}
        {@const isActive = activeCategory === cat.key}
        <button
          type="button"
          class="px-6 h-full text-base font-bold transition-colors rounded-none
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
        class="w-full h-14 flex items-center justify-center gap-2 px-4 bg-primary/5 hover:bg-primary/10 text-primary transition-colors border-b border-primary/10 shrink-0"
        onclick={openAddModal}
      >
        <Icon icon="heroicons:plus-circle" class="w-5 h-5" />
        <span class="text-base font-bold">품목 추가</span>
      </button>
    {/if}

    {#if filteredItems.length > 0}
      <div class="h-14 bg-base-200 border-b border-base-300 px-4 shrink-0 flex items-center">
        <div class="flex-1 min-w-0">
          <span class="text-sm font-bold text-base-content/40 uppercase tracking-wider">품목명</span>
        </div>
        <div class="w-10 shrink-0"></div>
        <div class="w-32 text-center shrink-0">
          <span class="text-sm font-bold text-base-content/40 uppercase tracking-wider">세탁완료</span>
        </div>
        <div class="w-12 shrink-0"></div>
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
            class="flex items-center min-h-20 px-4 border-b border-base-200 transition-colors border-l-2
              {isSel ? 'bg-primary/5 border-l-primary' : 'border-l-transparent hover:bg-base-200/60'}"
          >
            <!-- 품목명 클릭 영역 -->
            <button
              type="button"
              class="flex-1 py-3 text-left min-w-0 h-full"
              onclick={() => toggleItem(item.id)}
            >
              <span class="text-lg font-bold truncate block
                {isSel ? 'text-primary' : 'text-base-content'}">
                {item.name}
              </span>
            </button>

            <!-- 기록(시계) 버튼 -->
            <div class="w-10 shrink-0 flex items-center justify-center">
              <button
                type="button"
                class="btn btn-ghost btn-sm w-9 h-9 p-0 rounded-lg text-base-content/30 hover:text-base-content/70"
                onclick={(e) => { e.stopPropagation(); openLogDrawer(item); }}
                title="기록 보기"
              >
                <Icon icon="heroicons:clock" class="w-5 h-5" />
              </button>
            </div>

            <!-- 세탁완료 수 -->
            <div class="w-32 flex justify-center items-center shrink-0">
              <span class="text-3xl font-black
                {completed === 0 ? 'text-base-content/20' : 'text-success'}">
                {completed}
              </span>
            </div>

            <!-- 체크 인디케이터 -->
            <div class="w-12 shrink-0 flex items-center justify-center">
              <div class="w-8 h-8 rounded-full border-2 transition-all duration-150 flex items-center justify-center
                {isSel
                  ? 'bg-primary border-primary'
                  : 'border-base-300 bg-base-100'}">
                {#if isSel}
                  <Icon icon="heroicons:check" class="w-5 h-5 text-primary-content" />
                {/if}
              </div>
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

        <!-- 현재 수량 + 입력 미리보기 2컬럼 -->
        <div class="px-6 py-5 border-b border-base-200 shrink-0">
          <div class="grid grid-cols-2 gap-3 h-28">
            <!-- 왼쪽: 현재 수량 -->
            <div class="rounded-2xl bg-base-200 flex flex-col items-center justify-center gap-1">
              <span class="text-xs font-bold text-base-content/40 uppercase tracking-wider">현재 수량</span>
              <span class="text-5xl font-black text-base-content">{currentCompleted}</span>
              <span class="text-sm font-bold text-base-content/30">개</span>
            </div>
            <!-- 오른쪽: 입력값 미리보기 -->
            <div class="rounded-2xl border-2 border-success/60 bg-success/5 flex flex-col items-center justify-center gap-1">
              {#if inputNum !== null && !isNaN(inputNum)}
                <span class="text-xs font-bold text-success/70 uppercase tracking-wider">+ {inputNum} = 결과</span>
                <span class="text-5xl font-black text-success">{previewResult()}</span>
                <span class="text-sm font-bold text-success/50">개</span>
              {:else}
                <span class="text-xs font-bold text-base-content/30 uppercase tracking-wider">입력</span>
                <span class="text-5xl font-black text-base-content/20 tracking-widest">{inputValue || '—'}</span>
                <span class="text-sm font-bold text-base-content/20">개</span>
              {/if}
            </div>
          </div>
          <!-- 선택 해제 버튼 -->
          <button
            type="button"
            class="mt-3 w-full h-9 rounded-xl btn btn-ghost text-sm text-base-content/40 border border-base-200"
            onclick={() => { selectedItemId = null; inputValue = ''; }}
          >
            <Icon icon="heroicons:x-mark" class="w-4 h-4" />
            {selectedItem.name} 선택 해제
          </button>
        </div>

        <!-- 숫자패드 -->
        <div class="px-6 pt-5 pb-2 shrink-0">
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
                  onclick={() => { if (inputValue.length < 6) inputValue = inputValue + key; }}
                >{key}</button>
              {/if}
            {/each}
          </div>
        </div>

        <!-- 적용 버튼 -->
        <div class="px-6 pb-6 pt-2 shrink-0">
          <button
            type="button"
            class="btn btn-success w-full h-20 text-2xl font-black
              {(inputNum === null || isNaN(inputNum ?? NaN)) ? 'opacity-40' : ''}"
            disabled={inputNum === null || isNaN(inputNum ?? NaN)}
            onclick={applyInput}
          >
            <Icon icon="heroicons:plus" class="w-7 h-7" />
            추가 적용
            {#if inputValue !== '' && inputNum !== null && !isNaN(inputNum)}
              <span class="text-base font-normal opacity-80 ml-1">→ {previewResult()}개</span>
            {/if}
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
              <button type="button" class="h-16 rounded-lg font-black text-2xl btn btn-ghost bg-base-100 border border-base-300 shadow-sm text-base-content active:scale-95" onclick={() => { if (inputValue.length < 6) inputValue = inputValue + key; }}>{key}</button>
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
    class="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center sm:p-4"
    role="button" tabindex="-1"
    onclick={closeAddModal}
    onkeydown={(e) => e.key === 'Escape' && closeAddModal()}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-sm overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <!-- 모달 헤더 -->
      <div class="flex items-center justify-between px-4 py-3 border-b border-base-200">
        <span class="text-sm font-bold text-base-content">품목 추가</span>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" onclick={closeAddModal}>
          <Icon icon="heroicons:x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>

      <div class="px-4 py-4 space-y-4">
        <!-- 카테고리 선택 -->
        <div>
          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">카테고리</p>
          <div class="grid grid-cols-3 gap-2">
            {#each ([['towel', '🛁', '타올'], ['sheet', '🛏', '시트'], ['uniform', '👔', '유니폼']] as const) as [cat, icon, label] (cat)}
              <button
                type="button"
                class="flex flex-col items-center gap-1 py-3 rounded-xl border-2 transition-all font-medium text-sm
                  {modalCategory === cat
                    ? 'border-primary bg-primary/5 text-primary'
                    : 'border-base-300 bg-base-100 text-base-content/60 hover:border-base-400'}"
                onclick={() => { modalCategory = cat; }}
              >
                <span class="text-2xl">{icon}</span>
                <span>{label}</span>
              </button>
            {/each}
          </div>
        </div>

        <!-- 품목명 입력 -->
        <div>
          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">품목명</p>
          <input
            type="text"
            class="input input-bordered w-full text-sm font-medium"
            placeholder="예) 대형 수건, 베갯잇..."
            bind:value={modalItemName}
            onkeydown={(e) => e.key === 'Enter' && submitAddItem()}
          />
        </div>

        <!-- 적용 범위 -->
        <div>
          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">적용 범위</p>
          <div class="grid grid-cols-2 gap-2">
            <button
              type="button"
              class="btn btn-sm h-10 rounded-lg font-medium
                {modalScope === 'this' ? 'btn-primary' : 'btn-ghost bg-base-200 text-base-content/60'}"
              onclick={() => { modalScope = 'this'; }}
            >이 거래처만</button>
            <button
              type="button"
              class="btn btn-sm h-10 rounded-lg font-medium
                {modalScope === 'all' ? 'btn-warning' : 'btn-ghost bg-base-200 text-base-content/60'}"
              onclick={() => { modalScope = 'all'; }}
            >모든 거래처</button>
          </div>
          {#if modalScope === 'all'}
            <p class="text-xs text-warning font-bold mt-1.5">⚠ 모든 거래처에 동일하게 추가됩니다</p>
          {/if}
        </div>

        <!-- 추가 버튼 -->
        <button
          type="button"
          class="btn btn-primary w-full font-bold"
          disabled={!modalItemName.trim()}
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
  <div class="fixed top-0 right-0 h-full w-96 bg-base-100 shadow-2xl z-50 flex flex-col animate-slide-in">
    <!-- 드로어 헤더 -->
    <div class="px-4 py-3 bg-primary shrink-0 flex items-start justify-between">
      <div class="flex-1 min-w-0 mr-3">
        <h3 class="text-sm font-bold text-primary-content truncate">
          {logTargetItem?.name ?? ''} 기록
        </h3>
        <p class="text-xs text-primary-content/60 mt-0.5">오늘 처리 내역</p>
      </div>
      <button
        type="button"
        class="btn btn-ghost btn-xs btn-circle text-primary-content/70 hover:text-primary-content"
        onclick={closeLogDrawer}
      >
        <Icon icon="heroicons:x-mark" class="w-4 h-4" />
      </button>
    </div>

    <!-- 안내 문구 -->
    <div class="px-4 py-2.5 bg-warning/10 border-b border-warning/20 shrink-0">
      <p class="text-xs text-warning font-bold">오늘 날짜 기록만 표시됩니다. 수정 불가.</p>
    </div>

    <!-- 컬럼 헤더 -->
    <div class="h-10 bg-base-200 border-b border-base-300 shrink-0 flex items-center px-4">
      <div class="flex-1 grid grid-cols-5 gap-1 text-xs font-semibold text-base-content/40 uppercase tracking-wider">
        <div class="col-span-2">시각</div>
        <div class="text-center">방식</div>
        <div class="text-center">이전</div>
        <div class="text-center">결과</div>
      </div>
    </div>

    <!-- 기록 목록 -->
    <div class="flex-1 overflow-y-auto">
      {#if logEntries().length === 0}
        <div class="flex flex-col items-center justify-center h-full text-base-content/20 gap-3">
          <Icon icon="heroicons:clock" class="w-14 h-14 opacity-40" />
          <p class="text-sm font-semibold">오늘 기록이 없습니다</p>
        </div>
      {:else}
        {#each logEntries() as entry (entry.id)}
          <div class="px-4 py-3 border-b border-base-200 hover:bg-base-200/60 transition-colors">
            <div class="grid grid-cols-5 gap-1 items-center">
              <!-- 시각 -->
              <div class="col-span-2">
                <span class="text-xs font-bold text-base-content">{formatTime(entry.createdAt)}</span>
              </div>
              <!-- 방식 -->
              <div class="text-center">
                <span class="badge badge-sm font-bold
                  {entry.actionType === 'add' ? 'badge-success' : 'badge-primary'}">
                  {entry.actionType === 'add' ? '+추가' : '지정'}
                </span>
              </div>
              <!-- 이전 -->
              <div class="text-center">
                <span class="text-sm font-bold text-base-content/50">{entry.before}</span>
              </div>
              <!-- 결과 -->
              <div class="text-center">
                <span class="text-sm font-bold
                  {entry.after > entry.before ? 'text-success' : entry.after < entry.before ? 'text-error' : 'text-base-content/50'}">
                  {entry.after}
                </span>
              </div>
            </div>
            <!-- 서브 텍스트 -->
            {#if entry.actionType === 'add'}
              <p class="text-xs text-base-content/40 mt-0.5">
                {entry.before} + {entry.delta} = {entry.after}
              </p>
            {:else}
              <p class="text-xs text-base-content/40 mt-0.5">
                {entry.before} → {entry.after}
                {#if entry.delta !== 0}
                  <span class="{entry.delta > 0 ? 'text-success' : 'text-error'}">
                    ({entry.delta > 0 ? '+' : ''}{entry.delta})
                  </span>
                {/if}
              </p>
            {/if}
          </div>
        {/each}
      {/if}
    </div>

    <!-- 드로어 하단 -->
    <div class="px-4 py-3 border-t border-base-200 shrink-0">
      <button
        type="button"
        class="btn btn-sm w-full btn-ghost border border-base-300 text-base-content/60"
        onclick={closeLogDrawer}
      >닫기</button>
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
