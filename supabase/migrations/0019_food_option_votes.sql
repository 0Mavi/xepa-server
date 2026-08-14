-- Votação em "Onde vamos comer?" — cada morador vota em UMA opção (a
-- primary key é só user_id, não o par option_id+user_id), então votar de
-- novo troca o voto em vez de acumular. O sorteio continua existindo à
-- parte, sem depender da votação.
create table if not exists public.food_option_votes (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  option_id uuid not null references public.food_options (id) on delete cascade,
  criado_em timestamptz not null default now()
);

alter table public.food_option_votes enable row level security;

drop policy if exists "select_food_option_votes_grupo" on public.food_option_votes;
create policy "select_food_option_votes_grupo" on public.food_option_votes
  for select using (public.is_approved());

drop policy if exists "insert_own_food_option_vote" on public.food_option_votes;
create policy "insert_own_food_option_vote" on public.food_option_votes
  for insert with check (auth.uid() = user_id and public.is_approved());

drop policy if exists "update_own_food_option_vote" on public.food_option_votes;
create policy "update_own_food_option_vote" on public.food_option_votes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "delete_own_food_option_vote" on public.food_option_votes;
create policy "delete_own_food_option_vote" on public.food_option_votes
  for delete using (auth.uid() = user_id);

-- A policy de insert de opção nunca exigiu is_approved() (só conferia o
-- autor) — corrige aprovado o mesmo padrão usado em todo o resto do app.
drop policy if exists "insert_food_option" on public.food_options;
create policy "insert_food_option" on public.food_options
  for insert with check (auth.uid() = criado_por and public.is_approved());

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'food_option_votes'
  ) then
    alter publication supabase_realtime add table public.food_option_votes;
  end if;
end $$;
