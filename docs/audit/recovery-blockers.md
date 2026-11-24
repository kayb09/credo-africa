# Recovery status and scope

**Status: the requested read-only recovery is complete.** Supabase authentication was available in this Codespaces workspace, and project `mfvhurvsgnzltkwvmoki` was confirmed as active.

## Recovered and verified

- Exact deployed source for `whatsapp-bot` active version 5 and `keep-alive` active version 1. Both local candidates were byte-for-byte compared with fresh Supabase API downloads.
- Eight live migration identities and the corresponding SQL text stored in the authoritative migration ledger. The recovered statements were reviewed for data-changing statements and sensitive markers; none were found.
- A schema-only dump of the live `public` schema, with no table rows.
- TypeScript database types generated from the live `public` schema.

## Scope and safeguards

- Recovery used read-only Supabase operations. No production schema, policy, function, or merchant record was changed.
- No merchant rows, personal information, function secrets, API keys, or access tokens were retrieved into repository artifacts.
- Milestone 1's schema snapshot covers Credo `public`; Milestone 2 inspected only verified Credo components and live storage policy/bucket metadata. See [milestone-2-security-audit.md](./milestone-2-security-audit.md).
- The corrected Milestone 2 catalog sweep covers 58 verified Credo-owned non-system tables and three views. It excludes any resource that may belong to another application. The database session could not establish the external PostgREST exposed-schema configuration; confirm whether `net`, `realtime`, and `extensions` are API-exposed before considering the related draft-only ACL remediations.
- The historical SQL is retained for audit/provenance only. In particular, one stored migration drops and recreates tables with `CASCADE`; do not replay or deploy these artifacts as part of this recovery.
- The four protected PostgreSQL 17 checkpoint files remain unchanged.
