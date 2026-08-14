-- 1) A divisão anterior arredondava cada parcela individualmente
-- (round(total / n, 2)), então a soma das parcelas quase nunca batia com
-- o valor_total (ex.: R$100 / 3 = R$33,33 cada, soma R$99,99 — sobra 1
-- centavo perdido). Agora divide em centavos inteiros e distribui o resto
-- da divisão pros primeiros participantes, então a soma sempre fecha.
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
  v_total_centavos integer;
  v_n integer;
  v_base_centavos integer;
  v_resto integer;
  v_valor numeric(10, 2);
  v_i integer;
  v_user_id uuid;
begin
  v_todos_ids := array_append(p_participante_ids, auth.uid());
  v_n := array_length(v_todos_ids, 1);
  v_total_centavos := round(p_valor_total * 100);
  v_base_centavos := v_total_centavos / v_n;
  v_resto := v_total_centavos - (v_base_centavos * v_n);

  insert into public.splits (autor_id, descricao, valor_total, chave_pix)
  values (auth.uid(), p_descricao, p_valor_total, p_chave_pix)
  returning * into v_split;

  for v_i in 1..v_n loop
    v_user_id := v_todos_ids[v_i];
    v_valor := (v_base_centavos + case when v_i <= v_resto then 1 else 0 end) / 100.0;

    insert into public.split_participants (split_id, user_id, valor_devido, status)
    values (
      v_split.id,
      v_user_id,
      v_valor,
      case when v_user_id = auth.uid() then 'pago' else 'pendente' end
    );
  end loop;

  return v_split;
end;
$$;

-- 2) Permite desfazer um "Já paguei" por engano — antes o with check
-- travava status em 'pago' pra sempre, sem volta.
drop policy if exists "update_own_split_participant" on public.split_participants;
create policy "update_own_split_participant" on public.split_participants
  for update using (
    auth.uid() = user_id
  ) with check (
    auth.uid() = user_id
  );

-- 3) Permite cancelar um racha inteiro (autor ou síndico/admin). Os
-- participantes somem junto via "on delete cascade" da FK.
drop policy if exists "delete_own_or_moderate_split" on public.splits;
create policy "delete_own_or_moderate_split" on public.splits
  for delete using (
    auth.uid() = autor_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
  );
