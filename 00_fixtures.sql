-- TEST FIXTURES ONLY. Synthetic. The two helper functions are STUBS with the signatures the migration
-- preflight demands (setof uuid / boolean). They are NOT the production definitions (those do not exist in production).
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end $$;
create table public.businesses (id uuid primary key default gen_random_uuid(), name text);
create table public.test_members (user_id uuid, business_id uuid);
create function public.current_business_ids() returns setof uuid language sql stable
  as $$ select business_id from public.test_members where user_id = nullif(current_setting('test.uid', true), '')::uuid $$;
create function public.is_admin() returns boolean language sql stable
  as $$ select coalesce(nullif(current_setting('test.admin', true), '')::boolean, false) $$;
grant usage on schema public to anon, authenticated;
grant select on public.test_members, public.businesses to authenticated;
grant execute on function public.current_business_ids(), public.is_admin() to authenticated;
create table public.test_results (n serial, label text, ok boolean, detail text);
create function public.t_ok(p_label text, p_cond boolean, p_detail text default '') returns void language sql
  as $$ insert into public.test_results(label, ok, detail) values (p_label, coalesce(p_cond,false), p_detail) $$;
create function public.t_err(p_label text, p_sql text, p_like text default '') returns void language plpgsql as $$
begin
  execute p_sql;
  execute 'set constraints all immediate';
  insert into public.test_results(label, ok, detail) values (p_label, false, 'no error raised');
exception when others then
  insert into public.test_results(label, ok, detail) values (p_label, (p_like = '' or sqlerrm ilike '%'||p_like||'%'), sqlerrm);
end $$;
grant all on public.test_results to authenticated, anon;
grant usage on sequence public.test_results_n_seq to authenticated, anon;
grant execute on function public.t_ok(text,boolean,text), public.t_err(text,text,text) to authenticated, anon;
insert into public.businesses(id,name) values
 ('aaaaaaaa-0000-0000-0000-00000000000a','Synthetic A'),('bbbbbbbb-0000-0000-0000-00000000000b','Synthetic B');
insert into public.test_members values
 ('11111111-1111-1111-1111-111111111111','aaaaaaaa-0000-0000-0000-00000000000a'),
 ('22222222-2222-2222-2222-222222222222','bbbbbbbb-0000-0000-0000-00000000000b');
