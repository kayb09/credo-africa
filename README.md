# Stock and Purchasing V1, revision 3 (development only)
Nothing here is committed or applied to production. Run tests only on a throwaway PostgreSQL you control, never Supabase production.
Order: tests/run.sh <db> ; tests/20_concurrency.sh <db> ; tests/30_multi_item.sh <db>
Real output: tests/OUTPUT_rev3_pg16.15_2026-11-14.txt. Revision 2 reproduction of the multi item deadlock and the stale snapshot: tests/history/.
Tested on PostgreSQL 16.15 only (production is 17.6). Test helper functions are stubs, not Credo's definitions.
