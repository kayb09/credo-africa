<!-- markdownlint-disable MD013 MD060 -->

# Staging Identity Test Specification

## 1. Purpose and environment

This document defines the staging acceptance tests for the proposed Credo
identity, merchant isolation, administrator, Storage, WhatsApp and privacy
architecture. It is a test plan only. It does not execute SQL or application
code and does not authorize implementation or deployment.

### Staging target

- Project name: `credo-africa-staging`
- Project reference: `hqxgpmopjtgggldolimz`
- PostgreSQL: `17.12`
- Region: `eu-west-1`

The repository-recorded staging baseline is described in
[staging-baseline.md](./staging-baseline.md) and the bootstrap SQL is
`../../supabase/staging/20261124_public_schema_baseline.sql`.

According to that baseline record (not independently rechecked against a live
database during this task):

- closed by default;
- composed of nine public application tables;
- protected by RLS enabled on all nine tables;
- without application policies;
- without `anon` or `authenticated` table privileges;
- configured for trusted `service_role` access;
- without application records.

This baseline must not be changed during the documentation task. Future tests
require a separately approved staging implementation.

This specification documents test requirements; it does not evidence an
implementation. No test has been executed by preparing this document. Tests
without an unmet prerequisite are `NOT RUN`; tests dependent on unresolved
decisions or approvals are `BLOCKED`. No test is `PASS` or `FAIL`.

## 2. Test data

All test identities and data must be synthetic.

| Persona | Synthetic attributes |
|---|---|
| Merchant A | One synthetic owner, one or more synthetic businesses, and a synthetic OTP-capable phone identity. |
| Merchant B | Separate synthetic owner, businesses and synthetic phone identity. |
| Merchant C | A duplicate or changed phone scenario using synthetic numbers. |
| Administrator | Synthetic Auth identity with an approved test role. |
| Ordinary merchant | Merchant A or B with no administrator role. |
| Unauthenticated visitor | No valid JWT or session. |
| Invalid WhatsApp sender | Forged or unlinked synthetic webhook sender. |
| Authorized WhatsApp service operation | A synthetic trusted server operation, not an external browser. |

Never use actual merchant names, telephone numbers, identity documents,
selfies, production records or production secrets.

Synthetic phone numbers must be reserved test values and must not receive real
merchant traffic. Test evidence must redact JWTs, OTPs and credentials.

## 3. Authentication tests

| Test ID | Scenario | Expected result |
|---|---|---|
| AUTH-001 | Successful phone OTP verification | Exactly one synthetic Auth identity is verified and receives the intended limited session. |
| AUTH-002 | Incorrect OTP | Verification fails; no session or privileged merchant state is granted. |
| AUTH-003 | Expired OTP | Verification fails and the attempt is rejected. |
| AUTH-004 | Reused OTP | Reuse is denied after the first accepted verification. |
| AUTH-005 | OTP resend limits | Excess resend attempts are throttled and auditable. |
| AUTH-006 | OTP rate limiting | Excess attempts are blocked by configured limits without bypass. |
| AUTH-007 | Session expiration | Expired session cannot read or write protected data. |
| AUTH-008 | Logout | Session cannot continue access after logout. |
| AUTH-009 | Account recovery | Recovery requires the approved challenge and cannot bypass ownership validation. |
| AUTH-010 | Phone number change | Existing relationships remain intact only after successful verification and link approval. |
| AUTH-011 | Duplicate phone number | The system identifies ambiguity and prevents silent ownership assignment. |
| AUTH-012 | Failed verification | No owner, business or privileged role is granted. |

Evidence should include status, error behavior, session state, audit reference
and redacted request identifiers. Logs must not contain OTP values or secrets.

## 4. Existing owner linking tests

| Test ID | Scenario | Expected result |
|---|---|---|
| LINK-001 | Correct verified owner linking | Auth user links to the intended existing `owner.id`; no ID is changed. |
| LINK-002 | Incorrect phone verification | Candidate owner is not linked. |
| LINK-003 | Duplicate owner phone numbers | Ambiguous link is rejected or escalated for manual recovery. |
| LINK-004 | One Auth user claims multiple owners | Unauthorized additional claim is denied. |
| LINK-005 | Multiple Auth users claim one owner | Only the approved verified relationship is created. |
| LINK-006 | Changed phone number | Link remains controlled and no relationship is silently reassigned. |
| LINK-007 | Inaccessible phone number | Link does not proceed without the approved recovery workflow. |
| LINK-008 | Manual recovery approval | Approver, evidence and decision are audited; existing owner and business IDs remain intact. |

No test may use phone matching alone as proof of ownership.

## 5. Administrator tests

| Test ID | Scenario | Expected result |
|---|---|---|
| ADM-001 | Valid administrator access | Approved administrator performs only permitted operations. |
| ADM-002 | Ordinary merchant attempts administrator access | Access is denied even with a valid merchant JWT. |
| ADM-003 | Anonymous visitor attempts administrator access | Access is denied. |
| ADM-004 | User edits own role field or metadata | Edit is denied and no role escalation occurs. |
| ADM-005 | Stale administrator JWT after role removal | Role removal takes effect and stale privilege is denied. |
| ADM-006 | Revoked administrator session | Session cannot continue privileged access. |
| ADM-007 | Unauthorized document access | Restricted document is denied. |
| ADM-008 | Privileged action audit | Actor, target, action, purpose, timestamp and outcome are recorded. |

Attempted role edits through `user_metadata`, direct table writes, or API
endpoints must not confer administrator authorization.

## 6. RLS and database tests

The following tests apply to all nine application tables:

- `owners`
- `businesses`
- `credit_scores`
- `bot_sessions`
- `revenue_entries`
- `expense_entries`
- `supplier_records`
- `trust_signals`
- `activity_history`

Before testing, rerun staging RLS, grant and policy inspection if a
configuration change is applied. Reconfirm the live production inventory
separately; do not alter the staging baseline outside an approved test setup.

| Test ID | Scenario | Expected result |
|---|---|---|
| RLS-001 | Anonymous `SELECT` on each table | Denied. |
| RLS-002 | Anonymous `INSERT` on each table | Denied. |
| RLS-003 | Anonymous `UPDATE` on each table | Denied. |
| RLS-004 | Anonymous `DELETE` on each table | Denied. |
| RLS-005 | Merchant A reads Merchant B records | Denied for each merchant-owned table. |
| RLS-006 | Merchant A inserts records for Merchant B | Denied. |
| RLS-007 | Merchant A updates Merchant B records | Denied. |
| RLS-008 | Merchant A deletes Merchant B records | Denied. |
| RLS-009 | Merchant A reassigns owner or business ID | Denied by RLS and validation. |
| RLS-010 | Merchant A modifies privileged role fields | Denied. |
| RLS-011 | Approved administrator reads approved data | Allowed only for authorized scope and purpose. |
| RLS-012 | Ordinary merchant uses administrator role data | Denied. |
| RLS-013 | Trusted backend service operation | Succeeds only through approved backend authorization, tenant/input checks and audit; service-role RLS bypass is not a control. |
| RLS-014 | Direct service-role browser request | No service-role key exists in browser assets/traffic, so the browser cannot obtain or use it. |

For every applicable `UPDATE`, test both:

- **USING:** no row outside the merchant or administrator scope is selected for
  update.
- **WITH CHECK:** the resulting row remains in the authorized scope and cannot
  reassign ownership or privilege.

Views and helper functions must be tested for unintended privilege escalation,
anonymous reachability and cross-merchant access. Any `SECURITY DEFINER`
function must reject unauthenticated, unapproved or unexpected inputs.

## 7. Onboarding tests

