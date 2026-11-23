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

printf 'Using PostgreSQL %s on approved local host %s:%s; recreating only %s\n' "$SERVER_MAJOR" "$HOST" "$PORT" "$DB"
"${PSQL[@]}" -d postgres -c "drop database if exists \"$DB\" with (force)" -c "create database \"$DB\""
"${PSQL[@]}" -d "$DB" -f "$(cd "$(dirname "$0")/.." && pwd)/tests/00_fixtures.sql"
"${PSQL[@]}" -d "$DB" -f "$(cd "$(dirname "$0")/.." && pwd)/supabase/drafts/006_stock_purchasing_v1_DRAFT.sql"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
functional_status=0
if "${PSQL[@]}" -q -d "$DB" -f "$ROOT/tests/10_functional.sql"; then
  :
else
  functional_status=$?
  printf 'FAIL: tests/10_functional.sql exited with status %s\n' "$functional_status" >&2
fi

printf '\nFunctional test results:\n'
"${PSQL[@]}" -d "$DB" -qAt -F ' | ' -c \
  "select case when ok then 'PASS' else 'FAIL' end, label, coalesce(detail, '') from public.test_results order by n"
SUMMARY=$("${PSQL[@]}" -d "$DB" -qAt -F '|' -c \
  "select count(*) filter (where ok), count(*) filter (where not ok), count(*) from public.test_results")
IFS='|' read -r passed failed total <<<"$SUMMARY"
printf 'SUMMARY: %s passed, %s failed (%s recorded)\n' "$passed" "$failed" "$total"

if ((total == 0)); then
  printf 'FAIL: no test results were recorded\n' >&2
  exit 1
fi
if ((functional_status != 0 || failed != 0)); then
  exit 1
fi
