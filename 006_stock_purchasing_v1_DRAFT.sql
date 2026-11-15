-- CREDO STOCK AND PURCHASING V1  (revision 3)
-- DRAFT ONLY. DO NOT APPLY TO PRODUCTION. For an isolated development database only.
--
-- Dependencies that are NOT created here and must exist first (preflight below refuses otherwise):
--   public.businesses(id uuid, unique/primary key)
--   public.current_business_ids()  returning SETOF uuid, no arguments
--   public.is_admin()              returning boolean, no arguments
-- This file does not modify or delete any existing table or row. It is a one shot migration:
-- if any object it creates already exists it stops, it never skips silently.
--
-- LOCKING AND TRANSACTION RULES (enforced by trigger code, not by convention)
--   Row lock    : every ledger write locks the item row, FOR NO KEY UPDATE, in a BEFORE INSERT trigger
--                 (purchase_records, stock_movements, stock_snapshots). NO KEY UPDATE, not UPDATE, because
--                 foreign key checks take KEY SHARE on the item row and FOR UPDATE could deadlock against them.
--   One item    : a transaction may post stock for ONE inventory item only. public.stock_enter_item() takes a
--                 transaction scoped advisory lock (namespace 1129465156, key hashtext(item id)) before the row
--                 lock and RAISES if this backend already holds that namespace lock for a different item.
--                 With one item per transaction no wait cycle between items can form, so multi item deadlocks
--                 are impossible by construction. The marker cannot be released by the client: transaction
--                 scoped advisory locks are not freed by pg_advisory_unlock*, and a client cannot clear them.
--                 Exception: creating an item with an opening quantity does not take the marker (the new item row
--                 is invisible to every other session, so nobody can wait on it). Bulk item creation is allowed.
--   Isolation   : only READ COMMITTED is supported. stock_enter_item() raises under REPEATABLE READ and
--                 SERIALIZABLE, because there the balance query would run on a snapshot taken before the lock
--                 was granted and could miss committed movements (reproduced on revision 2).
--   Atomicity   : all ledger writes are in the statement or transaction of the caller; any failure rolls back
--                 the purchase, its movement, the snapshot and its correction together.
--   Multi item work (a stocktake of many items) is posted one item per request, or by a future batch function
--   that locks items in ascending id order. Revision 3 deliberately does not ship that function.

begin;

-- ---------------------------------------------------------------- preflight
do $$
declare
  v_missing text[] := '{}';
begin
  if not exists (
    select 1 from pg_index x
    join pg_class c on c.oid = x.indrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum = x.indkey[0]
    where n.nspname = 'public' and c.relname = 'businesses'
      and x.indisunique and x.indnatts = 1 and a.attname = 'id' and a.atttypid = 'uuid'::regtype
  ) then v_missing := array_append(v_missing, 'public.businesses(id uuid) with a unique or primary key index'::text); end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'current_business_ids' and p.pronargs = 0
      and p.proretset and p.prorettype = 'uuid'::regtype
  ) then v_missing := array_append(v_missing, 'public.current_business_ids() returning SETOF uuid'::text); end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_admin' and p.pronargs = 0
      and not p.proretset and p.prorettype = 'boolean'::regtype
  ) then v_missing := array_append(v_missing, 'public.is_admin() returning boolean'::text); end if;

  if to_regclass('public.inventory_items') is not null
     or to_regclass('public.purchase_records') is not null
     or to_regclass('public.stock_movements') is not null
     or to_regclass('public.stock_snapshots') is not null
     or to_regclass('public.stock_balances') is not null then
    v_missing := array_append(v_missing, 'NO existing inventory_items, purchase_records, stock_movements, stock_snapshots or stock_balances (already present)'::text);
  end if;

  if cardinality(v_missing) > 0 then
    raise exception 'Stock V1 preflight failed. Problems: %', array_to_string(v_missing, '; ');
  end if;
end;
$$;

