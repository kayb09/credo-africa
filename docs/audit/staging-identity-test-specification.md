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

The verified staging baseline is recorded in
[staging-baseline.md](./staging-baseline.md) and the bootstrap SQL is
`../../supabase/staging/20261124_public_schema_baseline.sql`.

The baseline is:

- closed by default;
- composed of nine public application tables;
- protected by RLS enabled on all nine tables;
- without application policies;
- without `anon` or `authenticated` table privileges;
- configured for trusted `service_role` access;
- without application records.

This baseline must not be changed during the documentation task. Future tests
require a separately approved staging implementation.

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
| RLS-013 | Trusted backend service operation | Allowed only through an approved server path with audited context. |
| RLS-014 | Direct service-role browser request | Denied or impossible; key must not be exposed. |

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
| ONB-002 | Duplicate submission | Only one logical owner, business and consent state is created. |
| ONB-003 | Retry after network failure | No duplicate records or inconsistent phase state remain. |
| ONB-004 | Failure after Auth creation | Recovery state identifies the Auth user and permits safe completion or cleanup. |
| ONB-005 | Failure after owner creation | Recovery state identifies the owner and prevents duplicate owner creation. |
| ONB-006 | Failure during business creation | No orphaned active business; failure is recoverable or reverses safely. |
| ONB-007 | Failure during document upload | Registration is incomplete and recoverable, with no false success. |
| ONB-008 | Recovery from incomplete registration | Approved retry resumes or rolls back the correct phase. |
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
| STO-007 | Expired signed URL | Denied. |
| STO-008 | Invalid MIME type | Rejected before object creation or immediately quarantined. |
| STO-009 | Oversized file | Rejected according to the approved size limit. |
| STO-010 | Invalid merchant-scoped object path | Denied. |
| STO-011 | Document access audit | Upload, access and restricted access attempts are recorded. |

Test the Storage bucket and object policy through the approved staging API.
Do not use real documents or PII.

## 9. WhatsApp tests

| Test ID | Scenario | Expected result |
|---|---|---|
| WA-001 | Valid Twilio signature | Webhook proceeds only to authorized operations. |
| WA-002 | Invalid signature | Request is rejected before merchant or database operations. |
| WA-003 | Missing signature | Request is rejected. |
| WA-004 | Altered request parameters | Signature failure is deterministic. |
| WA-005 | Incorrect external URL validation | Request is rejected because signed URL context differs. |
| WA-006 | Replayed message | Duplicate side effects are prevented. |
| WA-007 | Duplicate message | Only one logical operation or response occurs. |
| WA-008 | Unlinked sender | Sender is not associated with a merchant. |
| WA-009 | Unauthorized sender | No merchant write or sensitive read occurs. |
| WA-010 | Oversized media | Media is rejected within size controls. |
| WA-011 | Invalid media type | Media is rejected. |
| WA-012 | Malicious redirect | Redirect is denied and not followed. |
| WA-013 | Network destination restriction | Internal or disallowed destination is denied. |
| WA-014 | Service-role secret exposure | Secret never appears in response, logs or code. |
| WA-015 | Forged sender or request body | Privileged operation is rejected. |

Signature tests must use synthetic request values and validate the exact
externally visible staging URL.

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

## 11. Release gates

No production rollout may occur until all applicable gates are passed and
explicitly approved.

| Gate | Mandatory evidence | Status |
|---|---|---|
| GATE 1: Identity design approved | Architecture decision record approved by product and database owners. | NOT RUN |
| GATE 2: Auth configuration and provider costs verified | Provider coverage, cost, abuse controls and phone support recorded. | NOT RUN |
| GATE 3: Synthetic merchant authentication tests pass | AUTH-001 through AUTH-012 pass. | NOT RUN |
| GATE 4: Existing owner linking passes without changing IDs | LINK-001 through LINK-008 pass and ID preservation is evidenced. | NOT RUN |
| GATE 5: Merchant isolation and administrator authorization pass | RLS and ADM test groups pass. | NOT RUN |
| GATE 6: Storage tests pass | STO-001 through STO-011 pass. | NOT RUN |
| GATE 7: WhatsApp signature and replay tests pass | WA-001 through WA-015 pass. | NOT RUN |
| GATE 8: Consent and privacy workflows pass | PRI-001 through PRI-010 pass. | NOT RUN |
| GATE 9: Full regression tests pass | Relevant existing and new staging tests pass. | NOT RUN |
| GATE 10: Backup, rollback and production change plan approved | Recovery, rollback, support and explicit approval evidence exists. | NOT RUN |

