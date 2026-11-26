# Credo Identity Architecture Decision Record

## 1. Document status

- **Status:** Proposed for review.
- **Date:** 25 November 2026.
- **Document type:** Architecture documentation only.
- **Authorization:** This document does **not** authorize production changes,
  SQL deployment, application deployment, Supabase configuration changes,
  database migrations, or access to real merchant data.

This decision record describes a proposed identity architecture for Credo
Africa Identity. It must be approved and implemented only through the release
gates in
[Staging Identity Test Specification](./staging-identity-test-specification.md).

## 2. Existing system context

The following findings are established by the existing Credo read-only audit
evidence and repository artifacts. Some production observations have a captured
or previously reported evidence basis but have not been refreshed as part of
this documentation task.

- The tracked frontend does not implement a complete Supabase Auth flow.
- Administrator authentication currently relies on a hardcoded browser PIN
  and a `localStorage` authorization flag.
- The browser directly inserts owner and business records.
- The browser directly uploads verification documents.
- The recovered production schema evidence showed unsafe broad grants and
  policies for anonymous and authenticated API roles. These remain historical
  findings until an authorized live recheck is completed.
- The WhatsApp Edge Function uses a server-side Supabase service-role key.
- Twilio signature validation was not visible in the tracked WhatsApp function
  source.
- `owners.id` is an existing primary key and is referenced by businesses.
- `owners.auth_user_id` does not currently exist.
- Existing consent and privacy workflows are incomplete.
- The staging baseline is a separate, intentionally closed environment.

Relevant existing evidence includes:
[audit-report.md](./audit-report.md),
[milestone-2-security-audit.md](./milestone-2-security-audit.md),
[live-public-schema.sql](./live-public-schema.sql), and
[staging-baseline.md](./staging-baseline.md).

These findings describe risk and current evidence. They do not claim that every
production behavior remains unchanged or that all captured findings were
remediated.

## 3. Merchant identity architecture

### Decision

Merchant identity should use **Supabase Auth with verified phone-based OTP**
as the intended architecture. OTP provider selection is explicitly unresolved.
The implementation must not claim a provider is approved until compatibility,
coverage, cost, abuse controls, and South African support have been assessed.

The design review must cover:

- Supabase-supported phone providers and their technical constraints.
- SMS versus WhatsApp delivery.
- Twilio configuration and costs, if Twilio or another provider is selected.
- South African number format, delivery, and roaming support.
- Per-identity, per-IP and per-device abuse prevention.
- Supabase and application rate limiting.
- OTP expiry, resend limits, attempt limits, and replay protection.
- Account recovery, phone change, and changed-SIM workflows.
- Duplicate-number and inaccessible-number handling.
- Operational logging that excludes OTP codes and unnecessary PII.

### Existing owner linkage

Existing `owners.id` values must be preserved. Owners may not be recreated as
new records merely to attach an authentication identity.

A schema design should be reviewed for a nullable, unique
`owners.auth_user_id` relationship to `auth.users(id)`. The exact column type,
constraints, foreign-key behavior, and migration plan require live schema
review. This design is proposed, not implemented.

Existing owner records must not be silently linked based on phone-number
matching alone. Matching a phone number may help identify a candidate owner,
but verified ownership still requires an explicit, reviewable challenge.

Verified ownership challenges should account for:

- an existing owner with a matching verified number;
- duplicate or shared phone numbers;
- a changed or reassigned number;
- an inaccessible original number;
- a one-time or temporary number;
- one Auth user attempting to claim multiple owners;
- multiple Auth users attempting to claim one owner; and
- manual recovery requiring approval and an audit trail.

No authorized manual link may overwrite or delete an existing owner or business
relationship. Manual recovery decisions should record the approver, reason,
scope, affected IDs, evidence references, and the resulting owner relationship.

## 4. Administrator architecture

The administrator architecture should use Supabase Auth for identity plus
server-managed authorization.

Authorization should use:

- protected `app_metadata` maintained only by a trusted server or operator, or
- a protected authorization table with row-level and service-role controls.

The application must never trust `user_metadata` for administrator decisions.
The browser PIN and `localStorage` administrator state must be removed as
authorization mechanisms and may only remain, if at all, as presentation
layout rather than access control.

Required controls include:

- no public administrator registration;
- server-verified role or permission checks for every privileged operation;
- auditable privileged actions;
- session revocation and offboarding;
- stale JWT handling after role removal;
- least-privilege role granularity;
- separation of onboarding, document review, operational support and
  institutional access roles where appropriate.

The administrator audit record should capture actor, purpose, target, action,
timestamp and outcome without exposing secrets or unnecessary PII.

## 5. Database and RLS architecture

The database should use least-privilege API grants and table-specific RLS
policies. Authentication alone must not grant merchant access.

Merchant access should be derived from a verified Supabase Auth identity and
its relationship to `owners` and `businesses`. Reassignment of arbitrary
`owner_id` or `business_id` values must be prevented in `INSERT`, `UPDATE`, and
any trusted write helper.

The nine currently identified application tables are:

1. `owners`
2. `businesses`
3. `credit_scores`
4. `bot_sessions`
5. `revenue_entries`
6. `expense_entries`
7. `supplier_records`
8. `trust_signals`
9. `activity_history`

This inventory is the staging and implementation scope in this milestone, not
a statement that no additional legitimate live resources exist. The live schema
must be reconfirmed before implementation.

Required database controls include:

- table-specific `SELECT`, `INSERT`, `UPDATE`, and `DELETE` privileges;
- no broad anonymous access to sensitive merchant records;
- explicit RLS policies for merchant and approved administrator roles;
- `UPDATE USING` and `UPDATE WITH CHECK` that prevent ownership changes;
- no access merely because a JWT belongs to an authenticated user;
- service-role access limited to trusted backend operations;
- service-role credentials kept only in server-side secrets;
- review of views and helper functions for unintended RLS bypass;
- restriction of exposed schemas and function execute privileges;
- no client capability to directly insert privileged audit or role fields.