-- ---------------------------------------------------------------- tables
create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  item_name text not null check (length(trim(item_name)) between 1 and 120),
  category text check (category is null or length(category) <= 80),
  unit text not null default 'unit' check (length(trim(unit)) between 1 and 40),
  opening_quantity numeric(14,3) not null default 0 check (opening_quantity >= 0),
  minimum_quantity numeric(14,3) not null default 0 check (minimum_quantity >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, business_id),
  unique (business_id, item_name)
);

create table public.purchase_records (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  inventory_item_id uuid not null,
  quantity numeric(14,3) not null check (quantity > 0),
  total_cost numeric(14,2) not null check (total_cost >= 0),
  supplier_name text check (supplier_name is null or length(supplier_name) <= 200),
  purchase_date date not null default ((now() at time zone 'Africa/Johannesburg')::date),
  notes text check (notes is null or length(notes) <= 1000),
  client_request_id uuid,
  created_at timestamptz not null default now(),
  unique (id, business_id, inventory_item_id),
  unique (business_id, client_request_id),
  constraint purchase_item_business_fk
    foreign key (inventory_item_id, business_id)
    references public.inventory_items(id, business_id) on delete restrict
);

create table public.stock_snapshots (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  inventory_item_id uuid not null,
  counted_quantity numeric(14,3) not null check (counted_quantity >= 0),
  expected_quantity numeric(14,3) not null,
  variance numeric(14,3) not null,
  counted_at timestamptz not null default now(),
  notes text check (notes is null or length(notes) <= 1000),
  client_request_id uuid,
  created_at timestamptz not null default now(),
  unique (id, business_id, inventory_item_id),
  unique (business_id, client_request_id),
  constraint snapshot_item_business_fk
    foreign key (inventory_item_id, business_id)
    references public.inventory_items(id, business_id) on delete restrict
);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  inventory_item_id uuid not null,
  movement_type text not null check (movement_type in (
    'opening','purchase','sale','usage','waste','damage',
    'complimentary','internal_use','adjustment_in','adjustment_out',
    'count_correction'
  )),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  purchase_record_id uuid unique,
  stock_snapshot_id uuid unique,
  movement_date timestamptz not null default now(),
  notes text check (notes is null or length(notes) <= 1000),
  client_request_id uuid,
  created_at timestamptz not null default now(),
  unique (business_id, client_request_id),
  constraint movement_item_business_fk
    foreign key (inventory_item_id, business_id)
    references public.inventory_items(id, business_id) on delete restrict,
  constraint movement_purchase_fk
    foreign key (purchase_record_id, business_id, inventory_item_id)
    references public.purchase_records(id, business_id, inventory_item_id) on delete restrict,
  constraint movement_snapshot_fk
    foreign key (stock_snapshot_id, business_id, inventory_item_id)
    references public.stock_snapshots(id, business_id, inventory_item_id) on delete restrict
    deferrable initially deferred,   -- the correction is posted from the snapshot BEFORE trigger, before the snapshot row exists
  constraint movement_sign_ck check (
    (movement_type in ('opening','purchase','adjustment_in') and quantity_delta > 0)
    or (movement_type in ('sale','usage','waste','damage','complimentary','internal_use','adjustment_out') and quantity_delta < 0)
    or movement_type = 'count_correction'
  ),
  constraint movement_link_ck check (
    (movement_type = 'purchase'         and purchase_record_id is not null and stock_snapshot_id is null)
    or (movement_type = 'count_correction' and stock_snapshot_id is not null and purchase_record_id is null)
    or (movement_type not in ('purchase','count_correction') and purchase_record_id is null and stock_snapshot_id is null)
  ),
  constraint movement_adjustment_reason_ck check (
    movement_type not in ('adjustment_in','adjustment_out') or length(trim(coalesce(notes, ''))) > 0
  )
);

create unique index stock_one_opening_per_item
  on public.stock_movements(inventory_item_id) where movement_type = 'opening';
create index stock_movements_item_idx on public.stock_movements(inventory_item_id, business_id);
create index purchase_records_item_idx on public.purchase_records(inventory_item_id, business_id);
create index stock_snapshots_item_idx on public.stock_snapshots(inventory_item_id, business_id);

