# Credo security remediation plan

This plan reflects captured source/schema evidence and previously reported
catalog observations. It authorizes no production changes. All SQL remains
draft-only.

## P0 — Public application database access

1. The recovered public schema snapshot records broad `anon` and
   `authenticated` grants, unconditional anonymous reads, an anonymous
   `activity_history` insert policy, and unconditional `owners`/`businesses`
   policies. Treat these as verified in the captured snapshot; current live
   state and API behavior were not rechecked.
2. The hardening draft proposes least-privilege access using explicit
   owner-to-Auth linkage. Do not apply it before product and database-owner
   review, staging validation, and approved identity mapping.
3. The nine currently identified public application tables are the Credo
   application inventory. The 58 previously reported catalog relations are
   not 58 verified Credo-owned tables.

## P0 — Verification storage

1. The earlier catalog report described anonymous object insertion into the
   private `verifications` bucket and no configured size/MIME limits. This is
   a previously reported finding, not independently rechecked here.
2. Keep the existing draft-only restrictions unapplied until the Storage
   policy and actual API behavior are confirmed through authorized read-only
   evidence and a separately approved staging plan.

## P1 — WhatsApp webhook

1. The recovered source uses a service-role key, lacks visible Twilio
   signature validation, and fetches caller-provided media URLs with Twilio
   credentials without visible origin/redirect/size checks.
2. The reported `verify_jwt=false` setting is prior deployment metadata and
   was not rechecked. The validation helper is draft-only and is not wired
   into the deployed function by this task.
3. Integrate and test a suitable signature/media validation flow only under
   an approved implementation and deployment milestone.

## P1 — Frontend administrator and consent state

1. The tracked frontend uses a hardcoded PIN and `localStorage` state. Treat
   these as presentation controls only, not server authentication or proof
   of consent.
2. Verify backend authorization and define an authoritative consent record
   before implementation. No frontend behavior was changed.

## P2 — Migration and object provenance

1. The prior migration recovery recorded eight ledger entries. Seven files
   remain active Credo migration artifacts. The eighth, version `20260627101525`,
   is excluded from the active migration directory and documented as
   historical provenance only.
2. The reported entry and catalog presence do not establish product
   ownership. Reconciliation against the live authorized Credo ledger remains
   pending separate approval; do not replay the historical SQL.
3. Database objects outside the nine currently identified public application
   tables are classified by schema convention or marked unresolved, not
   automatically treated as Credo application functionality.

## Required verification before future remediation

- Reconfirm current public grants, RLS/policies, default ACLs, and effective
  role privileges on the authorized Credo project.
- Confirm PostgREST/GraphQL schema exposure and test actual endpoints in an
  approved non-production environment.
- Confirm Storage policy, bucket restrictions, and API behavior.
- Confirm deployed webhook configuration and server-side administrator
  authorization.
- Keep all changes and migrations reviewed, staged, and explicitly approved.
