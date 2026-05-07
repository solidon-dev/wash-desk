// ── 타입 ──────────────────────────────────────────────────────────
export type ClientType = 'hotel' | 'pension' | 'resort' | 'etc';
export type LaundryCategory = 'towel' | 'sheet' | 'uniform' | 'all';
export type LaundryItemStatus = 'received' | 'washing' | 'completed' | 'stock' | 'shipped';
export type LaundryStatusCounts = Record<LaundryItemStatus, number>;

export interface LaundryItem {
  id: string; clientId: string; category: string; name: string;
  alias?: string; counts: LaundryStatusCounts; updatedAt: string;
}
export interface Client {
  id: string; name: string; type: ClientType; address: string;
  phone?: string; businessNo?: string; ownerName?: string;
  managerName?: string; managerPhone?: string; memo?: string; createdAt: string;
}
export interface ShipmentItem {
  laundryItemId: string; itemName: string;
  category: Exclude<LaundryCategory, 'all'>; quantity: number;
}
export interface Shipment {
  id: string; clientId: string; items: ShipmentItem[];
  driverId: string; memo?: string; shippedAt: string; createdAt: string;
}
export interface CompletedLogEntry {
  id: string; laundryItemId: string; clientId: string; itemName: string;
  category: Exclude<LaundryCategory, 'all'>; actionType: 'add' | 'set';
  delta: number; before: number; after: number; createdAt: string; date: string;
}

// ── 상수 ──────────────────────────────────────────────────────────
export const CATEGORY_LABELS: Record<LaundryCategory, string> = {
  towel: '타올', sheet: '시트', uniform: '유니폼', all: '전체',
};

export const CLIENT_TYPE_ICON: Record<string, string> = {
  hotel: '🏨', pension: '🏡', resort: '🌴', etc: '🏢',
};
export const CLIENT_TYPE_BADGE: Record<string, string> = {
  hotel: 'badge-primary', pension: 'badge-success',
  resort: 'badge-warning', etc: 'badge-neutral',
};
export const CLIENT_TYPE_LABEL: Record<string, string> = {
  hotel: '호텔', pension: '펜션', resort: '리조트', etc: '기타',
};

export const NAV_ITEMS = [
  { path: '/',        icon: 'heroicons:inbox-stack',            label: '세탁물' },
  { path: '/shipout', icon: 'heroicons:archive-box-arrow-down', label: '출고'   },
  { path: '/history', icon: 'heroicons:chart-bar',              label: '현황'   },
] as const;

