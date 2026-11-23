#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

if (($# != 1)); then
  die "usage: $0 credo_<name>_test"
fi
DB=$1
[[ $DB =~ ^credo_[A-Za-z0-9_]+_test$ ]] || die "database name must match credo_*_test"
(( ${#DB} <= 63 )) || die "database name must not exceed PostgreSQL's 63-byte identifier limit"
[[ -z ${PGSERVICE:-} ]] || die "PGSERVICE is not allowed; pass a direct local connection"
[[ -z ${PGHOSTADDR:-} ]] || die "PGHOSTADDR is not allowed"
HOST=${PGHOST:-/tmp}
case $HOST in
  localhost|127.0.0.1|::1|/tmp|/var/run/postgresql) ;;
  *) die "unapproved PostgreSQL host '$HOST'; only loopback or approved local sockets are allowed" ;;
esac
PORT=${PGPORT:-5499}
[[ $PORT =~ ^[0-9]+$ ]] && ((PORT >= 1 && PORT <= 65535)) || die "invalid PGPORT"
USER=${PGUSER:-postgres}
command -v psql >/dev/null 2>&1 || die "psql is required"
command -v pgbench >/dev/null 2>&1 || die "pgbench is required"

PSQL=(psql -X -h "$HOST" -p "$PORT" -U "$USER" -v ON_ERROR_STOP=1)
SERVER_MAJOR=$("${PSQL[@]}" -d postgres -Atc "select current_setting('server_version_num')::integer / 10000")
[[ $SERVER_MAJOR == 17 ]] || die "PostgreSQL 17 required; connected server major version is $SERVER_MAJOR"

db_psql() {
  "${PSQL[@]}" -d "$DB" "$@"
}

record_result() {
  local label=$1 condition=$2 detail=${3:-}
  if [[ $condition == true ]]; then
    ((passed += 1))
    printf 'PASS: %s%s\n' "$label" "${detail:+ - $detail}"
  else
    ((failed += 1))
    printf 'FAIL: %s%s\n' "$label" "${detail:+ - $detail}" >&2
  fi
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/credo-v1-concurrency.XXXXXX")
trap 'rm -rf -- "$tmp_dir"' EXIT
passed=0
failed=0
A=aaaaaaaa-0000-0000-0000-00000000000a
ITEM=$(db_psql -qAt -c "select gen_random_uuid()")
SNAP1=$(db_psql -qAt -c "select gen_random_uuid()")
SNAP2=$(db_psql -qAt -c "select gen_random_uuid()")
db_psql -q -c "insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values ('$ITEM','$A','Concurrency test item','kg',100)"

printf 'PostgreSQL %s concurrency tests on %s\n' "$SERVER_MAJOR" "$DB"
printf '== C1: purchase of 50 holds the item lock; the count must wait and include it\n'
(
  db_psql -c "begin; insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$ITEM',50,10); select pg_sleep(3); commit;"
) >"$tmp_dir/c1-purchase.log" 2>&1 &
purchase_pid=$!
sleep 0.5
start_ns=$(date +%s%N)
if db_psql -c "insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('$SNAP1','$A','$ITEM',140)" >"$tmp_dir/c1-count.log" 2>&1; then
  c1_count_rc=0
else
  c1_count_rc=$?
fi
end_ns=$(date +%s%N)
if wait "$purchase_pid"; then
  c1_purchase_rc=0
else
  c1_purchase_rc=$?
fi
c1_elapsed=$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.3f", (end-start)/1000000000 }')
printf 'C1 purchase session (exit %s):\n' "$c1_purchase_rc"
cat "$tmp_dir/c1-purchase.log"
printf 'C1 count session (exit %s, waited %s seconds):\n' "$c1_count_rc" "$c1_elapsed"
cat "$tmp_dir/c1-count.log"
c1_waited=$(awk -v elapsed="$c1_elapsed" 'BEGIN { print (elapsed >= 1.5) ? "true" : "false" }')
c1_data=$(db_psql -qAt -c "select exists (select 1 from public.stock_snapshots where id='$SNAP1' and expected_quantity=150 and variance=-10) and exists (select 1 from public.stock_movements where stock_snapshot_id='$SNAP1' and movement_type='count_correction' and quantity_delta=-10) and (select current_quantity=140 from public.stock_balances where inventory_item_id='$ITEM')")
record_result "C1 purchase blocks count; expected 150, variance -10" \
  "$([[ $c1_purchase_rc == 0 && $c1_count_rc == 0 && $c1_waited == true && $c1_data == t ]] && printf true || printf false)" \
  "waited ${c1_elapsed}s; purchase exit=$c1_purchase_rc; count exit=$c1_count_rc; database assertion=$c1_data"

printf '== C2: count holds the item lock; the purchase must wait and final balance must be 155\n'
(
  db_psql -c "begin; insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('$SNAP2','$A','$ITEM',150); select pg_sleep(3); commit;"
) >"$tmp_dir/c2-count.log" 2>&1 &
count_pid=$!
sleep 0.5
start_ns=$(date +%s%N)
if db_psql -c "insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$ITEM',5,1)" >"$tmp_dir/c2-purchase.log" 2>&1; then
  c2_purchase_rc=0
else
  c2_purchase_rc=$?
fi
end_ns=$(date +%s%N)
if wait "$count_pid"; then
  c2_count_rc=0
else
  c2_count_rc=$?
fi
c2_elapsed=$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.3f", (end-start)/1000000000 }')
printf 'C2 count session (exit %s):\n' "$c2_count_rc"
cat "$tmp_dir/c2-count.log"
printf 'C2 purchase session (exit %s, waited %s seconds):\n' "$c2_purchase_rc" "$c2_elapsed"
cat "$tmp_dir/c2-purchase.log"
c2_waited=$(awk -v elapsed="$c2_elapsed" 'BEGIN { print (elapsed >= 1.5) ? "true" : "false" }')
c2_data=$(db_psql -qAt -c "select exists (select 1 from public.stock_snapshots where id='$SNAP2' and expected_quantity=140 and variance=10) and (select current_quantity=155 from public.stock_balances where inventory_item_id='$ITEM') and exists (select 1 from public.purchase_records p join public.stock_movements m on m.purchase_record_id=p.id and m.inventory_item_id=p.inventory_item_id where p.inventory_item_id='$ITEM' and p.quantity=5 and m.quantity_delta=5)")
record_result "C2 count blocks purchase; final balance is 155" \
  "$([[ $c2_count_rc == 0 && $c2_purchase_rc == 0 && $c2_waited == true && $c2_data == t ]] && printf true || printf false)" \
  "waited ${c2_elapsed}s; count exit=$c2_count_rc; purchase exit=$c2_purchase_rc; database assertion=$c2_data"

printf '== C3: 16 pgbench clients post purchases, reductions, and counts for 8 seconds\n'
cat >"$tmp_dir/pgbench.sql" <<SQL
\set kind random(1,100)
\if :kind <= 40
insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$ITEM',1,1);
\elif :kind <= 85
insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('$A','$ITEM','sale',-1);
\else
\set counted random(0,200)
insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity) values ('$A','$ITEM',:counted);
\endif
SQL
deadlocks_before=$(db_psql -qAt -c "select deadlocks from pg_stat_database where datname=current_database()")
if pgbench -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c 16 -j 4 -T 8 -n -f "$tmp_dir/pgbench.sql" >"$tmp_dir/c3-pgbench.log" 2>&1; then
  pgbench_rc=0
else
  pgbench_rc=$?
fi
printf 'Complete pgbench output (exit %s):\n' "$pgbench_rc"
cat "$tmp_dir/c3-pgbench.log"
if awk '
  tolower($0) ~ /(^|[^[:alpha:]])error([^[:alpha:]]|$)|deadlock detected/ { bad=1 }
  /number of failed transactions:/ {
    found=1
    line=$0
    sub(/^.*number of failed transactions:[[:space:]]*/, "", line)
    split(line, fields, /[[:space:]]+/)
    if (fields[1] != "0") bad=1
  }
  END { if (!found) bad=1; exit bad }
' "$tmp_dir/c3-pgbench.log"; then
  pgbench_output_ok=true
else
  pgbench_output_ok=false
fi
deadlocks_after=$(db_psql -qAt -c "select deadlocks from pg_stat_database where datname=current_database()")
deadlocks_delta=$((deadlocks_after - deadlocks_before))
c3_data=$(db_psql -qAt -c "
select
  (select current_quantity=(select coalesce(sum(quantity_delta),0) from public.stock_movements where inventory_item_id='$ITEM')
     and opening_total+purchased_total+reductions_total+adjustments_total=current_quantity
   from public.stock_balances where inventory_item_id='$ITEM')
  and not exists (
    select 1 from public.purchase_records p
    where p.inventory_item_id='$ITEM' and not exists (
      select 1 from public.stock_movements m
      where m.purchase_record_id=p.id and m.inventory_item_id=p.inventory_item_id
        and m.movement_type='purchase' and m.quantity_delta=p.quantity))
  and not exists (
    select 1 from public.stock_snapshots s
    where s.inventory_item_id='$ITEM'
      and (s.variance is distinct from s.counted_quantity-s.expected_quantity
        or (s.variance=0 and exists (select 1 from public.stock_movements m where m.stock_snapshot_id=s.id))
        or (s.variance<>0 and not exists (
          select 1 from public.stock_movements m
          where m.stock_snapshot_id=s.id and m.movement_type='count_correction'
            and m.quantity_delta=s.variance))))
  and not exists (
    select 1 from public.stock_movements m
    where m.inventory_item_id='$ITEM' and m.movement_type='count_correction'
      and not exists (select 1 from public.stock_snapshots s where s.id=m.stock_snapshot_id and s.variance=m.quantity_delta))
")
printf 'C3 results: deadlocks during benchmark=%s; reconciliation assertion=%s\n' "$deadlocks_delta" "$c3_data"
record_result "C3 pgbench: 16 clients, 8 seconds, no errors/failures/deadlocks, ledger reconciles" \
  "$([[ $pgbench_rc == 0 && $pgbench_output_ok == true && $deadlocks_delta == 0 && $c3_data == t ]] && printf true || printf false)" \
  "pgbench exit=$pgbench_rc; output valid=$pgbench_output_ok; deadlocks=$deadlocks_delta; reconciliation=$c3_data"

printf 'SUMMARY: %s passed, %s failed\n' "$passed" "$failed"
((passed + failed > 0)) || die "no concurrency test results were recorded"
((failed == 0))
