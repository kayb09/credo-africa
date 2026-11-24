# Recovered Credo migration history

Seven active Credo migration files are retained in this directory. The prior recovery inventory reported eight entries in the project's `supabase_migrations.schema_migrations` ledger; one historical entry is excluded from the active directory because its product ownership is unresolved. See [migration-recovery-inventory.md](../../docs/audit/migration-recovery-inventory.md) and [historical-migration-provenance.md](../../docs/audit/historical-migration-provenance.md).

These files are historical audit artifacts, not instructions to replay or deploy. One includes `DROP TABLE ... CASCADE`. No production migration was run. The files in `supabase/drafts/` and `tests/history/` remain development/test artifacts, not part of this recovered migration history.