| Test ID | Scenario | Expected result |
|---|---|---|
| ONB-001 | Successful merchant registration | Auth identity, owner, business, consent and approved recovery state are consistent. |
| ONB-002 | Sequential duplicate submission | A sequential repeat resolves to the same logical owner, business and consent state; no duplicate is created. Concurrent same-key submissions are covered separately by ONB-017. |
| ONB-003 | Retry after network failure | No duplicate records or inconsistent phase state remain. |
| ONB-004 | Auth creation fails or returns an unknown outcome before identity confirmation | No owner/business state is created; reconciliation determines whether the Auth identity exists before retry. Failure after a confirmed Auth creation is covered by ONB-011. |
| ONB-005 | Owner creation/linking fails before a durable owner relationship is confirmed | Recovery state identifies the unresolved phase and prevents duplicate owner creation. Failure after a confirmed owner write is covered by ONB-012. |
| ONB-006 | Business creation fails before durable business association | No orphaned active business; failure is recoverable or reverses safely. Failure after confirmed business creation is covered by ONB-013. |
| ONB-007 | Document upload returns failure or an unknown outcome before object persistence is confirmed | Registration is incomplete and recoverable, with no false success. Failure after confirmed upload is covered by ONB-015. |
| ONB-008 | Reconcile an incomplete registration with mixed completed/incomplete phases | Approved retry resumes or compensates the correct phase without duplicating prior durable state. The final completion-transition failure is covered by ONB-016. |
| ONB-009 | Durable consent record creation | Purpose, notice version, status, timestamp, channel and identity are stored. |
| ONB-010 | Direct anonymous onboarding write | Denied. |

No test may infer success solely from an HTTP 2xx response. Database state,
idempotency state and audit evidence must agree.

## 8. Storage tests

| Test ID | Scenario | Expected result |
|---|---|---|
| STO-001 | Anonymous upload | Denied. |
| STO-002 | Anonymous download | Denied. |
| STO-003 | Merchant A accesses Merchant B document | Denied. |
| STO-004 | Authorized merchant accesses own document | Allowed only within policy scope. |
| STO-005 | Unauthorized administrator accesses restricted document | Denied. |
| STO-006 | Approved administrator accesses permitted document | Allowed and audited. |
| STO-007 | Expired signed URL on the direct Storage access path | Denied; signed-URL renewal behavior is tested separately by STO-013. |
| STO-008 | Disallowed declared MIME type | Rejected before object creation or immediately quarantined. Content/signature mismatch and stream-size behavior are covered by STO-017. |
| STO-009 | Upload exceeds approved file-size limit | Rejected according to the approved size limit. Streaming beyond the cap is also tested by STO-017. |
| STO-010 | Invalid merchant-scoped object path | Denied. |
| STO-011 | Document access audit | Upload, access and restricted access attempts are recorded. |

Test the Storage bucket and object policy through the approved staging API.
Do not use real documents or PII.

## 9. WhatsApp tests

| Test ID | Scenario | Expected result |
|---|---|---|
| WA-001 | Valid Twilio signature | Webhook proceeds only to authorized operations. |
| WA-002 | Invalid signature | Request is rejected before merchant or database operations; WA-023 separately measures privileged database-operation count. |
| WA-003 | Missing signature | Request is rejected. |
| WA-004 | Altered signed request parameters | Signature failure is deterministic. Altered externally visible URL handling is specifically covered by WA-018. |
| WA-005 | Incorrect external URL validation | Request is rejected because signed URL context differs. |
| WA-006 | Replay of a previously accepted message identifier outside the permitted retry case | Duplicate side effects are prevented. A valid signed retry within the permitted provider window is covered by WA-017. |
| WA-007 | Sequential duplicate delivery | Only one logical operation or response occurs. Concurrent duplicate delivery is covered by WA-016. |
| WA-008 | Unlinked sender | Sender is not associated with a merchant. |
| WA-009 | Unauthorized sender | No merchant write or sensitive read occurs. |
| WA-010 | Media with declared or known total size above the approved limit | Media is rejected within size controls. A response that streams past the cap is covered by WA-021. |
| WA-011 | Media whose declared MIME type is outside the approved allowlist | Media is rejected. MIME/content disagreement is covered by WA-022. |
| WA-012 | Redirect to a disallowed destination | Redirect is denied and not followed. Per-hop redirect and DNS revalidation are covered by WA-020. |
| WA-013 | Direct media destination resolves to loopback/private/link-local/reserved or otherwise prohibited IP space | Destination is denied; DNS rebinding is tested by changing answers between validation and connection. |
| WA-014 | Secret exposure in webhook responses, logs or server code | Secret never appears in response, logs or code. Client bundles and browser network are covered by WA-024. |
| WA-015 | Forged sender/body with invalid or unauthenticated request context | Privileged operation is rejected. A valid Twilio signature with an unlinked/unauthorized sender is covered by WA-019. |

Signature tests must use synthetic request values and validate the exact
externally visible staging URL. Media destination tests must include IPv4 and
IPv6 loopback, private, link-local, reserved and otherwise prohibited
destinations. Change the controlled DNS answer between validation and
connection, and across redirect hops; verify that the fetcher re-resolves and
revalidates each destination immediately before connecting, pins the validated
address or provides equivalent race protection, and sends no request to a
prohibited destination. A recorded response alone is insufficient: use the
controlled destination's request log to prove no prohibited destination
received traffic.

## 10. Consent and privacy tests

| Test ID | Scenario | Expected result |
|---|---|---|
| PRI-001 | Consent version stored | The exact approved notice/policy version is recorded. |
| PRI-002 | Consent timestamp stored | Timestamp and timezone are durable and correct. |
| PRI-003 | Consent channel recorded | Channel is stored in a controlled value set. |
| PRI-004 | Processing purpose recorded | Purpose is specific and linked to the record. |
| PRI-005 | Withdrawal recorded | Withdrawal and effective state are durable. |
| PRI-006 | Access request workflow | Request is authenticated, tracked and fulfilled or refused appropriately. |
| PRI-007 | Correction request workflow | Requested correction is reviewed and audited. |
| PRI-008 | Retention expiry | Expired synthetic data follows the approved retention state. |
| PRI-009 | Deletion where legally permissible | Synthetic data is deleted or irreversibly de-identified as required. |
| PRI-010 | Administrative access audit | Access purpose and actor are recorded. |

Test only synthetic data. Legal review must approve consent language,
lawful-basis mapping and retention behavior before implementation.

## 11. Executable-in-principle test protocol

### Common identities, setup and result rules

Use the synthetic personas in section 2. Provision test accounts only in an
approved staging implementation:

- Merchant A and B each have one verified synthetic Auth identity, one
  distinct owner, and at least one business with known synthetic rows in each
  applicable table.
- Merchant C has two controlled cases: a duplicate phone candidate and a
  changed/inaccessible phone candidate. Neither case is auto-linked.
- The administrator account receives its role through the approved trusted
  role-assignment path, not through a client-editable profile field.
- The anonymous visitor has no Auth session. The forged WhatsApp sender has
  no verified owner link. Trusted backend tests use isolated server-side test
  credentials and synthetic inputs only.
- Record fixture IDs, request/correlation IDs and initial row counts in the
  test evidence. Do not retain OTPs, access/refresh tokens, signed URLs,
  secrets, personal contact data or document contents in evidence.

Run API cases with a fresh request and the specified identity. For every
operation record method, endpoint/surface, redacted request ID, response
status, response classification and post-operation database state.
Authorization, ownership, onboarding and privileged-operation evidence must
include both the observed response and persisted before/after state; include
correlated audit evidence wherever the design requires an audit. Exact
HTTP status codes are implementation-dependent until the API contract is
approved: record the approved expected code for each endpoint before
execution. A denied operation may be represented by an implementation-approved
401/403/404 or by a successful filtered response with zero affected rows, but
must produce no unauthorized read or state change. Never pass based on status
alone.

For database assertions, compare before/after rows, ownership keys, row counts,
foreign keys, audit events and idempotency state through an authorized
staging-only inspection path. Rejected actions should leave protected data
unchanged. Expected audit evidence is a correlated allow/deny event with actor,
target, action, purpose and outcome where the design requires an audit; do not
log secrets or document contents. Cleanup removes only the named synthetic
fixtures and test sessions/objects, then verifies their removal and any
required retained audit record. Never clean up shared or production data.

Each test group uses the following execution profile. The profile supplies
identity, setup, operation surface, result, audit, cleanup and pass criteria
for every test ID in that group; the case tables above/below identify the
scenario-specific assertion.

