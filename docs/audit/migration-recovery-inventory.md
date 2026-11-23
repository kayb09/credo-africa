# Migration recovery inventory

**Status: blocked; no live migration identities or original SQL were recovered.**

The task-supplied live-environment fact is that the project records eight application migrations. The exact versions and names are not available in the repository, and could not be read from the project because the Supabase CLI reported that an access token is required. No migration identity has been inferred or invented.

| Live history | Version | Name | Original SQL in this repository |
|---|---|---|---|
| 8 recorded entries | Not retrieved | Not retrieved | Not found |

The eight entries must be enumerated from the live migration history before this inventory can be completed. Then each exact original SQL file should be recovered from an authoritative source (for example, the original source-control history or a verified backup) and compared with the deployed schema.

## Local SQL files are not original application migrations

The repository has no `supabase/migrations/` directory at the checkpoint. The files below are development or test artifacts and must not be relabelled as any of the eight live migrations:

- `supabase/drafts/006_stock_purchasing_v1_DRAFT.sql` — explicitly a one-shot development draft; not reported as applied to production.
- `supabase/drafts/006_ROLLBACK_DRAFT.sql` — destructive rollback for that draft; not a historical migration.
- `tests/history/006_rev2_for_reproduction.sql` — historical test/reproduction artifact for Stock and Purchasing V1; not an original application migration.

No schema snapshot should be placed in this directory or represented as a migration. Populate this directory only with verified original migration files after their version and name have been confirmed against the live migration history.