-- ---------------------------------------------------------------- functions
-- Plain (invoker) helpers: no table reads.
create function public.stock_set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function public.stock_guard_item_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id is distinct from old.id
     or new.business_id is distinct from old.business_id
     or new.opening_quantity is distinct from old.opening_quantity
     or new.created_at is distinct from old.created_at then
    raise exception 'id, business_id, opening_quantity and created_at of an inventory item cannot be changed; post an adjustment movement instead';
  end if;
  return new;
end;
$$;

create function public.stock_reject_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception '% is append only: % is not allowed', tg_table_name, tg_op;
end;
$$;

-- Concurrency gate. Plain invoker function, called only from the SECURITY DEFINER triggers below.
create function public.stock_enter_item(p_item uuid)
returns void language plpgsql set search_path = '' as $$
declare
  c_ns constant integer := 1129465156;            -- 0x43524544, our advisory lock namespace
  v_key integer := hashtext(p_item::text);
  v_other integer;
begin
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'Stock postings require READ COMMITTED isolation; this transaction is %', current_setting('transaction_isolation')
      using errcode = '25000';
  end if;
  select count(*) into v_other
    from pg_catalog.pg_locks l
   where l.pid = pg_catalog.pg_backend_pid() and l.locktype = 'advisory' and l.granted
     and l.objsubid = 2 and l.classid::bigint = c_ns
     and l.objid::bigint <> (v_key::bigint & 4294967295);
  if v_other > 0 then
    raise exception 'One transaction may post stock for only one inventory item; send one request per item'
      using errcode = '25000';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(c_ns, v_key);
end;
$$;

-- SECURITY DEFINER is required for the six functions below only because they write ledger rows
-- (opening, purchase, count correction movements) that merchants are deliberately NOT allowed to
-- insert themselves. Fixed empty search_path, every object schema qualified, EXECUTE revoked
-- from everyone below (they run only as triggers).

create function public.stock_post_opening()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.opening_quantity > 0 then
    insert into public.stock_movements (business_id, inventory_item_id, movement_type, quantity_delta, movement_date, notes)
    values (new.business_id, new.id, 'opening', new.opening_quantity, new.created_at, 'Opening stock');
  end if;
  return new;
end;
$$;

create function public.stock_lock_purchase_item()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_active boolean;
begin
  perform public.stock_enter_item(new.inventory_item_id);
  select i.is_active into v_active
    from public.inventory_items i
   where i.id = new.inventory_item_id and i.business_id = new.business_id
   for no key update of i;
  if not found then raise exception 'Inventory item not found for this business'; end if;
  if not v_active then raise exception 'Inventory item is inactive'; end if;
  return new;
end;
$$;

create function public.stock_post_purchase_movement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.stock_movements (business_id, inventory_item_id, movement_type, quantity_delta,
                                      purchase_record_id, movement_date, notes)
  values (new.business_id, new.inventory_item_id, 'purchase', new.quantity, new.id,
          (new.purchase_date::timestamp at time zone 'Africa/Johannesburg'),
          coalesce(new.notes, 'Posted from purchase record'));
  return new;
end;
$$;

create function public.stock_movement_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_open numeric(14,3);
  v_active boolean;
  v_qty numeric(14,3);
begin
  if new.movement_type <> 'opening' then
    perform public.stock_enter_item(new.inventory_item_id);
  end if;
  select i.opening_quantity, i.is_active into v_open, v_active
    from public.inventory_items i
   where i.id = new.inventory_item_id and i.business_id = new.business_id
   for no key update of i;
  if not found then raise exception 'Inventory item not found for this business'; end if;
  if not v_active then raise exception 'Inventory item is inactive'; end if;

  if new.movement_type = 'opening' then
    if new.quantity_delta is distinct from v_open then
      raise exception 'Opening movement must equal the item opening_quantity (%)', v_open;
    end if;
  elsif new.movement_type = 'purchase' then
    select p.quantity into v_qty from public.purchase_records p
     where p.id = new.purchase_record_id and p.business_id = new.business_id
       and p.inventory_item_id = new.inventory_item_id;
    if not found then raise exception 'Purchase movement needs a matching purchase record'; end if;
    if v_qty is distinct from new.quantity_delta then
      raise exception 'Purchase movement quantity must equal the purchase record quantity (%)', v_qty;
    end if;
  end if;
  return new;
