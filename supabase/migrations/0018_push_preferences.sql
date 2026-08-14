-- Preferência por módulo de notificação push (Xepa Signal / S.O.S), uma
-- linha por usuário (não por subscription/device — o mesmo morador pode
-- ter várias). Ausência de linha = tudo ativado, então quem já tinha push
-- ligado antes desta migration continua recebendo normalmente.
create table if not exists public.push_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  notificar_signals boolean not null default true,
  notificar_sos boolean not null default true,
  atualizado_em timestamptz not null default now()
);

alter table public.push_preferences enable row level security;

drop policy if exists "select_own_push_preferences" on public.push_preferences;
create policy "select_own_push_preferences" on public.push_preferences
  for select using (auth.uid() = user_id);

drop policy if exists "insert_own_push_preferences" on public.push_preferences;
create policy "insert_own_push_preferences" on public.push_preferences
  for insert with check (auth.uid() = user_id);

drop policy if exists "update_own_push_preferences" on public.push_preferences;
create policy "update_own_push_preferences" on public.push_preferences
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
