-- Bootstrap: o primeiro admin do condomínio não tem quem gere convite ou aprove seu cadastro.
-- Após o primeiro signup, promover manualmente via SQL Editor do Supabase:
-- update public.profiles set role = 'admin', status = 'aprovado' where id = '<uuid-do-usuario>';
create type public.user_role as enum ('morador', 'sindico', 'admin');
create type public.profile_status as enum ('pendente', 'aprovado');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null,
  apartamento text not null,
  avatar_url text,
  role public.user_role not null default 'morador',
  status public.profile_status not null default 'pendente',
  criado_em timestamptz not null default now()
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  criado_por uuid not null references public.profiles (id) on delete cascade,
  validade timestamptz not null,
  usado boolean not null default false,
  criado_em timestamptz not null default now()
);

create index invites_codigo_idx on public.invites (codigo) where usado = false;

alter table public.profiles enable row level security;
alter table public.invites enable row level security;

create policy "select_profiles_grupo" on public.profiles
  for select using (auth.role() = 'authenticated');

create policy "insert_own_profile" on public.profiles
  for insert with check (auth.uid() = id);

create policy "update_own_profile" on public.profiles
  for update using (auth.uid() = id);

create policy "moderate_profiles" on public.profiles
  for update using (
    exists (
      select 1 from public.profiles moderator
      where moderator.id = auth.uid() and moderator.role in ('sindico', 'admin')
    )
  );

create or replace function public.prevent_self_role_escalation()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if not exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    ) then
      raise exception 'apenas admin pode alterar o cargo de um morador';
    end if;
  end if;

  if new.status is distinct from old.status then
    if not exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    ) then
      raise exception 'apenas sindico ou admin pode aprovar um cadastro';
    end if;
  end if;

  return new;
end;
$$;

create trigger prevent_self_role_escalation
  before update on public.profiles
  for each row
  execute function public.prevent_self_role_escalation();

create or replace function public.is_approved()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and (status = 'aprovado' or role in ('sindico', 'admin'))
  );
$$;

create policy "select_invites_moderacao" on public.invites
  for select using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

create policy "insert_invites_moderacao" on public.invites
  for insert with check (
    auth.uid() = criado_por
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

create policy "update_invites_moderacao" on public.invites
  for update using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );

create or replace function public.validate_invite_code(input_codigo text)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  return exists (
    select 1 from public.invites
    where codigo = input_codigo
      and usado = false
      and validade > now()
  );
end;
$$;

create or replace function public.redeem_invite_code(input_codigo text)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.invites
  set usado = true
  where codigo = input_codigo
    and usado = false
    and validade > now();

  return found;
end;
$$;

grant execute on function public.validate_invite_code(text) to anon, authenticated;
grant execute on function public.redeem_invite_code(text) to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_codigo text := new.raw_user_meta_data ->> 'codigo_convite';
begin
  if v_codigo is null or not public.validate_invite_code(v_codigo) then
    raise exception 'código de convite inválido ou expirado';
  end if;

  insert into public.profiles (id, nome, apartamento)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nome', ''),
    coalesce(new.raw_user_meta_data ->> 'apartamento', '')
  );

  perform public.redeem_invite_code(v_codigo);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
