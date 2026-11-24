# Milestone 2: Credo Africa Identity security audit and remediation preparation

**Status:** read-only catalog review complete; remediation is draft-only.
No production migration, policy, record, function, storage setting, or credential
was changed. No table rows or real merchant personal information were queried.

## Project scope

This audit is limited to Credo Africa Identity and its authorised Supabase project
`mfvhurvsgnzltkwvmoki`. Mzansi Tax App is a separate project and is not included.
Any resource that may belong to another project must be stopped and reported,
not incorporated into this audit.

## Evidence collected

The read-only `supabase_read_only_user` session inventoried 58 verified
Credo-owned non-system tables and three views, along with observed RLS policies,
effective table/function/schema/sequence privileges, RLS flags, default ACLs,
role RLS-bypass flags, routine metadata, and the `verifications` bucket
configuration. No explicit column-level ACL entries were found for `anon`,
`authenticated`, or `service_role`.

The public schema snapshot is
[live-public-schema.sql](./live-public-schema.sql). No Mzansi Tax App schema,
table, migration, credential, or data artifact is included.

## Credo public application tables

RLS is enabled but not forced on all nine public tables. `anon` and
`authenticated` have broad table privileges, including `TRUNCATE`, which RLS
alone cannot constrain. The permissive policies create the following exposure:

| Tables | Observed policy/access |
|---|---|
| `owners`, `businesses` | Anonymous `SELECT` and unconditional `ALL` policy coverage that applies to API roles with the existing grants. |
| `activity_history` | Anonymous unrestricted `SELECT` and `INSERT`; authenticated has no row policy. |
| `bot_sessions` | Anonymous unrestricted `SELECT`; authenticated has no row policy. |
| `credit_scores`, `expense_entries`, `revenue_entries`, `supplier_records`, `trust_signals` | Anonymous unrestricted `SELECT`; authenticated has no row policy. |

`service_role` has `BYPASSRLS` and broad table privileges. It must remain
server-only. `postgres` also has `BYPASSRLS`.

The proposed draft removes broad public grants and unconditional policies,
requires an explicit owner-to-Auth mapping, and constrains merchant operations.

## Storage

The `verifications` bucket is private, but an active anonymous `INSERT` policy
on `storage.objects` permits uploads and no size or MIME limit was configured.
The draft removes anonymous and authenticated direct object privileges and drops
the anonymous upload policy. It does not change bucket settings or managed
storage defaults.

## Supabase-managed and API surfaces

The catalog evidence, not proof of PostgREST reachability, found:

| Schema or surface | Credo-only assessment |
|---|---|
| `public` | Nine application tables require policy and grant hardening. |
| `storage` | Direct API-role object privileges and an anonymous verification upload policy require review. |
| `net` | API roles have table and routine access. REST exposure is unconfirmed. The focused draft remains draft-only. |
| `realtime` | API roles have subscription-table access and RLS is disabled on that table. RLS denies direct `messages` access. |
| `extensions` | Query-statistics views/functions are selectable by API roles. REST exposure is unconfirmed. |
| `cron` | Two RLS-enabled tables have two policies; API-role schema usage was absent. |
| `auth` | No API-role table privileges were observed. |
| `supabase_migrations` | No API-role schema usage or table grants were observed. |
| `vault` | Secret access was restricted to privileged server roles in effective grants; no secret values were queried. |

The API-exposed schema list was unavailable. Exposure of `net`, `realtime`,
`extensions`, or GraphQL routes remains an explicit staging check.

## Proposed access model

- **Anonymous:** no access to public application rows or verification objects.
- **Merchant:** explicit, secure `public.owners.auth_user_id` mapping; least-
  privilege reads and permitted revenue/expense operations only.
- **Administrator:** private server-enforced allowlist and audited backend
  operations, never direct client writes.
- **Backend:** `service_role` remains server-only and bypasses RLS.
- **Storage:** verification objects remain backend-only until a separately
  approved signed/authenticated flow exists.
- **Supabase-managed schemas:** preserve server/platform dependencies and
  change only with owner review.

## Draft artifacts

- [007_security_hardening_DRAFT.sql](../../supabase/drafts/007_security_hardening_DRAFT.sql)
- [007_supabase_admin_defaults_DRAFT.sql](../../supabase/drafts/007_supabase_admin_defaults_DRAFT.sql)
- [008_net_schema_lockdown_DRAFT.sql](../../supabase/drafts/008_net_schema_lockdown_DRAFT.sql)
- [009_extension_stats_lockdown_DRAFT.sql](../../supabase/drafts/009_extension_stats_lockdown_DRAFT.sql)
- [010_realtime_subscription_lockdown_DRAFT.sql](../../supabase/drafts/010_realtime_subscription_lockdown_DRAFT.sql)
- [whatsapp-bot-security_DRAFT.mjs](../../supabase/drafts/whatsapp-bot-security_DRAFT.mjs)

All draft SQL remains unapplied. Safe rollbacks remain fail-closed.

## Dependencies and remaining risks

1. Approve explicit owner-to-Auth mapping and merchant write operations.
2. Confirm API-exposed schemas and validate `graphql_public.graphql`.
3. Validate storage and public policies in staging without production records.
4. Integrate Twilio signature validation and media-origin checks only in a
   separately approved, tested deployment.
5. No production migration or credential change has been made.
