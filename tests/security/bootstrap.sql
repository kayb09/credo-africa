\set ON_ERROR_STOP on

CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE ROLE supabase_admin NOLOGIN;

CREATE SCHEMA auth;
CREATE TABLE auth.users (
  id uuid PRIMARY KEY
);
CREATE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $function$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$function$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;

CREATE SCHEMA storage;
CREATE TABLE storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean NOT NULL DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
CREATE TABLE storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text,
  name text,
  owner uuid,
  metadata jsonb
);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON storage.buckets, storage.objects TO anon, authenticated, service_role;
CREATE POLICY "Allow anon upload to verifications"
  ON storage.objects FOR INSERT TO anon
  WITH CHECK (bucket_id = 'verifications');
INSERT INTO storage.buckets (id, name, public) VALUES ('verifications', 'verifications', false);

-- Reproduce the unsafe owner-specific defaults observed in the live catalog.
SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
RESET ROLE;

CREATE SCHEMA net;
CREATE TABLE net.http_request_queue (
  id bigserial PRIMARY KEY,
  method text,
  url text,
  headers jsonb,
  body text
);
CREATE TABLE net._http_response (
  id bigint PRIMARY KEY,
  status_code integer,
  content text
);
GRANT USAGE ON SCHEMA net TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA net TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA net TO anon, authenticated, service_role;
CREATE FUNCTION net.http_post(url text)
RETURNS integer
LANGUAGE sql
AS $function$
  SELECT 200
$function$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO anon, authenticated, service_role;

CREATE SCHEMA extensions;
CREATE FUNCTION extensions.pg_stat_statements(showtext boolean)
RETURNS TABLE(query text, calls bigint)
LANGUAGE sql
STABLE
AS $function$
  SELECT 'synthetic-test-query'::text, 1::bigint
$function$;
CREATE FUNCTION extensions.pg_stat_statements_info()
RETURNS TABLE(dealloc bigint)
LANGUAGE sql
STABLE
AS $function$
  SELECT 0::bigint
$function$;
CREATE VIEW extensions.pg_stat_statements AS
  SELECT * FROM extensions.pg_stat_statements(true);
CREATE VIEW extensions.pg_stat_statements_info AS
  SELECT * FROM extensions.pg_stat_statements_info();
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;
GRANT SELECT ON TABLE
  extensions.pg_stat_statements,
  extensions.pg_stat_statements_info
TO anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO anon, authenticated, service_role;

CREATE SCHEMA realtime;
CREATE TABLE realtime.messages (id integer PRIMARY KEY);
ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;
CREATE TABLE realtime.subscription (id bigserial PRIMARY KEY);
INSERT INTO realtime.messages VALUES (1);
INSERT INTO realtime.subscription VALUES (1);
GRANT USAGE ON SCHEMA realtime TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON realtime.messages TO anon, authenticated, service_role;
GRANT SELECT ON realtime.subscription TO anon, authenticated, service_role;
GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO anon, authenticated, service_role;
