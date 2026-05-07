<script lang="ts">
  import Icon from '@iconify/svelte';

  interface Props {
    show: boolean;
    target: 'from' | 'to' | 'single';
    /** 'date' | 'datetime' */
    mode?: 'date' | 'datetime';
    fromDate: string;
    toDate: string;
    /** datetime 모드일 때 사용 (ISO or datetime-local 형식) */
    datetimeValue?: string;
    onselect: (target: 'from' | 'to' | 'single', ymd: string) => void;
    ondatetimeselect?: (value: string) => void;
    onclose: () => void;
  }

  let {
    show, target, mode = 'date',
    fromDate, toDate, datetimeValue = '',
    onselect, ondatetimeselect, onclose,
  }: Props = $props();

  function pad(n: number) { return String(n).padStart(2, '0'); }

  let pickerYear  = $state(new Date().getFullYear());
  let pickerMonth = $state(new Date().getMonth());
  let pickerHour  = $state(new Date().getHours());
  let pickerMin   = $state(0);

  $effect(() => {
    if (!show) return;
    if (mode === 'datetime' && datetimeValue) {
      const base = new Date(datetimeValue);
      pickerYear  = base.getFullYear();
      pickerMonth = base.getMonth();
      pickerHour  = base.getHours();
      pickerMin   = base.getMinutes();
    } else {
      const src = target === 'to' ? toDate : fromDate;
      const base = src ? new Date(src) : new Date();
      pickerYear  = base.getFullYear();
      pickerMonth = base.getMonth();
    }
  });

  const MONTH_NAMES = ['1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'];
  const DAY_NAMES   = ['일','월','화','수','목','금','토'];

  function pickerDays(): (number | null)[] {
    const first = new Date(pickerYear, pickerMonth, 1).getDay();
    const last  = new Date(pickerYear, pickerMonth + 1, 0).getDate();
    const cells: (number | null)[] = Array(first).fill(null);
    for (let d = 1; d <= last; d++) cells.push(d);
    return cells;
  }

  function prevMonth() {
    if (pickerMonth === 0) { pickerMonth = 11; pickerYear -= 1; }
    else pickerMonth -= 1;
  }
  function nextMonth() {
    if (pickerMonth === 11) { pickerMonth = 0; pickerYear += 1; }
    else pickerMonth += 1;
  }

  // 날짜 선택 시
  let pickerSelectedDate = $state(''); // 'YYYY-MM-DD'
  $effect(() => {
    if (!show) return;
    if (mode === 'datetime' && datetimeValue) {
      const d = new Date(datetimeValue);
      pickerSelectedDate = `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`;
    } else {
      pickerSelectedDate = target === 'to' ? toDate : fromDate;
    }
  });

  function selectDay(day: number) {
    const ymd = `${pickerYear}-${pad(pickerMonth + 1)}-${pad(day)}`;
    if (mode === 'datetime') {
      pickerSelectedDate = ymd;
      // datetime 모드는 날짜 선택 후 시간 확인 버튼으로 최종 확정
    } else {
      onselect(target, ymd);
    }
  }

  function confirmDatetime() {
    const value = `${pickerSelectedDate}T${pad(pickerHour)}:${pad(pickerMin)}`;
    ondatetimeselect?.(value);
    onclose();
  }

  const headerLabel: Record<string, string> = {
    from: '시작일',
    to: '종료일',
    single: '날짜 선택',
  };
</script>

