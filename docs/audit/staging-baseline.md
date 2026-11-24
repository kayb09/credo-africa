# Credo staging public-schema baseline

**Status:** repository record of a baseline reported as already applied to the
separate staging project. This document and SQL are not evidence from a live
database check. The SQL was not executed or reapplied during this repository
task.

## Staging target

- Project name: `credo-africa-staging`
- Project reference: `hqxgpmopjtgggldolimz`
- Region: `eu-west-1`
- PostgreSQL: `17.12`
- Reported migration version/name: `20261124135801`,
  `staging_public_schema_baseline`

These target and application details are recorded as supplied for this task;
they were not independently verified by connecting to Supabase.

## Baseline record

The exact SQL reported as applied is preserved at
[`supabase/staging/20261124_public_schema_baseline.sql`](../../supabase/staging/20261124_public_schema_baseline.sql).
It creates nine tables in `public`: `owners`, `businesses`, `credit_scores`,
`bot_sessions`, `revenue_entries`, `expense_entries`, `supplier_records`,
`trust_signals`, and `activity_history`.

The SQL enables RLS on all nine tables and creates no `anon` or
`authenticated` policies. It revokes `PUBLIC`, `anon`, and `authenticated`
privileges on the public schema, tables, sequences, and specified future
objects, grants `service_role` schema usage, and grants it all table and
sequence privileges.

No production data or merchant personal information was copied. This staging
baseline does not enable `pg_cron` or `pg_net` and does not reproduce
production scheduled jobs. It does not require `uuid-ossp`.

## Migration-history boundary

The live production ledger is reported to contain eight historical entries;
seven active Credo migration files match seven reported live version/name
pairs. One eighth historical out-of-scope entry is excluded from this staging
baseline. Its identifier and SQL are intentionally omitted here.

The historical production migration sequence is not replayed: it includes
destructive table rebuilds and a keep-alive job targeting the production Edge
Function URL. This baseline is staging-only bootstrap material, not an active
production migration.

## Repository handling

This SQL is under `supabase/staging/`, not `supabase/migrations/`; it must not
be included in a production `db push`. Do not copy it into the active
migrations directory or execute it again. The reported staging application is
preserved here for auditability; no database, production system, Edge Function,
or deployment was accessed or changed while recording it.
