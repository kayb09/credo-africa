# Migration recovery inventory

**Status: recovered Credo migration identities from the live migration ledger.**

Read-only queries to `supabase_migrations.schema_migrations` on project `mfvhurvsgnzltkwvmoki` returned the following seven Credo migration version/name pairs and their stored `statements` arrays. Each array contained one semicolon-terminated SQL statement. The files below preserve that statement text exactly as recorded by the live ledger; they were not reconstructed from the current schema or inferred from local drafts. Mzansi Tax App migrations are explicitly excluded.

| Version | Name | Recovered file |
|---|---|---|
| `20260603080701` | `create_owners_table` | `supabase/migrations/20260603080701_create_owners_table.sql` |
| `20260603080707` | `create_businesses_table` | `supabase/migrations/20260603080707_create_businesses_table.sql` |
| `20260603082036` | `update_schema_for_new_bot` | `supabase/migrations/20260603082036_update_schema_for_new_bot.sql` |
| `20260603114635` | `ensure_schema_policies_and_test_data` | `supabase/migrations/20260603114635_ensure_schema_policies_and_test_data.sql` |
| `20260604181157` | `create_new_tables` | `supabase/migrations/20260604181157_create_new_tables.sql` |
| `20260715032923` | `setup_keepalive_cron` | `supabase/migrations/20260715032923_setup_keepalive_cron.sql` |
| `20261016053445` | `onboarding_upload_and_activity_policies` | `supabase/migrations/20261016053445_onboarding_upload_and_activity_policies.sql` |

The recovered SQL contains schema operations only; no row data was retrieved. The `20260603082036` record drops and recreates tables with `CASCADE`. These are historical artifacts for audit and provenance, not instructions to replay or deploy. The Stock and Purchasing V1 files under `supabase/drafts/` and `tests/history/` remain development/test artifacts, not part of this live migration history.
