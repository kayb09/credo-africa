# Recovery status and scope

**Status:** repository recovery documentation is reconciled; live migration
ledger and database state were not accessed in this task.

## Recovered evidence

- The prior recovery report records seven Credo migration files plus an eighth
  historical ledger entry, version `20260627101525`. The eighth entry is
  excluded from active migrations and documented in
  [historical-migration-provenance.md](./historical-migration-provenance.md).
- The currently identified Credo public application inventory consists of
  nine tables. The previous 58-table catalog count is not an ownership count;
  other schemas are classified separately in
  [milestone-2-security-audit.md](./milestone-2-security-audit.md).
- The recovered public schema snapshot is structural evidence only and
  contains no table rows.
- Prior catalog and deployment findings are labeled as captured or previously
  observed. Current API exposure, Storage behavior, and deployed function
  configuration remain unverified in this task.

## Scope and safeguards

- No database, production system, migration, function, credential, or
  deployment was accessed or changed during this documentation reconciliation.
- No separate Mzansi Tax App repository or project resource was accessed or
  modified. Repository-local historical evidence is retained only as
  provenance and is not treated as Credo application functionality.
- The four protected PostgreSQL 17 checkpoint files remain unchanged.
- Security remediation SQL remains draft-only. Do not apply or deploy it as
  part of this recovery.

## Remaining blockers

1. Reconcile the reported eight-entry historical ledger against the live
   authorized Credo ledger through a separate approved read-only check.
2. Verify current catalog privileges and PostgREST exposed schemas.
3. Validate Storage API behavior and deployed webhook settings without
   changing production.
4. Resolve ownership questions for catalog objects not identified as Credo
   application tables before including them in Credo audit conclusions.
