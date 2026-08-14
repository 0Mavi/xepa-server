create table public.food_options (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criado_por uuid not null references public.profiles (id) on delete cascade,
  criado_em timestamptz not null default now()
);

alter table public.food_options enable row level security;

create policy "select_food_options_grupo" on public.food_options
  for select using (auth.role() = 'authenticated');

create policy "insert_food_option" on public.food_options
  for insert with check (auth.uid() = criado_por);

create policy "delete_own_or_moderate_food_option" on public.food_options
  for delete using (
    auth.uid() = criado_por
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );
