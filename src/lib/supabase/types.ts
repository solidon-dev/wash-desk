/**
 * Supabase 타입 레퍼
 *
 * database.types.ts 에 자동 생성된 헬퍼 타입을 그대로 활용합니다.
 * 외부에서는 이 파일만 임포트해서 사용하세요.
 *
 * @example
 * import type { Invoice, InvoiceInsert, ProcessInventoryOutArgs } from '$lib/supabase/types';
 */

import type { Database, Tables, TablesInsert, TablesUpdate, Enums } from './database.types';

export type { Database, Tables, TablesInsert, TablesUpdate, Enums };

// ----------------------------------------------------------------
// Enum 타입
// ----------------------------------------------------------------

export type UserRole = Enums<'user_role'>; // 'super_admin' | 'factory_admin' | 'worker'
export type LogType  = Enums<'log_type'>;  // 'in' | 'out'

// ----------------------------------------------------------------
// 테이블 Row 타입 (SELECT 결과)
// ----------------------------------------------------------------

export type Category         = Tables<'categories'>;
export type Client           = Tables<'clients'>;
export type Factory          = Tables<'factories'>;
export type FactoryMember    = Tables<'factory_members'>;
export type Inventory        = Tables<'inventory'>;
export type InventoryLog     = Tables<'inventory_logs'>;
export type InvoiceAttachment = Tables<'invoice_attachments'>;
export type InvoiceItem      = Tables<'invoice_items'>;
export type InvoiceMemo      = Tables<'invoice_memos'>;
export type Invoice          = Tables<'invoices'>;
export type ItemPrice        = Tables<'item_prices'>;
export type Item             = Tables<'items'>;
export type Profile          = Tables<'profiles'>;

// ----------------------------------------------------------------
// 테이블 Insert 타입
// ----------------------------------------------------------------

export type CategoryInsert          = TablesInsert<'categories'>;
export type ClientInsert            = TablesInsert<'clients'>;
export type FactoryInsert           = TablesInsert<'factories'>;
export type FactoryMemberInsert     = TablesInsert<'factory_members'>;
export type InventoryInsert         = TablesInsert<'inventory'>;
export type InventoryLogInsert      = TablesInsert<'inventory_logs'>;
export type InvoiceAttachmentInsert = TablesInsert<'invoice_attachments'>;
export type InvoiceItemInsert       = TablesInsert<'invoice_items'>;
export type InvoiceMemoInsert       = TablesInsert<'invoice_memos'>;
export type InvoiceInsert           = TablesInsert<'invoices'>;
export type ItemPriceInsert         = TablesInsert<'item_prices'>;
export type ItemInsert              = TablesInsert<'items'>;
export type ProfileInsert           = TablesInsert<'profiles'>;

// ----------------------------------------------------------------
// 테이블 Update 타입
// ----------------------------------------------------------------

export type CategoryUpdate          = TablesUpdate<'categories'>;
export type ClientUpdate            = TablesUpdate<'clients'>;
export type FactoryUpdate           = TablesUpdate<'factories'>;
export type FactoryMemberUpdate     = TablesUpdate<'factory_members'>;
export type InventoryUpdate         = TablesUpdate<'inventory'>;
export type InventoryLogUpdate      = TablesUpdate<'inventory_logs'>;
export type InvoiceAttachmentUpdate = TablesUpdate<'invoice_attachments'>;
export type InvoiceItemUpdate       = TablesUpdate<'invoice_items'>;
export type InvoiceMemoUpdate       = TablesUpdate<'invoice_memos'>;
export type InvoiceUpdate           = TablesUpdate<'invoices'>;
export type ItemPriceUpdate         = TablesUpdate<'item_prices'>;
export type ItemUpdate              = TablesUpdate<'items'>;
export type ProfileUpdate           = TablesUpdate<'profiles'>;

// ----------------------------------------------------------------
// RPC 함수 타입
// ----------------------------------------------------------------

type Functions = Database['public']['Functions'];

/** RPC 함수 인자 타입 */
export type RpcArgs<T extends keyof Functions>     = Functions[T]['Args'];

/** RPC 함수 반환 타입 */
export type RpcReturns<T extends keyof Functions>  = Functions[T]['Returns'];

// RPC 함수별 명시적 alias
export type GetUnitPriceArgs          = RpcArgs<'get_unit_price'>;
export type GetUnitPriceReturns       = RpcReturns<'get_unit_price'>;

export type IsFactoryMemberArgs       = RpcArgs<'is_factory_member'>;
export type IsFactoryMemberReturns    = RpcReturns<'is_factory_member'>;

export type MyRoleReturns             = RpcReturns<'my_role'>;

export type ProcessInventoryOutArgs    = RpcArgs<'process_inventory_out'>;
export type ProcessInventoryOutReturns = RpcReturns<'process_inventory_out'>;

export type CreateItemWithPriceArgs    = RpcArgs<'create_item_with_price'>;
export type CreateItemWithPriceReturns = RpcReturns<'create_item_with_price'>;
