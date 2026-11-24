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
- The structural-only public schema is [live-public-schema.sql](./live-public-schema.sql); generated types are in [database.types.ts](../../supabase/types/database.types.ts). Storage bucket/object policy configuration was not part of this public-schema recovery.

## Risk assessment

The recovered public-schema policies warrant urgent review because the anonymous policies use unconditional predicates and permit reads or inserts on application tables. The two policies without an explicit role target apply to the default `PUBLIC` role. This report does not test effective access through grants, views, RPCs, or role inheritance. Storage policy behavior was not inspected here.

The recovered WhatsApp function uses the service-role key from its environment and contains no visible Twilio signature validation. The browser-side administrator gate and consent flag are not server authorization or durable consent records. These findings need a separate approved remediation effort; this recovery made no production changes.

## Audit coverage by area

- **Frontend:** the static observations above are confirmed from the tracked source. Authentication, authorization, privacy, accessibility, and runtime behavior were not comprehensively tested.
- **Backend and integrations:** exact deployed source was recovered. `keep-alive` returns a timestamped alive response; neither runtime behavior nor abuse controls were exercised.
- **Database:** the migration identities and ledger-stored SQL were recovered, and a structural-only public schema snapshot plus generated public types were captured. No table data was queried. Storage configuration and an effective role/access test matrix remain unverified.
- **Business intelligence:** table names alone do not establish scoring implementation, feature definitions, or validation. Fairness, explainability, data quality, and decision-use risks were not assessed.
- **Repository readiness:** no frontend package manifest or automated frontend test suite is tracked. The Stock and Purchasing V1 SQL and tests are a separate development checkpoint.

## Remaining work

Recovery is complete for the requested artifact scope. Remaining audit/remediation work includes:

- Testing effective access as `anon`, authenticated users, and privileged backend roles, including views and RPCs.
- Inspecting storage bucket/object policies and their effective access.
- Defining and testing suitable Twilio webhook authentication and the intended public behavior for `keep-alive`.
- Reviewing and approving any security remediation separately. Do not replay historical SQL or deploy recovered functions from this branch as part of recovery.

See [security-remediation-plan.md](./security-remediation-plan.md) for proposed follow-up work.
