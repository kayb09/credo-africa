#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
command -v docker >/dev/null 2>&1 || {
  printf 'ERROR: docker is required for isolated PostgreSQL 17 security tests\n' >&2
  exit 2
}
command -v node >/dev/null 2>&1 || {
  printf 'ERROR: node is required for webhook helper tests\n' >&2
  exit 2
}

CONTAINER="credo-security-test-$$"
cleanup() {
  docker stop "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm --detach \
  --name "$CONTAINER" \
  --network none \
  --tmpfs /var/lib/postgresql/data:rw,noexec,nosuid,size=1g \
  --env POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:17 >/dev/null

ready=false
for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
[[ $ready == true ]] || {
  printf 'ERROR: isolated PostgreSQL 17 did not become ready\n' >&2
  exit 2
}

psql_exec() {
  docker exec -i "$CONTAINER" psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres "$@"
}

psql_exec -f - < "$ROOT/tests/security/bootstrap.sql"
psql_exec -f - < "$ROOT/docs/audit/live-public-schema.sql"

(
  printf '%s\n' 'SET ROLE supabase_admin;'
  sed -n '1,$p' "$ROOT/supabase/drafts/007_supabase_admin_defaults_DRAFT.sql"
) | psql_exec -f -

psql_exec -f - < "$ROOT/supabase/drafts/007_security_hardening_DRAFT.sql"
psql_exec -f - < "$ROOT/supabase/drafts/008_net_schema_lockdown_DRAFT.sql"
psql_exec -f - < "$ROOT/supabase/drafts/009_extension_stats_lockdown_DRAFT.sql"
psql_exec -f - < "$ROOT/supabase/drafts/010_realtime_subscription_lockdown_DRAFT.sql"
psql_exec -f - < "$ROOT/tests/security/fixtures.sql"

pass() {
  printf 'PASS %s\n' "$1"
}

assert_value() {
  local label=$1 expected=$2 sql=$3 output actual
  output=$(psql_exec -qAt -c "$sql")
  actual=$(printf '%s\n' "$output" | tail -n 1)
  [[ $actual == "$expected" ]] || {
    printf 'FAIL %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  }
  pass "$label"
}

assert_denied() {
  local label=$1 sql=$2 output
  if output=$(psql_exec -qAt -c "$sql" 2>&1); then
    printf 'FAIL %s: query unexpectedly succeeded\n' "$label" >&2
    exit 1
  fi
  if [[ $output != *"permission denied"* && $output != *"row-level security policy"* ]]; then
    printf 'FAIL %s: unexpected error: %s\n' "$label" "$output" >&2
    exit 1
  fi
  pass "$label"
}

user_a="00000000-0000-4000-8000-000000000001"
user_b="00000000-0000-4000-8000-000000000002"
admin="00000000-0000-4000-8000-000000000003"
unlinked_user="00000000-0000-4000-8000-000000000004"

assert_denied "anon cannot read owners" \
  "SET ROLE anon; SELECT * FROM public.owners"
assert_denied "anon cannot read revenue entries" \
  "SET ROLE anon; SELECT * FROM public.revenue_entries"
assert_denied "anon cannot insert activity" \
  "SET ROLE anon; INSERT INTO public.activity_history (activity_type) VALUES ('forged')"
assert_denied "anon cannot truncate public tables despite RLS" \
  "SET ROLE anon; TRUNCATE TABLE public.owners"
assert_denied "anon cannot truncate storage tables" \
  "SET ROLE anon; TRUNCATE TABLE storage.buckets"
assert_denied "anon cannot upload verification objects" \
  "SET ROLE anon; INSERT INTO storage.objects (bucket_id, name) VALUES ('verifications', 'fake.jpg')"
assert_denied "authenticated users cannot upload verification objects" \
  "SET ROLE authenticated; INSERT INTO storage.objects (bucket_id, name) VALUES ('verifications', 'fake.jpg')"
assert_denied "authenticated users cannot self-provision admin membership" \
  "SET ROLE authenticated; INSERT INTO app_private.admin_users (user_id) VALUES ('$user_a')"
assert_denied "anon cannot read pg_net's request queue" \
  "SET ROLE anon; SELECT * FROM net.http_request_queue"
assert_denied "anon cannot allocate pg_net queue ids" \
  "SET ROLE anon; SELECT nextval('net.http_request_queue_id_seq')"
assert_denied "authenticated users cannot call pg_net directly" \
  "SET ROLE authenticated; SELECT net.http_post('https://test.invalid')"
assert_value "service role retains pg_net execution" 200 \
  "SET ROLE service_role; SELECT net.http_post('https://test.invalid')"
assert_value "service role retains pg_net queue access" 0 \
  "SET ROLE service_role; SELECT count(*) FROM net.http_request_queue"
assert_value "service role retains pg_net sequence access" t \
  "SET ROLE service_role; SELECT has_sequence_privilege(current_user, 'net.http_request_queue_id_seq', 'USAGE')"
assert_denied "anon cannot inspect query statistics" \
  "SET ROLE anon; SELECT * FROM extensions.pg_stat_statements"
assert_denied "authenticated users cannot call query-statistics function" \
  "SET ROLE authenticated; SELECT * FROM extensions.pg_stat_statements(true)"
assert_value "service role retains query-statistics access" 1 \
  "SET ROLE service_role; SELECT count(*) FROM extensions.pg_stat_statements"
assert_denied "anon cannot read Realtime subscriptions" \
  "SET ROLE anon; SELECT * FROM realtime.subscription"
assert_denied "authenticated users cannot read Realtime subscriptions" \
  "SET ROLE authenticated; SELECT * FROM realtime.subscription"
assert_denied "anon cannot allocate Realtime subscription ids" \
  "SET ROLE anon; SELECT nextval('realtime.subscription_id_seq')"
assert_value "Realtime messages remain protected by RLS" 0 \
  "SET ROLE authenticated; SELECT count(*) FROM realtime.messages"
assert_value "service role retains Realtime subscription access" 1 \
  "SET ROLE service_role; SELECT count(*) FROM realtime.subscription"
assert_value "service role retains Realtime sequence access" t \
  "SET ROLE service_role; SELECT has_sequence_privilege(current_user, 'realtime.subscription_id_seq', 'USAGE')"

assert_value "merchant A sees only own owner row" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.owners"
assert_value "merchant A sees only own business row" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.businesses"
assert_value "authenticated user without an owner link sees no owner rows" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$unlinked_user', false); SELECT count(*) FROM public.owners"
assert_value "authenticated user without an owner link sees no businesses" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$unlinked_user', false); SELECT count(*) FROM public.businesses"
assert_value "merchant A cannot read merchant B revenue" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.revenue_entries WHERE business_id = '20000000-0000-4000-8000-000000000002'"
assert_value "merchant A can read own revenue" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.revenue_entries WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_value "merchant A cannot read merchant B activities" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.activity_history WHERE business_id = '20000000-0000-4000-8000-000000000002'"
assert_value "merchant A cannot read merchant B credit scores" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.credit_scores WHERE business_id = '20000000-0000-4000-8000-000000000002'"
assert_value "merchant A cannot read merchant B expenses" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.expense_entries WHERE business_id = '20000000-0000-4000-8000-000000000002'"
assert_value "merchant A cannot read merchant B supplier records" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.supplier_records WHERE business_id = '20000000-0000-4000-8000-000000000002'"
assert_value "merchant A cannot read merchant B trust signals" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.trust_signals WHERE business_id = '20000000-0000-4000-8000-000000000002'"
assert_value "merchant A can read own activity" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.activity_history WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_value "merchant A can read own credit score" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.credit_scores WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_value "merchant A can read own expenses" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.expense_entries WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_value "merchant A can read own supplier records" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.supplier_records WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_value "merchant A can read own trust signals" 1 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.trust_signals WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_value "merchant A sees no bot sessions" 0 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); SELECT count(*) FROM public.bot_sessions"
assert_denied "merchant A cannot insert revenue for merchant B" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.revenue_entries (business_id, amount, entry_date) VALUES ('20000000-0000-4000-8000-000000000002', 99, CURRENT_DATE)"
assert_denied "merchant A cannot insert expenses for merchant B" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.expense_entries (business_id, amount, expense_date) VALUES ('20000000-0000-4000-8000-000000000002', 99, CURRENT_DATE)"
assert_denied "merchant A cannot insert activity history" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.activity_history (business_id, activity_type) VALUES ('20000000-0000-4000-8000-000000000001', 'forged')"
assert_denied "merchant A cannot insert supplier records" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.supplier_records (business_id, supplier_name) VALUES ('20000000-0000-4000-8000-000000000001', 'forged')"
assert_denied "merchant A cannot mutate credit scores" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); UPDATE public.credit_scores SET score = 999 WHERE business_id = '20000000-0000-4000-8000-000000000001'"
assert_denied "merchant A cannot create bot sessions" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.bot_sessions (phone) VALUES ('forged-session')"

