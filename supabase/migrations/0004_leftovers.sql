create type public.leftover_status as enum ('disponivel', 'reservado');

create table public.leftovers (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.profiles (id) on delete cascade,
  descricao text not null,
  foto_url text,
  status public.leftover_status not null default 'disponivel',
  reservado_por uuid references public.profiles (id) on delete set null,
  criado_em timestamptz not null default now()
);

alter table public.leftovers enable row level security;

create policy "select_leftovers_grupo" on public.leftovers
  for select using (auth.role() = 'authenticated');

create policy "insert_own_leftover" on public.leftovers
  for insert with check (auth.uid() = autor_id);

-- Update condicional: só altera quem ainda está 'disponivel' e só para 'reservado'
-- pelo próprio usuário autenticado. A cláusula USING é reavaliada por linha antes do
-- UPDATE ser aplicado, então duas reservas concorrentes nunca vencem as duas: a segunda
-- transação só enxerga o status já como 'reservado' e não casa mais o USING.
create policy "reserve_available_leftover" on public.leftovers
  for update using (
    auth.role() = 'authenticated' and status = 'disponivel'
  ) with check (
    status = 'reservado' and reservado_por = auth.uid()
  );

create policy "delete_own_or_moderate_leftover" on public.leftovers
  for delete using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );
