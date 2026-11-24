# Milestone 2: database security audit and remediation preparation

**Status:** read-only catalog review complete; remediation is draft-only. No production migration, policy, record, function, or storage setting was changed. No table rows or real merchant personal information were queried.

## Evidence collected

Read-only queries inventoried every non-system table and view and inspected policies, effective table/function/schema/sequence privileges, RLS flags, default ACLs, role RLS-bypass flags, routine metadata, and the `verifications` bucket configuration. The inventory covers 63 tables in `auth`, `cron`, `mzanzi`, `net`, `public`, `realtime`, `storage`, `supabase_migrations`, and `vault`, plus two `extensions` views and one `vault` view. Fifteen policies were found: twelve in `public`, two in `cron`, and one in `storage`; no policies were found on the other inspected tables. No explicit column-level ACL entries were found for `anon`, `authenticated`, or `service_role`. The public schema snapshot is [live-public-schema.sql](./live-public-schema.sql); the current row-free tax-schema snapshot is [mzanzi-schema.sql](./mzanzi-schema.sql).

The Supabase catalog session was `supabase_read_only_user`; it cannot change default privileges. Current project API-exposed-schema configuration was not available from the database session. No `SELECT` was issued against application or storage rows.

## Findings by schema

### `public` — nine application tables

RLS is enabled but not forced on all nine tables. `anon` and `authenticated` have all standard table privileges on each, including `TRUNCATE`, which is not constrained by RLS. The permissive RLS policies determine row-level operations reachable through APIs that support them:

| Tables | Observed policy/access |
|---|---|
| `owners`, `businesses` | Anonymous `SELECT` plus an unconditional `ALL` policy whose role target is `PUBLIC`; with existing grants this permits anonymous and authenticated reads/writes. |
| `activity_history` | Anonymous unrestricted `SELECT` and `INSERT`; authenticated has no row policy. |
| `bot_sessions` | Anonymous unrestricted `SELECT`; authenticated has no row policy. Sessions can contain onboarding data. |
| `credit_scores`, `expense_entries`, `revenue_entries`, `supplier_records`, `trust_signals` | Anonymous unrestricted `SELECT`; authenticated has no row policy. |

`service_role` has `BYPASSRLS` and current table privileges. Do not add a “service role” RLS policy: backend operations should use its server-only credential, never a browser key. `postgres` also has `BYPASSRLS`.

Default privileges for objects created by both `postgres` and `supabase_admin` in `public` grant broad table, sequence, and function privileges to `anon` and `authenticated`. The proposed migration removes current client grants and `postgres` defaults; a separate owner-scoped draft handles `supabase_admin` defaults. That step requires an owner/member role the recovery CLI does not have.

### `mzanzi` — five tax/account tables

`capital_gains`, `tax_documents`, `tax_returns`, `transactions`, and `users` have RLS disabled and no policies. The `mzanzi` schema has no `USAGE` for `anon`, `authenticated`, or `service_role`, and those roles have no effective table privileges. Thus the current API roles cannot access the schema, but this depends on grants/schema exposure rather than RLS.

The `users` definition includes fields such as `hashed_password`, date of birth, and VAT data. These are column names only; no rows were read. No link from this schema’s integer `user_id`/user table to Supabase Auth or the Credo owner model was found. The draft enables RLS with no client policies and keeps all API roles denied pending a separate identity and product review.

### `storage` — managed tables and private verification bucket

All eight inspected storage tables have RLS enabled. The only observed storage policy is an active anonymous `INSERT` on `storage.objects` when `bucket_id = 'verifications'`. The bucket is private, but has no configured file-size or MIME-type limit. `anon` and `authenticated` have all four table privileges on `buckets`, `buckets_analytics`, and `objects`; they have `SELECT` on `buckets_vectors`, `vector_indexes`, `s3_multipart_uploads`, and `s3_multipart_uploads_parts`. They have no privileges on `migrations`. `service_role` has all four privileges on `buckets`, `buckets_analytics`, `objects`, and both multipart tables; it has `SELECT` on the two vector tables and no privileges on `migrations`. RLS denies operations without a matching policy.

The proposed draft removes anonymous and authenticated direct grants on `storage.objects` and drops the specific anonymous upload policy; it does not change bucket settings or Supabase-managed storage defaults. Validate this backend-only model against the Storage API in staging.

### Supabase-managed schemas and non-table API paths

The following inventory records effective catalog privileges, not proof that a relation is reachable over PostgREST. The configured API-exposed schema list could not be read, so `net`, `realtime`, and `extensions` exposure remains an explicit pre-rollout check.