end;
$$;

create function public.stock_verify_count_correction()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_var numeric(14,3);
begin
  select s.variance into v_var from public.stock_snapshots s
   where s.id = new.stock_snapshot_id and s.business_id = new.business_id
     and s.inventory_item_id = new.inventory_item_id;
  if not found or v_var is distinct from new.quantity_delta then
    raise exception 'Count correction must equal the variance of its stock snapshot';
  end if;
  return new;
end;
$$;

create function public.stock_prepare_snapshot()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_active boolean;
  v_expected numeric(14,3);
begin
  perform public.stock_enter_item(new.inventory_item_id);
  select i.is_active into v_active
    from public.inventory_items i
   where i.id = new.inventory_item_id and i.business_id = new.business_id
   for no key update of i;
  if not found then raise exception 'Inventory item not found for this business'; end if;
  if not v_active then raise exception 'Inventory item is inactive'; end if;

  select coalesce(sum(m.quantity_delta), 0) into v_expected
    from public.stock_movements m
   where m.inventory_item_id = new.inventory_item_id and m.business_id = new.business_id;

  new.expected_quantity := v_expected;
  new.variance := new.counted_quantity - v_expected;

  -- Posted here (BEFORE ROW) so a later row of the same statement already sees this correction.
  if new.variance <> 0 then
    insert into public.stock_movements (business_id, inventory_item_id, movement_type, quantity_delta,
                                        stock_snapshot_id, movement_date, notes)
    values (new.business_id, new.inventory_item_id, 'count_correction', new.variance, new.id,
            new.counted_at, coalesce(new.notes, 'Physical count correction'));
  end if;
  return new;
end;
$$;

revoke all on function public.stock_set_updated_at(), public.stock_guard_item_update(),
  public.stock_reject_change(), public.stock_enter_item(uuid), public.stock_post_opening(), public.stock_lock_purchase_item(),
  public.stock_post_purchase_movement(), public.stock_movement_before_insert(),
  public.stock_verify_count_correction(), public.stock_prepare_snapshot()
  from public, anon, authenticated;

-- ---------------------------------------------------------------- triggers
-- Same event fires in alphabetical name order, hence the numeric prefixes.
create trigger inventory_items_10_guard before update on public.inventory_items
  for each row execute function public.stock_guard_item_update();
create trigger inventory_items_20_updated_at before update on public.inventory_items
  for each row execute function public.stock_set_updated_at();
create trigger inventory_items_30_post_opening after insert on public.inventory_items
  for each row execute function public.stock_post_opening();

create trigger purchase_records_10_lock before insert on public.purchase_records
  for each row execute function public.stock_lock_purchase_item();
create trigger purchase_records_20_post_movement after insert on public.purchase_records
  for each row execute function public.stock_post_purchase_movement();

create trigger stock_snapshots_10_prepare before insert on public.stock_snapshots
  for each row execute function public.stock_prepare_snapshot();

create trigger stock_movements_10_validate before insert on public.stock_movements
  for each row execute function public.stock_movement_before_insert();
create constraint trigger stock_movements_90_verify_correction after insert on public.stock_movements
  deferrable initially deferred
  for each row when (new.movement_type = 'count_correction')
  execute function public.stock_verify_count_correction();   -- runs at commit, when the snapshot row exists

create trigger purchase_records_99_immutable before update or delete on public.purchase_records
  for each row execute function public.stock_reject_change();
create trigger stock_movements_99_immutable before update or delete on public.stock_movements
  for each row execute function public.stock_reject_change();
create trigger stock_snapshots_99_immutable before update or delete on public.stock_snapshots
  for each row execute function public.stock_reject_change();
create trigger purchase_records_98_no_truncate before truncate on public.purchase_records
  for each statement execute function public.stock_reject_change();
create trigger stock_movements_98_no_truncate before truncate on public.stock_movements
  for each statement execute function public.stock_reject_change();
create trigger stock_snapshots_98_no_truncate before truncate on public.stock_snapshots
  for each statement execute function public.stock_reject_change();

