-- CREDO STOCK AND PURCHASING V1
-- DRAFT ONLY. DO NOT APPLY TO PRODUCTION.
-- Dependencies to verify against an isolated copy before execution:
-- public.businesses(id), public.current_business_ids(), public.is_admin()
-- This file intentionally does not modify existing Credo tables.

begin;

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  item_name text not null check (length(trim(item_name)) between 1 and 120),
  category text,
  unit text not null default 'unit' check (length(trim(unit)) between 1 and 40),
  minimum_quantity numeric(14,3) not null default 0 check (minimum_quantity >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, business_id),
  unique (business_id, item_name)
);

create table if not exists public.purchase_records (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  inventory_item_id uuid not null,
  quantity numeric(14,3) not null check (quantity > 0),
  total_cost numeric(14,2) not null check (total_cost >= 0),
  supplier_name text,
  purchase_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  unique (id, business_id),
  constraint purchase_item_business_fk
    foreign key (inventory_item_id, business_id)
    references public.inventory_items(id, business_id) on delete restrict
);

create table if not exists public.stock_movements (
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
  movement_date timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now(),
  constraint movement_item_business_fk
    foreign key (inventory_item_id, business_id)
    references public.inventory_items(id, business_id) on delete restrict,
  constraint movement_purchase_business_fk
    foreign key (purchase_record_id, business_id)
    references public.purchase_records(id, business_id) on delete restrict,
  constraint movement_sign_ck check (
    (movement_type in ('opening','purchase','adjustment_in') and quantity_delta > 0)
    or (movement_type in ('sale','usage','waste','damage','complimentary','internal_use','adjustment_out') and quantity_delta < 0)
    or movement_type = 'count_correction'
  ),
  constraint purchase_link_type_ck check (
    (movement_type = 'purchase' and purchase_record_id is not null)
    or (movement_type <> 'purchase' and purchase_record_id is null)
  )
);

create unique index if not exists stock_one_opening_per_item
  on public.stock_movements(inventory_item_id) where movement_type = 'opening';

create table if not exists public.stock_snapshots (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  inventory_item_id uuid not null,
  counted_quantity numeric(14,3) not null check (counted_quantity >= 0),
  expected_quantity numeric(14,3) not null,
  variance numeric(14,3) not null,
  counted_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now(),
  constraint snapshot_item_business_fk
    foreign key (inventory_item_id, business_id)
    references public.inventory_items(id, business_id) on delete restrict
);

create or replace function public.stock_set_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists inventory_items_set_updated_at on public.inventory_items;
create trigger inventory_items_set_updated_at
before update on public.inventory_items
for each row execute function public.stock_set_updated_at();

create or replace function public.stock_post_purchase_movement()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.stock_movements (
    business_id, inventory_item_id, movement_type, quantity_delta,
    purchase_record_id, movement_date, notes
  ) values (
    new.business_id, new.inventory_item_id, 'purchase', new.quantity,
    new.id, new.purchase_date::timestamptz,
    coalesce(new.notes, 'Automatically posted from purchase record')
  );
  return new;
end;
$$;

drop trigger if exists purchase_records_post_stock_movement on public.purchase_records;
create trigger purchase_records_post_stock_movement
after insert on public.purchase_records
for each row execute function public.stock_post_purchase_movement();

create or replace function public.stock_prepare_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expected numeric(14,3);
begin
  perform 1 from public.inventory_items
   where id = new.inventory_item_id and business_id = new.business_id
   for update;
  if not found then
    raise exception 'Inventory item not found for this business';
  end if;

  select coalesce(sum(quantity_delta), 0)
    into v_expected
    from public.stock_movements
   where inventory_item_id = new.inventory_item_id
     and business_id = new.business_id;

  new.expected_quantity := v_expected;
  new.variance := new.counted_quantity - v_expected;
  return new;
end;
$$;

drop trigger if exists stock_snapshots_prepare on public.stock_snapshots;
create trigger stock_snapshots_prepare
before insert on public.stock_snapshots
for each row execute function public.stock_prepare_snapshot();

create or replace function public.stock_apply_snapshot_correction()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.variance <> 0 then
    insert into public.stock_movements (
      business_id, inventory_item_id, movement_type, quantity_delta,
      movement_date, notes
    ) values (
      new.business_id, new.inventory_item_id, 'count_correction',
      new.variance, new.counted_at,
      coalesce(new.notes, 'Physical count correction')
    );
  end if;
  return new;
end;
$$;

drop trigger if exists stock_snapshots_apply_correction on public.stock_snapshots;
create trigger stock_snapshots_apply_correction
after insert on public.stock_snapshots
for each row execute function public.stock_apply_snapshot_correction();

create or replace view public.stock_balances
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
  coalesce(sum(m.quantity_delta), 0)::numeric(14,3) as current_quantity,
  (coalesce(sum(m.quantity_delta), 0) <= i.minimum_quantity) as below_minimum
from public.inventory_items i
left join public.stock_movements m
  on m.inventory_item_id = i.id and m.business_id = i.business_id
group by i.id, i.business_id, i.item_name, i.category, i.unit,
         i.minimum_quantity, i.is_active;

alter table public.inventory_items enable row level security;
alter table public.purchase_records enable row level security;
alter table public.stock_movements enable row level security;
alter table public.stock_snapshots enable row level security;

revoke all on public.inventory_items, public.purchase_records,
  public.stock_movements, public.stock_snapshots, public.stock_balances
  from anon, authenticated;

grant select, insert on public.inventory_items to authenticated;
grant update (item_name, category, unit, minimum_quantity, is_active)
  on public.inventory_items to authenticated;
grant select, insert on public.purchase_records to authenticated;
grant select, insert on public.stock_movements to authenticated;
grant select, insert on public.stock_snapshots to authenticated;
grant select on public.stock_balances to authenticated;

drop policy if exists inventory_items_select_member on public.inventory_items;
create policy inventory_items_select_member on public.inventory_items
for select to authenticated
using (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists inventory_items_insert_member on public.inventory_items;
create policy inventory_items_insert_member on public.inventory_items
for insert to authenticated
with check (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists inventory_items_update_member on public.inventory_items;
create policy inventory_items_update_member on public.inventory_items
for update to authenticated
using (business_id = any(public.current_business_ids()) or public.is_admin())
with check (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists purchase_records_select_member on public.purchase_records;
create policy purchase_records_select_member on public.purchase_records
for select to authenticated
using (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists purchase_records_insert_member on public.purchase_records;
create policy purchase_records_insert_member on public.purchase_records
for insert to authenticated
with check (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists stock_movements_select_member on public.stock_movements;
create policy stock_movements_select_member on public.stock_movements
for select to authenticated
using (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists stock_movements_insert_member on public.stock_movements;
create policy stock_movements_insert_member on public.stock_movements
for insert to authenticated
with check (
  (business_id = any(public.current_business_ids()) or public.is_admin())
  and movement_type not in ('purchase','count_correction')
);

drop policy if exists stock_snapshots_select_member on public.stock_snapshots;
create policy stock_snapshots_select_member on public.stock_snapshots
for select to authenticated
using (business_id = any(public.current_business_ids()) or public.is_admin());

drop policy if exists stock_snapshots_insert_member on public.stock_snapshots;
create policy stock_snapshots_insert_member on public.stock_snapshots
for insert to authenticated
with check (business_id = any(public.current_business_ids()) or public.is_admin());

commit;