| Schema | Tables and RLS | Observed policy/grant path |
|---|---|---|
| `auth` | `audit_log_entries`, `custom_oauth_providers`, `flow_state`, `identities`, `instances`, `mfa_amr_claims`, `mfa_challenges`, `mfa_factors`, `mfa_recovery_code_sets`, `mfa_recovery_codes`, `oauth_authorizations`, `oauth_client_states`, `oauth_clients`, `oauth_consents`, `one_time_tokens`, `refresh_tokens`, `saml_providers`, `saml_relay_states`, `schema_migrations`, `scim_tokens`, `scim_users`, `sessions`, `sso_domains`, `sso_providers`, `users`, `webauthn_challenges`, `webauthn_credentials` (27; 16 RLS-enabled) | No `anon`, `authenticated`, or `service_role` table privileges were observed. API roles have schema usage and can execute four Auth helper routines; no table rows were read. |
| `cron` | `job`, `job_run_details` (2; both RLS-enabled) | Schema usage is absent for the API roles. Both tables have `SELECT`; `job_run_details` also has `DELETE`. Two policies restrict rows to `username = current_user`; no API path is established from the observed privileges because schema usage is absent. |
| `mzanzi` | `capital_gains`, `tax_documents`, `tax_returns`, `transactions`, `users` (5; none RLS-enabled before the draft) | No API-role schema usage or table grants. Details are in the section above. |
| `net` | `_http_response`, `http_request_queue` (2; neither RLS-enabled) | `anon`, `authenticated`, and `service_role` have schema usage and all table privileges, including `TRUNCATE`, plus access to `http_request_queue_id_seq`; all 12 `net` routines are executable by those roles. This includes pg_net outbound-HTTP operations. If `net` is API-exposed, clients may reach outbound HTTP and queue/response operations. Exposure is unconfirmed. The separate [pg_net lockdown draft](../../supabase/drafts/008_net_schema_lockdown_DRAFT.sql) removes client grants while preserving `service_role` and `supabase_admin`; platform-owner and product-dependency review is required. |
| `public` | Nine application tables, all RLS-enabled | See the section above. Anonymous access is currently governed by broad policies and grants. `anon`/`authenticated` also have `TRUNCATE` on all nine tables; this bypasses RLS if an execution path supports the command. The draft's `REVOKE ALL` removes those privileges. |
| `realtime` | `messages`, six dated `messages_*` partitions, `schema_migrations`, `subscription` (8; only `messages` has RLS enabled) | No policies were observed. API roles have `SELECT` on `messages` and `subscription`, plus `INSERT`/`UPDATE` on `messages`; RLS on `messages` has no policies and therefore denies rows. `subscription` has RLS disabled, with `SELECT` and sequence privileges for API roles. The focused [subscription lockdown draft](../../supabase/drafts/010_realtime_subscription_lockdown_DRAFT.sql) revokes direct client table/sequence access to subscription state while preserving server/platform access and existing Realtime message ACLs. Confirm service dependencies before any change. |
| `storage` | `buckets`, `buckets_analytics`, `buckets_vectors`, `migrations`, `objects`, `s3_multipart_uploads`, `s3_multipart_uploads_parts`, `vector_indexes` (8; all RLS-enabled) | See the detailed grants and policy above. `anon`/`authenticated` also have `TRUNCATE` on `buckets`, `buckets_analytics`, and `objects`; the draft revokes `TRUNCATE` across storage tables and removes all direct client privileges on `objects`. |
| `supabase_migrations` | `schema_migrations` (1; RLS disabled) | No API-role schema usage or table grants. |
| `vault` | `secrets` (1; RLS disabled) | No `anon`/`authenticated` schema usage or table grants. `service_role` has schema usage and `SELECT`/`DELETE`; the `decrypted_secrets` view is also selectable by `service_role`. This is a privileged server capability; never expose or query secret values in this audit. |

The `graphql_public.graphql` RPC is executable by `anon` and `authenticated`; it is `SECURITY INVOKER`, so GraphQL operations use the caller's table grants and RLS. It is an alternate route to the same currently permissive `public` access and must be included in staging validation. The `graphql_public` API schema configuration itself was not available.