assert_value "merchant A can insert own revenue" t \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.revenue_entries (business_id, amount, entry_date) VALUES ('20000000-0000-4000-8000-000000000001', 30, CURRENT_DATE); SELECT EXISTS (SELECT 1 FROM public.revenue_entries WHERE business_id = '20000000-0000-4000-8000-000000000001' AND amount = 30)"
assert_value "merchant A can insert own expenses" t \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); INSERT INTO public.expense_entries (business_id, amount, expense_date) VALUES ('20000000-0000-4000-8000-000000000001', 40, CURRENT_DATE); SELECT EXISTS (SELECT 1 FROM public.expense_entries WHERE business_id = '20000000-0000-4000-8000-000000000001' AND amount = 40)"
assert_value "merchant A can update allowed own business profile" t \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); UPDATE public.businesses SET location = 'Test A Updated' WHERE id = '20000000-0000-4000-8000-000000000001'; SELECT EXISTS (SELECT 1 FROM public.businesses WHERE id = '20000000-0000-4000-8000-000000000001' AND location = 'Test A Updated')"
assert_denied "merchant A cannot change business ownership" \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$user_a', false); UPDATE public.businesses SET owner_id = '10000000-0000-4000-8000-000000000002' WHERE id = '20000000-0000-4000-8000-000000000001'"

