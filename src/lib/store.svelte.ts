import type { Client, Factory } from '$lib/supabase/types';

export const NAV_ITEMS = [
  { path: '/laundry',  icon: 'heroicons:inbox-stack',            label: '세탁물' },
  { path: '/shipout',  icon: 'heroicons:archive-box-arrow-down', label: '출고'   },
  { path: '/history',  icon: 'heroicons:chart-bar',              label: '현황'   },
] as const;

export const store = $state({
  clients: [] as Client[],
  factories: [] as Factory[],
  selectedClientId: null as string | null,
  factoryId: null as string | null,
  isSuperAdmin: false,
});

export function selectClient(id: string | null) {
  store.selectedClientId = id;
}
