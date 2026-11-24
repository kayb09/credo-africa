
-- Enable required extensions
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Schedule keep-alive ping every 3 days at 03:00 UTC
select cron.schedule(
  'credo-africa-keep-alive',
  '0 3 */3 * *',
  $$
  select net.http_get(
    url := 'https://mfvhurvsgnzltkwvmoki.supabase.co/functions/v1/keep-alive'
  );
  $$
);
