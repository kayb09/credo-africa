create policy "Allow anon upload to verifications"
on storage.objects for insert to anon
with check (bucket_id = 'verifications');

create policy "Allow anon insert activity"
on public.activity_history for insert to anon
with check (true);