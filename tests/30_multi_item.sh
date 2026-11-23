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

assert_no_partial_rows() {
  local label=$1 result
  result=$(db_psql -qAt -c "
    select
      (select count(*)=0 from public.purchase_records where inventory_item_id in ('$I1','$I2'))
      and (select count(*)=0 from public.stock_snapshots where inventory_item_id in ('$I1','$I2'))
      and (select count(*)=0 from public.stock_movements where inventory_item_id in ('$I1','$I2') and movement_type<>'opening')
      and (select count(*)=2 from public.stock_movements where inventory_item_id in ('$I1','$I2') and movement_type='opening')
      and (select count(*)=2 from public.stock_balances where inventory_item_id in ('$I1','$I2') and current_quantity=100)
  ")
  record_result "$label" "$([[ $result == t ]] && printf true || printf false)" "database assertion: $result"
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/credo-v1-multi-item.XXXXXX")
trap 'rm -rf -- "$tmp_dir"' EXIT
A=aaaaaaaa-0000-0000-0000-00000000000a
I1=$(db_psql -qAt -c "select gen_random_uuid()")
I2=$(db_psql -qAt -c "select gen_random_uuid()")
I3=$(db_psql -qAt -c "select gen_random_uuid()")
RC_SNAPSHOT=$(db_psql -qAt -c "select gen_random_uuid()")
db_psql -q -c "insert into public.inventory_items(id,business_id,item_name,unit,opening_quantity) values ('$I1','$A','Multi test item one','kg',100),('$I2','$A','Multi test item two','kg',100),('$I3','$A','Read committed item','kg',100)"

printf 'PostgreSQL %s multi-item tests on %s\n' "$SERVER_MAJOR" "$DB"
passed=0
failed=0

stmt() {
  local kind=$1 item=$2
  case $kind in
    purchase)
      printf "insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('%s','%s',10,1);" "$A" "$item"
      ;;
    movement)
      printf "insert into public.stock_movements(business_id,inventory_item_id,movement_type,quantity_delta) values ('%s','%s','sale',-1);" "$A" "$item"
      ;;
    count)
      printf "insert into public.stock_snapshots(business_id,inventory_item_id,counted_quantity) values ('%s','%s',90);" "$A" "$item"
      ;;
    *)
      die "unknown transaction kind '$kind'"
      ;;
  esac
}

for kind in purchase movement count; do
  for ordering in opposite same; do
    printf '== %s, %s order: concurrent transactions each post two items and must be rejected\n' "$kind" "$ordering"
    if [[ $ordering == opposite ]]; then
      a_first=$I1; a_second=$I2
      b_first=$I2; b_second=$I1
    else
      a_first=$I1; a_second=$I2
      b_first=$I1; b_second=$I2
    fi
    a_sql="begin; $(stmt "$kind" "$a_first") select pg_sleep(0.5); $(stmt "$kind" "$a_second") commit;"
    b_sql="begin; $(stmt "$kind" "$b_first") select pg_sleep(0.5); $(stmt "$kind" "$b_second") commit;"
    (db_psql -c "$a_sql") >"$tmp_dir/${kind}-${ordering}-a.log" 2>&1 &
    pid_a=$!
    (db_psql -c "$b_sql") >"$tmp_dir/${kind}-${ordering}-b.log" 2>&1 &
    pid_b=$!
    if wait "$pid_a"; then
      rc_a=0
    else
      rc_a=$?
    fi
    if wait "$pid_b"; then
      rc_b=0
    else
      rc_b=$?
    fi
    printf 'Session A (exit %s):\n' "$rc_a"
    cat "$tmp_dir/${kind}-${ordering}-a.log"
    printf 'Session B (exit %s):\n' "$rc_b"
    cat "$tmp_dir/${kind}-${ordering}-b.log"
    for session in a b; do
      if [[ $session == a ]]; then
        rc=$rc_a; log="$tmp_dir/${kind}-${ordering}-a.log"
      else
        rc=$rc_b; log="$tmp_dir/${kind}-${ordering}-b.log"
      fi
      if ((rc != 0)) && [[ $(<"$log") == *"only one inventory item"* ]]; then
        accepted=true
      else
        accepted=false
      fi
      record_result "$kind/$ordering session $session rejected with the one-item error" "$accepted" "exit=$rc"
    done
    assert_no_partial_rows "$kind/$ordering rejection leaves purchases, movements, balances, and snapshots unchanged"
  done