| Group | Identity and required setup | Exact operation surface | Expected outcome and persisted state | Audit, cleanup and pass rule |
|---|---|---|---|---|
| AUTH | Synthetic phone identities A/B/C; selected and approved OTP provider/configuration | Supabase Auth phone sign-in/OTP request and verify operations (`signInWithOtp`, `verifyOtp`); refresh/session/logout and selected recovery/phone-change operations | Valid OTP yields the verified test identity only. Invalid, expired, reused, throttled or failed attempts yield no verified session or merchant link. Exact HTTP code is an implementation decision; assert response, Auth/session state and no unauthorized owner/business writes. | Record redacted Auth event/correlation IDs and rate-limit outcome; delete/revoke synthetic identities/sessions and test OTP state. Pass only if all AUTH assertions hold and secrets are absent from logs. |
| LINK | A/B/C verified synthetic Auth identities; seeded candidate owners/businesses and duplicate/changed-number cases | The approved backend owner-claim/link/recovery operation; direct table writes are separately denied under RLS tests | Only explicitly verified/approved link is persisted; existing owner IDs and all business foreign keys remain identical. Ambiguity or failed proof changes no link. Exact HTTP code is implementation-dependent; compare response and rows before/after. | Record challenge, approver, decision and owner references without phone/OTP; remove synthetic links/fixtures. Pass only with no unauthorized claim and preserved IDs/relationships. |
| ADM | Synthetic administrator and merchant; assignment via trusted role authority; second administrator/role removal path where available | Trusted role-assignment/removal operation; privileged application endpoint and direct API attempts; Auth refresh/session revocation endpoints | Role is present only after trusted assignment. After removal, all sensitive endpoints deny the old JWT within the approved revocation bound, including after refresh and session revocation. No role change via `user_metadata`. Assert response and persisted authorization/resource state. | Record role transition, each attempted operation and required audit evidence; revoke sessions and remove test role. Pass only if stale and refreshed credentials cannot perform privileged actions. |
| RLS | A/B owners and businesses with rows in each table; anon, unlinked Auth, A, B and approved admin tokens | Direct PostgREST table `SELECT`/`INSERT`/`UPDATE`/`DELETE`; exposed views; RPC/helper functions; corresponding application endpoints. Run each table/operation in RLS-OWN, RLS-X, RLS-INS, RLS-UPD and RLS-DEL suites below. | Match the ADR table authorization matrix. Verify both update row qualification (`USING`) and resulting row validation (`WITH CHECK`). Verify views/RPC/application methods do not broaden access. No administrator receives unrestricted CRUD by virtue of role. | For each authorization/ownership operation, capture response plus before/after persisted state; record required audit evidence. Record grants/policies/function identity; delete only synthetic fixtures. Pass only when every path matches the matrix and no unauthorized data is returned or changed. |
| SERVICE | Synthetic A/B requests sent through the trusted backend test harness; no service key in client | Browser bundle/source inspection and network capture; approved server-side secret inventory; backend operation endpoints invoked with A/B identities and tampered owner/business identifiers | Service-role key is absent from browser assets and client traffic, exists only in approved server-side secret storage, and is never returned. Because service role bypasses RLS, backend validation must deny A-to-B access and reject tampered identifiers before/at the service operation. | Record sanitized secret-location evidence, authorization decision and audit event; revoke test secrets if any were provisioned and remove fixtures. Pass only if no browser credential exposure and all cross-tenant server calls are denied with no mutation. |
| ONB | New synthetic identities and isolated fault-injection request keys; known initial absence of owner/business/consent/document records | Approved onboarding API, staged Auth operation, owner/business/consent service calls, private Storage API and finalization endpoint; inject a failure after each boundary | Each successful phase has durable state; failure leaves a visible incomplete state, not a false complete result. Repeating the same request creates no duplicate logical record/object. Verify final owner/business/consent/document references and completion flag. Exact HTTP codes are implementation-dependent. | For each phase, capture response plus persisted state and required audit evidence. Record correlation IDs and failure/retry/recovery events; clean up only test rows/objects/Auth identities, then verify no orphan except explicitly retained audit. Pass only if retry/reconciliation reaches one consistent result or a clearly recoverable failure. |
| STORAGE | A/B synthetic documents in the private test bucket; merchant and approved/unapproved admin identities; approved maximum URL exposure window recorded before test | Supabase Storage upload/download/delete and signed-URL operations, plus any authenticated download proxy selected | Own permitted access succeeds; cross-merchant/unauthorized access fails. Valid URL works only within approved lifetime; after expiry it fails. Role removal during URL validity demonstrates the residual bearer window or immediate revocation behavior of the selected pattern. | Capture response plus persisted object/access state and required audit evidence. Record object IDs, MIME/size decisions, URL issue/expiry times (never URL token), and allow/deny audit. Delete test objects and revoke access; verify. Pass only if actual exposure does not exceed approved maximum and access checks/audit match design. |
| WHATSAPP | Synthetic valid, invalid and unlinked sender payloads; test Twilio signature material; controlled fake media server with permitted and forbidden destinations, DNS answers and redirects | Staging `whatsapp-bot` Edge Function HTTP endpoint; signature verifier; idempotency store; sender-link resolver; media fetcher; database-operation spy/records | Valid signature alone does not grant merchant authority. Invalid/missing signature is rejected before merchant data reads/writes. Duplicate valid delivery has one logical effect; replay is rejected or safely idempotent. Unsafe redirects, private/internal destinations including DNS-rebinding changes, invalid MIME and byte-limit excess are rejected. | Capture response, signature result, message ID hash/reference, media validation, persisted state and DB-operation count; record required audit evidence. Remove synthetic events/sessions/media. Pass only when invalid requests produce zero privileged data operations and secrets are not exposed. |
| PRIVACY | Synthetic subject A and approved policy versions/purposes; no real PII | Approved consent/rights request interfaces and authorized staging-only record inspection | Record/version/purpose/channel/time and withdrawal/change are durable; access/correction/objection/deletion/retention actions follow the legally approved workflow. Exact response deadlines/content depend on legal/product decisions and remain OPEN. | Record request/case IDs, actor and decision; clean synthetic data only where permitted and preserve required test audit. Pass only when all required fields and transitions match the approved legal design. |
| PARITY | No production identity or credential in this milestone; future run requires explicit authorization and named reviewers | Approved read-only inventory/export from each authorized environment, normalized comparison, signed review report; no automated apply/push operation | Compare every item in section 12. Differences are classified and approved; unexplained drift blocks release. This test has not executed and its register status is BLOCKED until separate authorization; it must not connect to production during this documentation task. | Evidence references inventory timestamps, reviewers, drift decisions and approvals, without secrets or row-level merchant data. Cleanup local report artifacts under approved controls. Pass only after authorized fresh comparison and explicit sign-off. |

### Table-by-table RLS execution set

For each table below, create a synthetic own-business row and, where relevant,
a foreign-business row. Run each operation using Merchant A against Merchant
A's own row and Merchant B's row, and using Merchant A to submit a row or
changed ownership value targeting Merchant B. `RLS-OWN-nn` verifies allowed
own-record reads/writes in the ADR matrix, except `RLS-OWN-04`, which verifies
that direct merchant table CRUD on `bot_sessions` is denied; `RLS-X-nn` verifies cross-merchant
SELECT denial; `RLS-INS-nn` verifies foreign-owner INSERT denial;
`RLS-UPD-nn` verifies both UPDATE `USING` and `WITH CHECK`; `RLS-DEL-nn`
verifies foreign-row DELETE denial. Where the matrix denies own writes, the
expected own-operation result is denial too. Always assert no protected state
changed after denial.

