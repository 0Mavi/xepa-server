create table if not exists public.pearl_comments (
  id uuid primary key default gen_random_uuid(),
  pearl_id uuid not null references public.pearls (id) on delete cascade,
  autor_id uuid not null references public.profiles (id) on delete cascade,
  texto text not null,
  criado_em timestamptz not null default now()
);

create index if not exists pearl_comments_pearl_id_idx
  on public.pearl_comments (pearl_id);

alter table public.pearl_comments enable row level security;

drop policy if exists "select_pearl_comments_grupo" on public.pearl_comments;
create policy "select_pearl_comments_grupo" on public.pearl_comments
  for select using (public.is_approved());

drop policy if exists "insert_own_pearl_comment" on public.pearl_comments;
create policy "insert_own_pearl_comment" on public.pearl_comments
  for insert with check (auth.uid() = autor_id and public.is_approved());

drop policy if exists "delete_own_or_moderate_pearl_comment" on public.pearl_comments;
create policy "delete_own_or_moderate_pearl_comment" on public.pearl_comments
  for delete using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pearl_comments'
  ) then
    alter publication supabase_realtime add table public.pearl_comments;
  end if;
end $$;