The two `extensions` views, `pg_stat_statements` and `pg_stat_statements_info`, are owned by `postgres` and selectable by `anon`, `authenticated`, and `service_role`; the corresponding statistics functions are executable by those roles. If `extensions` is API-exposed, operational statistics (and query text subject to PostgreSQL's role checks) may be disclosed. The focused [statistics lockdown draft](../../supabase/drafts/009_extension_stats_lockdown_DRAFT.sql) restricts those views/functions to trusted server/platform roles without removing other extension functions. Seventeen `storage` routines and 54 `extensions` routines are also executable by API roles; none of those routines is `SECURITY DEFINER`. Their endpoint reachability depends on API schema exposure and must be confirmed before rollout.

Seventeen routines were found in `storage`; none were security-definer. The `vault.decrypted_secrets` view exposes the decrypted-secret expression only to `service_role` in the observed effective grants. No view or row data was read from the application or storage tables.

## Proposed access model

- **Anonymous:** no access to public application rows, `mzanzi`, or verification objects.
- **Merchant:** a Supabase Auth identity must be explicitly and securely linked to `public.owners.auth_user_id`. Do not auto-link by phone or email. A merchant can read their owner/business and related business rows, update only business name/type/location, and insert revenue/expense rows for a business they own. Activity history, bot sessions, credit scores, supplier records, trust signals, and ownership links are not directly writable by merchants.
- **Administrator:** a private `app_private.admin_users` allowlist, provisioned only by an authorized database owner, enables cross-business reads for authenticated administrators. The table is not client-readable/writable. Administrative mutations go through an audited backend service operation, not direct authenticated-table writes.
- **Backend:** `service_role` remains server-only and bypasses RLS. Keep it out of browsers and logs. It remains the only application writer for audit/scoring/session/supplier flows.
- **Tax schema:** all API roles, including `service_role`, remain denied until its Auth linkage, admin scope, and backend requirements are explicitly approved.
- **Storage:** the private `verifications` bucket is service/backend-only until a separately reviewed signed-upload flow binds paths to a verified business. Set size and MIME limits only after the product owner approves those values.
- **Supabase-managed schemas:** keep `net`, `realtime`, `extensions`, `cron`, `auth`, `storage`, and `vault` behind their intended internal/server surfaces. API-exposed schema configuration must be verified before rollout. Do not blanket-revoke privileges in managed schemas: the separate `net` and statistics drafts are narrowly scoped; no realtime ACL change is proposed until service dependencies are understood.

## Draft artifacts and behavior

- [007_security_hardening_DRAFT.sql](../../supabase/drafts/007_security_hardening_DRAFT.sql) replaces broad public policies/grants with the model above, enables RLS on `mzanzi`, and blocks client access to verification objects.
- [007_supabase_admin_defaults_DRAFT.sql](../../supabase/drafts/007_supabase_admin_defaults_DRAFT.sql) must be run by `supabase_admin` or a member to remove that owner’s future broad grants.
- [007_security_hardening_SAFE_ROLLBACK_DRAFT.sql](../../supabase/drafts/007_security_hardening_SAFE_ROLLBACK_DRAFT.sql) is deliberately fail-closed. It does not restore anonymous access or delete identity/admin mapping data; it revokes client access and leaves service operations intact.
- [008_net_schema_lockdown_DRAFT.sql](../../supabase/drafts/008_net_schema_lockdown_DRAFT.sql) removes `anon`/`authenticated` access to pg_net tables/functions while keeping `service_role` and `supabase_admin` access. Its safe rollback remains closed to API roles. This is a draft for platform-owner review, not an instruction to change the live managed schema.
- [009_extension_stats_lockdown_DRAFT.sql](../../supabase/drafts/009_extension_stats_lockdown_DRAFT.sql) restricts the two statistics views and corresponding functions to trusted roles; its safe rollback does not reopen client access.
- [010_realtime_subscription_lockdown_DRAFT.sql](../../supabase/drafts/010_realtime_subscription_lockdown_DRAFT.sql) restricts direct client reads of the RLS-disabled subscription table only; its safe rollback remains closed to API roles. Realtime message policies/ACLs are not changed.
- [whatsapp-bot-security_DRAFT.mjs](../../supabase/drafts/whatsapp-bot-security_DRAFT.mjs) provides signature and media-origin checks; [the integration notes](./milestone-2-webhook-remediation.md) explain what must be wired before a future function deployment. The exact recovered deployed source remains unchanged.

Expected behavior is tested by [the security test runner](../../tests/security/run.sh): anonymous reads/writes and uploads fail; a merchant sees only their linked business and cannot cross-read/write; admin membership permits cross-business reads but not direct writes; service-role backend operations continue; `mzanzi` remains unavailable; direct pg_net, query-statistics, and Realtime subscription access is restricted; RLS still denies direct Realtime message access; and safe rollbacks do not reopen client access.

## Dependencies and remaining risks

1. Review and approve the proposed owner-to-Auth linking, allowed merchant write operations, and admin list. Existing owner rows remain unlinked until individually verified; migration does not infer a match from phone/email.
2. The current frontend has no Supabase Auth flow. Applying the policy draft before auth/linking would deny its present anonymous data paths by design.
3. Execute the public and `supabase_admin` default-privilege drafts only through authorized owner processes. The recovery CLI role cannot run them.
4. Confirm the API-exposed schema list. In particular, determine whether `net`, `realtime`, or `extensions` is exposed; validate pg_net and Realtime dependencies with the Supabase platform owner before applying their focused drafts. Include the `graphql_public.graphql` route in staging tests.
5. Confirm storage object path conventions and approved upload size/MIME policy.
6. Integrate and test Twilio signature validation and restricted media fetching before deploying any function. The helper is a draft and is not wired into the recovered function.
7. Validate the migration against a production-equivalent staging clone, including views/RPCs, cross-tenant cases, and actual Storage API behavior. No production migration has been run.