| Table | Own-record operations | Cross-merchant SELECT | Foreign INSERT | Ownership-changing UPDATE (`USING` + `WITH CHECK`) | Foreign DELETE | Unlinked Auth CRUD | Administrator CRUD | Trusted operation | Views/RPC/app paths |
|---|---|---|---|---|---|---|---|---|---|
| `owners` | `RLS-OWN-01` | `RLS-X-01` | `RLS-INS-01` | `RLS-UPD-01` | `RLS-DEL-01` | `RLS-UNLINK-01` | `RLS-ADM-01` | `RLS-SVC-01` | `RLS-PATH-01` |
| `businesses` | `RLS-OWN-02` | `RLS-X-02` | `RLS-INS-02` | `RLS-UPD-02` | `RLS-DEL-02` | `RLS-UNLINK-02` | `RLS-ADM-02` | `RLS-SVC-02` | `RLS-PATH-02` |
| `credit_scores` | `RLS-OWN-03` | `RLS-X-03` | `RLS-INS-03` | `RLS-UPD-03` | `RLS-DEL-03` | `RLS-UNLINK-03` | `RLS-ADM-03` | `RLS-SVC-03` | `RLS-PATH-03` |
| `bot_sessions` | `RLS-OWN-04` | `RLS-X-04` | `RLS-INS-04` | `RLS-UPD-04` | `RLS-DEL-04` | `RLS-UNLINK-04` | `RLS-ADM-04` | `RLS-SVC-04` | `RLS-PATH-04` |
| `revenue_entries` | `RLS-OWN-05` | `RLS-X-05` | `RLS-INS-05` | `RLS-UPD-05` | `RLS-DEL-05` | `RLS-UNLINK-05` | `RLS-ADM-05` | `RLS-SVC-05` | `RLS-PATH-05` |
| `expense_entries` | `RLS-OWN-06` | `RLS-X-06` | `RLS-INS-06` | `RLS-UPD-06` | `RLS-DEL-06` | `RLS-UNLINK-06` | `RLS-ADM-06` | `RLS-SVC-06` | `RLS-PATH-06` |
| `supplier_records` | `RLS-OWN-07` | `RLS-X-07` | `RLS-INS-07` | `RLS-UPD-07` | `RLS-DEL-07` | `RLS-UNLINK-07` | `RLS-ADM-07` | `RLS-SVC-07` | `RLS-PATH-07` |
| `trust_signals` | `RLS-OWN-08` | `RLS-X-08` | `RLS-INS-08` | `RLS-UPD-08` | `RLS-DEL-08` | `RLS-UNLINK-08` | `RLS-ADM-08` | `RLS-SVC-08` | `RLS-PATH-08` |
| `activity_history` | `RLS-OWN-09` | `RLS-X-09` | `RLS-INS-09` | `RLS-UPD-09` | `RLS-DEL-09` | `RLS-UNLINK-09` | `RLS-ADM-09` | `RLS-SVC-09` | `RLS-PATH-09` |

For `bot_sessions`, `RLS-OWN-04` and `RLS-PATH-04` test denial through direct
client table and exposed client-facing paths; they do not represent an
accessible merchant-owned session row. `RLS-SVC-04` is a separate trusted
backend test for a verified sender-bound session and is `BLOCKED` until the
phone-keyed session has an approved owner-binding design and secure sender
resolution. Do not combine these cases or infer that a merchant can directly
read or mutate `bot_sessions`.

For each table also execute `SELECT`, `INSERT`, `UPDATE` and `DELETE` as
anonymous visitor (the existing `RLS-001` through `RLS-004` suites must
enumerate all nine tables), as an authenticated but unlinked user, and as an
approved administrator only within the ADR's table-by-table scope. Administrator
CRUD never means unrestricted access: deny each operation not explicitly
permitted by that table's matrix row. Exercise ordinary merchant administrator attempts.
Repeat all four CRUD operations where meaningful through direct table REST,
every exposed view and RPC/helper, and the application API. Record exact
response status and confirm the database outcome. For service-role actions,
do not assert that RLS denies access: service role bypasses RLS. Instead use
the SERVICE profile to prove the trusted method's own authentication, tenant
validation, input validation and audit controls.

### Additional revocation, onboarding, Storage and webhook cases

| Test ID | Scenario and operation | Required measurable outcome |
|---|---|---|
| SERVICE-001 | Inspect browser-delivered assets and source maps for service-role key | No key present. |
| SERVICE-002 | Inspect approved server secret configuration | Credential is server-side only; record name/location, never value. |
| SERVICE-003 | Call privileged operation outside trusted backend path | Operation is unavailable or denied. |
| SERVICE-004 | Tamper owner/business IDs in trusted request | Backend denies cross-merchant operation; no state change. |
| SERVICE-005 | Execute permitted privileged operation | Correct scoped result and correlated audit event. |
| SERVICE-006 | Attempt to obtain/use service-role credential from browser | Credential cannot be obtained or used. |

| Test ID | Scenario and operation | Required measurable outcome |
|---|---|---|
| ADM-009 | Trusted authority assigns a role; read role through privileged backend | Only approved target gains the role; actor/reason/time recorded. |
| ADM-010 | Remove administrator role, then call sensitive endpoint with pre-removal JWT | Denied within the explicitly approved maximum revocation bound; no protected read/write. |
| ADM-011 | After role removal, use the same refresh token to obtain a new JWT | New token cannot authorize sensitive operations; removed role is not restored. |
| ADM-012 | Revoke administrator session, then retry with its access/refresh credentials | Session/refresh behavior matches platform contract and sensitive backend operation is denied. |
| ADM-013 | Direct REST/RPC/application API attempt after role removal | All sensitive surfaces deny the stale role; record status and no state change. |
| ADM-014 | Invoke privileged backend operation after role removal using stale JWT | Backend's current-role check denies it; an audit denial is correlated. |
| ADM-015 | Attempt self-assignment through `user_metadata` and direct role API | No role change; authorization record is unchanged. |
| ADM-016 | Offboard administrator and inspect active sessions/URLs | Sessions/refresh capability are revoked; any still-valid signed URL remains within approved maximum or is immediately revoked by selected pattern. |
| ONB-011 | Inject failure immediately after Auth identity creation | No owner/business/consent/document is marked complete; same request retry reconciles one Auth identity. |
| ONB-012 | Inject failure after owner link or new owner creation | Existing owner ID is unchanged or exactly one new owner exists; retry creates no duplicate. |
| ONB-013 | Inject failure after business creation | Exactly one expected business remains associated with the verified owner; retry is idempotent. |
| ONB-014 | Inject failure after consent recording | Exactly one logical consent/basis event exists; retry does not duplicate or overwrite history. |
| ONB-015 | Inject failure after document upload | One expected object exists or an explicit recoverable orphan state is recorded; retry does not create duplicate logical document. |
| ONB-016 | Inject failure during final completion transition | Registration remains incomplete until all phase checks pass; recovery completes once. |
| ONB-017 | Submit same idempotency key concurrently and then retry after completion | One logical owner/business/consent/document set and one final completion; all responses resolve to the same workflow. |
| STO-012 | Fetch signed URL before its expiry | Access outcome matches approved merchant/admin scope; record issue/expiry times without logging token. |
| STO-013 | Fetch same signed URL after expiry | Download is denied and no new URL is implicitly issued. |
| STO-014 | Remove merchant role while a signed URL remains unexpired | Demonstrate and record residual exposure; exposure never exceeds approved maximum, or selected proxy/revocation mechanism denies immediately. |
| STO-015 | Remove administrator role while a signed URL remains unexpired | Same maximum-exposure assertion for administrator documents. |
| STO-016 | Attempt cross-merchant object path and direct object download | Denied with no object bytes returned; denied-access event recorded where required. |
| STO-017 | Upload invalid MIME, spoofed content type and oversized byte stream | Rejected/quarantined according to approved rules; no accepted document record or usable object. |
| STO-018 | Audit allowed and denied document access | Each event has actor, object reference, purpose, time and outcome; no signed URL token or document content. |
| WA-016 | Submit valid duplicate message identifiers concurrently | One logical operation and idempotent response; no duplicate database writes. |
| WA-017 | Retry a valid signed request within the permitted provider retry window | Returns the prior idempotent outcome or safely reprocesses without a second effect; WA-006 tests replay outside that permitted retry case. |
| WA-018 | Alter the externally visible URL used for signature validation | Signature validation fails before merchant lookup or protected table access; WA-004 tests altered signed parameters. |
| WA-019 | Submit a forged/unlinked sender with otherwise valid Twilio signature | Signature may validate, but owner authorization fails and no merchant data is read or changed. |
| WA-020 | Media redirect or DNS answer changes between validation and connection | Revalidate every redirect hop and every resolved destination immediately before connecting; pin the validated destination or use equivalent race protection. Prohibited destinations receive no request, and credentials/request data are never forwarded there. |
| WA-021 | Media server streams beyond configured byte cap | Fetch aborts at or before cap; content is not persisted as accepted. |
| WA-022 | Media response declares allowed MIME but contains disallowed bytes, or vice versa | Content validation rejects it; no accepted document or downstream operation. |
| WA-023 | Submit missing/invalid signature and instrument privileged DB operations | Rejected before merchant data access; protected-read/write operation count is zero. |
| WA-024 | Inspect frontend assets, source maps and browser network for service-role secret | No service-role credential appears in any client-delivered artifact or request. |
| PARITY-001 | Fresh authorized inventory and comparison against approved design | Every parity category in section 12 has a dated evidence reference, reviewer, variance classification and disposition; any unexplained difference blocks release. |

### Retained overlapping scenarios

Similar names do not indicate duplicate coverage. These IDs remain separate
because they exercise different commit points, request timing, access paths or
evidence:

