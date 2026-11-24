


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activity_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "activity_type" "text" NOT NULL,
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."activity_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bot_sessions" (
    "phone" "text" NOT NULL,
    "step" integer DEFAULT 1,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."bot_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."businesses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid",
    "business_name" "text",
    "business_type" "text",
    "location" "text",
    "monthly_revenue" numeric,
    "age_years" integer,
    "employee_count" integer,
    "has_bank_account" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."businesses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credit_scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "score" integer NOT NULL,
    "tier" "text",
    "scored_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."credit_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "amount" numeric NOT NULL,
    "category" "text",
    "notes" "text",
    "expense_date" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."expense_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."owners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "phone" "text" NOT NULL,
    "full_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."owners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."revenue_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "amount" numeric NOT NULL,
    "entry_date" "date" NOT NULL,
    "source" "text" DEFAULT 'whatsapp'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."revenue_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "receipt_image_path" "text",
    "supplier_name" "text",
    "purchase_date" "date",
    "amount" numeric,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."supplier_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."trust_signals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_id" "uuid",
    "signal_type" "text" NOT NULL,
    "confidence" numeric DEFAULT 0.5,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."trust_signals" OWNER TO "postgres";


ALTER TABLE ONLY "public"."activity_history"
    ADD CONSTRAINT "activity_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bot_sessions"
    ADD CONSTRAINT "bot_sessions_pkey" PRIMARY KEY ("phone");



ALTER TABLE ONLY "public"."businesses"
    ADD CONSTRAINT "businesses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credit_scores"
    ADD CONSTRAINT "credit_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expense_entries"
    ADD CONSTRAINT "expense_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."owners"
    ADD CONSTRAINT "owners_phone_key" UNIQUE ("phone");



ALTER TABLE ONLY "public"."owners"
    ADD CONSTRAINT "owners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."revenue_entries"
    ADD CONSTRAINT "revenue_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."supplier_records"
    ADD CONSTRAINT "supplier_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trust_signals"
    ADD CONSTRAINT "trust_signals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activity_history"
    ADD CONSTRAINT "activity_history_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."businesses"
    ADD CONSTRAINT "businesses_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."owners"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credit_scores"
    ADD CONSTRAINT "credit_scores_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_entries"
    ADD CONSTRAINT "expense_entries_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."revenue_entries"
    ADD CONSTRAINT "revenue_entries_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."supplier_records"
    ADD CONSTRAINT "supplier_records_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trust_signals"
    ADD CONSTRAINT "trust_signals_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "public"."businesses"("id") ON DELETE CASCADE;



CREATE POLICY "Allow anon insert activity" ON "public"."activity_history" FOR INSERT TO "anon" WITH CHECK (true);



CREATE POLICY "Allow anon select" ON "public"."activity_history" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."bot_sessions" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."businesses" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."credit_scores" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."expense_entries" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."owners" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."revenue_entries" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."supplier_records" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon select" ON "public"."trust_signals" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Service role full access on businesses" ON "public"."businesses" USING (true) WITH CHECK (true);



CREATE POLICY "Service role full access on owners" ON "public"."owners" USING (true) WITH CHECK (true);



ALTER TABLE "public"."activity_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bot_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."businesses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."credit_scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expense_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."owners" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."revenue_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trust_signals" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON TABLE "public"."activity_history" TO "anon";
GRANT ALL ON TABLE "public"."activity_history" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_history" TO "service_role";



GRANT ALL ON TABLE "public"."bot_sessions" TO "anon";
GRANT ALL ON TABLE "public"."bot_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."bot_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."businesses" TO "anon";
GRANT ALL ON TABLE "public"."businesses" TO "authenticated";
GRANT ALL ON TABLE "public"."businesses" TO "service_role";



GRANT ALL ON TABLE "public"."credit_scores" TO "anon";
GRANT ALL ON TABLE "public"."credit_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_scores" TO "service_role";



GRANT ALL ON TABLE "public"."expense_entries" TO "anon";
GRANT ALL ON TABLE "public"."expense_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."expense_entries" TO "service_role";



GRANT ALL ON TABLE "public"."owners" TO "anon";
GRANT ALL ON TABLE "public"."owners" TO "authenticated";
GRANT ALL ON TABLE "public"."owners" TO "service_role";



GRANT ALL ON TABLE "public"."revenue_entries" TO "anon";
GRANT ALL ON TABLE "public"."revenue_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."revenue_entries" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_records" TO "anon";
GRANT ALL ON TABLE "public"."supplier_records" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_records" TO "service_role";



GRANT ALL ON TABLE "public"."trust_signals" TO "anon";
GRANT ALL ON TABLE "public"."trust_signals" TO "authenticated";
GRANT ALL ON TABLE "public"."trust_signals" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
