# Production schema snapshot recovery

**Status: recovered from the previously authorized Credo project; not refreshed
in this documentation task.**

The schema-only `public` snapshot is
[live-public-schema.sql](./live-public-schema.sql). The prior recovery report
says it was captured from project `mfvhurvsgnzltkwvmoki` on 2026-11-24. It
contains nine currently identified Credo public application tables, twelve
policies, and RLS enabled on those nine tables. It contains no table rows
(`INSERT` or `COPY` data statements).

This is structural evidence at capture time, not a current database check or
a claim that the database contains no other legitimate Credo resources. The
broader earlier catalog count does not establish ownership; see
[milestone-2-security-audit.md](./milestone-2-security-audit.md).
Generated public types are in
[`database.types.ts`](../../supabase/types/database.types.ts).
