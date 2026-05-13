drop extension if exists "pg_net";


  create table "public"."categories" (
    "id" uuid not null default gen_random_uuid(),
    "factory_id" uuid not null,
    "name" text not null,
    "sort_order" integer not null default 0,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."categories" enable row level security;


  create table "public"."clients" (
    "id" uuid not null default gen_random_uuid(),
    "factory_id" uuid not null,
    "name" text not null,
    "business_number" text,
    "email" text,
    "manager_name" text,
    "manager_phone" text,
    "contract_start_date" date,
    "contract_end_date" date,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."clients" enable row level security;


  create table "public"."factories" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "phone" text,
    "address" text,
    "created_at" timestamp with time zone not null default now(),
    "deleted_at" timestamp with time zone
      );


alter table "public"."factories" enable row level security;


  create table "public"."factory_members" (
    "id" uuid not null default gen_random_uuid(),
    "factory_id" uuid not null,
    "user_id" uuid not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."factory_members" enable row level security;


  create table "public"."inventory" (
    "id" uuid not null default gen_random_uuid(),
    "factory_id" uuid not null,
    "client_id" uuid not null,
    "item_id" uuid not null,
    "quantity" integer not null default 0,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."inventory" enable row level security;


  create table "public"."inventory_logs" (
    "id" uuid not null default gen_random_uuid(),
    "inventory_id" uuid not null,
    "factory_id" uuid not null,
    "client_id" uuid not null,
    "item_id" uuid not null,
    "log_type" text not null,
    "quantity" integer not null,
    "processed_at" timestamp with time zone not null default now(),
    "note" text,
    "created_by" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."inventory_logs" enable row level security;


  create table "public"."invoice_attachments" (
    "id" uuid not null default gen_random_uuid(),
    "invoice_id" uuid not null,
    "file_url" text not null,
    "file_name" text,
    "mime_type" text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."invoice_attachments" enable row level security;


  create table "public"."invoice_items" (
    "id" uuid not null default gen_random_uuid(),
    "invoice_id" uuid not null,
    "item_name_ko" text not null,
    "item_name_en" text,
    "item_name_zh" text,
    "category_name" text,
    "unit_price" integer not null default 0,
    "quantity" integer not null default 0,
    "amount" integer not null default 0,
    "sort_order" integer not null default 0,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."invoice_items" enable row level security;


  create table "public"."invoice_memos" (
    "id" uuid not null default gen_random_uuid(),
    "invoice_id" uuid not null,
    "title" text,
    "content" text,
    "created_by" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."invoice_memos" enable row level security;


  create table "public"."invoices" (
    "id" uuid not null default gen_random_uuid(),
    "factory_id" uuid not null,
    "client_id" uuid not null,
    "period_start" date not null,
    "period_end" date not null,
    "subtotal" integer not null default 0,
    "discount" integer not null default 0,
    "vat" integer not null default 0,
    "total" integer not null default 0,
    "status" text not null default 'draft'::text,
    "snapshot_factory" jsonb,
    "snapshot_client" jsonb,
    "created_by" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."invoices" enable row level security;


  create table "public"."item_prices" (
    "id" uuid not null default gen_random_uuid(),
    "item_id" uuid not null,
    "unit_price" integer not null default 0,
    "effective_from" date not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."item_prices" enable row level security;


  create table "public"."items" (
    "id" uuid not null default gen_random_uuid(),
    "category_id" uuid not null,
    "factory_id" uuid not null,
    "name_ko" text not null,
    "name_en" text,
    "name_zh" text,
    "nickname" text,
    "sort_order" integer not null default 0,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."items" enable row level security;


  create table "public"."profiles" (
    "id" uuid not null,
    "full_name" text,
    "role" text not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."profiles" enable row level security;

CREATE INDEX categories_factory_id_sort_order_idx ON public.categories USING btree (factory_id, sort_order);

CREATE UNIQUE INDEX categories_pkey ON public.categories USING btree (id);

CREATE INDEX clients_factory_id_idx ON public.clients USING btree (factory_id);

CREATE UNIQUE INDEX clients_pkey ON public.clients USING btree (id);

CREATE INDEX factories_deleted_at_idx ON public.factories USING btree (deleted_at);

CREATE UNIQUE INDEX factories_pkey ON public.factories USING btree (id);

CREATE INDEX factory_members_factory_id_idx ON public.factory_members USING btree (factory_id);

CREATE UNIQUE INDEX factory_members_factory_id_user_id_key ON public.factory_members USING btree (factory_id, user_id);

CREATE UNIQUE INDEX factory_members_pkey ON public.factory_members USING btree (id);

CREATE INDEX factory_members_user_id_idx ON public.factory_members USING btree (user_id);

CREATE INDEX inventory_factory_id_client_id_idx ON public.inventory USING btree (factory_id, client_id);

CREATE UNIQUE INDEX inventory_factory_id_client_id_item_id_key ON public.inventory USING btree (factory_id, client_id, item_id);

CREATE INDEX inventory_logs_factory_id_processed_at_idx ON public.inventory_logs USING btree (factory_id, processed_at);

CREATE INDEX inventory_logs_inventory_id_processed_at_idx ON public.inventory_logs USING btree (inventory_id, processed_at);

CREATE UNIQUE INDEX inventory_logs_pkey ON public.inventory_logs USING btree (id);

CREATE UNIQUE INDEX inventory_pkey ON public.inventory USING btree (id);

CREATE UNIQUE INDEX invoice_attachments_pkey ON public.invoice_attachments USING btree (id);

CREATE UNIQUE INDEX invoice_items_pkey ON public.invoice_items USING btree (id);

CREATE INDEX invoice_memos_invoice_id_idx ON public.invoice_memos USING btree (invoice_id);

CREATE UNIQUE INDEX invoice_memos_pkey ON public.invoice_memos USING btree (id);

CREATE INDEX invoices_factory_id_period_start_period_end_idx ON public.invoices USING btree (factory_id, period_start, period_end);

CREATE UNIQUE INDEX invoices_pkey ON public.invoices USING btree (id);

CREATE INDEX item_prices_item_id_effective_from_idx ON public.item_prices USING btree (item_id, effective_from DESC);

CREATE UNIQUE INDEX item_prices_pkey ON public.item_prices USING btree (id);

CREATE INDEX items_category_id_sort_order_idx ON public.items USING btree (category_id, sort_order);

CREATE INDEX items_factory_id_idx ON public.items USING btree (factory_id);

CREATE UNIQUE INDEX items_pkey ON public.items USING btree (id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

alter table "public"."categories" add constraint "categories_pkey" PRIMARY KEY using index "categories_pkey";

alter table "public"."clients" add constraint "clients_pkey" PRIMARY KEY using index "clients_pkey";

alter table "public"."factories" add constraint "factories_pkey" PRIMARY KEY using index "factories_pkey";

alter table "public"."factory_members" add constraint "factory_members_pkey" PRIMARY KEY using index "factory_members_pkey";

alter table "public"."inventory" add constraint "inventory_pkey" PRIMARY KEY using index "inventory_pkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_pkey" PRIMARY KEY using index "inventory_logs_pkey";

alter table "public"."invoice_attachments" add constraint "invoice_attachments_pkey" PRIMARY KEY using index "invoice_attachments_pkey";

alter table "public"."invoice_items" add constraint "invoice_items_pkey" PRIMARY KEY using index "invoice_items_pkey";

alter table "public"."invoice_memos" add constraint "invoice_memos_pkey" PRIMARY KEY using index "invoice_memos_pkey";

alter table "public"."invoices" add constraint "invoices_pkey" PRIMARY KEY using index "invoices_pkey";

alter table "public"."item_prices" add constraint "item_prices_pkey" PRIMARY KEY using index "item_prices_pkey";

alter table "public"."items" add constraint "items_pkey" PRIMARY KEY using index "items_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."categories" add constraint "categories_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."categories" validate constraint "categories_factory_id_fkey";

alter table "public"."clients" add constraint "clients_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."clients" validate constraint "clients_factory_id_fkey";

alter table "public"."factory_members" add constraint "factory_members_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."factory_members" validate constraint "factory_members_factory_id_fkey";

alter table "public"."factory_members" add constraint "factory_members_factory_id_user_id_key" UNIQUE using index "factory_members_factory_id_user_id_key";

alter table "public"."factory_members" add constraint "factory_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."factory_members" validate constraint "factory_members_user_id_fkey";

alter table "public"."inventory" add constraint "inventory_client_id_fkey" FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE not valid;

alter table "public"."inventory" validate constraint "inventory_client_id_fkey";

alter table "public"."inventory" add constraint "inventory_factory_id_client_id_item_id_key" UNIQUE using index "inventory_factory_id_client_id_item_id_key";

alter table "public"."inventory" add constraint "inventory_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."inventory" validate constraint "inventory_factory_id_fkey";

alter table "public"."inventory" add constraint "inventory_item_id_fkey" FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE not valid;

alter table "public"."inventory" validate constraint "inventory_item_id_fkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_client_id_fkey" FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_client_id_fkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_created_by_fkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_factory_id_fkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_inventory_id_fkey" FOREIGN KEY (inventory_id) REFERENCES public.inventory(id) ON DELETE CASCADE not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_inventory_id_fkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_item_id_fkey" FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_item_id_fkey";

alter table "public"."inventory_logs" add constraint "inventory_logs_log_type_check" CHECK ((log_type = ANY (ARRAY['in'::text, 'out'::text]))) not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_log_type_check";

alter table "public"."inventory_logs" add constraint "inventory_logs_quantity_check" CHECK ((quantity > 0)) not valid;

alter table "public"."inventory_logs" validate constraint "inventory_logs_quantity_check";

alter table "public"."invoice_attachments" add constraint "invoice_attachments_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."invoice_attachments" validate constraint "invoice_attachments_invoice_id_fkey";

alter table "public"."invoice_items" add constraint "invoice_items_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."invoice_items" validate constraint "invoice_items_invoice_id_fkey";

alter table "public"."invoice_memos" add constraint "invoice_memos_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) not valid;

alter table "public"."invoice_memos" validate constraint "invoice_memos_created_by_fkey";

alter table "public"."invoice_memos" add constraint "invoice_memos_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."invoice_memos" validate constraint "invoice_memos_invoice_id_fkey";

alter table "public"."invoices" add constraint "invoices_client_id_fkey" FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE not valid;

alter table "public"."invoices" validate constraint "invoices_client_id_fkey";

alter table "public"."invoices" add constraint "invoices_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) not valid;

alter table "public"."invoices" validate constraint "invoices_created_by_fkey";

alter table "public"."invoices" add constraint "invoices_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."invoices" validate constraint "invoices_factory_id_fkey";

alter table "public"."invoices" add constraint "invoices_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'sent'::text, 'paid'::text]))) not valid;

alter table "public"."invoices" validate constraint "invoices_status_check";

alter table "public"."item_prices" add constraint "item_prices_item_id_fkey" FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE not valid;

alter table "public"."item_prices" validate constraint "item_prices_item_id_fkey";

alter table "public"."items" add constraint "items_category_id_fkey" FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE not valid;

alter table "public"."items" validate constraint "items_category_id_fkey";

alter table "public"."items" add constraint "items_factory_id_fkey" FOREIGN KEY (factory_id) REFERENCES public.factories(id) ON DELETE CASCADE not valid;

alter table "public"."items" validate constraint "items_factory_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_role_check" CHECK ((role = ANY (ARRAY['super_admin'::text, 'factory_admin'::text, 'worker'::text]))) not valid;

alter table "public"."profiles" validate constraint "profiles_role_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_unit_price(p_item_id uuid, p_date date)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
  select unit_price
  from public.item_prices
  where item_id = p_item_id
    and effective_from <= p_date
  order by effective_from desc
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.is_factory_member(p_factory_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  select exists (
    select 1 from public.factory_members
    where factory_id = p_factory_id and user_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION public.my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  select role from public.profiles where id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.process_inventory_out(p_inventory_id uuid, p_quantity integer, p_created_by uuid, p_note text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_current_qty   int;
  v_factory_id    uuid;
  v_client_id     uuid;
  v_item_id       uuid;
begin
  -- 1. 해당 행을 잠금 (다른 트랜잭션은 여기서 대기)
  select quantity, factory_id, client_id, item_id
  into v_current_qty, v_factory_id, v_client_id, v_item_id
  from public.inventory
  where id = p_inventory_id
  for update;  -- 🔒 핵심

  -- 2. 재고 부족 체크
  if v_current_qty < p_quantity then
    raise exception '재고 부족: 현재 % 개, 요청 % 개', v_current_qty, p_quantity;
  end if;

  -- 3. 재고 차감
  update public.inventory
  set quantity   = quantity - p_quantity,
      updated_at = now()
  where id = p_inventory_id;

  -- 4. 로그 기록
  insert into public.inventory_logs (
    inventory_id, factory_id, client_id, item_id,
    log_type, quantity, created_by, note
  ) values (
    p_inventory_id, v_factory_id, v_client_id, v_item_id,
    'out', p_quantity, p_created_by, p_note
  );

  return json_build_object('success', true, 'remaining', v_current_qty - p_quantity);

exception
  when others then
    -- 트랜잭션 자동 롤백됨
    return json_build_object('success', false, 'error', sqlerrm);
end;
$function$
;

grant delete on table "public"."categories" to "anon";

grant insert on table "public"."categories" to "anon";

grant references on table "public"."categories" to "anon";

grant select on table "public"."categories" to "anon";

grant trigger on table "public"."categories" to "anon";

grant truncate on table "public"."categories" to "anon";

grant update on table "public"."categories" to "anon";

grant delete on table "public"."categories" to "authenticated";

grant insert on table "public"."categories" to "authenticated";

grant references on table "public"."categories" to "authenticated";

grant select on table "public"."categories" to "authenticated";

grant trigger on table "public"."categories" to "authenticated";

grant truncate on table "public"."categories" to "authenticated";

grant update on table "public"."categories" to "authenticated";

grant delete on table "public"."categories" to "service_role";

grant insert on table "public"."categories" to "service_role";

grant references on table "public"."categories" to "service_role";

grant select on table "public"."categories" to "service_role";

grant trigger on table "public"."categories" to "service_role";

grant truncate on table "public"."categories" to "service_role";

grant update on table "public"."categories" to "service_role";

grant delete on table "public"."clients" to "anon";

grant insert on table "public"."clients" to "anon";

grant references on table "public"."clients" to "anon";

grant select on table "public"."clients" to "anon";

grant trigger on table "public"."clients" to "anon";

grant truncate on table "public"."clients" to "anon";

grant update on table "public"."clients" to "anon";

grant delete on table "public"."clients" to "authenticated";

grant insert on table "public"."clients" to "authenticated";

grant references on table "public"."clients" to "authenticated";

grant select on table "public"."clients" to "authenticated";

grant trigger on table "public"."clients" to "authenticated";

grant truncate on table "public"."clients" to "authenticated";

grant update on table "public"."clients" to "authenticated";

grant delete on table "public"."clients" to "service_role";

grant insert on table "public"."clients" to "service_role";

grant references on table "public"."clients" to "service_role";

grant select on table "public"."clients" to "service_role";

grant trigger on table "public"."clients" to "service_role";

grant truncate on table "public"."clients" to "service_role";

grant update on table "public"."clients" to "service_role";

grant delete on table "public"."factories" to "anon";

grant insert on table "public"."factories" to "anon";

grant references on table "public"."factories" to "anon";

grant select on table "public"."factories" to "anon";

grant trigger on table "public"."factories" to "anon";

grant truncate on table "public"."factories" to "anon";

grant update on table "public"."factories" to "anon";

grant delete on table "public"."factories" to "authenticated";

grant insert on table "public"."factories" to "authenticated";

grant references on table "public"."factories" to "authenticated";

grant select on table "public"."factories" to "authenticated";

grant trigger on table "public"."factories" to "authenticated";

grant truncate on table "public"."factories" to "authenticated";

grant update on table "public"."factories" to "authenticated";

grant delete on table "public"."factories" to "service_role";

grant insert on table "public"."factories" to "service_role";

grant references on table "public"."factories" to "service_role";

grant select on table "public"."factories" to "service_role";

grant trigger on table "public"."factories" to "service_role";

grant truncate on table "public"."factories" to "service_role";

grant update on table "public"."factories" to "service_role";

grant delete on table "public"."factory_members" to "anon";

grant insert on table "public"."factory_members" to "anon";

grant references on table "public"."factory_members" to "anon";

grant select on table "public"."factory_members" to "anon";

grant trigger on table "public"."factory_members" to "anon";

grant truncate on table "public"."factory_members" to "anon";

grant update on table "public"."factory_members" to "anon";

grant delete on table "public"."factory_members" to "authenticated";

grant insert on table "public"."factory_members" to "authenticated";

grant references on table "public"."factory_members" to "authenticated";

grant select on table "public"."factory_members" to "authenticated";

grant trigger on table "public"."factory_members" to "authenticated";

grant truncate on table "public"."factory_members" to "authenticated";

grant update on table "public"."factory_members" to "authenticated";

grant delete on table "public"."factory_members" to "service_role";

grant insert on table "public"."factory_members" to "service_role";

grant references on table "public"."factory_members" to "service_role";

grant select on table "public"."factory_members" to "service_role";

grant trigger on table "public"."factory_members" to "service_role";

grant truncate on table "public"."factory_members" to "service_role";

grant update on table "public"."factory_members" to "service_role";

grant delete on table "public"."inventory" to "anon";

grant insert on table "public"."inventory" to "anon";

grant references on table "public"."inventory" to "anon";

grant select on table "public"."inventory" to "anon";

grant trigger on table "public"."inventory" to "anon";

grant truncate on table "public"."inventory" to "anon";

grant update on table "public"."inventory" to "anon";

grant delete on table "public"."inventory" to "authenticated";

grant insert on table "public"."inventory" to "authenticated";

grant references on table "public"."inventory" to "authenticated";

grant select on table "public"."inventory" to "authenticated";

grant trigger on table "public"."inventory" to "authenticated";

grant truncate on table "public"."inventory" to "authenticated";

grant update on table "public"."inventory" to "authenticated";

grant delete on table "public"."inventory" to "service_role";

grant insert on table "public"."inventory" to "service_role";

grant references on table "public"."inventory" to "service_role";

grant select on table "public"."inventory" to "service_role";

grant trigger on table "public"."inventory" to "service_role";

grant truncate on table "public"."inventory" to "service_role";

grant update on table "public"."inventory" to "service_role";

grant delete on table "public"."inventory_logs" to "anon";

grant insert on table "public"."inventory_logs" to "anon";

grant references on table "public"."inventory_logs" to "anon";

grant select on table "public"."inventory_logs" to "anon";

grant trigger on table "public"."inventory_logs" to "anon";

grant truncate on table "public"."inventory_logs" to "anon";

grant update on table "public"."inventory_logs" to "anon";

grant delete on table "public"."inventory_logs" to "authenticated";

grant insert on table "public"."inventory_logs" to "authenticated";

grant references on table "public"."inventory_logs" to "authenticated";

grant select on table "public"."inventory_logs" to "authenticated";

grant trigger on table "public"."inventory_logs" to "authenticated";

grant truncate on table "public"."inventory_logs" to "authenticated";

grant update on table "public"."inventory_logs" to "authenticated";

grant delete on table "public"."inventory_logs" to "service_role";

grant insert on table "public"."inventory_logs" to "service_role";

grant references on table "public"."inventory_logs" to "service_role";

grant select on table "public"."inventory_logs" to "service_role";

grant trigger on table "public"."inventory_logs" to "service_role";

grant truncate on table "public"."inventory_logs" to "service_role";

grant update on table "public"."inventory_logs" to "service_role";

grant delete on table "public"."invoice_attachments" to "anon";

grant insert on table "public"."invoice_attachments" to "anon";

grant references on table "public"."invoice_attachments" to "anon";

grant select on table "public"."invoice_attachments" to "anon";

grant trigger on table "public"."invoice_attachments" to "anon";

grant truncate on table "public"."invoice_attachments" to "anon";

grant update on table "public"."invoice_attachments" to "anon";

grant delete on table "public"."invoice_attachments" to "authenticated";

grant insert on table "public"."invoice_attachments" to "authenticated";

grant references on table "public"."invoice_attachments" to "authenticated";

grant select on table "public"."invoice_attachments" to "authenticated";

grant trigger on table "public"."invoice_attachments" to "authenticated";

grant truncate on table "public"."invoice_attachments" to "authenticated";

grant update on table "public"."invoice_attachments" to "authenticated";

grant delete on table "public"."invoice_attachments" to "service_role";

grant insert on table "public"."invoice_attachments" to "service_role";

grant references on table "public"."invoice_attachments" to "service_role";

grant select on table "public"."invoice_attachments" to "service_role";

grant trigger on table "public"."invoice_attachments" to "service_role";

grant truncate on table "public"."invoice_attachments" to "service_role";

grant update on table "public"."invoice_attachments" to "service_role";

grant delete on table "public"."invoice_items" to "anon";

grant insert on table "public"."invoice_items" to "anon";

grant references on table "public"."invoice_items" to "anon";

grant select on table "public"."invoice_items" to "anon";

grant trigger on table "public"."invoice_items" to "anon";

grant truncate on table "public"."invoice_items" to "anon";

grant update on table "public"."invoice_items" to "anon";

grant delete on table "public"."invoice_items" to "authenticated";

grant insert on table "public"."invoice_items" to "authenticated";

grant references on table "public"."invoice_items" to "authenticated";

grant select on table "public"."invoice_items" to "authenticated";

grant trigger on table "public"."invoice_items" to "authenticated";

grant truncate on table "public"."invoice_items" to "authenticated";

grant update on table "public"."invoice_items" to "authenticated";

grant delete on table "public"."invoice_items" to "service_role";

grant insert on table "public"."invoice_items" to "service_role";

grant references on table "public"."invoice_items" to "service_role";

grant select on table "public"."invoice_items" to "service_role";

grant trigger on table "public"."invoice_items" to "service_role";

grant truncate on table "public"."invoice_items" to "service_role";

grant update on table "public"."invoice_items" to "service_role";

grant delete on table "public"."invoice_memos" to "anon";

grant insert on table "public"."invoice_memos" to "anon";

grant references on table "public"."invoice_memos" to "anon";

grant select on table "public"."invoice_memos" to "anon";

grant trigger on table "public"."invoice_memos" to "anon";

grant truncate on table "public"."invoice_memos" to "anon";

grant update on table "public"."invoice_memos" to "anon";

grant delete on table "public"."invoice_memos" to "authenticated";

grant insert on table "public"."invoice_memos" to "authenticated";

grant references on table "public"."invoice_memos" to "authenticated";

grant select on table "public"."invoice_memos" to "authenticated";

grant trigger on table "public"."invoice_memos" to "authenticated";

grant truncate on table "public"."invoice_memos" to "authenticated";

grant update on table "public"."invoice_memos" to "authenticated";

grant delete on table "public"."invoice_memos" to "service_role";

grant insert on table "public"."invoice_memos" to "service_role";

grant references on table "public"."invoice_memos" to "service_role";

grant select on table "public"."invoice_memos" to "service_role";

grant trigger on table "public"."invoice_memos" to "service_role";

grant truncate on table "public"."invoice_memos" to "service_role";

grant update on table "public"."invoice_memos" to "service_role";

grant delete on table "public"."invoices" to "anon";

grant insert on table "public"."invoices" to "anon";

grant references on table "public"."invoices" to "anon";

grant select on table "public"."invoices" to "anon";

grant trigger on table "public"."invoices" to "anon";

grant truncate on table "public"."invoices" to "anon";

grant update on table "public"."invoices" to "anon";

grant delete on table "public"."invoices" to "authenticated";

grant insert on table "public"."invoices" to "authenticated";

grant references on table "public"."invoices" to "authenticated";

grant select on table "public"."invoices" to "authenticated";

grant trigger on table "public"."invoices" to "authenticated";

grant truncate on table "public"."invoices" to "authenticated";

grant update on table "public"."invoices" to "authenticated";

grant delete on table "public"."invoices" to "service_role";

grant insert on table "public"."invoices" to "service_role";

grant references on table "public"."invoices" to "service_role";

grant select on table "public"."invoices" to "service_role";

grant trigger on table "public"."invoices" to "service_role";

grant truncate on table "public"."invoices" to "service_role";

grant update on table "public"."invoices" to "service_role";

grant delete on table "public"."item_prices" to "anon";

grant insert on table "public"."item_prices" to "anon";

grant references on table "public"."item_prices" to "anon";

grant select on table "public"."item_prices" to "anon";

grant trigger on table "public"."item_prices" to "anon";

grant truncate on table "public"."item_prices" to "anon";

grant update on table "public"."item_prices" to "anon";

grant delete on table "public"."item_prices" to "authenticated";

grant insert on table "public"."item_prices" to "authenticated";

grant references on table "public"."item_prices" to "authenticated";

grant select on table "public"."item_prices" to "authenticated";

grant trigger on table "public"."item_prices" to "authenticated";

grant truncate on table "public"."item_prices" to "authenticated";

grant update on table "public"."item_prices" to "authenticated";

grant delete on table "public"."item_prices" to "service_role";

grant insert on table "public"."item_prices" to "service_role";

grant references on table "public"."item_prices" to "service_role";

grant select on table "public"."item_prices" to "service_role";

grant trigger on table "public"."item_prices" to "service_role";

grant truncate on table "public"."item_prices" to "service_role";

grant update on table "public"."item_prices" to "service_role";

grant delete on table "public"."items" to "anon";

grant insert on table "public"."items" to "anon";

grant references on table "public"."items" to "anon";

grant select on table "public"."items" to "anon";

grant trigger on table "public"."items" to "anon";

grant truncate on table "public"."items" to "anon";

grant update on table "public"."items" to "anon";

grant delete on table "public"."items" to "authenticated";

grant insert on table "public"."items" to "authenticated";

grant references on table "public"."items" to "authenticated";

grant select on table "public"."items" to "authenticated";

grant trigger on table "public"."items" to "authenticated";

grant truncate on table "public"."items" to "authenticated";

grant update on table "public"."items" to "authenticated";

grant delete on table "public"."items" to "service_role";

grant insert on table "public"."items" to "service_role";

grant references on table "public"."items" to "service_role";

grant select on table "public"."items" to "service_role";

grant trigger on table "public"."items" to "service_role";

grant truncate on table "public"."items" to "service_role";

grant update on table "public"."items" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";


  create policy "categories_delete"
  on "public"."categories"
  as permissive
  for delete
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "categories_insert"
  on "public"."categories"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "categories_select"
  on "public"."categories"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "categories_update"
  on "public"."categories"
  as permissive
  for update
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "clients_delete"
  on "public"."clients"
  as permissive
  for delete
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "clients_insert"
  on "public"."clients"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "clients_select"
  on "public"."clients"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "clients_update"
  on "public"."clients"
  as permissive
  for update
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "factories_delete"
  on "public"."factories"
  as permissive
  for delete
  to public
using ((public.my_role() = 'super_admin'::text));



  create policy "factories_insert"
  on "public"."factories"
  as permissive
  for insert
  to public
with check ((public.my_role() = 'super_admin'::text));



  create policy "factories_select"
  on "public"."factories"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(id)));



  create policy "factories_update"
  on "public"."factories"
  as permissive
  for update
  to public
using ((public.my_role() = 'super_admin'::text));



  create policy "factory_members_delete"
  on "public"."factory_members"
  as permissive
  for delete
  to public
using ((public.my_role() = 'super_admin'::text));



  create policy "factory_members_insert"
  on "public"."factory_members"
  as permissive
  for insert
  to public
with check ((public.my_role() = 'super_admin'::text));



  create policy "factory_members_select"
  on "public"."factory_members"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR (user_id = auth.uid())));



  create policy "inventory_insert"
  on "public"."inventory"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "inventory_select"
  on "public"."inventory"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "inventory_update"
  on "public"."inventory"
  as permissive
  for update
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "inventory_logs_insert"
  on "public"."inventory_logs"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "inventory_logs_select"
  on "public"."inventory_logs"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "invoice_attachments_insert"
  on "public"."invoice_attachments"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_attachments.invoice_id) AND (public.my_role() = 'factory_admin'::text) AND public.is_factory_member(inv.factory_id))))));



  create policy "invoice_attachments_select"
  on "public"."invoice_attachments"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_attachments.invoice_id) AND public.is_factory_member(inv.factory_id))))));



  create policy "invoice_items_insert"
  on "public"."invoice_items"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_items.invoice_id) AND public.is_factory_member(inv.factory_id))))));



  create policy "invoice_items_select"
  on "public"."invoice_items"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_items.invoice_id) AND public.is_factory_member(inv.factory_id))))));



  create policy "invoice_memos_insert"
  on "public"."invoice_memos"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM public.invoices
  WHERE (invoices.id = invoice_memos.invoice_id))));



  create policy "invoice_memos_select"
  on "public"."invoice_memos"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.invoices inv
  WHERE ((inv.id = invoice_memos.invoice_id) AND public.is_factory_member(inv.factory_id))))));



  create policy "invoices_insert"
  on "public"."invoices"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "invoices_select"
  on "public"."invoices"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "invoices_update"
  on "public"."invoices"
  as permissive
  for update
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "item_prices_insert"
  on "public"."item_prices"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.items i
  WHERE ((i.id = item_prices.item_id) AND (public.my_role() = 'factory_admin'::text) AND public.is_factory_member(i.factory_id))))));



  create policy "item_prices_select"
  on "public"."item_prices"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.items i
  WHERE ((i.id = item_prices.item_id) AND public.is_factory_member(i.factory_id))))));



  create policy "item_prices_update"
  on "public"."item_prices"
  as permissive
  for update
  to public
using (((public.my_role() = 'super_admin'::text) OR (EXISTS ( SELECT 1
   FROM public.items i
  WHERE ((i.id = item_prices.item_id) AND (public.my_role() = 'factory_admin'::text) AND public.is_factory_member(i.factory_id))))));



  create policy "items_delete"
  on "public"."items"
  as permissive
  for delete
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "items_insert"
  on "public"."items"
  as permissive
  for insert
  to public
with check (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "items_select"
  on "public"."items"
  as permissive
  for select
  to public
using (((public.my_role() = 'super_admin'::text) OR public.is_factory_member(factory_id)));



  create policy "items_update"
  on "public"."items"
  as permissive
  for update
  to public
using (((public.my_role() = 'super_admin'::text) OR ((public.my_role() = 'factory_admin'::text) AND public.is_factory_member(factory_id))));



  create policy "profiles_select"
  on "public"."profiles"
  as permissive
  for select
  to public
using (((id = auth.uid()) OR (public.my_role() = 'super_admin'::text)));



  create policy "profiles_update_self"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((id = auth.uid()));