A gate may be marked PASS only when every applicable test in that gate has
passing evidence. `NOT RUN` and `BLOCKED` are not passing states.

## 12. Test reporting template

All tests must initially be recorded as `NOT RUN`. Test evidence must be
reproducible and must not contain secrets or real PII.

| Test ID | Scenario | Expected result | Actual result | Status | Evidence reference | Defect or follow-up |
|---|---|---|---|---|---|---|
| AUTH-001 | Successful OTP verification | Exactly one synthetic Auth identity is verified and receives the intended limited session. |  | NOT RUN |  |  |
| AUTH-002 | Incorrect OTP | Verification fails; no session or privileged merchant state is granted. |  | NOT RUN |  |  |
| AUTH-003 | Expired OTP | Verification fails and the attempt is rejected. |  | NOT RUN |  |  |
| AUTH-004 | Reused OTP | Reuse is denied after the first accepted verification. |  | NOT RUN |  |  |
| AUTH-005 | OTP resend limits | Excess resend attempts are throttled and audited. |  | NOT RUN |  |  |
| AUTH-006 | OTP rate limiting | Excess attempts are blocked. |  | NOT RUN |  |  |
| AUTH-007 | Session expiration | Expired session cannot read or write protected data. |  | NOT RUN |  |  |
| AUTH-008 | Logout | Session cannot continue access after logout. |  | NOT RUN |  |  |
| AUTH-009 | Account recovery | Approved challenge is required. |  | NOT RUN |  |  |
| AUTH-010 | Phone number change | Relationships remain controlled and intact. |  | NOT RUN |  |  |
| AUTH-011 | Duplicate phone number | Ambiguity is prevented or escalated. |  | NOT RUN |  |  |
| AUTH-012 | Failed verification | No owner, business or role is granted. |  | NOT RUN |  |  |
| LINK-001 | Correct verified owner linking | Existing owner ID is preserved. |  | NOT RUN |  |  |
| LINK-002 | Incorrect phone verification | Candidate owner is not linked. |  | NOT RUN |  |  |
| LINK-003 | Duplicate owner phone numbers | Ambiguity is rejected or escalated. |  | NOT RUN |  |  |
| LINK-004 | One Auth user claims multiple owners | Unauthorized claim is denied. |  | NOT RUN |  |  |
| LINK-005 | Multiple Auth users claim one owner | Only approved relationship is created. |  | NOT RUN |  |  |
| LINK-006 | Changed phone number | No silent reassignment occurs. |  | NOT RUN |  |  |
| LINK-007 | Inaccessible phone number | Approved recovery is required. |  | NOT RUN |  |  |
| LINK-008 | Manual recovery approval | Approver and evidence are audited. |  | NOT RUN |  |  |
| ADM-001 | Valid administrator access | Approved scope only. |  | NOT RUN |  |  |
| ADM-002 | Merchant administrator attempt | Denied. |  | NOT RUN |  |  |
| ADM-003 | Anonymous administrator attempt | Denied. |  | NOT RUN |  |  |
| ADM-004 | User edits own role | Role remains unchanged. |  | NOT RUN |  |  |
| ADM-005 | Stale administrator JWT | Removed role remains denied. |  | NOT RUN |  |  |
| ADM-006 | Revoked session | Access stops. |  | NOT RUN |  |  |
| ADM-007 | Unauthorized document access | Denied. |  | NOT RUN |  |  |
| ADM-008 | Audit log recording | Required fields are recorded. |  | NOT RUN |  |  |
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
| RLS-011 | Approved administrator access | Allowed only by approved role. |  | NOT RUN |  |  |
| RLS-012 | Merchant bypasses administrator controls | Denied. |  | NOT RUN |  |  |
| RLS-013 | Trusted service operation | Allowed only through trusted path. |  | NOT RUN |  |  |
| RLS-014 | Direct browser service-role request | Impossible or denied. |  | NOT RUN |  |  |
| ONB-001 | Successful registration | Consistent synthetic state. |  | NOT RUN |  |  |
| ONB-002 | Duplicate submission | No duplicates. |  | NOT RUN |  |  |
| ONB-003 | Retry after network failure | Consistent state. |  | NOT RUN |  |  |
| ONB-004 | Failure after Auth creation | Durable recovery state. |  | NOT RUN |  |  |
| ONB-005 | Failure after owner creation | Durable recovery state. |  | NOT RUN |  |  |
| ONB-006 | Failure during business creation | No unauthorized orphan. |  | NOT RUN |  |  |
| ONB-007 | Failure during document upload | No false success. |  | NOT RUN |  |  |
| ONB-008 | Recovery from incomplete registration | Safe completion or rollback. |  | NOT RUN |  |  |
| ONB-009 | Durable consent | Required consent fields stored. |  | NOT RUN |  |  |
| ONB-010 | Anonymous onboarding write | Denied. |  | NOT RUN |  |  |
| STO-001 | Anonymous upload | Denied. |  | NOT RUN |  |  |
| STO-002 | Anonymous download | Denied. |  | NOT RUN |  |  |
| STO-003 | Cross-merchant document access | Denied. |  | NOT RUN |  |  |
| STO-004 | Own document access | Allowed only for authorized merchant. |  | NOT RUN |  |  |
| STO-005 | Unauthorized administrator document access | Denied. |  | NOT RUN |  |  |
| STO-006 | Approved administrator document access | Allowed and audited. |  | NOT RUN |  |  |
| STO-007 | Expired signed URL | Denied. |  | NOT RUN |  |  |
| STO-008 | Invalid MIME type | Rejected or quarantined. |  | NOT RUN |  |  |
| STO-009 | Oversized file | Rejected. |  | NOT RUN |  |  |
| STO-010 | Invalid object path | Denied. |  | NOT RUN |  |  |
| STO-011 | Document access audit | Recorded. |  | NOT RUN |  |  |
| WA-001 | Valid Twilio signature | Proceeds only to authorized operation. |  | NOT RUN |  |  |
| WA-002 | Invalid Twilio signature | Rejected before side effects. |  | NOT RUN |  |  |
| WA-003 | Missing Twilio signature | Rejected. |  | NOT RUN |  |  |
| WA-004 | Altered request parameters | Rejected. |  | NOT RUN |  |  |
| WA-005 | Incorrect external URL validation | Rejected. |  | NOT RUN |  |  |
| WA-006 | Replayed message | No repeated side effects. |  | NOT RUN |  |  |
| WA-007 | Duplicate message | Single logical effect. |  | NOT RUN |  |  |
| WA-008 | Unlinked sender | No association. |  | NOT RUN |  |  |
| WA-009 | Unauthorized sender | No write or sensitive read. |  | NOT RUN |  |  |
| WA-010 | Oversized media | Rejected. |  | NOT RUN |  |  |
| WA-011 | Invalid media type | Rejected. |  | NOT RUN |  |  |
| WA-012 | Malicious redirect | Denied. |  | NOT RUN |  |  |
| WA-013 | Network destination restriction | Disallowed destination denied. |  | NOT RUN |  |  |
| WA-014 | Service-role secret exposure | No exposure. |  | NOT RUN |  |  |
| WA-015 | Forged sender | Rejected. |  | NOT RUN |  |  |
| PRI-001 | Consent version | Exact version stored. |  | NOT RUN |  |  |
| PRI-002 | Consent timestamp | Timestamp and timezone stored. |  | NOT RUN |  |  |
| PRI-003 | Consent channel | Channel stored. |  | NOT RUN |  |  |
| PRI-004 | Processing purpose | Purpose stored. |  | NOT RUN |  |  |
| PRI-005 | Withdrawal | Withdrawal state durable. |  | NOT RUN |  |  |
| PRI-006 | Access request | Workflow completes or is appropriately refused. |  | NOT RUN |  |  |
| PRI-007 | Correction request | Workflow is audited. |  | NOT RUN |  |  |
| PRI-008 | Retention expiry | Approved expiry behavior. |  | NOT RUN |  |  |
| PRI-009 | Deletion | Data deleted or irreversibly de-identified. |  | NOT RUN |  |  |
| PRI-010 | Administrative access audit | Required audit fields recorded. |  | NOT RUN |  |  |

The long reporting table is illustrative. Actual evidence should reference
test logs or tickets and keep credentials and PII out of repository artifacts.
The table itself must not be used to claim a test passed merely because this
specification exists.

## 13. Cross-reference

The approved architecture and unresolved decisions are in
[Identity Architecture Decision Record](./identity-architecture-decision-record.md).
The staging baseline and environment restrictions are in
[staging-baseline.md](./staging-baseline.md).