done

printf '== Reject REPEATABLE READ and SERIALIZABLE postings for purchases, movements, and counts\n'
for isolation in "repeatable read" serializable; do
  for kind in purchase movement count; do
    log="$tmp_dir/isolation-${isolation// /-}-$kind.log"
    sql="begin isolation level $isolation; $(stmt "$kind" "$I1") commit;"
    if db_psql -c "$sql" >"$log" 2>&1; then
      rc=0
    else
      rc=$?
    fi
    printf 'Isolation %s, %s (exit %s):\n' "$isolation" "$kind" "$rc"
    cat "$log"
    if ((rc != 0)) && [[ $(<"$log") == *"require READ COMMITTED isolation"* ]]; then
      accepted=true
    else
      accepted=false
    fi
    record_result "$isolation rejects $kind" "$accepted" "exit=$rc"
  done
done
assert_no_partial_rows "isolation failures leave purchases, movements, balances, and snapshots unchanged"

printf '== READ COMMITTED count must see a purchase committed while it waits\n'
(
  db_psql -c "begin isolation level read committed; select count(*) from public.stock_movements where inventory_item_id='$I3'; select pg_sleep(2); insert into public.stock_snapshots(id,business_id,inventory_item_id,counted_quantity) values ('$RC_SNAPSHOT','$A','$I3',140); commit;"
) >"$tmp_dir/read-committed-count.log" 2>&1 &
reader_pid=$!
sleep 0.5
if db_psql -c "insert into public.purchase_records(business_id,inventory_item_id,quantity,total_cost) values ('$A','$I3',50,1)" >"$tmp_dir/read-committed-purchase.log" 2>&1; then
  purchase_rc=0
else
  purchase_rc=$?
fi
if wait "$reader_pid"; then
  reader_rc=0
else
  reader_rc=$?
fi
printf 'READ COMMITTED count session (exit %s):\n' "$reader_rc"
cat "$tmp_dir/read-committed-count.log"
printf 'READ COMMITTED purchase session (exit %s):\n' "$purchase_rc"
cat "$tmp_dir/read-committed-purchase.log"
rc_data=$(db_psql -qAt -c "
  select exists (
    select 1 from public.stock_snapshots s
    where s.id='$RC_SNAPSHOT' and s.expected_quantity=150 and s.variance=-10
      and exists (select 1 from public.stock_movements m where m.stock_snapshot_id=s.id and m.quantity_delta=-10)
  )
  and (select current_quantity=140 from public.stock_balances where inventory_item_id='$I3')
  and exists (
    select 1 from public.purchase_records p
    join public.stock_movements m on m.purchase_record_id=p.id
    where p.inventory_item_id='$I3' and p.quantity=50 and m.quantity_delta=50
  )
")
record_result "READ COMMITTED count sees committed purchase (expected 150, variance -10)" \
  "$([[ $reader_rc == 0 && $purchase_rc == 0 && $rc_data == t ]] && printf true || printf false)" \
  "reader exit=$reader_rc; purchase exit=$purchase_rc; database assertion=$rc_data"

printf '== Attempts to bypass the one-item marker with session-level changes\n'
for bypass in advisory_unlock clear_setting reset_all; do
  log="$tmp_dir/bypass-$bypass.log"
  case $bypass in
    advisory_unlock)
      between="select pg_advisory_unlock_all();"
      ;;
    clear_setting)
      between="select set_config('credo.stock_item','',true);"
      ;;
    reset_all)
      between="reset all;"
      ;;
  esac
  sql="begin; $(stmt purchase "$I1") $between $(stmt purchase "$I2") commit;"
  if db_psql -c "$sql" >"$log" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  printf 'Bypass %s (exit %s):\n' "$bypass" "$rc"
  cat "$log"
  if ((rc != 0)) && [[ $(<"$log") == *"only one inventory item"* ]]; then
    accepted=true
  else
    accepted=false
  fi
  record_result "$bypass cannot bypass the one-item restriction" "$accepted" "exit=$rc"
done
assert_no_partial_rows "bypass attempts leave purchases, movements, balances, and snapshots unchanged"

printf 'SUMMARY: %s passed, %s failed\n' "$passed" "$failed"
((passed + failed > 0)) || die "no multi-item test results were recorded"
((failed == 0))
