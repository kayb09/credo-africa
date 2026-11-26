<!-- markdownlint-disable MD013 MD060 -->

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

Role assignment and removal must be performed only by a designated trusted
Credo security authority using a protected server-side administrative path.
That authority and approval separation must be named before rollout; public
registration, self-assignment, merchant support flows and client-side metadata
updates cannot grant roles. Role changes must record the approving actor,
target identity, old/new role, reason, time and result. Granularity remains
OPEN, but permissions must be least-privilege and explicit.

Do not treat role changes as automatic JWT invalidation. An already-issued JWT
may retain old `app_metadata` until expiry; refresh-token revocation or
session revocation does not necessarily invalidate a JWT already presented to
a backend that only validates its signature and expiry. Therefore every
sensitive administrator operation must consult current server-managed
authorization (or a revocation/version mechanism with an explicitly approved
maximum cache lifetime) in addition to validating the Auth session. If the
current role cannot be verified, fail closed. The implementation must define
and test an immediate privilege-removal bound; the bound is OPEN and must be
approved before staging acceptance.

An RLS policy or RPC must not authorize sensitive administrator access solely
from an administrator claim embedded in a previously issued JWT. Either
evaluate current authorization at the trusted database/backend boundary or
route the sensitive operation through a backend that performs the current-role
check before its service-role call.

Distinguish these lifecycle actions:

- **JWT expiry:** the access token naturally ceases to be accepted at its
  expiry; this is not immediate role removal.
- **Refresh-token revocation:** prevents or limits future token refreshes
  according to the Auth implementation; it does not by itself invalidate an
  already-issued access token.
- **Session revocation:** invalidates the identified Auth session and its
  refresh capability according to platform behavior; each backend must still
  check current authorization for sensitive operations.
- **Immediate privilege removal:** remove the server-side role and make every
  sensitive operation observe the removal within the approved bound, even if a
  previously issued JWT still contains an administrator claim.

Offboarding must remove all role grants, revoke active sessions and refresh
capabilities, rotate/remove any individual credentials, review active
administrator-issued signed URLs, and preserve the audit trail. A signed
document URL may remain usable until expiry as described in Storage controls.

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

### Table-by-table authorization matrix

The matrix is a proposed authorization contract, not evidence of implemented
policies. `R`, `I`, `U`, and `D` mean `SELECT`, `INSERT`, `UPDATE`, and
`DELETE`. `No` means denied. `Scoped` means only the named row, columns,
purpose, and workflow may be used. `OPEN` means the product/security owner
must decide before the corresponding permission is enabled; default is deny.
“Authenticated merchant (unlinked)” has a valid Auth identity but no verified
owner relationship. “Other merchant” means a row belonging to a different
verified owner. Administrator access is always limited by an approved role,
purpose, and scope. Trusted backend operations are narrowly defined application
operations, not an unrestricted grant to clients.

