# Credo platform audit: recovery status

**Status: requested read-only recovery is complete.** This report records repository and live-schema evidence; it is not a production remediation approval or a comprehensive application security audit.

## Scope and evidence

- The branch preserves the Stock and Purchasing V1 PostgreSQL 17 checkpoint. Those drafts and tests are separate from the live Credo application schema.
- The frontend is a single-page `index.html` using the Supabase JavaScript client from a CDN, direct Supabase queries, and a `verifications` storage upload. Its administrator gate and consent state are stored in `localStorage`; no Supabase sign-in flow was found in the inspected frontend.
- Read-only Supabase CLI operations confirmed project `mfvhurvsgnzltkwvmoki` is active and reports PostgreSQL 17.6.1.
- No production database, policy, storage setting, function, or deployment was changed. No merchant rows, personal information, function secrets, API keys, or access tokens were retrieved into repository artifacts.

## Verified live observations

- Eight migration version/name pairs and the SQL text stored in the live migration ledger were recovered. See [migration-recovery-inventory.md](./migration-recovery-inventory.md).
- `whatsapp-bot` is active at version 5 and `keep-alive` at version 1; both report `verify_jwt=false`. The recovered source files match fresh Supabase API downloads byte-for-byte.
- The WhatsApp function reads `SUPABASE_SERVICE_ROLE_KEY` from its environment. No Twilio signature validation was found in the recovered source. Secret values were not retrieved.
- The public schema contains nine application tables: `owners`, `businesses`, `activity_history`, `credit_scores`, `bot_sessions`, `revenue_entries`, `expense_entries`, `supplier_records`, and `trust_signals`.
- The schema dump records twelve policies, including unrestricted anonymous `SELECT` policies on application tables, an anonymous `INSERT` policy for `activity_history`, and two owner/business policies with unconditional predicates and no explicit `TO` clause. RLS is enabled on all nine public tables. The effective access matrix was not tested.
- A Milestone 2 catalog audit covers verified Credo-owned components only: 58 non-system tables in the authorised Credo Supabase project, all observed RLS policies and effective API-role table/schema/function privileges, plus three views and the Storage bucket policy. It confirmed the `verifications` bucket is private but has an active anonymous object-insert policy and no size/MIME limits. pg_net tables/functions and query-statistics views have API-role grants whose REST reachability depends on an unverified exposed-schema configuration. See [milestone-2-security-audit.md](./milestone-2-security-audit.md).
- The structural-only public schema is [live-public-schema.sql](./live-public-schema.sql), and generated public types are in [database.types.ts](../../supabase/types/database.types.ts). The policy matrix has not yet been exercised against a production-like deployment.

## Risk assessment

The recovered public-schema policies warrant urgent review because anonymous policies use unconditional predicates and permit reads or inserts on application tables. The two policies without an explicit role target apply to the default `PUBLIC` role. Catalog inspection confirms broad role grants and `service_role` RLS bypass. The active storage policy permits anonymous uploads to the private verification bucket. `anon` and `authenticated` also have broad direct privileges on the Supabase-managed `net` schema, access to query-statistics views, and read access to RLS-disabled Realtime subscription state; whether those relations are reachable through PostgREST is unknown because the API-exposed-schema configuration was not available. Draft-only focused restrictions and isolated tests were added; no production change was made. This report does not exercise production HTTP/API or Storage behavior.

The recovered WhatsApp function uses the service-role key from its environment and contains no visible Twilio signature validation. The browser-side administrator gate and consent flag are not server authorization or durable consent records. These findings need a separate approved remediation effort; this recovery made no production changes.

## Audit coverage by area

- **Frontend:** the static observations above are confirmed from the tracked source. Authentication, authorization, privacy, accessibility, and runtime behavior were not comprehensively tested.
- **Backend and integrations:** exact deployed source was recovered. `keep-alive` returns a timestamped alive response; neither runtime behavior nor abuse controls were exercised.
- **Database:** Credo public-schema migration identities and ledger-stored SQL were recovered. The public schema snapshot was captured with no table rows. Credo-only catalog access/RLS/policy evidence covers verified public and managed components. Draft RLS/ACL tests run in an isolated local database; production-like API and Storage behavior and API-exposed schemas remain unverified. No resource that may belong to Mzansi Tax App is included.
- **Business intelligence:** table names alone do not establish scoring implementation, feature definitions, or validation. Fairness, explainability, data quality, and decision-use risks were not assessed.
- **Repository readiness:** no frontend package manifest or automated frontend test suite is tracked. The Stock and Purchasing V1 SQL and tests are a separate development checkpoint.

## Remaining work

Recovery is complete for the requested artifact scope. Remaining audit/remediation work includes:

- Testing effective access as `anon`, authenticated users, and privileged backend roles, including views and RPCs.
- Confirming API-exposed schemas and validating the migration in staging, including views/RPCs and Storage API behavior.
- Defining and testing suitable Twilio webhook authentication and the intended public behavior for `keep-alive`.
- Reviewing and approving any security remediation separately. Do not replay historical SQL or deploy recovered functions from this branch as part of recovery.

See [security-remediation-plan.md](./security-remediation-plan.md) for proposed follow-up work.