// ── 유틸 ──────────────────────────────────────────────────────────
export function genId() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}
export function todayYMD() {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
export function calcStock(c: number) { return c; }
export function zeroCounts(): LaundryStatusCounts {
  return { received: 0, washing: 0, completed: 0, stock: 0, shipped: 0 };
}

// ── 초기 데이터 ───────────────────────────────────────────────────
const _clients: Client[] = [
  { id: 'client-001', name: '그랜드호텔',  type: 'hotel',   address: '서울특별시 강남구 테헤란로 123',          phone: '02-1234-5678',  businessNo: '123-45-67890', ownerName: '김대표', managerName: '박매니저', managerPhone: '010-1234-5678', memo: 'VIP 거래처',       createdAt: '2024-01-10T09:00:00.000Z' },
  { id: 'client-002', name: '씨뷰펜션',    type: 'pension', address: '강원도 강릉시 해안로 456',               phone: '033-456-7890',  businessNo: '234-56-78901', ownerName: '이사장', managerName: '최담당',   managerPhone: '010-2345-6789', memo: '주말 수거',         createdAt: '2024-02-15T09:00:00.000Z' },
  { id: 'client-003', name: '파크리조트',  type: 'resort',  address: '경기도 가평군 청평면 789',               phone: '031-789-0123',  businessNo: '345-67-89012', ownerName: '정오너', managerName: '한실장',   managerPhone: '010-3456-7890', memo: '월 2회 정기 수거', createdAt: '2024-03-01T09:00:00.000Z' },
  { id: 'client-004', name: '스카이호텔',  type: 'hotel',   address: '부산광역시 해운대구 마린시티로 321',      phone: '051-321-6540',  businessNo: '456-78-90123', ownerName: '조회장', managerName: '윤팀장',   managerPhone: '010-4567-8901', memo: '이틀 전 예약 필수', createdAt: '2024-03-20T09:00:00.000Z' },
  { id: 'client-005', name: '오션펜션',    type: 'pension', address: '제주특별자치도 서귀포시 중문관광로 654', phone: '064-654-9870',  businessNo: '567-89-01234', ownerName: '강대표', managerName: '임담당',   managerPhone: '010-5678-9012',                                  createdAt: '2024-04-05T09:00:00.000Z' },
];

const _towelNames   = ['대타올','중타올','소타올','목욕가운','슬리퍼타올','핸드타올','페이스타올','풀타올','짐타올','비치타올'];
const _sheetNames   = ['시트S','시트D','시트Q','시트K','두베커버S','두베커버D','두베커버Q','두베커버K','베개커버','베개커버L','매트리스커버S','매트리스커버D','매트리스커버K'];
const _uniformNames = ['상의','하의','앞치마','조끼','모자','주방복상의','주방복하의','청소복','객실복','벨복','안전조끼'];
const _catItems: Record<Exclude<LaundryCategory, 'all'>, string[]> = {
  towel: _towelNames, sheet: _sheetNames, uniform: _uniformNames,
};

function buildItems(): LaundryItem[] {
  const items: LaundryItem[] = [];
  const now = new Date().toISOString();
  const randN = (a: number, b: number) => Math.floor(Math.random() * (b - a + 1)) + a;
  const randomCounts = (): LaundryStatusCounts => {
    const c = randN(10, 60);
    return { received: 0, washing: 0, completed: c, stock: c, shipped: randN(10, 60) };
  };
  for (const c of _clients)
    for (const [cat, names] of Object.entries(_catItems) as [Exclude<LaundryCategory, 'all'>, string[]][])
      for (const name of names)
        items.push({ id: `${c.id}__${name}`, clientId: c.id, category: cat, name, counts: randomCounts(), updatedAt: now });
  return items;
}

// ── 전역 공유 상태 ($state) ───────────────────────────────────────
export const store = $state({
  clients:       _clients as Client[],
  laundryItems:  buildItems() as LaundryItem[],
  shipments:     [] as Shipment[],
  completedLogs: [] as CompletedLogEntry[],
  selectedClientId: (_clients[0]?.id ?? null) as string | null,
});

// ── 공유 액션 ─────────────────────────────────────────────────────
export function selectClient(id: string | null) {
  store.selectedClientId = id;
}

export function getItemsByCategory(clientId: string, cat: LaundryCategory): LaundryItem[] {
  const items = store.laundryItems.filter(i => i.clientId === clientId);
  return cat === 'all' ? items : items.filter(i => i.category === cat);
}

export function getTotalCompleted(clientId: string): number {
  return store.laundryItems
    .filter(i => i.clientId === clientId)
    .reduce((s, i) => s + i.counts.completed, 0);
}

export function addCompleted(clientId: string, itemId: string, delta: number) {
  const item = store.laundryItems.find(i => i.id === itemId && i.clientId === clientId);
  if (!item) return;
  const before = item.counts.completed;
  const after = Math.max(0, before + delta);
  const actualDelta = after - before;
  store.laundryItems = store.laundryItems.map(i => {
    if (i.id !== itemId || i.clientId !== clientId) return i;
    const c = { ...i.counts, completed: after };
    c.stock = calcStock(c.completed);
    return { ...i, counts: c, updatedAt: new Date().toISOString() };
  });
  store.completedLogs = [...store.completedLogs, {
    id: `log-${genId()}`, laundryItemId: itemId, clientId,
    itemName: item.name, category: item.category as Exclude<LaundryCategory, 'all'>,
    actionType: 'add', delta: actualDelta, before, after,
    createdAt: new Date().toISOString(), date: todayYMD(),
  }];
}

export function setCompleted(clientId: string, itemId: string, value: number) {
  const item = store.laundryItems.find(i => i.id === itemId && i.clientId === clientId);
  if (!item) return;
  const before = item.counts.completed;
  const after = Math.max(0, value);
  const delta = after - before;
  store.laundryItems = store.laundryItems.map(i => {
    if (i.id !== itemId || i.clientId !== clientId) return i;
    const c = { ...i.counts, completed: after };
    c.stock = calcStock(c.completed);
    return { ...i, counts: c, updatedAt: new Date().toISOString() };
  });
  store.completedLogs = [...store.completedLogs, {
    id: `log-${genId()}`, laundryItemId: itemId, clientId,
    itemName: item.name, category: item.category as Exclude<LaundryCategory, 'all'>,
    actionType: 'set', delta, before, after,
    createdAt: new Date().toISOString(), date: todayYMD(),
  }];
}

export function addLaundryItemType(clientId: string, cat: string, name: string) {
  if (store.laundryItems.some(i => i.clientId === clientId && i.name === name && i.category === cat)) return;
  store.laundryItems = [...store.laundryItems, {
    id: `${clientId}__${name}`, clientId, category: cat, name,
    counts: zeroCounts(), updatedAt: new Date().toISOString(),
  }];
}

export function addLaundryItemTypeToAll(cat: string, name: string) {
  const now = new Date().toISOString();
  const added: LaundryItem[] = [];
  for (const c of store.clients) {
    if (!store.laundryItems.some(i => i.clientId === c.id && i.name === name && i.category === cat))
      added.push({ id: `${c.id}__${name}`, clientId: c.id, category: cat, name, counts: zeroCounts(), updatedAt: now });
  }
  if (added.length > 0) store.laundryItems = [...store.laundryItems, ...added];
}

export function addShipment(s: Omit<Shipment, 'id' | 'createdAt'>): Shipment {
  const n: Shipment = { ...s, id: `ship-${genId()}`, createdAt: new Date().toISOString() };
  store.shipments = [n, ...store.shipments];
  return n;
}

export function applyShipout(clientId: string, items: { itemId: string; quantity: number }[]) {
  for (const { itemId, quantity } of items) {
    store.laundryItems = store.laundryItems.map(item => {
      if (item.id !== itemId || item.clientId !== clientId) return item;
      const nc = Math.max(0, item.counts.completed - quantity);
      const ns = item.counts.shipped + quantity;
      const c = { ...item.counts, completed: nc, shipped: ns };
      c.stock = calcStock(c.completed);
      return { ...item, counts: c, updatedAt: new Date().toISOString() };
    });
  }
}

export function updateShipment(id: string, updates: Partial<Omit<Shipment, 'id' | 'createdAt'>>) {
  store.shipments = store.shipments.map(s => s.id === id ? { ...s, ...updates } : s);
}

export function removeShipment(id: string) {
  store.shipments = store.shipments.filter(s => s.id !== id);
}
