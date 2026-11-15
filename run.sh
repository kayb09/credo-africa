#!/bin/bash
# usage: run.sh <db> ; needs a PostgreSQL server you control. NEVER point at Supabase production.
set -e; D=$(cd "$(dirname "$0")/.." && pwd); DB=$1; P="psql -h ${PGHOST:-/tmp} -p ${PGPORT:-5499} -U postgres -v ON_ERROR_STOP=1 -q"
$P -d postgres -c "drop database if exists $DB" -c "create database $DB"
$P -d $DB -f $D/tests/00_fixtures.sql
$P -d $DB -f $D/supabase/drafts/006_stock_purchasing_v1_DRAFT.sql
$P -d $DB -f $D/tests/10_functional.sql >/dev/null
$P -d $DB -tA -F ' | ' -c "select case when ok then 'PASS' else 'FAIL' end, label, case when ok then '' else detail end from public.test_results order by n"
$P -d $DB -tAc "select 'SUMMARY: '||count(*) filter (where ok)||' passed, '||count(*) filter (where not ok)||' failed' from public.test_results"
