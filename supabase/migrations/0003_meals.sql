create type public.meal_period as enum ('cafe', 'almoco', 'janta', 'happy_hour');

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.profiles (id) on delete cascade,
  cardapio text not null,
  periodo public.meal_period not null,
  horario timestamptz not null,
  local text not null,
  criado_em timestamptz not null default now()
);

create table public.meal_confirmations (
  meal_id uuid not null references public.meals (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (meal_id, user_id)
);

alter table public.meals enable row level security;
alter table public.meal_confirmations enable row level security;

create policy "select_meals_grupo" on public.meals
  for select using (auth.role() = 'authenticated');

create policy "insert_own_meal" on public.meals
  for insert with check (auth.uid() = autor_id);

create policy "delete_own_or_moderate_meal" on public.meals
  for delete using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

create policy "select_meal_confirmations_grupo" on public.meal_confirmations
  for select using (auth.role() = 'authenticated');

create policy "insert_own_meal_confirmation" on public.meal_confirmations
  for insert with check (auth.uid() = user_id);

create policy "delete_own_meal_confirmation" on public.meal_confirmations
  for delete using (auth.uid() = user_id);
