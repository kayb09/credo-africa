# Credo platform audit: recovery status

**Status: incomplete; production metadata recovery is blocked.** This report separates repository observations from environment facts supplied for this task. It is not a production verification or a deployment approval.

## Scope and evidence

- The recovery branch starts at checkpoint `cae57a7f63417063b9d78b931979d26a8ae7ab21`.
- The tracked repository contains a single-page frontend in `index.html`, development-only Stock and Purchasing SQL under `supabase/drafts/`, and its PostgreSQL tests. It has no original `supabase/migrations/`, Edge Function source, or generated database types.
- The frontend source references the Supabase JavaScript client from a CDN, performs direct Supabase queries and a `verifications` storage upload, and keeps the administrator gate and consent state in `localStorage`. The administrator gate is not server authentication. No Supabase sign-in flow was found in the inspected frontend.
- The live environment facts below were provided for this task and were not independently queried. A read-only Supabase CLI function download was attempted for project `mfvhurvsgnzltkwvmoki`; the CLI returned `AccessTokenRequiredError` and did not authenticate. No production credential, API key, function secret, merchant record, or personal information was requested or exported.
- No production database, policy, storage setting, function, or deployment was changed.

## Supplied live-environment facts (not independently verified)

- PostgreSQL server version: 17.6.
- Eight application migrations are recorded in the live project. Their versions and names were not supplied and could not be queried.
- Two deployed Edge Functions are reported: `whatsapp-bot` active version 5 and `keep-alive` active version 1. Both have `verify_jwt=false`.
- The WhatsApp function is reported to use the service-role key and not visibly validate Twilio request signatures. Its deployed source and configuration were not recovered.
- The public schema is reported to contain `owners`, `businesses`, `activity_history`, `credit_scores`, `bot_sessions`, `revenue_entries`, `expense_entries`, `supplier_records`, and `trust_signals`.
- Reported policy issues: anonymous unrestricted reads on several application tables; two policies labelled as service-role policies are assigned to `public` and allow unrestricted operations; and anonymous uploads are allowed to the private `verifications` bucket.
- The frontend is reported to contain a hardcoded administrator PIN and a `localStorage`-only administrator gate, to store consent in `localStorage`, and to have no Supabase authentication flow.

## Risk assessment

The supplied policy and storage findings create potential unauthorized disclosure and write paths. The `public` role assignment must be evaluated by its effective privileges, not its policy name. Anonymous access to private verification storage can permit untrusted content uploads. A browser-side PIN or consent flag is not an authentication or durable consent record. A service-role key in an Edge Function increases impact if the webhook is not authenticated and the key is exposed or misused.

These are high-priority findings requiring live policy, bucket, and function-source verification. The exact affected policies, tables, operations, data exposure, and reachable attack paths remain unconfirmed in this recovery because live read access was unavailable.

## Audit coverage by area

- **Frontend:** the tracked application is a single `index.html` using CDN-loaded libraries and direct Supabase client calls. The reported administrator gate and consent flag are browser-local only. Authentication, authorization, privacy, accessibility, and runtime behavior cannot be validated comprehensively without an executable frontend test setup and backend policy evidence.
- **Backend and integrations:** no Edge Function source or configuration is present in the checkpoint. The reported WhatsApp/Twilio integration therefore cannot be reviewed for signature validation, service-role usage, input validation, replay protection, logging, or error handling. The purpose and abuse controls for `keep-alive` also remain unverified.
- **Database:** no original application migration history or live catalog snapshot is available. The supplied table and policy inventory is insufficient to confirm definitions, grants, RLS expressions, triggers, RPCs, or effective access.
- **Business intelligence:** the supplied names include credit-score and trust-signal tables, but no scoring implementation, feature definitions, or validation evidence is available. Fairness, explainability, data quality, and decision-use risks cannot be assessed from table names alone.
- **Repository readiness:** no frontend package manifest or automated frontend test suite is tracked. The Stock and Purchasing V1 SQL and tests are a separate development checkpoint and are not evidence of the deployed application schema.

## Missing evidence and unresolved questions

See [migration-recovery-inventory.md](./migration-recovery-inventory.md), [schema-snapshot-status.md](./schema-snapshot-status.md), and [security-remediation-plan.md](./security-remediation-plan.md). In summary:

- The eight live migration version/name pairs and the corresponding original SQL are not in the repository or available through the attempted CLI request.
- Neither deployed Edge Function source nor its deployed configuration was recovered; the current deployed code cannot be compared with repository source.
- A structural-only live schema snapshot and generated TypeScript database types were not produced.
- The exact RLS policies and role targets, storage policies, grants, indexes, constraints, triggers, and function definitions need read-only live inspection.
- The intended Twilio webhook authentication and replay-protection requirements, and the intended public access for `keep-alive`, need owner confirmation.

Do not treat any recovery status file in this branch as function source, generated types, a schema snapshot, or an original migration. Do not deploy from this branch until the missing production artifacts have been recovered and reviewed.
