# Milestone 2: Credo Africa Identity security audit

**Status:** documentation reconciled from repository artifacts and previously
recorded read-only evidence. No database was accessed in this reconciliation.
All security remediation SQL remains draft-only; no production change is
claimed.

## Scope and evidence boundaries

The authorized project previously identified in recovery is Supabase project
`mfvhurvsgnzltkwvmoki`. Database presence is not by itself proof of Credo
application ownership. The currently identified Credo public application tables
are exactly:

`owners`, `businesses`, `activity_history`, `credit_scores`, `bot_sessions`,
`revenue_entries`, `expense_entries`, `supplier_records`, and `trust_signals`.

This is the currently identified set, not a claim that no other legitimate
Credo components exist. The earlier 58-table count is a catalog count after
excluding five relations in the disputed `mzanzi` schema; it is not 58 verified
Credo-owned application tables.

The prior catalog report states it inspected table/view metadata, RLS,
privileges, policies, default ACLs, role flags, routines, and Storage metadata.
Raw catalog query output is not retained here, and these observations were not
independently refreshed. The structural public-schema snapshot
[live-public-schema.sql](./live-public-schema.sql) is retained and documents
nine public tables, their policies, grants, and RLS settings as captured.
No table rows are in that snapshot.

## Database object classification

The following counts are transcribed from the earlier catalog report, not a
current database query. Classification reflects schema conventions and the
prior report, not independent proof of product or object ownership.

| Schema | Previously reported table relations | Classification |
|---|---:|---|
| `public` | 9 | Currently identified Credo application tables; see list above. |
| `auth` | 27 | Supabase authentication/platform infrastructure by convention. |
| `cron` | 2 | Platform/extension infrastructure by convention; exact ownership unresolved. |
| `net` | 2 | Previously described as pg_net extension relations; current state unresolved. |
| `realtime` | 8 | Realtime infrastructure by convention, including six dated partitions; lifecycle/ownership not independently verified. |
| `storage` | 8 | Supabase Storage infrastructure by convention. |
| `supabase_migrations` | 1 | Migration-ledger/platform metadata. |
| `vault` | 1 | Supabase Vault infrastructure by convention. |
| **Total excluding disputed historical schema** | **58** | **Catalog count only; not a Credo ownership total.** |

The earlier report separately described two `extensions` statistics views and
one `vault` view. Those are not tables and are not included in the count.

The prior inventory also recorded five relations in schema `mzanzi`. Their
database presence and a prior ledger entry are historical facts reported by
repository evidence. Their ownership and product scope are unresolved; they
are not Credo application components and are excluded from the Credo findings
below. See [historical-migration-provenance.md](./historical-migration-provenance.md).

## Findings by evidence status

### Captured public-schema evidence

The recovered schema snapshot records:

- Nine public application tables, each with RLS enabled (not forced).
- Broad table grants to `anon` and `authenticated`.
- Unconditional anonymous `SELECT` policies on public application tables and
  an anonymous `INSERT` policy on `activity_history`.
- Unconditional `owners` and `businesses` policies without an explicit role
  target.
- Twelve policies total in the snapshot.

These are real configuration findings in the captured snapshot. The prior
catalog report additionally stated effective API-role privileges included
`TRUNCATE`; this is not an end-to-end test of REST behavior. The current live
state was not rechecked, and no remediation has been applied.

### Previously reported catalog findings; not independently rechecked

- **Storage:** the prior report described a private `verifications` bucket
  with an active anonymous object `INSERT` policy and no configured size/MIME
  limits. The underlying Storage catalog output is not retained. This remains
  a reported security finding requiring authorized read-only confirmation.
- **Default privileges:** the prior report described broad public-schema
  defaults for `postgres` and `supabase_admin`. Those statements were not
  refreshed in this task.
- **Managed-schema privileges:** the prior report described API-role grants
  on `net`, query-statistics access in `extensions`, and access to
  `realtime.subscription`. Current privileges were not rechecked.

### Exposure or behavior requiring live configuration checks

The prior audit could not establish the PostgREST exposed-schema list. Thus
catalog privileges on `net`, `realtime`, and `extensions` do not by themselves
prove REST reachability. GraphQL exposure, actual REST/Storage operations, and
production-like cross-tenant behavior remain unverified.

### Recovered application source

- **WhatsApp:** the recovered `whatsapp-bot` source uses
  `SUPABASE_SERVICE_ROLE_KEY`, has no visible Twilio signature validation, and
  fetches request-supplied media URLs with Twilio credentials without visible
  origin, redirect, or response-size checks. The earlier recovery report says
  the source matched the deployed source at that time. The reported
  `verify_jwt=false` setting is prior deployment metadata, not independently
  rechecked here.
- **Frontend administrator gate:** tracked `index.html` has a hardcoded PIN
  and `localStorage` administrator flag. These are client-side controls, not
  server authentication. Backend enforcement was not tested.

## Remediation status and limits

All SQL artifacts under `supabase/drafts/` remain draft-only and unapplied.
The helper for webhook validation is not evidence that the deployed function
has been changed. No production vulnerability is claimed fixed.

Before any remediation decision, separately verify current Credo catalog
state, API-exposed schemas, Storage API behavior and limits, server-side
authorization, and deployed webhook configuration. Do not access or modify
resources belonging to a separate project.
