# Security remediation plan

This plan is ordered by severity and distinguishes recovered read-only evidence from work still requiring verification. No production changes are authorized or performed by this branch.

## P0 — Contain anonymous data access

1. **Confirmed:** the public catalog has unconditional anonymous reads on all nine tables, an anonymous activity insert, and unconditional `PUBLIC` all-operation policies on `owners` and `businesses`. Effective grants are broad for `anon` and `authenticated`.
2. [The hardening draft](../../supabase/drafts/007_security_hardening_DRAFT.sql) removes these client paths and proposes ownership policies based on an explicit Auth-to-owner link.
3. [Local security tests](../../tests/security/run.sh) cover anon, merchant, cross-business, administrator, service-role, and safe-rollback behavior. Staging validation of views/RPCs and the Storage API remains required.
4. **Confirmed:** `postgres` and `supabase_admin` default ACLs grant broad public-schema privileges to API roles. The main draft revokes `postgres` defaults; [the owner-scoped draft](../../supabase/drafts/007_supabase_admin_defaults_DRAFT.sql) handles `supabase_admin`.
5. **Confirmed, exposure conditional:** API roles have full table access and execute privileges on the Supabase-managed `net` schema, including pg_net HTTP routines; they can select query-statistics views/functions in `extensions` and read the RLS-disabled `realtime.subscription` table. The API-exposed-schema list is unknown. [Focused net](../../supabase/drafts/008_net_schema_lockdown_DRAFT.sql), [statistics](../../supabase/drafts/009_extension_stats_lockdown_DRAFT.sql), and [Realtime subscription](../../supabase/drafts/010_realtime_subscription_lockdown_DRAFT.sql) drafts restrict these capabilities while preserving server/platform access; review with the platform owner before any change. Realtime message ACLs/policies are not changed.

## P0 — Restrict verification uploads

1. **Confirmed:** `verifications` is private, but an active anonymous `INSERT` policy allows uploads; the bucket has no size or MIME limits. The draft removes the anonymous policy and direct client object grants.
2. Keep uploads backend-only until a signed/authenticated flow binds object paths to a verified business. Size/MIME values need product approval.
3. Validate real Storage API behavior in staging, including reads/listing, overwrites, content limits, and cross-business paths.

## P1 — Authenticate the WhatsApp webhook safely

1. **Recovered/reviewed:** the exact deployed source reports `verify_jwt=false`, uses the service-role key, lacks visible Twilio signature validation, and fetches request-supplied media URLs with Twilio credentials.
2. The separate [webhook helper draft](../../supabase/drafts/whatsapp-bot-security_DRAFT.mjs) validates signatures and media origins; integration and end-to-end tests remain required.
3. Keep the Twilio token server-side, reject redirects to prevent credential forwarding, and add replay/duplicate handling and bounded processing before deployment.
4. Do **not** solve this by simply enabling Supabase JWT verification: Twilio webhooks need their own suitable authentication mechanism.
5. Rotate the service-role key only if exposure is confirmed or suspected, using an approved change process and coordinated function configuration update.

## P1 — Replace the frontend administrator gate

1. Remove the hardcoded PIN and treat the `localStorage` flag as presentation state only, never authorization.
2. Introduce Supabase authentication and server-side authorization with explicit administrator roles and least privilege. Require MFA for privileged access where supported.
3. Verify that every privileged data read/write is rejected by backend policy or a trusted server function when the caller lacks authorization.

## P1 — Make consent authoritative and auditable

1. Do not treat browser `localStorage` as proof of consent or withdrawal.
2. Define the consent record, versioned notice, purposes, timestamp, and withdrawal behavior with the privacy owner.
3. Record and enforce consent server-side for processing and sharing that depends on it; test tampering and cross-device behavior.

## P2 — Recover and reconcile platform source of truth

1. **Recovered:** the eight migration identities and ledger-stored SQL are recorded in `docs/audit/migration-recovery-inventory.md`. Do not synthesize historical migrations from the current schema.
2. **Recovered:** the Credo public structural snapshot and current public types were captured. Mzansi Tax App resources are excluded from Credo recovery and remediation.
3. **Recovered:** both deployed Edge Function sources were downloaded and compared byte-for-byte with the existing candidates. Authentication/media hardening is a separate, un-deployed draft.
4. Add CI checks for type drift, migration replay on a disposable PostgreSQL instance, policy tests, and Edge Function tests. Keep production credentials out of CI logs and source control.
