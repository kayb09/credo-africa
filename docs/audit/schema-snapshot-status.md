# Production schema snapshot recovery

**Status: recovered.** A schema-only dump of the live `public` schema was saved at [`live-public-schema.sql`](./live-public-schema.sql). It was captured from project `mfvhurvsgnzltkwvmoki` with the Supabase CLI `db dump --schema=public` command on 2026-11-24.

The snapshot contains definitions for nine tables, twelve policies, and row-level security enabled on all nine tables. It contains no table rows (`INSERT` or `COPY` data statements). It is structural evidence, not a migration, and was not applied to production.

The snapshot is limited to the `public` schema. A separate [mzanzi schema snapshot](./mzanzi-schema.sql) and the full catalog access/RLS audit for 63 non-system tables and three views are documented in [milestone-2-security-audit.md](./milestone-2-security-audit.md). No table data was retrieved. See [`database.types.ts`](../../supabase/types/database.types.ts) for TypeScript types generated from the live public schema.
