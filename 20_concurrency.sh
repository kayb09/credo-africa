#!/bin/bash
# Separate database sessions on a real server. usage: 20_concurrency.sh <db>   (db already prepared by run.sh)
DB=$1; P="psql -h ${PGHOST:-/tmp} -p ${PGPORT:-5499} -U postgres -d $DB -v ON_ERROR_STOP=1 -qtA"
A=aaaaaaaa-0000-0000-0000-00000000000a
$P -c "insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values ('e0000000-0000-0000-0000-000000000001','$A','Conc item','kg',100)"
ITEM=e0000000-0000-0000-0000-000000000001
echo "== C1: purchase holds lock 3s, count in second session must wait and then include the purchase"
( $P -c "begin; insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$ITEM',50,10); select pg_sleep(3); commit;" ) &
sleep 1
START=$(date +%s.%N)
$P -c "insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('f0000000-0000-0000-0000-000000000001','$A','$ITEM',140)"
END=$(date +%s.%N); wait
echo "count waited $(echo "$END - $START" | bc) s (expected about 2 s or more)"
$P -c "select 'expected='||expected_quantity||' variance='||variance from public.stock_snapshots where id='f0000000-0000-0000-0000-000000000001'"
echo "(correct if expected=150 variance=-10: the count saw the committed purchase)"
echo "== C2: count holds lock 3s, purchase in second session must wait; final balance must reconcile"
( $P -c "begin; insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('f0000000-0000-0000-0000-000000000002','$A','$ITEM',150); select pg_sleep(3); commit;" ) &
sleep 1
$P -c "insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$ITEM',5,1)"
wait
$P -c "select 'balance='||current_quantity from public.stock_balances where inventory_item_id='$ITEM'"
echo "(correct: 150 after count of 150 on top of 140, then +5 purchase = 155)"
echo "== C3: 16 clients hammer the same item for 8 s with purchases, sales and counts (pgbench), then reconcile"
cat > /tmp/conc_bench.sql <<SQL
\set r random(1,100)
\if :r <= 40
insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$ITEM',1,1);
\elif :r <= 85
insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('$A','$ITEM','sale',-1);
\else
insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity) values ('$A','$ITEM',random()*200);
\endif
SQL
DL0=$(grep -c "deadlock detected" /var/tmp/pgdata16/log)
pgbench -h ${PGHOST:-/tmp} -p ${PGPORT:-5499} -U postgres -d $DB -c 16 -j 4 -T 8 -n -f /tmp/conc_bench.sql 2>&1 | grep -E "number of transactions|number of failed|deadlock|error" 
echo "deadlocks logged DURING C3 (log count after minus before): $(( $(grep -c "deadlock detected" /var/tmp/pgdata16/log) - DL0 ))"
$P -c "select 'ledger_sum='||sum(quantity_delta)||'  view_balance='||(select current_quantity from public.stock_balances where inventory_item_id='$ITEM')||'  movements='||count(*) from public.stock_movements where inventory_item_id='$ITEM'"
$P -c "select 'purchases_without_movement='||(select count(*) from public.purchase_records p where p.inventory_item_id='$ITEM' and not exists (select 1 from public.stock_movements m where m.purchase_record_id=p.id))||'  snapshots_with_wrong_correction='||(select count(*) from public.stock_snapshots s where s.inventory_item_id='$ITEM' and s.variance <> coalesce((select m.quantity_delta from public.stock_movements m where m.stock_snapshot_id=s.id),0))"
echo "Replay check: each snapshot's expected_quantity must equal the ledger sum of movements created before it (by creation order inside lock)."
$P -c "select 'snapshots_total='||count(*)||' ; snapshots_whose_post_count_balance_equals_counted='||count(*) filter (where counted_quantity = expected_quantity+variance) from public.stock_snapshots where inventory_item_id='$ITEM'"
