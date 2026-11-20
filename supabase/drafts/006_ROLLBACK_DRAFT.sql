-- Rollback for 006_stock_purchasing_v1_DRAFT.sql. Development databases only.
-- Destroys all stock data. The append only triggers are dropped together with their tables.
begin;
drop view if exists public.stock_balances;
drop table if exists public.stock_movements, public.stock_snapshots, public.purchase_records, public.inventory_items cascade;
drop function if exists public.stock_set_updated_at(), public.stock_guard_item_update(), public.stock_reject_change(), public.stock_enter_item(uuid),
  public.stock_post_opening(), public.stock_lock_purchase_item(), public.stock_post_purchase_movement(),
  public.stock_movement_before_insert(), public.stock_verify_count_correction(), public.stock_prepare_snapshot();
commit;