- **Onboarding:** ONB-002 is sequential duplication; ONB-017 is concurrent
  same-key submission plus a post-completion retry. ONB-004 through ONB-008
  test failures before durable state is confirmed or general reconciliation;
  ONB-011 through ONB-016 test failures after confirmed stage commits or at
  final completion. ONB-009 tests a durable consent record; ONB-014 tests
  recovery after that record has committed.
- **Storage:** STO-003 tests merchant policy isolation; STO-016 tests direct
  object-path access and confirms no bytes are returned. STO-007 tests expiry
  on the direct Storage path; STO-013 tests reuse after expiry and prevents
  implicit renewal. STO-008 tests a disallowed declared MIME; STO-009 tests
  the approved file-size threshold; STO-017 tests spoofed MIME/content and a
  streaming over-limit upload. STO-011 checks that access events exist;
  STO-018 checks the required event fields and exclusion of tokens/content.
- **WhatsApp:** WA-002 tests rejection of an invalid signature; WA-023
  additionally proves zero privileged database operations. WA-004 alters
  signed parameters; WA-018 alters the externally visible URL. WA-006 tests
  replay outside the permitted retry case; WA-017 tests a valid retry within
  that case. WA-007 tests sequential duplicates; WA-016 tests concurrency.
  WA-010 tests known/declared size; WA-021 tests a streaming byte cap.
  WA-012 tests redirect rejection; WA-013 tests prohibited direct
  destinations and DNS rebinding; WA-020 tests revalidation across redirects
  and changing DNS answers. WA-014 tests server-side secret locations;
  WA-024 inspects client-delivered assets and traffic. WA-015 tests forged
  unauthenticated sender/body data; WA-019 tests an unlinked sender despite a
  valid Twilio signature.

Run failure injection only in an approved isolated staging implementation using
test-only fault controls. Do not introduce a production bypass or leave fault
controls enabled after the run. Cleanup verifies synthetic Auth identities,
rows, Storage objects, sessions and idempotency fixtures are removed or
explicitly retained for audit.

## 12. Production parity review

This is a release test, not permission to access production. Its reporting
status must remain `BLOCKED` until a separate explicit authorization identifies
the production project, reviewers, read-only method and evidence handling.
The release gate remains `NOT RUN` until the authorized comparison is executed
and reviewed. Do not connect to production as part of this documentation
milestone.

Before any production rollout, perform a fresh read-only inventory of the
authorized live environment and compare it with the approved staging design
and release candidate. Compare and record evidence for:

- tables and columns, including types, nullability and constraints;
- foreign keys, indexes and uniqueness;
- RLS enablement, forced-RLS state where applicable, and every policy;
- API grants, role memberships and default privileges;
- Storage buckets, privacy flags, size/MIME settings and object policies;
- database functions, views, triggers, owners and security mode;
- Auth providers, phone settings, session/token and redirect configuration;
- Edge Functions, deployment settings and secret names/configuration (never
  secret values);
- WhatsApp signature, sender-linking, replay/idempotency and media controls;
- scheduled jobs, extensions and network access relevant to the application;
- required backup, rollback and recovery controls.

Historical production findings in prior audit documents remain historical
until refreshed by this authorized comparison. Do not include production rows,
merchant PII, tokens or secret values in the parity report. Every variance must
be explained, risk-assessed, assigned an owner and approved or resolved before
release. No automatic migration or repair is part of the parity check.

## 13. Release gates

No production rollout may occur until all applicable gates are passed and
explicitly approved.

| Gate | Mandatory evidence | Status |
|---|---|---|
| GATE 1: Identity design approved | Architecture decision record approved by product and database owners. | NOT RUN |
| GATE 2: Auth configuration and provider costs verified | Provider coverage, cost, abuse controls and phone support recorded. | NOT RUN |
| GATE 3: Synthetic merchant authentication tests pass | AUTH-001–AUTH-012 pass. | NOT RUN |
| GATE 4: Existing owner linking passes without changing IDs | LINK-001–LINK-008 pass and ID preservation is evidenced. | NOT RUN |
| GATE 5: Merchant isolation and administrator authorization pass | RLS-001–RLS-014; RLS-OWN-01–RLS-OWN-09; RLS-X-01–RLS-X-09; RLS-INS-01–RLS-INS-09; RLS-UPD-01–RLS-UPD-09; RLS-DEL-01–RLS-DEL-09; RLS-UNLINK-01–RLS-UNLINK-09; RLS-ADM-01–RLS-ADM-09; RLS-SVC-01–RLS-SVC-09; RLS-PATH-01–RLS-PATH-09; ADM-001–ADM-016; SERVICE-001–SERVICE-006 pass, with administrator CRUD limited to the ADR matrix. | NOT RUN |
| GATE 6: Storage tests pass | STO-001–STO-018 pass. | NOT RUN |
| GATE 7: WhatsApp signature and replay tests pass | WA-001–WA-024 pass. | NOT RUN |
| GATE 8: Consent and privacy workflows pass | PRI-001–PRI-010 pass. | NOT RUN |
| GATE 9: Onboarding and regression tests pass | ONB-001–ONB-017 and relevant existing staging regression tests pass. | NOT RUN |
| GATE 10: Backup, rollback and production change plan approved | Recovery, rollback, support and explicit approval evidence exists. | NOT RUN |
| GATE 11: Fresh production parity review approved | PARITY-001 passes under separate explicit authorization; all variances are resolved and reviewed. | NOT RUN |

A gate may be marked PASS only when every applicable test in that gate has
passing evidence. `NOT RUN` and `BLOCKED` are not passing states.
GATE 11 remains NOT RUN in this task and must not be run without separate
authorization. No production rollout is permitted while it or any other
applicable gate is incomplete.

## 14. Open decisions and test blockers

The following decisions must be resolved and documented by the authorized
owners before affected tests can pass:

- OTP provider and delivery channel.
- Account recovery authority, duplicate/changed-number policy and manual
  linking evidence standard.
- Administrator role authority/granularity and maximum privilege-removal
  propagation bound.
- Consent wording, lawful-basis mapping and approved privacy request behavior.
- Retention/deletion periods and lawful deletion exceptions.
- Maximum signed-URL lifetime and whether immediate-revocation proxy access is
  required.
- Approved Storage/media MIME-content allowlists and maximum upload byte
  limits.
- Bot-session owner binding, key design and inactivity/absolute expiry.
- Per-table merchant-visible fields and allowed update/delete/correction
  operations.
- Trust-signal producers, visibility and correction/retraction process.
- Durable onboarding state representation, Auth reconciliation, and
  compensation/recovery authority.
- Institutional access eligibility, permissions and purpose.
- Exact endpoint contracts and expected HTTP status codes for the selected
  implementation.
- Production rollout method and parity evidence/review ownership.

Do not fill these values by assumption. A dependent test remains `BLOCKED`
until its prerequisite is approved; it is not a pass and does not authorize
production access.

### Explicit blocked-test mapping

These are decision/approval blockers, not test results. The affected reporting
rows are marked `BLOCKED`; no test has been executed. Other test rows remain
`NOT RUN`.

| Unresolved prerequisite | Affected test IDs |
|---|---|
| OTP provider and delivery channel | AUTH-001–AUTH-012; LINK-001–LINK-008; ONB-001–ONB-009; ONB-011–ONB-017 |
| Recovery authority, duplicate/changed-number policy and link evidence | LINK-003; LINK-006–LINK-008 |
| Administrator role authority/granularity and approved scope | ADM-001; ADM-009; RLS-011; RLS-ADM-01–RLS-ADM-09; STO-006 |
| Current-role revocation bound and session/refresh revocation behavior | ADM-005–ADM-006; ADM-010–ADM-014; ADM-016 |
| Per-table merchant visibility and permitted fields/operations | RLS-OWN-01–RLS-OWN-03; RLS-OWN-05–RLS-OWN-09; RLS-PATH-01–RLS-PATH-03; RLS-PATH-05–RLS-PATH-09 |
| Trusted per-table workflows and producer authorization | RLS-SVC-01–RLS-SVC-09 |
| Phone-keyed bot-session owner binding and verified sender resolution | RLS-SVC-04; WA-001; WA-008–WA-009; WA-015; WA-019 |
| Durable onboarding state and recovery/compensation authority | ONB-001–ONB-008; ONB-011–ONB-017 |
| Consent wording, lawful-basis mapping and approved privacy behavior | ONB-009; ONB-014; PRI-001–PRI-010 |
| Maximum signed-URL lifetime and immediate-revocation pattern | ADM-016; STO-007; STO-012–STO-015 |
| Approved upload size limit and MIME/content allowlist | STO-008–STO-009; STO-017; WA-010–WA-011; WA-021–WA-022 |
| Replay/idempotency window, key retention and retry behavior | WA-006–WA-007; WA-016–WA-017 |
| Explicit authorization and reviewers for fresh production inventory | PARITY-001 |

