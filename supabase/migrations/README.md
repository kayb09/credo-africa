# Recovered migration history

The eight migration files in this directory were recovered from the `statements` arrays in the live project's `supabase_migrations.schema_migrations` table on 2026-11-24. Each file preserves the one statement recorded for its version. The version/name inventory and provenance are documented in [migration-recovery-inventory.md](../../docs/audit/migration-recovery-inventory.md).

These files are historical audit artifacts, not instructions to replay or deploy. One includes `DROP TABLE ... CASCADE`. No production migration was run. The files in `supabase/drafts/` and `tests/history/` remain development/test artifacts, not part of this live migration history.
