-- Pra sumir da lista 24h depois de usado, precisamos saber QUANDO foi usado
-- (antes só existia o boolean). Convite expirado já tem essa data — é a
-- própria "validade".
alter table public.invites add column if not exists usado_em timestamptz;

create or replace function public.redeem_invite_code(input_codigo text)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.invites
  set usado = true, usado_em = now()
  where codigo = input_codigo
    and usado = false
    and validade > now();

  return found;
end;
$$;
