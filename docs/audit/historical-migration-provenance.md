# Historical migration provenance record

**Purpose:** preserve a limited historical fact without treating the resource
as Credo Africa Identity product functionality.

## Recorded history

The previous recovery inventory states that a read-only query of
`supabase_migrations.schema_migrations` on the project then identified as the
authorized Credo Supabase project returned migration version
`20260627101525`, name `create_mzanzi_schema_and_tables`, and its SQL statement.
The preceding audit also reported a catalog observation of schema `mzanzi`
and five relations in that schema.

The historical SQL, as recovered in repository history, created a schema named
`mzanzi` and five tables. This document intentionally does not reproduce the
SQL, field definitions, or application logic. A ledger entry and catalog
presence establish historical database/recovery evidence only; they do not
establish that these objects were Credo product functionality or that this
migration alone caused their presence.

## Active migration treatment

The SQL is excluded from active Credo application migrations because its
application ownership is unresolved and the historical recovery associated it
with a separate product scope. The zero-byte placeholder was removed from
`supabase/migrations/`; no repository script or configuration inspected during
this task required an empty migration file. The migration identity remains
recorded here and in the corrected
[migration recovery inventory](./migration-recovery-inventory.md).

This repository-only choice does not reconcile local files against the live
migration ledger. That reconciliation remains pending a separate authorized
read-only verification before any migration operation.

## Separation and access statement

During this documentation reconciliation, no separate Mzansi Tax App
repository, database, Supabase project, credentials, application, or deployment
was accessed or modified. Only Credo repository history and its previously
recorded evidence were reviewed. No database or production system was accessed
or changed in this task.
