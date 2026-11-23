# Recovery blockers and missing artifacts

## Access blocker

The Supabase CLI was run in read-only function-download mode against project `mfvhurvsgnzltkwvmoki`. It returned `AccessTokenRequiredError`: no access token was available, and the CLI did not authenticate. No project access token, database password, API key, function secret, merchant data, or personal information was requested or exported. No production operation was performed.

## Not recovered

- Original deployed source and configuration for `whatsapp-bot` (reported active version 5).
- Original deployed source and configuration for `keep-alive` (reported active version 1).
- The eight live migration version/name pairs and their verified original SQL files.
- A structural-only production schema snapshot.
- Current generated TypeScript database types.

## Needed to complete recovery

Provide an approved, read-only Supabase project access path with the minimum permissions required to read Edge Function source and migration metadata, inspect database catalogs/policies, and generate types. Access must not expose or export function environment secrets, API keys, merchant records, or personal information. If database access requires credentials, use an authorized secure mechanism without placing them in source, command output, or artifacts.

Until then, the names and versions of the migrations, exact function source/configuration, schema details, types, and effective policy definitions remain unresolved. The function directories and documentation in this branch are recovery status markers, not deployable Edge Functions.