assert_value "admin can read all owner rows" 2 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$admin', false); SELECT count(*) FROM public.owners"
assert_value "admin can read all businesses" 2 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$admin', false); SELECT count(*) FROM public.businesses"
assert_value "admin can read all bot sessions" 2 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$admin', false); SELECT count(*) FROM public.bot_sessions"
assert_value "admin can read all trust signals" 2 \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$admin', false); SELECT count(*) FROM public.trust_signals"
assert_value "admin helper does not grant writes directly" f \
  "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '$admin', false); SELECT has_table_privilege(current_user, 'public.owners', 'UPDATE')"
assert_value "service role bypasses RLS for backend reads" 2 \
  "SET ROLE service_role; SELECT count(*) FROM public.owners"
assert_value "service role can perform backend writes" t \
  "SET ROLE service_role; UPDATE public.businesses SET location = 'Backend Updated' WHERE id = '20000000-0000-4000-8000-000000000002'; SELECT EXISTS (SELECT 1 FROM public.businesses WHERE id = '20000000-0000-4000-8000-000000000002' AND location = 'Backend Updated')"

assert_denied "anon has no mzanzi schema access" \
  "SET ROLE anon; SELECT * FROM mzanzi.users"
assert_denied "authenticated has no mzanzi schema access" \
  "SET ROLE authenticated; SELECT * FROM mzanzi.users"
assert_denied "service role has no mzanzi schema access" \
  "SET ROLE service_role; SELECT * FROM mzanzi.users"
assert_value "mzanzi RLS remains enabled without client policies" t \
  "SELECT bool_and(c.relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'mzanzi' AND c.relkind = 'r'"
assert_value "public defaults no longer grant anon/authenticated" t \
  "SELECT NOT EXISTS (SELECT 1 FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace CROSS JOIN LATERAL aclexplode(d.defaclacl) x WHERE n.nspname = 'public' AND x.grantee IN (0, (SELECT oid FROM pg_roles WHERE rolname = 'anon'), (SELECT oid FROM pg_roles WHERE rolname = 'authenticated')))"

psql_exec -f - < "$ROOT/supabase/drafts/007_security_hardening_SAFE_ROLLBACK_DRAFT.sql"
psql_exec -f - < "$ROOT/supabase/drafts/008_net_schema_lockdown_SAFE_ROLLBACK_DRAFT.sql"
psql_exec -f - < "$ROOT/supabase/drafts/009_extension_stats_lockdown_SAFE_ROLLBACK_DRAFT.sql"
psql_exec -f - < "$ROOT/supabase/drafts/010_realtime_subscription_lockdown_SAFE_ROLLBACK_DRAFT.sql"
assert_denied "safe rollback remains closed to anon" \
  "SET ROLE anon; SELECT * FROM public.owners"
assert_denied "safe rollback remains closed to authenticated clients" \
  "SET ROLE authenticated; SELECT * FROM public.owners"
assert_denied "safe rollback does not restore anonymous uploads" \
  "SET ROLE anon; INSERT INTO storage.objects (bucket_id, name) VALUES ('verifications', 'rollback.jpg')"
assert_denied "safe rollback does not restore anonymous pg_net access" \
  "SET ROLE anon; SELECT * FROM net.http_request_queue"
assert_denied "safe rollback does not restore anonymous query-statistics access" \
  "SET ROLE anon; SELECT * FROM extensions.pg_stat_statements"
assert_denied "safe rollback does not restore anonymous Realtime subscription reads" \
  "SET ROLE anon; SELECT * FROM realtime.subscription"
assert_value "safe rollback preserves backend service access" 2 \
  "SET ROLE service_role; SELECT count(*) FROM public.owners"
assert_value "safe rollback preserves pg_net server access" 200 \
  "SET ROLE service_role; SELECT net.http_post('https://test.invalid')"
assert_value "safe rollback preserves query-statistics server access" 1 \
  "SET ROLE service_role; SELECT count(*) FROM extensions.pg_stat_statements"
assert_value "safe rollback preserves Realtime server access" 1 \
  "SET ROLE service_role; SELECT count(*) FROM realtime.subscription"

node --test "$ROOT/tests/security/whatsapp-security.test.mjs"
