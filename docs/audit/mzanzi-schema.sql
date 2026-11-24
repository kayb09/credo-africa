


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


CREATE SCHEMA IF NOT EXISTS "mzanzi";


ALTER SCHEMA "mzanzi" OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "mzanzi"."capital_gains" (
    "id" integer NOT NULL,
    "user_id" integer NOT NULL,
    "asset_name" character varying NOT NULL,
    "acquisition_date" "date" NOT NULL,
    "disposal_date" "date" NOT NULL,
    "proceeds" double precision NOT NULL,
    "base_cost" double precision NOT NULL,
    "gain_or_loss" double precision NOT NULL,
    "tax_year" character varying NOT NULL
);


ALTER TABLE "mzanzi"."capital_gains" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "mzanzi"."capital_gains_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "mzanzi"."capital_gains_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "mzanzi"."capital_gains_id_seq" OWNED BY "mzanzi"."capital_gains"."id";



CREATE TABLE IF NOT EXISTS "mzanzi"."tax_documents" (
    "id" integer NOT NULL,
    "user_id" integer NOT NULL,
    "doc_type" character varying NOT NULL,
    "tax_year" character varying NOT NULL,
    "filename" character varying NOT NULL,
    "uploaded_at" timestamp without time zone DEFAULT "now"(),
    "verified" boolean DEFAULT false
);


ALTER TABLE "mzanzi"."tax_documents" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "mzanzi"."tax_documents_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "mzanzi"."tax_documents_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "mzanzi"."tax_documents_id_seq" OWNED BY "mzanzi"."tax_documents"."id";



CREATE TABLE IF NOT EXISTS "mzanzi"."tax_returns" (
    "id" integer NOT NULL,
    "user_id" integer NOT NULL,
    "tax_year" character varying NOT NULL,
    "total_income" double precision DEFAULT 0.0,
    "total_deductions" double precision DEFAULT 0.0,
    "taxable_income" double precision DEFAULT 0.0,
    "tax_liability" double precision DEFAULT 0.0,
    "rebates_applied" double precision DEFAULT 0.0,
    "medical_credits" double precision DEFAULT 0.0,
    "ra_deduction" double precision DEFAULT 0.0,
    "cgt_included" double precision DEFAULT 0.0,
    "final_tax_due" double precision DEFAULT 0.0,
    "audit_risk_score" integer DEFAULT 0,
    "filed_at" timestamp without time zone,
    "sars_reference" character varying
);


ALTER TABLE "mzanzi"."tax_returns" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "mzanzi"."tax_returns_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "mzanzi"."tax_returns_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "mzanzi"."tax_returns_id_seq" OWNED BY "mzanzi"."tax_returns"."id";



CREATE TABLE IF NOT EXISTS "mzanzi"."transactions" (
    "id" integer NOT NULL,
    "user_id" integer NOT NULL,
    "date" "date" NOT NULL,
    "description" character varying NOT NULL,
    "amount" double precision NOT NULL,
    "category" character varying DEFAULT 'Uncategorised'::character varying,
    "is_deductible" boolean DEFAULT false,
    "tax_code" character varying,
    "confidence" double precision DEFAULT 0.0,
    "user_confirmed" boolean DEFAULT false,
    "vat_amount" double precision DEFAULT 0.0,
    "receipt_linked" boolean DEFAULT false
);


ALTER TABLE "mzanzi"."transactions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "mzanzi"."transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "mzanzi"."transactions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "mzanzi"."transactions_id_seq" OWNED BY "mzanzi"."transactions"."id";



CREATE TABLE IF NOT EXISTS "mzanzi"."users" (
    "id" integer NOT NULL,
    "email" character varying NOT NULL,
    "hashed_password" character varying NOT NULL,
    "full_name" character varying NOT NULL,
    "date_of_birth" "date" NOT NULL,
    "is_provisional_taxpayer" boolean DEFAULT false,
    "is_disabled" boolean DEFAULT false,
    "is_vat_registered" boolean DEFAULT false,
    "vat_number" character varying,
    "medical_aid_members" integer DEFAULT 1,
    "medical_aid_dependants" integer DEFAULT 0,
    "popia_consent" boolean DEFAULT false,
    "popia_consent_date" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "mzanzi"."users" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "mzanzi"."users_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "mzanzi"."users_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "mzanzi"."users_id_seq" OWNED BY "mzanzi"."users"."id";



ALTER TABLE ONLY "mzanzi"."capital_gains" ALTER COLUMN "id" SET DEFAULT "nextval"('"mzanzi"."capital_gains_id_seq"'::"regclass");



ALTER TABLE ONLY "mzanzi"."tax_documents" ALTER COLUMN "id" SET DEFAULT "nextval"('"mzanzi"."tax_documents_id_seq"'::"regclass");



ALTER TABLE ONLY "mzanzi"."tax_returns" ALTER COLUMN "id" SET DEFAULT "nextval"('"mzanzi"."tax_returns_id_seq"'::"regclass");



ALTER TABLE ONLY "mzanzi"."transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"mzanzi"."transactions_id_seq"'::"regclass");



ALTER TABLE ONLY "mzanzi"."users" ALTER COLUMN "id" SET DEFAULT "nextval"('"mzanzi"."users_id_seq"'::"regclass");



ALTER TABLE ONLY "mzanzi"."capital_gains"
    ADD CONSTRAINT "capital_gains_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "mzanzi"."tax_documents"
    ADD CONSTRAINT "tax_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "mzanzi"."tax_returns"
    ADD CONSTRAINT "tax_returns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "mzanzi"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "mzanzi"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "mzanzi"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_mzanzi_documents_user" ON "mzanzi"."tax_documents" USING "btree" ("user_id");



CREATE INDEX "idx_mzanzi_gains_user" ON "mzanzi"."capital_gains" USING "btree" ("user_id");



CREATE INDEX "idx_mzanzi_returns_user" ON "mzanzi"."tax_returns" USING "btree" ("user_id");



CREATE INDEX "idx_mzanzi_transactions_user" ON "mzanzi"."transactions" USING "btree" ("user_id");



ALTER TABLE ONLY "mzanzi"."capital_gains"
    ADD CONSTRAINT "capital_gains_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "mzanzi"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "mzanzi"."tax_documents"
    ADD CONSTRAINT "tax_documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "mzanzi"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "mzanzi"."tax_returns"
    ADD CONSTRAINT "tax_returns_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "mzanzi"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "mzanzi"."transactions"
    ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "mzanzi"."users"("id") ON DELETE CASCADE;