| Table | Principal | R | I | U | D |
|---|---|---|---|---|---|
| `owners` | Anonymous visitor | No | No | No | No |
| `owners` | Authenticated merchant (unlinked) | No | No | No | No |
| `owners` | Merchant's own owner row | Scoped profile fields only | No; owner creation through onboarding | Scoped non-identity profile fields only; `id`, `auth_user_id`, phone-verification and privilege fields immutable to merchant | No |
| `owners` | Merchant accessing another owner | No | No | No | No |
| `owners` | Approved administrator | Scoped to approved support/review purpose | No; approved onboarding only | Scoped, audited correction workflow; identity-link changes require approved recovery | No; separate legally approved deletion workflow is OPEN |
| `owners` | Trusted backend/service operation | Scoped owner resolution and onboarding/link operations | Approved onboarding only | Approved linking/recovery only; preserve `id` | No; no general delete |
| `businesses` | Anonymous visitor | No | No | No | No |
| `businesses` | Authenticated merchant (unlinked) | No | No | No | No |
| `businesses` | Merchant's own business | Scoped business fields | Approved onboarding/business-add flow only | Scoped permitted business fields; `owner_id` and `id` immutable | OPEN; deny until closure/deletion policy is approved |
| `businesses` | Merchant accessing another business | No | No | No | No |
| `businesses` | Approved administrator | Scoped to approved support/review purpose | Approved workflow only | Scoped and audited | No; separate approved process required |
| `businesses` | Trusted backend/service operation | Owner-verified business operations | Onboarding/business-add only | Validated business workflow; cannot reassign existing owner | No; no general delete |
| `credit_scores` | Anonymous visitor | No | No | No | No |
| `credit_scores` | Authenticated merchant (unlinked) | No | No | No | No |
| `credit_scores` | Merchant's own business score | Scoped read only if product approves; otherwise deny (OPEN) | No | No | No |
| `credit_scores` | Merchant accessing another business score | No | No | No | No |
| `credit_scores` | Approved administrator | Scoped read for approved purpose | No | No direct edit; corrections through audited scoring workflow | No |
| `credit_scores` | Trusted approved scoring operation | Scoring workflow only | Create score result | Replace/revise only through versioned scoring workflow | No; retain history per approved retention policy |
| `bot_sessions` | Anonymous visitor | No | No | No | No |
| `bot_sessions` | Authenticated merchant (unlinked) | No | No | No | No |
| `bot_sessions` | Merchant using the bot (no direct table access) | No direct table access; approved bot interaction only (OPEN interface) | No direct table access | No direct table access | No direct table access |
| `bot_sessions` | Merchant accessing another sender's session | No | No | No | No |
| `bot_sessions` | Approved administrator | No by default; narrowly approved troubleshooting access is OPEN and audited | No | No | No |
| `bot_sessions` | Trusted WhatsApp/session backend | Resolve a verified sender to one owner-bound active session | Create for verified linked sender | Update that sender's active session only | Expire/delete only through lifecycle cleanup |
| `revenue_entries` | Anonymous visitor | No | No | No | No |
| `revenue_entries` | Authenticated merchant (unlinked) | No | No | No | No |
| `revenue_entries` | Merchant's own business entries | Scoped read | Validated entry for own business | Scoped correction of permitted fields; ownership and business linkage immutable | OPEN; deny until correction/deletion policy is approved |
| `revenue_entries` | Merchant accessing another business entries | No | No | No | No |
| `revenue_entries` | Approved administrator | Scoped read for approved support purpose | No; approved import/onboarding workflow only | Audited correction workflow only | No |
| `revenue_entries` | Trusted backend/service operation | Validated integration/report operation | Approved ingestion operation | Idempotent correction/ingestion workflow | No; no general delete |
| `expense_entries` | Anonymous visitor | No | No | No | No |
| `expense_entries` | Authenticated merchant (unlinked) | No | No | No | No |
| `expense_entries` | Merchant's own business entries | Scoped read | Validated entry for own business | Scoped correction of permitted fields; ownership and business linkage immutable | OPEN; deny until correction/deletion policy is approved |
| `expense_entries` | Merchant accessing another business entries | No | No | No | No |
| `expense_entries` | Approved administrator | Scoped read for approved support purpose | No; approved import/onboarding workflow only | Audited correction workflow only | No |
| `expense_entries` | Trusted backend/service operation | Validated integration/report operation | Approved ingestion operation | Idempotent correction/ingestion workflow | No; no general delete |
| `supplier_records` | Anonymous visitor | No | No | No | No |
| `supplier_records` | Authenticated merchant (unlinked) | No | No | No | No |
| `supplier_records` | Merchant's own business records | Scoped supplier fields; private document access separately authorized | Validated record for own business | Scoped correction; business linkage immutable | OPEN; deny until correction/deletion policy is approved |
| `supplier_records` | Merchant accessing another business records | No | No | No | No |
| `supplier_records` | Approved administrator | Scoped review access; document access separately approved and audited | No | Audited correction workflow only | No |
| `supplier_records` | Trusted backend/service operation | Validated document/record workflow | Approved ingestion only | Idempotent metadata correction only | Retention/deletion workflow only |
| `trust_signals` | Anonymous visitor | No | No | No | No |
| `trust_signals` | Authenticated merchant (unlinked) | No | No | No | No |
| `trust_signals` | Merchant's own business signals | Read-only presentation is OPEN; deny until visibility is approved | No | No | No |
| `trust_signals` | Merchant accessing another business signals | No | No | No | No |
| `trust_signals` | Approved administrator | Scoped read for approved purpose | No | No direct edit; correction must be attributable and audited | No |
| `trust_signals` | Named trusted signal producer | Scoped read if needed | Create only signal types explicitly assigned to that producer | Revise only its own signal through versioned, audited operation | No; retain/retract through audited lifecycle |
| `activity_history` | Anonymous visitor | No | No | No | No |
| `activity_history` | Authenticated merchant (unlinked) | No | No | No | No |
| `activity_history` | Merchant's own business history | Scoped read of merchant-visible events (event visibility is OPEN) | No direct table insert; append via validated event operation only | No; append correction event instead | No |
| `activity_history` | Merchant accessing another business history | No | No | No | No |
| `activity_history` | Approved administrator | Scoped read for approved purpose | Append administrator action through audited event service | No; append correction event | No |
| `activity_history` | Trusted event/audit operation | Scoped read when required | Append attributed event only | No; append correction event | No; retention process only under approved policy |

