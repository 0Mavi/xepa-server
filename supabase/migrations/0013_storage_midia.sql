-- Bucket público (a mídia postada — comida, pérolas — não é sensível o
-- suficiente pra justificar URL assinada; o upload em si continua exigindo
-- morador aprovado). Cada arquivo fica em "{user_id}/{uuid}.ext".
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'midia',
  'midia',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "midia_select_grupo" on storage.objects
  for select using (bucket_id = 'midia' and auth.role() = 'authenticated');

create policy "midia_insert_propria_pasta" on storage.objects
  for insert with check (
    bucket_id = 'midia'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_approved()
  );

create policy "midia_delete_propria_pasta" on storage.objects
  for delete using (
    bucket_id = 'midia'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
