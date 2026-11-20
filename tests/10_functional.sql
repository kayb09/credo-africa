\set A 'aaaaaaaa-0000-0000-0000-00000000000a'
\set B 'bbbbbbbb-0000-0000-0000-00000000000b'
set role authenticated; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
-- 1 opening > 0
insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity,minimum_quantity) values
 ('a0000000-0000-0000-0000-000000000001',:'A','Coffee beans','kg',10,2);
select public.t_ok('T01 opening>0 creates exactly one opening movement',
 (select count(*) from public.stock_movements where inventory_item_id='a0000000-0000-0000-0000-000000000001' and movement_type='opening')=1
 and (select current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001')=10);
-- 2 opening 0
insert into public.inventory_items(id,business_id,item_name,unit) values ('a0000000-0000-0000-0000-000000000002',:'A','Milk','l');
select public.t_ok('T02 opening=0 creates no movement',
 (select count(*) from public.stock_movements where inventory_item_id='a0000000-0000-0000-0000-000000000002')=0);
-- 17 no movements
select public.t_ok('T17 item with no movements shows 0 and below_minimum when min 0',
 (select current_quantity=0 and below_minimum from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000002'));
-- 3 duplicate / manual opening
select public.t_err('T03a merchant cannot insert manual opening movement',
 $q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','opening',5)$q$,'must equal the item opening_quantity');
select public.t_err('T03b opening_quantity cannot be updated by merchant',
 $q$update public.inventory_items set opening_quantity=99 where id='a0000000-0000-0000-0000-000000000001'$q$,'permission denied');
select public.t_err('T03c negative opening quantity rejected',
 $q$insert into public.inventory_items(business_id,item_name,opening_quantity) values ('aaaaaaaa-0000-0000-0000-00000000000a','Neg',-1)$q$,'check');
-- 4,5 purchase
insert into public.purchase_records(id,business_id,inventory_item_id,quantity,total_cost,supplier_name)
 values ('b0000000-0000-0000-0000-000000000001',:'A','a0000000-0000-0000-0000-000000000001',5,250.00,'Synthetic Supplier');
select public.t_ok('T04/T05 purchase posts exactly one matching purchase movement',
 (select count(*) from public.stock_movements where purchase_record_id='b0000000-0000-0000-0000-000000000001' and quantity_delta=5 and movement_type='purchase')=1
 and (select current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001')=15);
-- 6 duplicate purchase movement
reset role;
select public.t_err('T06 second purchase movement for same purchase rejected (owner path)',
 $q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,purchase_record_id) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','purchase',5,'b0000000-0000-0000-0000-000000000001')$q$,'unique');
select public.t_err('T06b purchase movement with wrong quantity rejected',
 $q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,purchase_record_id) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','purchase',7,'b0000000-0000-0000-0000-000000000001')$q$,'');
select public.t_err('T06c purchase movement without purchase record rejected',
 $q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','purchase',3)$q$,'matching purchase record');
select public.t_err('T06d non purchase movement referencing a purchase rejected',
 $q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,purchase_record_id) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','sale',-1,'b0000000-0000-0000-0000-000000000001')$q$,'movement_link_ck');
set role authenticated; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
-- 7 reductions
insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,notes) values
 (:'A','a0000000-0000-0000-0000-000000000001','sale',-3,null),
 (:'A','a0000000-0000-0000-0000-000000000001','usage',-1,null),
 (:'A','a0000000-0000-0000-0000-000000000001','waste',-0.5,null),
 (:'A','a0000000-0000-0000-0000-000000000001','damage',-0.25,null),
 (:'A','a0000000-0000-0000-0000-000000000001','complimentary',-0.25,null),
 (:'A','a0000000-0000-0000-0000-000000000001','internal_use',-1,null);
select public.t_ok('T07 reductions reduce balance (15-6=9) and are separate buckets',
 (select current_quantity=9 and reductions_total=-6 and purchased_total=5 and opening_total=10 from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001'));
select public.t_err('T07b sale with positive sign rejected',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','sale',2)$q$,'movement_sign_ck');
select public.t_err('T07c zero quantity rejected',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','sale',0)$q$,'check');
select public.t_err('T07d unknown movement type rejected',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','refund',-1)$q$,'row-level security');
-- 8 adjustments
insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,notes) values
 (:'A','a0000000-0000-0000-0000-000000000001','adjustment_in',2,'found a box'),
 (:'A','a0000000-0000-0000-0000-000000000001','adjustment_out',-1,'spilled');
select public.t_ok('T08 adjustments in and out (9+2-1=10)',(select current_quantity=10 and adjustments_total=1 from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001'));
select public.t_err('T08b adjustment without reason rejected',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','adjustment_in',1)$q$,'movement_adjustment_reason_ck');
-- 9 positive variance count (expected 10, count 12)
insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('c0000000-0000-0000-0000-000000000001',:'A','a0000000-0000-0000-0000-000000000001',12);
select public.t_ok('T09 positive variance +2 and one correction movement',
 (select expected_quantity=10 and variance=2 from public.stock_snapshots where id='c0000000-0000-0000-0000-000000000001')
 and (select count(*) from public.stock_movements where stock_snapshot_id='c0000000-0000-0000-0000-000000000001' and quantity_delta=2)=1
 and (select current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001')=12);
-- 10 negative variance (expected 12, count 9)
insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('c0000000-0000-0000-0000-000000000002',:'A','a0000000-0000-0000-0000-000000000001',9);
select public.t_ok('T10 negative variance -3',
 (select expected_quantity=12 and variance=-3 from public.stock_snapshots where id='c0000000-0000-0000-0000-000000000002')
 and (select current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001')=9);
-- 11 zero variance
insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('c0000000-0000-0000-0000-000000000003',:'A','a0000000-0000-0000-0000-000000000001',9);
select public.t_ok('T11 zero variance creates no movement',
 (select variance=0 from public.stock_snapshots where id='c0000000-0000-0000-0000-000000000003')
 and (select count(*) from public.stock_movements where stock_snapshot_id='c0000000-0000-0000-0000-000000000003')=0);
-- client cannot forge expected/variance
select public.t_err('T11b client cannot set expected_quantity (no column privilege)',
 $q$insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity,expected_quantity,variance) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',9,0,0)$q$,'permission denied');
-- multi row snapshot statement on one item: second row must see first correction
insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values
 ('c0000000-0000-0000-0000-000000000004',:'A','a0000000-0000-0000-0000-000000000001',20),
 ('c0000000-0000-0000-0000-000000000005',:'A','a0000000-0000-0000-0000-000000000001',20);
select public.t_ok('T11c two counts in one statement: second sees first correction (variance 0)',
 (select variance=11 from public.stock_snapshots where id='c0000000-0000-0000-0000-000000000004')
 and (select variance=0 from public.stock_snapshots where id='c0000000-0000-0000-0000-000000000005')
 and (select current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001')=20);
-- 14 cross business
select public.t_ok('T14a merchant A sees no B rows',
 (select count(*) from public.inventory_items where business_id=:'B')=0);
reset role;
insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values ('a0000000-0000-0000-0000-0000000000b1',:'B','B only item','kg',4);
set role authenticated; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select public.t_ok('T14b A cannot read B item, movement or balance',
 (select count(*) from public.inventory_items where id='a0000000-0000-0000-0000-0000000000b1')=0
 and (select count(*) from public.stock_movements where inventory_item_id='a0000000-0000-0000-0000-0000000000b1')=0
 and (select count(*) from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-0000000000b1')=0);
select public.t_err('T14c A cannot insert item for B',$q$insert into public.inventory_items(business_id,item_name) values ('bbbbbbbb-0000-0000-0000-00000000000b','x')$q$,'row-level security');
select public.t_err('T14d A cannot insert purchase for B item (own business id)',$q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-0000000000b1',1,1)$q$,'not found');
select public.t_err('T14e A cannot insert movement on B item',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-0000000000b1','sale',-1)$q$,'');
select public.t_err('T14f A cannot post a purchase with business B id',$q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('bbbbbbbb-0000-0000-0000-00000000000b','a0000000-0000-0000-0000-0000000000b1',1,1)$q$,'row-level security');
select public.t_err('T14g A cannot count B item',$q$insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-0000000000b1',0)$q$,'not found');
do $$ declare n int; begin update public.inventory_items set item_name='hacked' where id='a0000000-0000-0000-0000-0000000000b1'; get diagnostics n = row_count; perform public.t_ok('T14h A update of B item changes 0 rows', n=0, 'rows='||n); end $$;
-- 15 unauthorised inserts
select public.t_err('T15a merchant cannot insert count_correction directly',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','count_correction',5)$q$,'row-level security');
select public.t_err('T15b merchant cannot set purchase_record_id (no column privilege)',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,purchase_record_id) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','sale',-1,'b0000000-0000-0000-0000-000000000001')$q$,'permission denied');
-- admin read only
select set_config('test.uid','',false), set_config('test.admin','true',false);
select public.t_ok('T15c admin can read all items',(select count(*)>=3 from public.inventory_items));
select public.t_err('T15d admin cannot insert into merchant ledger',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','sale',-1)$q$,'row-level security');
select set_config('test.admin','false',false);
-- anon
reset role; set role anon;
select public.t_err('T15e anon cannot read stock tables',$q$select * from public.stock_movements$q$,'permission denied');
select public.t_err('T15f anon cannot read view',$q$select * from public.stock_balances$q$,'permission denied');
select public.t_err('T15g anon cannot write',$q$insert into public.inventory_items(business_id,item_name) values ('aaaaaaaa-0000-0000-0000-00000000000a','x')$q$,'permission denied');
reset role; set role authenticated; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select public.t_err('T15h merchant cannot execute posting function',$q$select public.stock_post_opening()$q$,'permission denied');
-- 16 immutability
select public.t_err('T16a merchant cannot update ledger',$q$update public.stock_movements set quantity_delta=-99$q$,'permission denied');
select public.t_err('T16b merchant cannot delete ledger',$q$delete from public.stock_movements$q$,'permission denied');
reset role;
select public.t_err('T16c owner update of ledger blocked by trigger',$q$update public.stock_movements set notes='x'$q$,'append only');
select public.t_err('T16d owner delete of purchase blocked',$q$delete from public.purchase_records$q$,'append only');
select public.t_err('T16e owner truncate of ledger blocked',$q$truncate public.stock_movements$q$,'append only');
select public.t_err('T16f owner update of snapshot blocked',$q$update public.stock_snapshots set counted_quantity=1$q$,'append only');
select public.t_err('T16g owner cannot change opening_quantity',$q$update public.inventory_items set opening_quantity=1 where id='a0000000-0000-0000-0000-000000000001'$q$,'cannot be changed');
select public.t_err('T16h owner cannot move item to another business',$q$update public.inventory_items set business_id='bbbbbbbb-0000-0000-0000-00000000000b' where id='a0000000-0000-0000-0000-000000000001'$q$,'cannot be changed');
-- forged correction (owner path): wrong amount, then valid snapshot link but wrong delta
select public.t_err('T16i correction not equal to snapshot variance rejected',
 $q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta,stock_snapshot_id) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','count_correction',1,'c0000000-0000-0000-0000-000000000003')$q$,'');
-- 18 rollback after failed trigger: purchase to inactive item
update public.inventory_items set is_active=false where id='a0000000-0000-0000-0000-000000000002';
select public.t_err('T18a purchase for inactive item fails',$q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000002',1,1)$q$,'inactive');
select public.t_ok('T18b failed purchase left no purchase row and no movement',
 (select count(*) from public.purchase_records where inventory_item_id='a0000000-0000-0000-0000-000000000002')=0
 and (select count(*) from public.stock_movements where inventory_item_id='a0000000-0000-0000-0000-000000000002')=0);
-- failure mid statement: second row bad => first row not kept
select public.t_err('T18c multi row purchase across two items is rejected (one item per transaction)',
 $q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values
   ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',1,1),
   ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000002',1,1)$q$,'only one inventory item');
select public.t_err('T18c2 multi row purchase, second row fails a CHECK, whole statement rolled back',
 $q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values
   ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',1,1),
   ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',0,1)$q$,'check');
select public.t_ok('T18d no partial rows from T18c',(select count(*) from public.purchase_records)=1
 and (select current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001')=20);
-- idempotency
set role authenticated; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost,client_request_id) values (:'A','a0000000-0000-0000-0000-000000000001',1,10,'dddddddd-0000-0000-0000-000000000001');
select public.t_err('T05b replayed request id does not duplicate',$q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost,client_request_id) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',1,10,'dddddddd-0000-0000-0000-000000000001')$q$,'unique');
-- view reconciliation
select public.t_ok('T-view formula: opening+purchases+reductions+adjustments = current',
 (select opening_total+purchased_total+reductions_total+adjustments_total=current_quantity from public.stock_balances where inventory_item_id='a0000000-0000-0000-0000-000000000001'));
select public.t_ok('T-view security_invoker set',(select coalesce((select 'security_invoker=true'=any(reloptions) from pg_class where relname='stock_balances'),false)));
-- T19 bulk creation of several items with opening stock in one statement is still allowed
insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values
 ('a0000000-0000-0000-0000-0000000000c1',:'A','Bulk 1','kg',3),('a0000000-0000-0000-0000-0000000000c2',:'A','Bulk 2','kg',4),('a0000000-0000-0000-0000-0000000000c3',:'A','Bulk 3','kg',0);
select public.t_ok('T19 bulk item creation: 2 opening movements, balances 3 and 4 and 0',
 (select count(*) from public.stock_movements where inventory_item_id in ('a0000000-0000-0000-0000-0000000000c1','a0000000-0000-0000-0000-0000000000c2','a0000000-0000-0000-0000-0000000000c3') and movement_type='opening')=2
 and (select sum(current_quantity) from public.stock_balances where item_name like 'Bulk %')=7);
reset role;
begin isolation level repeatable read;
select public.t_err('T20a purchase rejected under REPEATABLE READ',$q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',1,1)$q$,'READ COMMITTED');
rollback;
begin isolation level serializable;
select public.t_err('T20b count rejected under SERIALIZABLE',$q$insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001',1)$q$,'READ COMMITTED');
rollback;
begin isolation level repeatable read;
select public.t_err('T20c movement rejected under REPEATABLE READ',$q$insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','sale',-1)$q$,'READ COMMITTED');
rollback;
-- T21 same transaction, two items, cannot be evaded by releasing advisory locks
begin;
insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values (:'A','a0000000-0000-0000-0000-000000000001',1,1);
select pg_advisory_unlock_all();
select public.t_err('T21 second item in same transaction still rejected after pg_advisory_unlock_all()',$q$insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('aaaaaaaa-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-0000000000c1',1,1)$q$,'only one inventory item');
rollback;