#### Special table constraints

- **Owners:** Existing `owners.id` values and business foreign-key
  relationships must remain unchanged. Merchant APIs must not accept a
  caller-chosen owner ID or allow a merchant to edit `auth_user_id`, verified
  phone state, or authorization fields.
- **Businesses:** Access is derived from the verified owner relationship.
  `owner_id` cannot be reassigned by a merchant or ordinary update operation.
  Business closure and merchant deletion rights remain OPEN.
- **Credit scores:** Only a separately approved scoring operation may write
  scores or tiers. Preserve score provenance/version history; merchant
  visibility and correction rights are OPEN.
- **Bot sessions:** The current `bot_sessions` table is keyed by `phone`, not
  by owner or business. That key is not sufficient proof of authenticated
  merchant ownership and creates shared/reassigned-number risks. Before any
  user-facing session access, redesign or add a reviewed ownership binding
  from a verified sender/Auth identity to exactly one owner and active
  conversation. The backend must resolve the sender, enforce a short,
  approved inactivity/absolute expiry, prevent access by another owner, and
  expire/revoke sessions when identity linkage changes. Expiry values and
  whether the phone remains a key are OPEN. Until then, deny direct client
  table access.
- **Revenue and expenses:** Only permitted fields for a verified own business
  may be managed. Exact editable fields and deletion/correction behavior are
  OPEN and default-deny. Writes must preserve business linkage and provenance.
- **Supplier records:** Documents referenced by these records remain private
  Storage objects. Record visibility, correction and deletion are limited to
  an approved purpose.
- **Trust signals:** Merchant clients cannot create or alter signal evidence.
  Each trusted producer receives a narrowly scoped operation for assigned
  signal types. The producer inventory and merchant visibility are OPEN.
- **Activity history:** Ordinary application activity is append-only through a
  validated event operation. Administrative access creates attributable
  events. Corrections append a superseding/correction event rather than
  rewriting or deleting history. Legal retention/deletion exceptions require
  approval and audit.

The table matrix does not imply that an administrator or service credential
automatically gets broad access. Administrator scope is checked by the
privileged backend. Supabase service-role credentials bypass RLS; they must
never be exposed to a client, and each server operation must enforce caller,
tenant, purpose, input, and audit checks independently of RLS.

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

Auth, PostgreSQL and Storage are separate systems and do not participate in
one automatic atomic transaction. Use a durable, idempotent saga/workflow that
can reconcile each completed step, report incomplete state, and resume or
compensate under explicit rules. The durable state mechanism, schema, retention
and operator permissions are OPEN design details; do not imply a new table
already exists.

