create type public.split_participant_status as enum ('pendente', 'pago');

create table public.splits (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.profiles (id) on delete cascade,
  descricao text not null,
  valor_total numeric(10, 2) not null check (valor_total > 0),
  chave_pix text not null,
  criado_em timestamptz not null default now()
);

create table public.split_participants (
  split_id uuid not null references public.splits (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  valor_devido numeric(10, 2) not null,
  status public.split_participant_status not null default 'pendente',
  primary key (split_id, user_id)
);

alter table public.splits enable row level security;
alter table public.split_participants enable row level security;

create policy "select_splits_grupo" on public.splits
  for select using (auth.role() = 'authenticated');

create policy "insert_own_split" on public.splits
  for insert with check (auth.uid() = autor_id);

create policy "select_split_participants_grupo" on public.split_participants
  for select using (auth.role() = 'authenticated');

create policy "insert_split_participants_do_proprio_racha" on public.split_participants
  for insert with check (
    exists (
      select 1 from public.splits
      where id = split_id and autor_id = auth.uid()
    )
  );

create policy "update_own_split_participant" on public.split_participants
  for update using (
    auth.uid() = user_id
  ) with check (
    auth.uid() = user_id and status = 'pago'
  );

-- Cria o racha e todos os participantes (autor incluso, já como 'pago') em uma única
-- transação — o client não consegue inserir em duas tabelas atomicamente sozinho.
-- security invoker: as policies acima continuam valendo com o auth.uid() de quem chama.
create or replace function public.create_split(
  p_descricao text,
  p_valor_total numeric,
  p_chave_pix text,
  p_participante_ids uuid[]
)
returns public.splits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_split public.splits;
  v_todos_ids uuid[];
  v_valor_por_pessoa numeric(10, 2);
  v_user_id uuid;
begin
  v_todos_ids := array_append(p_participante_ids, auth.uid());
  v_valor_por_pessoa := round(p_valor_total / array_length(v_todos_ids, 1), 2);

  insert into public.splits (autor_id, descricao, valor_total, chave_pix)
  values (auth.uid(), p_descricao, p_valor_total, p_chave_pix)
  returning * into v_split;

  foreach v_user_id in array v_todos_ids loop
    insert into public.split_participants (split_id, user_id, valor_devido, status)
    values (
      v_split.id,
      v_user_id,
      v_valor_por_pessoa,
      case when v_user_id = auth.uid() then 'pago' else 'pendente' end
    );
  end loop;

  return v_split;
end;
$$;

grant execute on function public.create_split(text, numeric, text, uuid[]) to authenticated;