{#if show}
  <div
    class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4"
    role="button" tabindex="-1"
    onclick={onclose}
    onkeydown={(e) => e.key === 'Escape' && onclose()}
    aria-label="닫기"
  >
    <div
      class="bg-base-100 rounded-2xl shadow-2xl w-80 overflow-hidden"
      role="dialog" aria-modal="true"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      tabindex="-1"
    >
      <!-- 헤더 -->
      <div class="px-4 py-3 border-b border-base-200 flex items-center justify-between">
        <span class="text-xs font-bold text-base-content/40">{headerLabel[target] ?? '날짜 선택'}</span>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" onclick={onclose}>
          <Icon icon="heroicons:x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>

      <!-- 연/월 네비게이션 -->
      <div class="px-4 pt-3 pb-1 flex items-center justify-between">
        <div class="flex items-center gap-1">
          <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={() => pickerYear -= 1}>
            <Icon icon="heroicons:chevron-left" class="w-3.5 h-3.5" />
          </button>
          <span class="text-sm font-black w-14 text-center">{pickerYear}년</span>
          <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={() => pickerYear += 1}>
            <Icon icon="heroicons:chevron-right" class="w-3.5 h-3.5" />
          </button>
        </div>
        <div class="flex items-center gap-1">
          <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={prevMonth}>
            <Icon icon="heroicons:chevron-left" class="w-3.5 h-3.5" />
          </button>
          <span class="text-sm font-black w-10 text-center">{MONTH_NAMES[pickerMonth]}</span>
          <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={nextMonth}>
            <Icon icon="heroicons:chevron-right" class="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      <!-- 요일 헤더 -->
      <div class="grid grid-cols-7 px-3 pb-1">
        {#each DAY_NAMES as dn, i (dn)}
          <div class="text-center text-[10px] font-bold py-1
            {i === 0 ? 'text-error' : i === 6 ? 'text-info' : 'text-base-content/30'}">{dn}</div>
        {/each}
      </div>

      <!-- 날짜 그리드 -->
      <div class="grid grid-cols-7 px-3 pb-3 gap-y-0.5">
        {#each pickerDays() as cell, i (i)}
          {#if cell === null}
            <div></div>
          {:else}
            {@const ymd = `${pickerYear}-${pad(pickerMonth + 1)}-${pad(cell)}`}
            {@const isSelected = mode === 'datetime' ? pickerSelectedDate === ymd : (target === 'to' ? toDate : fromDate) === ymd}
            {@const isInRange = mode !== 'datetime' && ymd >= fromDate && ymd <= toDate}
            {@const dow = new Date(pickerYear, pickerMonth, cell).getDay()}
            <button
              type="button"
              class="h-8 w-full rounded-lg text-sm font-bold transition-colors
                {isSelected
                  ? 'bg-primary text-primary-content'
                  : isInRange
                    ? 'bg-primary/20 text-primary'
                    : dow === 0
                      ? 'text-error hover:bg-base-200'
                      : dow === 6
                        ? 'text-info hover:bg-base-200'
                        : 'text-base-content hover:bg-base-200'}"
              onclick={() => selectDay(cell)}
            >{cell}</button>
          {/if}
        {/each}
      </div>

      <!-- 시간 선택 (datetime 모드) -->
      {#if mode === 'datetime'}
        <div class="px-4 pb-3 border-t border-base-200 pt-3 flex items-center justify-center gap-3">
          <div class="flex items-center gap-1">
            <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={() => pickerHour = (pickerHour + 23) % 24}>
              <Icon icon="heroicons:chevron-left" class="w-3.5 h-3.5" />
            </button>
            <span class="text-xl font-black w-10 text-center tabular-nums">{pad(pickerHour)}</span>
            <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={() => pickerHour = (pickerHour + 1) % 24}>
              <Icon icon="heroicons:chevron-right" class="w-3.5 h-3.5" />
            </button>
          </div>
          <span class="text-lg font-black text-base-content/40">:</span>
          <div class="flex items-center gap-1">
            <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={() => pickerMin = (pickerMin + 55) % 60}>
              <Icon icon="heroicons:chevron-left" class="w-3.5 h-3.5" />
            </button>
            <span class="text-xl font-black w-10 text-center tabular-nums">{pad(pickerMin)}</span>
            <button type="button" class="btn btn-ghost btn-xs btn-square" onclick={() => pickerMin = (pickerMin + 5) % 60}>
              <Icon icon="heroicons:chevron-right" class="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
        <div class="px-4 pb-4">
          <button
            type="button"
            class="btn btn-primary w-full font-bold"
            onclick={confirmDatetime}
          >확인</button>
        </div>
      {/if}
    </div>
  </div>
{/if}
