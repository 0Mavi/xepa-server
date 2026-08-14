create type public.sos_status as enum ('ativo', 'resolvido');

create table public.sos_requests (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.profiles (id) on delete cascade,
  descricao text not null,
  status public.sos_status not null default 'ativo',
  resolvido_por uuid references public.profiles (id) on delete set null,
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz
);

alter table public.sos_requests enable row level security;

create policy "select_sos_requests_grupo" on public.sos_requests
  for select using (auth.role() = 'authenticated');

create policy "insert_own_sos_request" on public.sos_requests
  for insert with check (auth.uid() = autor_id);

-- Mesmo padrão de update condicional do leftovers: só resolve quem ainda está 'ativo'.
create policy "resolve_active_sos_request" on public.sos_requests
  for update using (
    auth.role() = 'authenticated' and status = 'ativo'
  ) with check (
    status = 'resolvido' and resolvido_por = auth.uid()
  );

create policy "delete_own_or_moderate_sos_request" on public.sos_requests
  for delete using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

-- resolvido_em é sempre carimbado pelo servidor, nunca confiado ao valor enviado pelo client.
create or replace function public.set_sos_resolved_at()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'resolvido' and old.status = 'ativo' then
    new.resolvido_em := now();
  end if;
  return new;
end;
$$;

create trigger set_sos_resolved_at
  before update on public.sos_requests
  for each row
  execute function public.set_sos_resolved_at();
