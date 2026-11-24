# Credo Africa Identity audit and recovery status

**Scope:** Credo Africa Identity only. This is an evidence-based recovery report,
not a production remediation approval or a comprehensive application security
audit. No production change has been made.

## A. Identified Credo application components

The currently identified Credo public application tables are:
`owners`, `businesses`, `activity_history`, `credit_scores`, `bot_sessions`,
`revenue_entries`, `expense_entries`, `supplier_records`, and `trust_signals`.
This is the currently identified application inventory, not proof that no
additional legitimate Credo resources exist.

The frontend is a tracked single-page `index.html` using the Supabase JavaScript
client and direct database/storage calls. The administrator gate uses a
hardcoded client-side PIN and a `localStorage` flag; no Supabase sign-in flow was
found in the inspected source. This does not establish whether independent
server-side authorization exists.

## B. Platform and database inventory

The earlier read-only catalog report described 63 table relations across
multiple schemas. Removing the five relations in the disputed historical
`mzanzi` schema leaves a **catalog count of 58**, not 58 Credo-owned tables.
Only the nine `public` tables above are currently identified as Credo
application tables. The other relations are classified by their schema and
previously recorded catalog description below; schema presence alone does not
establish product ownership.

| Schema | Previously reported relations | Classification and evidence status |
|---|---:|---|
| `public` | 9 | Currently identified Credo application tables; structural evidence is in [live-public-schema.sql](./live-public-schema.sql). |
| `auth` | 27 | Supabase authentication/platform schema by convention; catalog count was previously reported, not rechecked here. |
| `cron` | 2 | Platform/extension-managed schema by convention; exact object ownership and current state not independently verified. |
| `net` | 2 | Previously described as pg_net relations; PostgreSQL extension-managed, with current state not independently verified. |
| `realtime` | 8 | Previously described as Realtime relations, including dated partitions; platform-managed by convention, current state not independently verified. |
| `storage` | 8 | Supabase Storage relations; platform-managed by convention, current state not independently verified. |
| `supabase_migrations` | 1 | Migration ledger/platform metadata; not application data. |
| `vault` | 1 | Supabase Vault relation; platform-managed by convention, current state not independently verified. |
| **Subtotal excluding disputed historical schema** | **58** | Catalog arithmetic only; not an ownership count. |

The prior catalog report also described two `extensions` statistics views and one
`vault` view. They are views, not part of the 58 table-relation count. Their
current presence and reachability have not been independently rechecked.

Historical repository and audit evidence records five relations in schema
`mzanzi`. Their presence in a prior catalog report does not establish Credo
product ownership. They are excluded from the Credo application inventory and
from current Credo security conclusions pending separate authorized
reconciliation.

## C. Historical migration evidence

The prior recovery inventory recorded eight entries in the migration ledger,
including version `20260627101525`, name
`create_mzanzi_schema_and_tables`. The historical SQL was recorded as creating
schema `mzanzi` and five tables. The prior catalog report also recorded those
relations as present. This is historical evidence of a ledger entry and
database presence in the project previously identified as Credo's authorized
Supabase project; it does not prove Credo product ownership or establish that
the migration caused the observed objects.

The unrelated SQL is not retained in the active migration directory. The
pointer-level provenance record is
[historical-migration-provenance.md](./historical-migration-provenance.md).
Reconciliation against the live ledger requires a separate authorized
read-only verification. Do not replay or deploy the historical migration.

## D. Security findings and evidence level

### Public database access — captured structural evidence

The recovered public schema dump contains nine public tables, RLS enabled on
each, broad grants to `anon` and `authenticated`, and twelve policies. It
records anonymous unconditional `SELECT` policies on application tables, an
anonymous `INSERT` policy on `activity_history`, and unconditional
`owners`/`businesses` policies without an explicit role target. The snapshot
supports these historical configuration findings; it is not a live recheck or
an end-to-end API test. The prior catalog report also described broad effective
privileges, including `TRUNCATE`. No production fix is claimed.

### Storage — previously observed, not independently rechecked

The prior catalog report described the `verifications` bucket as private with
an anonymous object `INSERT` policy and no configured size/MIME limits. The
underlying Storage catalog output is not retained in the repository and was
not rechecked during this documentation task. Treat this as a previously
reported security finding requiring authorized read-only confirmation, not as
a verified current state or a fixed issue.

### Managed schemas and API exposure — privilege findings conditional on exposure

The earlier catalog report described API-role privileges on `net`, access to
query-statistics views/functions in `extensions`, and access to
`realtime.subscription`. The PostgREST exposed-schema configuration was not
available. REST reachability is therefore unverified; do not describe these
privileges alone as confirmed reachable API vulnerabilities. GraphQL exposure
and live endpoint behavior also remain unverified.

### WhatsApp webhook — recovered source evidence; deployment metadata not rechecked

The recovered `whatsapp-bot` source uses `SUPABASE_SERVICE_ROLE_KEY`, contains
no visible Twilio signature validation, and fetches request-supplied media URLs
with Twilio credentials without visible origin, redirect, or response-size
checks. The recovery report says this source matched the deployed source at
recovery time. The reported deployed `verify_jwt=false` setting is prior
deployment metadata and was not independently rechecked here. No function was
deployed or changed.

### Frontend administrator gate — tracked source evidence

The tracked frontend contains a hardcoded PIN and client-side `localStorage`
administrator state. These are not server authentication or authorization.
Whether all privileged data operations are independently protected must be
verified at the backend; the recovered public-schema evidence raises a
separate concern. No frontend or backend behavior was changed.

## E. Remediation and remaining verification

All security SQL remains draft-only and unapplied. No production database,
policy, storage setting, function, credential, or deployment was changed.
Previously reported findings remain findings; this documentation does not
claim they were remediated.

Remaining evidence gaps include current authorized catalog state; PostgREST and
GraphQL exposure; Storage API behavior and bucket limits; server-side
administrator authorization; deployed webhook configuration and end-to-end
signature/media behavior; and classification of database objects whose
ownership is unresolved. Resolve these only through separately authorized,
read-only Credo verification before considering remediation.
