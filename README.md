# Credo Stock and Purchasing Intelligence V1 — Development Draft

This package contains the initial design, SQL schema draft and verification plan for Credo's Stock and Purchasing Intelligence capability.

**This is not a production release. Do not apply the SQL to the live Supabase project.**

Before execution, verify the existing database schema and the definitions/return types of `public.current_business_ids()` and `public.is_admin()` in an isolated development database. The SQL is a starting draft and still requires real PostgreSQL execution, RLS tests, concurrency testing and review.

The current Credo application is a single-file React app in `index.html`. This package deliberately does not modify it.
