import type { Client, Factory, Category, Item } from '$lib/supabase/types';
import { supabase } from '$lib/supabase/client';
import { getClients } from '$lib/api/clients';
import { getFactories } from '$lib/api/factories';
import { getCategories } from '$lib/api/categories';
import { getItemsByClient } from '$lib/api/items';
import { getInventory } from '$lib/api/inventory';

export const NAV_ITEMS = [
  { path: '/laundry',  icon: 'heroicons:inbox-stack',            label: '세탁물' },
  { path: '/shipout',  icon: 'heroicons:archive-box-arrow-down', label: '출고'   },
  { path: '/history',  icon: 'heroicons:chart-bar',              label: '현황'   },
] as const;

export type ItemWithCategory = Item & { categories: { id: string; name: string } | null };
export type InventoryMap     = Record<string, number>;
export type InventoryIdMap   = Record<string, string>;

const LS_FACTORY_KEY = 'selectedFactoryId';
const LS_CLIENT_KEY  = 'selectedClientId';

export const store = $state({
  isSuperAdmin:     false,
  factoryId:        null as string | null,
  factories:        [] as Factory[],
  clients:          [] as Client[],
  selectedClientId: null as string | null,
  categories:       [] as Category[],
  items:            [] as ItemWithCategory[],
  inventoryMap:     {} as InventoryMap,
  inventoryIdMap:   {} as InventoryIdMap,
  dataLoading:      false,
});

// ── 카테고리·품목·재고 fetch ────────────────────────────────────────
// 컨텍스트 전환(공장·거래처 변경) 시 기존 데이터를 즉시 비운다.
function clearStoreData() {
  store.categories   = [];
  store.items        = [];
  store.inventoryMap = {};
  store.inventoryIdMap = {};
}

export async function loadData(factoryId: string, clientId: string) {
  store.dataLoading = true;
  // ← 기존 데이터를 여기서 비우지 않는다.
  //   갱신 중에도 이전 화면을 그대로 유지 → 깜빡임 제거.

  const [catRes, itemRes, invRes] = await Promise.all([
    getCategories(clientId),
    getItemsByClient(clientId),
    getInventory(factoryId, clientId),
  ]);

  // 응답 도중 공장/거래처가 바뀌었으면 버림
  if (store.factoryId !== factoryId || store.selectedClientId !== clientId) {
    store.dataLoading = false;
    return;
  }

  store.categories = catRes.data ?? [];

  // ── 재고: 변경된 항목만 키 단위로 패치 (전체 교체 → 불필요한 리렌더 방지) ──
  const freshInv    = invRes.data ?? [];
  const freshIdMap: InventoryIdMap = {};
  const freshItemIds = new Set<string>();

  for (const row of freshInv) {
    freshItemIds.add(row.item_id);
    freshIdMap[row.item_id] = row.id;
    if (store.inventoryMap[row.item_id] !== row.quantity) {
      store.inventoryMap[row.item_id] = row.quantity; // 변경된 키만 갱신
    }
  }
  // 더 이상 존재하지 않는 항목 제거
  for (const itemId of Object.keys(store.inventoryMap)) {
    if (!freshItemIds.has(itemId)) {
      delete store.inventoryMap[itemId];
    }
  }
  store.inventoryIdMap = freshIdMap;

  const rawItems = (itemRes.data ?? []) as ItemWithCategory[];
  store.items = rawItems.slice().sort((a, b) => (store.inventoryMap[b.id] ?? 0) - (store.inventoryMap[a.id] ?? 0));

  store.dataLoading = false;
}

// ── 공장 선택: 거래처 목록 + 데이터 로드 ────────────────────────────
export async function applyFactory(factoryId: string, preferClientId?: string | null) {
  const { data: clients } = await getClients(factoryId);
  const list = clients ?? [];
  const clientId =
    (preferClientId && list.find(c => c.id === preferClientId))
      ? preferClientId
      : list[0]?.id ?? null;

  store.clients          = list;
  store.factoryId        = factoryId;
  store.selectedClientId = clientId;
  clearStoreData(); // 컨텍스트 전환이므로 즉시 비움

  localStorage.setItem(LS_FACTORY_KEY, factoryId);
  if (clientId) localStorage.setItem(LS_CLIENT_KEY, clientId);
  else          localStorage.removeItem(LS_CLIENT_KEY);

  if (clientId) await loadData(factoryId, clientId);
}

// ── 거래처 선택: 데이터 로드 ────────────────────────────────────────
export async function switchClient(clientId: string) {
  store.selectedClientId = clientId;
  localStorage.setItem(LS_CLIENT_KEY, clientId);
  clearStoreData(); // 컨텍스트 전환이므로 즉시 비움
  if (store.factoryId) await loadData(store.factoryId, clientId);
}

// ── 세션 확인 후 store 초기화. 세션 없으면 false 반환 ─────────────────
export async function initializeStore(): Promise<boolean> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return false;

  const { data: profile } = await supabase
    .from('profiles')
    .select('factory_id, role')
    .eq('id', session.user.id)
    .single();

  store.isSuperAdmin = profile?.role === 'super_admin';

  if (store.isSuperAdmin) {
    const { data: factories } = await getFactories();
    store.factories = factories ?? [];

    const savedFactory  = localStorage.getItem(LS_FACTORY_KEY);
    const savedClient   = localStorage.getItem(LS_CLIENT_KEY);
    const targetFactory =
      (savedFactory && store.factories.find(f => f.id === savedFactory))
        ? savedFactory
        : store.factories[0]?.id ?? null;

    if (targetFactory) await applyFactory(targetFactory, savedClient);
  } else {
    if (profile?.factory_id) await applyFactory(profile.factory_id);
  }

  return true;
}

// ── store 전체 초기화 (로그아웃 시) ─────────────────────────────────
export function resetStore() {
  store.isSuperAdmin     = false;
  store.factoryId        = null;
  store.selectedClientId = null;
  store.clients          = [];
  store.factories        = [];
  store.categories       = [];
  store.items            = [];
  store.inventoryMap     = {};
  store.inventoryIdMap   = {};
}

// ── 단건 재고 업데이트 후 items 재정렬 ──────────────────────────────
export function updateInventoryItem(itemId: string, newQty: number) {
  store.inventoryMap = { ...store.inventoryMap, [itemId]: newQty };
  store.items = store.items
    .slice()
    .sort((a, b) => (store.inventoryMap[b.id] ?? 0) - (store.inventoryMap[a.id] ?? 0));
}

// ── 복수 재고 업데이트 후 items 재정렬 ──────────────────────────────
export function bulkUpdateInventory(updates: { item_id: string; new_qty: number }[]) {
  const newMap = { ...store.inventoryMap };
  for (const r of updates) newMap[r.item_id] = r.new_qty;
  store.inventoryMap = newMap;
  store.items = store.items
    .slice()
    .sort((a, b) => (store.inventoryMap[b.id] ?? 0) - (store.inventoryMap[a.id] ?? 0));
}