Do not assume the Auth provider/API honors the onboarding idempotency key.
Reconcile an uncertain Auth response against a trusted subject/correlation
before retrying identity creation; if the identity cannot be safely
determined, stop in a recoverable/manual-review state rather than create a
second identity.

| Stage | Preconditions and durable status | Idempotency and success condition | Failure, retry and recovery | Audit evidence |
|---|---|---|---|---|
| 1. Auth identity and phone verification | No privileged application state until Auth identity exists and phone verification is confirmed. Record a correlation/request ID and Auth identity state without storing OTP secrets. | Stable verified Auth subject; repeated request resolves to that subject and does not create a second identity. | Auth provider failure: no owner/business writes. Unknown response: query Auth by trusted identity/correlation before retry. Account recovery and duplicate-phone handling remain OPEN. | Auth subject reference, verification event, time, outcome; never OTP value. |
| 2. Owner lookup/link or approved creation | Verified Auth identity; candidate lookup is not proof by phone alone. Record `owner_pending`, `linked`, `creation_pending`, or actionable failure state. | Link only after approved ownership challenge; preserve existing owner ID. New owner creation uses a server-generated stable idempotency key and duplicate constraints after schema review. | Ambiguous/duplicate/inaccessible number: `manual_review`, no link. Retry checks existing link and candidate state. Recovery requires approved authority and evidence. | Challenge method/result, candidate owner reference, decision/approver, idempotency reference. |
| 3. Business create/link | Owner relationship is verified and durable. Record business phase and selected owner. | Same request returns same business; one approved owner/business association; no caller-controlled owner reassignment. | Failure leaves onboarding incomplete; retry reconciles existing business by idempotency reference. Resolve conflicts through recovery, not duplicate insertion. | Business reference, owner reference, operation, status, outcome. |
| 4. Consent/lawful-basis record | Correct data subject and approved notice/purpose; applicable legal basis confirmed by legal review. Record `pending`, `recorded`, or `review_required`. | Unique logical record per subject/purpose/notice/action; duplicate submission returns existing decision. | Persistence failure blocks completion. Retry verifies durable record; change/withdrawal creates new attributable state rather than silently overwriting. | Notice version, purpose, status, timestamp/channel, basis reference, actor. |
| 5. Private document upload | Verified onboarding correlation, approved document purpose, private bucket and policy. Record `upload_pending`, `uploaded_quarantined`, `accepted`, or `rejected`. | Stable object key per onboarding/document slot; retry checks object metadata/checksum before upload and does not create duplicate logical documents. | Interrupted upload is reconciled by object metadata; invalid file is rejected/quarantined. Orphan cleanup is delayed and audited; never delete a referenced valid object automatically. | Object reference, byte count, detected MIME, validation result, actor, access events; no document contents. |
| 6. Final completion | Required prior phases are durably successful; unresolved review, consent, or document state blocks completion. | Conditional final transition from incomplete to `complete` exactly once; repeated completion returns the same final state. | Failed final write remains incomplete; reconciliation checks every prerequisite and retries the transition. Compensation/closure is approved and auditable. | Correlation ID, phase outcomes, final state and timestamp. |

The lifecycle must distinguish at least `pending`, `in_progress`,
`manual_review`, `failed_retryable`, `failed_terminal`, `complete`, and
`cancelled/compensating` (final values are an implementation decision). A
successful HTTP response is not proof of completion: read back durable phase
state, verify owner/business linkage, consent and document references, and
confirm the final state. Recovery must be safe after process restart and must
not create duplicate logical records.

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

Each object must map to an immutable document record or trusted onboarding
correlation and a verified owner/business scope. Administrator access requires
a current approved role and purpose check and is audited. The maximum signed
URL lifetime is **OPEN** and must be approved as a measurable release
requirement. A signed URL is a bearer capability: removing a user's role does
not necessarily invalidate an already-issued URL, which may remain usable
until expiry. Immediate revocation requires a different access pattern, such
as an authenticated download proxy that checks current authorization on every
request, or an explicitly verified storage-token/object revocation mechanism.
Choose and test this behavior before sensitive documents are enabled.