Any genuinely necessary `SECURITY DEFINER` helper must:

- validate the caller's authorization and purpose;
- use a fixed `search_path`;
- avoid public schema exposure where possible;
- use tightly scoped privilege;
- reject ownership reassignment and unexpected input;
- be reviewable, testable and audited.

## 6. Secure onboarding

Merchant onboarding should be performed through a trusted backend operation,
not by direct browser inserts.

The operation should require:

- authenticated and phone-verified identity;
- strict input validation;
- owner and business creation or linking;
- explicit idempotency by request key or equivalent durable state;
- duplicate-phone and duplicate-owner prevention;
- owner and business relationship validation;
- partial-failure recovery;
- consent recording before or at the point of applicable processing;
- secure document upload to private Storage;
- no direct anonymous database writes;
- no service-role key in frontend code.

A repeat of a successful request must return the same logical outcome. A retry
after a network failure must not create duplicate owner, business or consent
records. Each onboarding phase should have durable status and a recovery path.
Failures after Auth, owner, business or document operations must be visible to
an authorized recovery workflow.

## 7. Storage architecture

Verification documents should use a private bucket. Public document access,
unrestricted anonymous upload, and direct file URLs must not be used.

Required controls include:

- private bucket and non-public object access;
- authenticated, policy-checked uploads only;
- merchant-scoped object paths;
- file type allowlists and size limits;
- server-generated or policy-validated filenames;
- short-lived signed URLs;
- restricted administrator access for legitimate review;
- audit records for upload and document access;
- retention and deletion controls;
- quarantine or rejection of invalid files.

Object paths should prove a relationship to the merchant and review context
without exposing personal information in predictable URLs.

## 8. WhatsApp and Twilio

The WhatsApp webhook must validate Twilio signatures before any privileged
operation. It must validate the exact externally visible HTTPS URL and signed
parameters, rather than an internally rewritten or assumed URL.

Required controls include:

- rejection of missing, invalid or altered signatures;
- replay and duplicate-message protection;
- idempotency based on a trusted message identifier;
- verified account linking before acting as a merchant;
- media allowlists and byte-size limits;
- rejection of disallowed MIME types;
- restrictions on network destinations and redirects;
- server-side credentials only;
- no secret, service-role key or credential exposure in messages or logs;
- rejection of forged sender information.

Request-supplied media URLs must be fetched only under validated network,
redirect and response-size constraints. Media may not be downloaded from
arbitrary destinations or allowed to access internal network resources.

## 9. POPIA and consent

The system should maintain durable, retrievable records for consent or any
other applicable lawful basis. A record should include:

- notice or policy version;
- processing purpose;
- consent or lawful-basis status;
- timestamp and timezone;
- consent channel;
- merchant or data-subject identity;
- versioned consent or privacy text reference;
- withdrawal or change;
- administrative actor and reason for privileged actions.

Privacy workflows should cover, where legally applicable:

- access requests;
- correction requests;
- objection;
- deletion or anonymization;
- retention expiry;
- complaint intake and escalation;
- secure communication and identity verification;
- auditable completion or refusal.

Lawful bases, consent wording, data-subject rights implementation, and
retention schedules require appropriate South African legal review. This
document does not determine legal advice or a final POPIA interpretation.

## 10. Future institutional access

Institutions must not receive unrestricted database access or a shared
merchant view.

Institutional access should use separate identities and authorization,
purpose-specific permissions, minimum necessary data, and auditable
queries or exports. A relationship to a merchant should require documented
merchant or lawful-basis authorization, where appropriate.

Each institutional access grant should define purpose, period, approved
roles, data scope, review/expiry date and revocation process. Institutional
access must not permit broad database export or bypass merchant consent and
RLS controls.

## 11. Implementation order

1. Obtain identity design approval.
2. Establish the Auth foundation in staging.
3. Link synthetic verification states to existing owners without changing IDs.
4. Implement server-managed administrator authorization.
5. Implement database RLS and least-privilege grants in staging.
6. Build a trusted, idempotent onboarding operation.
7. Secure private verification Storage.
8. Implement POPIA consent and privacy workflows.
9. Harden the WhatsApp and Twilio integration.
10. Integrate the frontend after backend controls are usable.
11. Prepare approved backup, rollback and production approval gates.

Production work must not begin until all applicable staging gates are passed
and explicitly approved.

## 12. Open decisions

The following decisions remain explicit and require resolution:

- OTP provider.
- SMS, WhatsApp or other delivery channel.
- Account recovery process.
- Duplicate and changed phone-number policy.
- Manual recovery authority and evidence standard.
- Administrator role granularity.
- Consent wording and presentation.
- Applicable lawful basis for each processing purpose.
- POPIA retention and deletion schedules.
- Institutional access eligibility and scope.
- Merchant data export and correction process.
- Staging-to-production migration and rollout sequence.

## 13. Explicit restrictions

- The staging baseline remains unchanged during this documentation milestone.
- No production remediation is authorized.
- No real merchant personal data may be copied into staging.
- The existing `007_security_hardening_DRAFT.sql` is not a complete
  authentication solution.
- Stock and Purchasing V1 remains protected.
- Mzansi Tax App is excluded from Credo Africa Identity scope.
- No secrets, credentials or real PII belong in this decision record.

## 14. Cross-reference

Implementation and verification of this architecture must use
[Staging Identity Test Specification](./staging-identity-test-specification.md).
The test environment and closed baseline are described in
[staging-baseline.md](./staging-baseline.md).
