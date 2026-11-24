# Credo migration recovery inventory

**Status:** seven active Credo migration files are retained in
`supabase/migrations/`. This is not a claim that the previously reported live
ledger contained only seven entries.

The prior recovery report states that read-only queries to
`supabase_migrations.schema_migrations` on project
`mfvhurvsgnzltkwvmoki` returned **eight** version/name pairs and SQL statements.
Seven are retained as active Credo migration files:

| Version | Name | Repository file |
|---|---|---|
| `20260603080701` | `create_owners_table` | `supabase/migrations/20260603080701_create_owners_table.sql` |
| `20260603080707` | `create_businesses_table` | `supabase/migrations/20260603080707_create_businesses_table.sql` |
| `20260603082036` | `update_schema_for_new_bot` | `supabase/migrations/20260603082036_update_schema_for_new_bot.sql` |
| `20260603114635` | `ensure_schema_policies_and_test_data` | `supabase/migrations/20260603114635_ensure_schema_policies_and_test_data.sql` |
| `20260604181157` | `create_new_tables` | `supabase/migrations/20260604181157_create_new_tables.sql` |
| `20260715032923` | `setup_keepalive_cron` | `supabase/migrations/20260715032923_setup_keepalive_cron.sql` |
| `20261016053445` | `onboarding_upload_and_activity_policies` | `supabase/migrations/20261016053445_onboarding_upload_and_activity_policies.sql` |

The eighth historically reported ledger entry was version `20260627101525`,
`create_mzanzi_schema_and_tables`. Its SQL is excluded from active Credo
migrations because its schema and tables are not established as Credo product
functionality. The migration identity and limited historical facts are recorded
separately in [historical-migration-provenance.md](./historical-migration-provenance.md);
the raw SQL is not reproduced.

The previous recovery report says each ledger statement was schema SQL and
records that `20260603082036` drops and recreates tables with `CASCADE`. These
are historical reports, not instructions to replay or deploy. The live ledger
has not been rechecked during this documentation task. Reconcile the reported
eight ledger entries against the current authorized Credo ledger before any
migration operation.

The remaining files under `supabase/migrations/` are not modified by this
reconciliation. The empty `20260627101525` placeholder has been removed from
the active directory; repository tooling did not show a requirement for an
empty migration file. This does not settle how the Supabase CLI will report a
remote-only ledger entry; verify that separately before migration operations.