The shared test protocol requires an approved expected HTTP contract per
endpoint before execution; do not invent status codes. The current report does
not claim a live test result. Gate 11 remains `NOT RUN`; PARITY-001 remains
`BLOCKED` until its separate production-access authorization is granted.

## 15. Test reporting template

No tests have executed. Record cases with unresolved prerequisites as
`BLOCKED`; record all other unexecuted cases as `NOT RUN`. Test evidence must
be reproducible and must not contain secrets or real PII.

The reporting register contains 207 unique IDs: 206 across AUTH (12), LINK
(8), ADM (16), RLS (95), SERVICE (6), ONB (17), STO (18), WA (24) and PRI
(10), plus PARITY-001.

Use these status meanings consistently: `DOCUMENTED` means only that a design
or test requirement exists; it is not an execution result. `NOT RUN` means no
test execution has occurred. `PASS` requires execution and evidence supporting
every expected result. `FAIL` means execution did not meet an expected result.
`BLOCKED` means execution could not proceed due to an unmet dependency or
approval. No unexecuted test may be marked `PASS` or `FAIL`; requirement
documentation is not a passing test.

| Test ID | Scenario | Expected result | Actual result | Status | Evidence reference | Defect or follow-up |
|---|---|---|---|---|---|---|
| AUTH-001 | Successful OTP verification | Exactly one synthetic Auth identity is verified and receives the intended limited session. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-002 | Incorrect OTP | Verification fails; no session or privileged merchant state is granted. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-003 | Expired OTP | Verification fails and the attempt is rejected. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-004 | Reused OTP | Reuse is denied after the first accepted verification. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-005 | OTP resend limits | Excess resend attempts are throttled and audited. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-006 | OTP rate limiting | Excess attempts are blocked. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-007 | Session expiration | Expired session cannot read or write protected data. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-008 | Logout | Session cannot continue access after logout. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-009 | Account recovery | Approved challenge is required. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-010 | Phone number change | Relationships remain controlled and intact. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-011 | Duplicate phone number | Ambiguity is prevented or escalated. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| AUTH-012 | Failed verification | No owner, business or role is granted. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| LINK-001 | Correct verified owner linking | Existing owner ID is preserved. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| LINK-002 | Incorrect phone verification | Candidate owner is not linked. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| LINK-003 | Duplicate owner phone numbers | Ambiguity is rejected or escalated. |  | BLOCKED |  | OTP and duplicate-number/recovery policy not approved. |
| LINK-004 | One Auth user claims multiple owners | Unauthorized claim is denied. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| LINK-005 | Multiple Auth users claim one owner | Only approved relationship is created. |  | BLOCKED |  | OTP provider and delivery channel not approved. |
| LINK-006 | Changed phone number | No silent reassignment occurs. |  | BLOCKED |  | Changed-number policy not approved. |
| LINK-007 | Inaccessible phone number | Approved recovery is required. |  | BLOCKED |  | Recovery authority and policy not approved. |
| LINK-008 | Manual recovery approval | Approver and evidence are audited. |  | BLOCKED |  | Recovery authority and evidence standard not approved. |
| ADM-001 | Valid administrator access | Approved scope only. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| ADM-002 | Merchant administrator attempt | Denied. |  | NOT RUN |  |  |
| ADM-003 | Anonymous administrator attempt | Denied. |  | NOT RUN |  |  |
| ADM-004 | User edits own role | Role remains unchanged. |  | NOT RUN |  |  |
| ADM-005 | Stale administrator JWT | Removed role remains denied. |  | BLOCKED |  | Maximum current-role revocation bound not approved. |
| ADM-006 | Revoked session | Access stops. |  | BLOCKED |  | Session and refresh-token revocation behavior not approved. |
| ADM-007 | Unauthorized document access | Denied. |  | NOT RUN |  |  |
| ADM-008 | Audit log recording | Required fields are recorded. |  | NOT RUN |  |  |
| ADM-009 | Trusted administrator role assignment | Approved target gains role; action audited. |  | BLOCKED |  | Role authority and granularity not approved. |
| ADM-010 | Role removal with pre-removal JWT | Denied within approved revocation bound. |  | BLOCKED |  | Maximum current-role revocation bound not approved. |
| ADM-011 | Refresh after role removal | Refreshed JWT cannot restore removed privileges. |  | BLOCKED |  | Maximum current-role revocation bound not approved. |
| ADM-012 | Reuse revoked administrator session | Sensitive operation denied. |  | BLOCKED |  | Session/refresh behavior and revocation bound not approved. |
| ADM-013 | Direct API attempts after role removal | All sensitive surfaces deny stale role. |  | BLOCKED |  | Maximum current-role revocation bound not approved. |
| ADM-014 | Privileged backend call after role removal | Current-role check denies and audits. |  | BLOCKED |  | Maximum current-role revocation bound not approved. |
| ADM-015 | Self-assignment via metadata or role API | No authorization change. |  | NOT RUN |  |  |
| ADM-016 | Offboarding and active sessions/URLs | Revocation and signed-URL exposure meet approved limits. |  | BLOCKED |  | Session revocation bound and signed-URL maximum lifetime not approved. |
| RLS-001 | Anonymous SELECT on all nine tables | All denied. |  | NOT RUN |  |  |
| RLS-002 | Anonymous INSERT on all nine tables | All denied. |  | NOT RUN |  |  |
| RLS-003 | Anonymous UPDATE on all nine tables | All denied. |  | NOT RUN |  |  |
| RLS-004 | Anonymous DELETE on all nine tables | All denied. |  | NOT RUN |  |  |
| RLS-005 | Merchant A reads Merchant B | Denied. |  | NOT RUN |  |  |
| RLS-006 | Merchant A inserts for Merchant B | Denied. |  | NOT RUN |  |  |
| RLS-007 | Merchant A updates Merchant B | Denied. |  | NOT RUN |  |  |
| RLS-008 | Merchant A deletes Merchant B | Denied. |  | NOT RUN |  |  |
| RLS-009 | Merchant A reassigns ownership | Denied. |  | NOT RUN |  |  |
| RLS-010 | Merchant A modifies role fields | Denied. |  | NOT RUN |  |  |
| RLS-011 | Approved administrator access | Allowed only by approved role and table-matrix scope. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-012 | Merchant bypasses administrator controls | Denied. |  | NOT RUN |  |  |
| RLS-013 | Trusted service operation | Allowed only through trusted path. |  | NOT RUN |  |  |
| RLS-014 | Direct browser service-role request | Browser has no service-role credential; do not treat RLS as protection for service-role calls. |  | NOT RUN |  |  |
| RLS-OWN-01 | Own `owners` row and matrix permissions | Only approved own profile read/update fields. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-OWN-02 | Own `businesses` row and matrix permissions | Scoped read and approved workflow writes only. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-OWN-03 | Own `credit_scores` and matrix permissions | Read only if approved; all merchant writes denied. |  | BLOCKED |  | Merchant score visibility not approved. |
| RLS-OWN-04 | Direct client CRUD against `bot_sessions` | Denied; no merchant-owned row is exposed to the client. |  | NOT RUN |  |  |
| RLS-OWN-05 | Own `revenue_entries` and matrix permissions | Scoped permitted fields only; unresolved delete denied. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-OWN-06 | Own `expense_entries` and matrix permissions | Scoped permitted fields only; unresolved delete denied. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-OWN-07 | Own `supplier_records` and matrix permissions | Scoped record access; private document policy applies. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-OWN-08 | Own `trust_signals` and matrix permissions | Read only if approved; merchant writes denied. |  | BLOCKED |  | Trust-signal visibility not approved. |
| RLS-OWN-09 | Own `activity_history` and matrix permissions | Scoped visible read; append via validated event operation only. |  | BLOCKED |  | Merchant-visible history events not approved. |
| RLS-X-01 | Read another owner's `owners` row | Denied. |  | NOT RUN |  |  |
| RLS-X-02 | Read another owner's `businesses` row | Denied. |  | NOT RUN |  |  |
| RLS-X-03 | Read another business's `credit_scores` | Denied. |  | NOT RUN |  |  |
| RLS-X-04 | Read another sender's `bot_sessions` | Denied. |  | NOT RUN |  |  |
| RLS-X-05 | Read another business's `revenue_entries` | Denied. |  | NOT RUN |  |  |
| RLS-X-06 | Read another business's `expense_entries` | Denied. |  | NOT RUN |  |  |
| RLS-X-07 | Read another business's `supplier_records` | Denied. |  | NOT RUN |  |  |
| RLS-X-08 | Read another business's `trust_signals` | Denied. |  | NOT RUN |  |  |
| RLS-X-09 | Read another business's `activity_history` | Denied. |  | NOT RUN |  |  |
| RLS-INS-01 | Insert owner or linkage for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-02 | Insert business for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-03 | Insert or forge Merchant B score | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-04 | Insert session for another sender | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-05 | Insert revenue for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-06 | Insert expense for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-07 | Insert supplier record for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-08 | Manufacture trust signal for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-INS-09 | Forge privileged history for Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UPD-01 | Change own or another owner's identity linkage | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UPD-02 | Reassign own business `owner_id` to Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UPD-03 | Change score or tier as Merchant A | Denied. |  | NOT RUN |  |  |
| RLS-UPD-04 | Change session owner/sender binding as Merchant A | Denied. |  | NOT RUN |  |  |
| RLS-UPD-05 | Reassign revenue `business_id` to Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UPD-06 | Reassign expense `business_id` to Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UPD-07 | Reassign supplier `business_id` to Merchant B | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UPD-08 | Manufacture or alter trust signal as Merchant A | Denied. |  | NOT RUN |  |  |
| RLS-UPD-09 | Rewrite or delete activity history as Merchant A | Denied; corrections append. |  | NOT RUN |  |  |
| RLS-DEL-01 | Delete another owner's row | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-02 | Delete another business | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-03 | Delete another business's score | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-04 | Delete another sender's session | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-05 | Delete another business's revenue | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-06 | Delete another business's expense | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-07 | Delete another business's supplier record | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-08 | Delete another business's trust signal | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-DEL-09 | Delete another business's activity history | Denied to Merchant A. |  | NOT RUN |  |  |
| RLS-UNLINK-01 | Unlinked Auth user against `owners` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-02 | Unlinked Auth user against `businesses` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-03 | Unlinked Auth user against `credit_scores` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-04 | Unlinked Auth user against `bot_sessions` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-05 | Unlinked Auth user against `revenue_entries` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-06 | Unlinked Auth user against `expense_entries` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-07 | Unlinked Auth user against `supplier_records` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-08 | Unlinked Auth user against `trust_signals` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-UNLINK-09 | Unlinked Auth user against `activity_history` CRUD | All denied. |  | NOT RUN |  |  |
| RLS-ADM-01 | Approved admin against `owners` CRUD | ADR matrix scope only; all other operations denied. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-02 | Approved admin against `businesses` CRUD | ADR matrix scope only; all other operations denied. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-03 | Approved admin against `credit_scores` CRUD | ADR matrix scope only; all other operations denied. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-04 | Approved admin against `bot_sessions` CRUD | Denied by default; no implied direct troubleshooting access. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-05 | Approved admin against `revenue_entries` CRUD | ADR matrix scope only; all other operations denied. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-06 | Approved admin against `expense_entries` CRUD | ADR matrix scope only; all other operations denied. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-07 | Approved admin against `supplier_records` CRUD | ADR matrix scope and document checks only. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-08 | Approved admin against `trust_signals` CRUD | ADR matrix read scope only; no direct signal mutation. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-ADM-09 | Approved admin against `activity_history` CRUD | ADR matrix scope only; no rewrite or delete. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| RLS-SVC-01 | Trusted operation against `owners` | Only approved owner workflow; immutable IDs. |  | BLOCKED |  | Trusted owner workflow not approved. |
| RLS-SVC-02 | Trusted operation against `businesses` | Only owner-validated workflow. |  | BLOCKED |  | Trusted business workflow not approved. |
| RLS-SVC-03 | Trusted operation against `credit_scores` | Approved scoring producer only. |  | BLOCKED |  | Scoring producer operation not approved. |
| RLS-SVC-04 | Trusted operation against `bot_sessions` | Verified sender-bound session only. |  | BLOCKED |  | Bot-session owner binding and verified sender resolution not approved. |
| RLS-SVC-05 | Trusted operation against `revenue_entries` | Approved validated ingestion only. |  | BLOCKED |  | Trusted ingestion scope not approved. |
| RLS-SVC-06 | Trusted operation against `expense_entries` | Approved validated ingestion only. |  | BLOCKED |  | Trusted ingestion scope not approved. |
| RLS-SVC-07 | Trusted operation against `supplier_records` | Approved record/document workflow only. |  | BLOCKED |  | Trusted supplier/document workflow not approved. |
| RLS-SVC-08 | Trusted operation against `trust_signals` | Assigned signal producer only. |  | BLOCKED |  | Trust-signal producer inventory not approved. |
| RLS-SVC-09 | Trusted operation against `activity_history` | Append attributed events only. |  | BLOCKED |  | Trusted event operation and visible event scope not approved. |
| RLS-PATH-01 | `owners` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-PATH-02 | `businesses` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-PATH-03 | `credit_scores` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Merchant score visibility not approved. |
| RLS-PATH-04 | `bot_sessions` via direct client view/RPC/application endpoint | Denied; no merchant-owned session row is exposed. |  | NOT RUN |  |  |
| RLS-PATH-05 | `revenue_entries` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-PATH-06 | `expense_entries` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-PATH-07 | `supplier_records` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Per-table merchant fields and operations not approved. |
| RLS-PATH-08 | `trust_signals` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Trust-signal visibility not approved. |
| RLS-PATH-09 | `activity_history` via view/RPC/application endpoint | Every exposed path matches matrix. |  | BLOCKED |  | Merchant-visible history events not approved. |
| SERVICE-001 | Inspect browser-delivered assets for service-role key | No key present. |  | NOT RUN |  |  |
| SERVICE-002 | Inspect approved server secret configuration | Credential is server-side only; record name/location, never value. |  | NOT RUN |  |  |
| SERVICE-003 | Call privileged operation outside trusted backend path | Unavailable or denied. |  | NOT RUN |  |  |
| SERVICE-004 | Tamper owner/business IDs in trusted request | Backend denies cross-merchant operation; no state change. |  | NOT RUN |  |  |
| SERVICE-005 | Execute permitted privileged operation | Correct scoped result and audit event. |  | NOT RUN |  |  |
| SERVICE-006 | Attempt to obtain/use service-role credential from browser | Credential cannot be obtained or used. |  | NOT RUN |  |  |
| ONB-001 | Successful registration | Consistent synthetic state. |  | BLOCKED |  | OTP provider, onboarding recovery design and consent basis not approved. |
| ONB-002 | Duplicate submission | No duplicates. |  | BLOCKED |  | OTP provider and onboarding recovery design not approved. |
| ONB-003 | Retry after network failure | Consistent state. |  | BLOCKED |  | OTP provider and onboarding recovery design not approved. |
| ONB-004 | Failure before Auth identity is confirmed | Durable recovery state. |  | BLOCKED |  | OTP provider and Auth reconciliation design not approved. |
| ONB-005 | Failure before owner relationship is confirmed | Durable recovery state. |  | BLOCKED |  | OTP provider and owner recovery design not approved. |
| ONB-006 | Failure during business creation | No unauthorized orphan. |  | BLOCKED |  | OTP provider and onboarding compensation design not approved. |
| ONB-007 | Failure during document upload | No false success. |  | BLOCKED |  | OTP provider and onboarding recovery design not approved. |
| ONB-008 | Recovery from incomplete registration | Safe completion or rollback. |  | BLOCKED |  | Onboarding state and recovery/compensation authority not approved. |
| ONB-009 | Durable consent | Required consent fields stored. |  | BLOCKED |  | Consent wording and lawful-basis mapping not approved. |
| ONB-010 | Anonymous onboarding write | Denied. |  | NOT RUN |  |  |
| ONB-011 | Failure after Auth creation | No completion; retry reconciles one identity. |  | BLOCKED |  | OTP provider and Auth reconciliation design not approved. |
| ONB-012 | Failure after owner link/create | Existing ID preserved or exactly one new owner. |  | BLOCKED |  | OTP provider and owner recovery design not approved. |
| ONB-013 | Failure after business creation | Exactly one expected linked business. |  | BLOCKED |  | OTP provider and onboarding compensation design not approved. |
| ONB-014 | Failure after consent recording | One logical durable consent/basis event. |  | BLOCKED |  | Consent wording/lawful-basis and onboarding recovery design not approved. |
| ONB-015 | Failure after document upload | One object or explicit recoverable orphan state. |  | BLOCKED |  | OTP provider and onboarding recovery design not approved. |
| ONB-016 | Failure at final completion | Remains incomplete until reconciled, then completes once. |  | BLOCKED |  | Durable onboarding state and recovery authority not approved. |
| ONB-017 | Concurrent duplicate and post-completion retry | One logical workflow and one completed state. |  | BLOCKED |  | OTP provider and idempotency/recovery design not approved. |
| STO-001 | Anonymous upload | Denied. |  | NOT RUN |  |  |
| STO-002 | Anonymous download | Denied. |  | NOT RUN |  |  |
| STO-003 | Cross-merchant document access | Denied. |  | NOT RUN |  |  |
| STO-004 | Own document access | Allowed only for authorized merchant. |  | NOT RUN |  |  |
| STO-005 | Unauthorized administrator document access | Denied. |  | NOT RUN |  |  |
| STO-006 | Approved administrator document access | Allowed and audited within approved scope. |  | BLOCKED |  | Administrator role authority/granularity and scope not approved. |
| STO-007 | Expired signed URL | Denied. |  | BLOCKED |  | Maximum signed-URL lifetime and expiry contract not approved. |
| STO-008 | Invalid MIME type | Rejected or quarantined. |  | BLOCKED |  | Upload MIME/content allowlist not approved. |
| STO-009 | Oversized file | Rejected. |  | BLOCKED |  | Upload size limit not approved. |
| STO-010 | Invalid object path | Denied. |  | NOT RUN |  |  |
| STO-011 | Document access audit | Recorded. |  | NOT RUN |  |  |
| STO-012 | Signed URL before expiry | Behavior matches approved scope; no URL token in evidence. |  | BLOCKED |  | Maximum signed-URL lifetime not approved. |
| STO-013 | Signed URL after expiry | Denied; no implicit renewal. |  | BLOCKED |  | Maximum signed-URL lifetime and expiry contract not approved. |
| STO-014 | Merchant role removal while URL remains valid | Residual exposure within approved maximum or immediately revoked. |  | BLOCKED |  | Maximum signed-URL lifetime/immediate-revocation pattern not approved. |
| STO-015 | Administrator role removal while URL remains valid | Residual exposure within approved maximum or immediately revoked. |  | BLOCKED |  | Maximum signed-URL lifetime/immediate-revocation pattern not approved. |
| STO-016 | Cross-merchant object access | Denied with no bytes returned. |  | NOT RUN |  |  |
| STO-017 | Invalid MIME/content and oversized upload | Rejected/quarantined; no accepted document state. |  | BLOCKED |  | Upload size limit and MIME/content allowlist not approved. |
| STO-018 | Allowed and denied document audit | Actor/object/purpose/time/outcome recorded without URL token/content. |  | NOT RUN |  |  |
| WA-001 | Valid Twilio signature | Proceeds only to an authorized sender-bound operation. |  | BLOCKED |  | Secure sender-to-owner resolution not approved. |
| WA-002 | Invalid Twilio signature | Rejected before side effects. |  | NOT RUN |  |  |
| WA-003 | Missing Twilio signature | Rejected. |  | NOT RUN |  |  |
| WA-004 | Altered request parameters | Rejected. |  | NOT RUN |  |  |
| WA-005 | Incorrect external URL validation | Rejected. |  | NOT RUN |  |  |
| WA-006 | Replay outside the permitted retry case | No repeated side effects. |  | BLOCKED |  | Replay/idempotency window and key-retention policy not approved. |
| WA-007 | Sequential duplicate delivery | Single logical effect. |  | BLOCKED |  | Replay/idempotency behavior not approved. |
| WA-008 | Unlinked sender | No association. |  | BLOCKED |  | Bot-session owner binding and verified sender resolution not approved. |
| WA-009 | Unauthorized sender | No write or sensitive read. |  | BLOCKED |  | Bot-session owner binding and verified sender resolution not approved. |
| WA-010 | Media with declared or known total size above approved limit | Rejected. |  | BLOCKED |  | Approved media size limit not selected. |
| WA-011 | Media whose declared MIME type is outside approved allowlist | Rejected. |  | BLOCKED |  | Approved media MIME/content allowlist not selected. |
| WA-012 | Malicious redirect | Denied. |  | NOT RUN |  |  |
| WA-013 | Network destination restriction | Disallowed destination denied. |  | NOT RUN |  |  |
| WA-014 | Service-role secret exposure | No exposure. |  | NOT RUN |  |  |
| WA-015 | Forged sender/body with invalid or unauthenticated context | Rejected. |  | BLOCKED |  | Secure sender-to-owner resolution not approved. |
| WA-016 | Concurrent duplicate message identifiers | One logical operation. |  | BLOCKED |  | Replay/idempotency concurrency and key-retention policy not approved. |
| WA-017 | Valid signed retry within permitted provider retry window | Prior idempotent outcome or no second effect. |  | BLOCKED |  | Replay/idempotency window and retry behavior not approved. |
| WA-018 | Altered signature parameters/external URL | Rejected before merchant data access. |  | NOT RUN |  |  |
| WA-019 | Valid signature but forged/unlinked sender | Authorization denied; no merchant data access/change. |  | BLOCKED |  | Bot-session owner binding and verified sender resolution not approved. |
| WA-020 | Redirect/DNS answer changes during media retrieval | Revalidate every redirect and DNS answer; prohibit requests to restricted destinations. |  | NOT RUN |  |  |
| WA-021 | Media response streams beyond approved byte cap | Fetch aborts at/before cap; not accepted. |  | BLOCKED |  | Approved media byte cap not selected. |
| WA-022 | MIME declaration/content mismatch | Rejected; no accepted document/downstream action. |  | BLOCKED |  | Approved media MIME/content allowlist not selected. |
| WA-023 | Instrument invalid-signature database operations | Zero privileged data reads/writes. |  | NOT RUN |  |  |
| WA-024 | Inspect frontend/browser traffic for service key | No service-role credential present. |  | NOT RUN |  |  |
| PRI-001 | Consent version | Exact version stored. |  | BLOCKED |  | Consent wording/version and lawful-basis mapping not approved. |
| PRI-002 | Consent timestamp | Timestamp and timezone stored. |  | BLOCKED |  | Consent and lawful-basis record requirements not approved. |
| PRI-003 | Consent channel | Channel stored. |  | BLOCKED |  | Consent channel and policy not approved. |
| PRI-004 | Processing purpose | Purpose stored. |  | BLOCKED |  | Lawful-basis mapping and approved purposes not approved. |
| PRI-005 | Withdrawal | Withdrawal state durable. |  | BLOCKED |  | Consent/lawful-basis transition rules not approved. |
| PRI-006 | Access request | Workflow completes or is appropriately refused. |  | BLOCKED |  | Privacy request authority and behavior not approved. |
| PRI-007 | Correction request | Workflow is audited. |  | BLOCKED |  | Privacy request authority and behavior not approved. |
| PRI-008 | Retention expiry | Approved expiry behavior. |  | BLOCKED |  | Retention schedule not approved. |
| PRI-009 | Deletion | Data deleted or irreversibly de-identified. |  | BLOCKED |  | Retention/deletion schedule and legal exceptions not approved. |
| PRI-010 | Administrative access audit | Required audit fields recorded. |  | BLOCKED |  | Privacy/admin access purpose and approved scope not approved. |
| PARITY-001 | Fresh authorized production inventory and comparison | Evidence covers every parity category; unexplained variance blocks release. |  | BLOCKED |  | Explicit production inventory authorization and reviewers not approved. |

The register is prepopulated with every specified test ID. Actual evidence
should reference reproducible test logs or tickets and keep credentials and
PII out of repository artifacts. Do not mark a test PASS merely because this
specification exists.

## 16. Cross-reference

The approved architecture and unresolved decisions are in
[Identity Architecture Decision Record](./identity-architecture-decision-record.md).
The staging baseline and environment restrictions are in
[staging-baseline.md](./staging-baseline.md).