Upload validation must enforce the approved size limit on actual bytes as
well as declared metadata, allowlist MIME/content types, reject path traversal
and unexpected object keys, and prevent overwrites outside an authorized
document workflow. Retention and deletion periods remain OPEN pending legal
review.

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

These are distinct controls:

1. **Twilio signature verification** establishes that the request parameters
   were signed for the exact externally visible URL. Validate the signature
   before reading or changing merchant data; account for approved proxy
   forwarding without trusting caller-supplied host headers.
2. **Replay prevention** rejects a previously accepted request/message
   identifier outside an explicitly bounded retry policy. Its durable key,
   retention window and concurrency behavior are implementation decisions.
3. **Duplicate idempotency** ensures permitted provider retries produce one
   logical effect, even when the request is valid and repeated.
4. **Merchant linking** independently resolves a verified sender to an
   approved owner relationship. A valid Twilio signature is not proof that the
   sender is an authorized merchant.
5. **Service-role authorization** is a server-side implementation credential,
   not proof of the sender's authority. Since it bypasses RLS, backend methods
   must enforce sender, owner, business, purpose and input authorization and
   write audit evidence.
6. **Media restrictions** apply to every fetch: allowlisted HTTPS origins
   where feasible; reject loopback, private, link-local, reserved and otherwise
   prohibited IPv4/IPv6 destinations; apply connect/read timeouts, a streaming
   byte cap, content-type and file-signature validation; and never forward
   credentials to an untrusted origin. Resolve and validate destinations
   immediately before connecting, then pin the validated address for that
   connection or use an equivalent control that prevents a DNS
   validation-to-connect race. Re-resolve and revalidate every redirect hop
   and retry; reject any prohibited answer or destination change rather than
   following it. DNS rebinding must not cause a request to reach a prohibited
   destination, including after redirects or DNS changes.

Provider/account configuration and OTP delivery provider remain unselected.

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
12. Complete a fresh production parity inventory and reviewed comparison
    against the approved staging design before any production rollout.

Production work must not begin until all applicable staging gates are passed
and explicitly approved. Historical production audit findings remain
historical until refreshed by separately authorized checks; this ADR does not
authorize production access or remediation.

### Mandatory production parity review

Before any production rollout, a separately authorized, fresh read-only review
must compare the then-current live Credo environment with the approved staging
design and release candidate. The comparison must cover:

- tables and columns, types, constraints, foreign keys, indexes and uniqueness;
- RLS enablement and policies, API grants, role memberships and default
  privileges;
- Storage buckets, privacy, upload limits and object policies;
- database functions, views, triggers, ownership and security modes;
- Auth providers and relevant phone, session, token and redirect configuration;
- Edge Functions, deployment settings and secret names/configuration (never
  secret values);
- WhatsApp signature, sender-linking, replay/idempotency and media controls;
- relevant scheduled jobs, extensions and network access;
- backup, rollback and recovery controls.

Record inventory timestamps, reviewers, evidence references, variances, risk
disposition and explicit approvals. Production rows, merchant PII, tokens and
secret values must not be copied into staging or the parity report. Every
unexplained variance blocks rollout. Historical audit findings remain
historical until this fresh review is explicitly authorized and completed.
The detailed test gate is defined in
[Staging Identity Test Specification](./staging-identity-test-specification.md).

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
- Exact merchant-readable fields and delete/correction rules for each table.
- Bot session owner-binding schema and expiry semantics.
- Trust-signal producer inventory and merchant visibility.
- Onboarding durable-state representation and compensation rules.
- Maximum signed URL lifetime and whether an authenticated proxy is required.
- Approved Storage/media MIME-content allowlists and maximum upload byte
  limits.
- Immediate administrator revocation mechanism and acceptable propagation
  bound.
- Production parity evidence owner, review process and acceptable drift.

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
