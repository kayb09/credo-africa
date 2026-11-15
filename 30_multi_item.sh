#!/bin/bash
# Multi item deadlock and isolation tests, separate sessions. usage: 30_multi_item.sh <db>  (db prepared by run.sh)
DB=$1; PORT=${PGPORT:-5499}; HOST=${PGHOST:-/tmp}
P="psql -h $HOST -p $PORT -U postgres -d $DB -qtA"
A=aaaaaaaa-0000-0000-0000-00000000000a
I1=e1000000-0000-0000-0000-000000000001; I2=e1000000-0000-0000-0000-000000000002
$P -c "insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values ('$I1','$A','M item 1','kg',100),('$I2','$A','M item 2','kg',100)" >/dev/null
stmt() { # $1 kind, $2 item
  case $1 in
   purchase) echo "insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$2',10,1);";;
   movement) echo "insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('$A','$2','sale',-1);";;
   count)    echo "insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity) values ('$A','$2',90);";;
  esac; }
for K in purchase movement count; do
  echo "== M-$K: session A item1 then item2, session B item2 then item1 (each statement in the same transaction, 2 s apart)"
  ( $P -v ON_ERROR_STOP=1 -c "begin; $(stmt $K $I1) select pg_sleep(2); $(stmt $K $I2) commit;" > /tmp/mA.out 2>&1; echo "A exit=$?" >> /tmp/mA.out ) &
  ( $P -v ON_ERROR_STOP=1 -c "begin; $(stmt $K $I2) select pg_sleep(2); $(stmt $K $I1) commit;" > /tmp/mB.out 2>&1; echo "B exit=$?" >> /tmp/mB.out ) &
  wait
  echo "A: $(grep -hE 'ERROR|exit' /tmp/mA.out | tr '\n' ' ')"; echo "B: $(grep -hE 'ERROR|exit' /tmp/mB.out | tr '\n' ' ')"
done
echo "== reconciliation after the multi item runs"
$P -c "select 'item '||inventory_item_id||' balance='||current_quantity||' ledger='||(select sum(quantity_delta) from public.stock_movements m where m.inventory_item_id=b.inventory_item_id) from public.stock_balances b where inventory_item_id in ('$I1','$I2') order by 1"
echo "== M-same-order: both sessions use the SAME order item1 then item2 (revision 2 allowed this; revision 3 rejects every two item transaction by design)"
( $P -v ON_ERROR_STOP=1 -c "begin; $(stmt purchase $I1) select pg_sleep(2); $(stmt purchase $I2) commit;" > /tmp/mA.out 2>&1; echo "A exit=$?" >> /tmp/mA.out ) &
( $P -v ON_ERROR_STOP=1 -c "begin; $(stmt purchase $I1) select pg_sleep(2); $(stmt purchase $I2) commit;" > /tmp/mB.out 2>&1; echo "B exit=$?" >> /tmp/mB.out ) &
wait
echo "A: $(grep -hE 'ERROR|exit' /tmp/mA.out | tr '\n' ' ')"; echo "B: $(grep -hE 'ERROR|exit' /tmp/mB.out | tr '\n' ' ')"
echo "== I1: REPEATABLE READ stale snapshot. Session RR takes its snapshot, then another session commits a purchase of +50, then RR posts a count"
I3=e1000000-0000-0000-0000-000000000003
$P -c "insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values ('$I3','$A','Iso item','kg',100)" >/dev/null
for LVL in "repeatable read" "serializable" "read committed"; do
  ( $P -c "begin isolation level $LVL; select count(*) from public.stock_movements; select pg_sleep(2); insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values (gen_random_uuid(),'$A','$I3',100); commit;" > /tmp/iso.out 2>&1; echo "exit=$?" >> /tmp/iso.out ) &
  sleep 1
  $P -c "insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$I3',50,1)" >/dev/null
  wait
  echo "isolation '$LVL': $(grep -hE 'ERROR|exit' /tmp/iso.out | tr '\n' ' ')"
  $P -c "select '   after: expected_quantity of latest count='||coalesce((select expected_quantity::text from public.stock_snapshots where inventory_item_id='$I3' order by created_at desc limit 1),'none (rejected)')||'  true ledger sum='||(select sum(quantity_delta) from public.stock_movements where inventory_item_id='$I3')"
  $P -c "delete from public.test_results where false" >/dev/null
done
echo "== E1: attempts to evade the one item rule inside one transaction"
$P -c "begin; $(stmt purchase $I1) select pg_advisory_unlock_all(); select set_config('credo.stock_item','',true); reset all; $(stmt purchase $I2) commit;" 2>&1 | grep -E "ERROR|COMMIT|ROLLBACK" | head -2