-- ---------------------------------------------------------------- view
create view public.stock_balances
with (security_invoker = true)
as
select
  i.id as inventory_item_id,
  i.business_id,
  i.item_name,
  i.category,
  i.unit,
  i.minimum_quantity,
  i.is_active,
  coalesce(sum(m.quantity_delta) filter (where m.movement_type = 'opening'), 0)::numeric(14,3) as opening_total,
  coalesce(sum(m.quantity_delta) filter (where m.movement_type = 'purchase'), 0)::numeric(14,3) as purchased_total,
  coalesce(sum(m.quantity_delta) filter (where m.movement_type in
    ('sale','usage','waste','damage','complimentary','internal_use')), 0)::numeric(14,3) as reductions_total,
  coalesce(sum(m.quantity_delta) filter (where m.movement_type in
    ('adjustment_in','adjustment_out','count_correction')), 0)::numeric(14,3) as adjustments_total,
  coalesce(sum(m.quantity_delta), 0)::numeric(14,3) as current_quantity,
  (coalesce(sum(m.quantity_delta), 0) <= i.minimum_quantity) as below_minimum,
  (coalesce(sum(m.quantity_delta), 0) < 0) as needs_attention
from public.inventory_items i
left join public.stock_movements m
  on m.inventory_item_id = i.id and m.business_id = i.business_id
group by i.id;

-- ---------------------------------------------------------------- privileges
alter table public.inventory_items enable row level security;
alter table public.purchase_records enable row level security;
alter table public.stock_movements enable row level security;
alter table public.stock_snapshots enable row level security;

revoke all on public.inventory_items, public.purchase_records, public.stock_movements,
  public.stock_snapshots, public.stock_balances from public, anon, authenticated;

grant select on public.inventory_items, public.purchase_records, public.stock_movements,
  public.stock_snapshots, public.stock_balances to authenticated;
grant insert (id, business_id, item_name, category, unit, opening_quantity, minimum_quantity, is_active)
  on public.inventory_items to authenticated;
grant update (item_name, category, unit, minimum_quantity, is_active)
  on public.inventory_items to authenticated;
grant insert (id, business_id, inventory_item_id, quantity, total_cost, supplier_name, purchase_date, notes, client_request_id)
  on public.purchase_records to authenticated;
grant insert (id, business_id, inventory_item_id, movement_type, quantity_delta, movement_date, notes, client_request_id)
  on public.stock_movements to authenticated;
grant insert (id, business_id, inventory_item_id, counted_quantity, counted_at, notes, client_request_id)
  on public.stock_snapshots to authenticated;

-- ---------------------------------------------------------------- policies
-- Members read and write only their own businesses. Admin READ only (no admin writes into merchant ledgers).
create policy inventory_items_select on public.inventory_items for select to authenticated
  using (business_id in (select public.current_business_ids()) or (select public.is_admin()));
create policy inventory_items_insert on public.inventory_items for insert to authenticated
  with check (business_id in (select public.current_business_ids()));
create policy inventory_items_update on public.inventory_items for update to authenticated
  using (business_id in (select public.current_business_ids()))
  with check (business_id in (select public.current_business_ids()));

create policy purchase_records_select on public.purchase_records for select to authenticated
  using (business_id in (select public.current_business_ids()) or (select public.is_admin()));
create policy purchase_records_insert on public.purchase_records for insert to authenticated
  with check (business_id in (select public.current_business_ids()));

create policy stock_movements_select on public.stock_movements for select to authenticated
  using (business_id in (select public.current_business_ids()) or (select public.is_admin()));
create policy stock_movements_insert on public.stock_movements for insert to authenticated
  with check (
    business_id in (select public.current_business_ids())
    and movement_type in ('sale','usage','waste','damage','complimentary','internal_use','adjustment_in','adjustment_out')
  );

create policy stock_snapshots_select on public.stock_snapshots for select to authenticated
  using (business_id in (select public.current_business_ids()) or (select public.is_admin()));
create policy stock_snapshots_insert on public.stock_snapshots for insert to authenticated
  with check (business_id in (select public.current_business_ids()));

commit;
