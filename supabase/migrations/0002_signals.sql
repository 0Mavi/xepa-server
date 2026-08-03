create type public.signal_type as enum ('cerveja', 'cafe', 'jogo', 'conversa', 'churrasco');
create type public.signal_status as enum ('ativo', 'encerrado', 'expirado');

create table public.signals (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.profiles (id) on delete cascade,
  tipo public.signal_type not null,
  local text not null,
  status public.signal_status not null default 'ativo',
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null
);

create unique index one_active_signal_per_author on public.signals (autor_id) where status = 'ativo';

create table public.signal_confirmations (
  signal_id uuid not null references public.signals (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (signal_id, user_id)
);

alter table public.signals enable row level security;
alter table public.signal_confirmations enable row level security;

create policy "select_signals_grupo" on public.signals
  for select using (auth.role() = 'authenticated');

create policy "insert_own_signal" on public.signals
  for insert with check (auth.uid() = autor_id);

create policy "update_own_or_moderate_signal" on public.signals
  for update using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

create policy "select_signal_confirmations_grupo" on public.signal_confirmations
  for select using (auth.role() = 'authenticated');

create policy "insert_own_signal_confirmation" on public.signal_confirmations
  for insert with check (auth.uid() = user_id);

create policy "delete_own_signal_confirmation" on public.signal_confirmations
  for delete using (auth.uid() = user_id);
