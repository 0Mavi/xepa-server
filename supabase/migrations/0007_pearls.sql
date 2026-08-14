create type public.pearl_type as enum ('foto', 'quote');

create table public.pearls (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.profiles (id) on delete cascade,
  tipo public.pearl_type not null,
  conteudo text not null default '',
  midia_url text,
  criado_em timestamptz not null default now()
);

create table public.pearl_reactions (
  pearl_id uuid not null references public.pearls (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null,
  criado_em timestamptz not null default now(),
  primary key (pearl_id, user_id, emoji)
);

alter table public.pearls enable row level security;
alter table public.pearl_reactions enable row level security;

create policy "select_pearls_grupo" on public.pearls
  for select using (auth.role() = 'authenticated');

create policy "insert_own_pearl" on public.pearls
  for insert with check (auth.uid() = autor_id);

create policy "delete_own_or_moderate_pearl" on public.pearls
  for delete using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

create policy "select_pearl_reactions_grupo" on public.pearl_reactions
  for select using (auth.role() = 'authenticated');

create policy "insert_own_pearl_reaction" on public.pearl_reactions
  for insert with check (auth.uid() = user_id);

create policy "delete_own_pearl_reaction" on public.pearl_reactions
  for delete using (auth.uid() = user_id);
