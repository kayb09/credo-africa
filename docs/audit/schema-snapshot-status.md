# Production schema snapshot recovery status

**No production schema snapshot was generated.** A safe, structural-only snapshot requires read-only access to the live PostgreSQL catalog. No database connection or Supabase access token was available, so creating a purported snapshot from the supplied table names would be incomplete and misleading.

The task-supplied table inventory is:

- `owners`
- `businesses`
- `activity_history`
- `credit_scores`
- `bot_sessions`
- `revenue_entries`
- `expense_entries`
- `supplier_records`
- `trust_signals`

The actual columns, types, defaults, primary keys, foreign keys, unique and other indexes, RLS-enabled status, policy expressions and role targets remain unverified. Do not treat this list as a schema snapshot.

When authorized read-only access is available, capture catalog/schema DDL only. Exclude all table rows, sequence values, comments or definitions that disclose personal information or secrets, and any credentials. Include the table/column definitions, primary and foreign keys, indexes, RLS status, and policy metadata. Record the PostgreSQL version and capture time, review the output for sensitive material, and keep it separate from the migration history.
