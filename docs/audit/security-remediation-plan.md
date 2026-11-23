# Security remediation plan

This plan is ordered by severity and is based on the live-environment facts supplied for this recovery. Verify each finding against the deployed configuration before changing production. No production changes are authorized or performed by this branch.

## P0 — Contain anonymous data access

1. Through read-only catalog and policy inspection, enumerate effective grants and RLS policies for all application tables and views. Verify the actual grantee, command, `USING`, and `WITH CHECK` expressions; do not rely on policy names.
2. Remove unrestricted anonymous read/write access from application data. Grant only the minimum required operations to explicit roles, and enforce tenant membership in database-side policy predicates.
3. Test the effective policy matrix as `anon`, an authenticated user with no membership, a member of one business, and a privileged backend role. Include views, RPCs, cross-business references, and direct table access.
4. Review the two reported policies assigned to `public`. Replace broad permissions with narrowly scoped role grants and row predicates only after their legitimate use is understood.

## P0 — Restrict verification uploads

1. Inspect the `verifications` bucket and every storage policy. Disable anonymous upload unless a documented, abuse-resistant flow requires it.
2. Bind uploads to an authenticated identity and authorized business; enforce object-path ownership, size and content-type limits, and safe retention.
3. Prefer short-lived signed upload authorization or an authenticated server-side upload flow. Quarantine and validate untrusted files before processing. Test anonymous and cross-tenant access.

## P1 — Authenticate the WhatsApp webhook safely

1. Recover and review the exact deployed `whatsapp-bot` source and configuration before making a change.
2. Validate Twilio's request signature using the official validation method and the exact externally visible URL plus request parameters/body. Keep the Twilio authentication token in server-side secret storage; never log it or expose it to the browser.
3. Add replay/duplicate handling and bounded request processing, and verify that invalid signatures cannot cause database writes or service-role operations.
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

1. Recover the eight migration identities and original SQL from an authoritative source. Do not synthesize historical migrations from the current schema.
2. Generate a structural-only schema snapshot and current database types from the verified live project; review differences against the recovered migrations.
3. Recover both deployed Edge Functions and configuration exactly, compare deployed and repository revisions, and add function-specific authentication and regression tests.
4. Add CI checks for type drift, migration replay on a disposable PostgreSQL instance, policy tests, and Edge Function tests. Keep production credentials out of CI logs and source control.
