# Migration recovery status

No original application migrations were available in the checkpoint repository. The task reports eight migrations in the live project, but their versions, names, and SQL could not be retrieved without authorized read access.

Do not add reconstructed SQL or rename a schema snapshot as a migration. The files in `supabase/drafts/` and `tests/history/` are development/test artifacts, not evidence of applied production migrations. See [the migration recovery inventory](../../docs/audit/migration-recovery-inventory.md).
