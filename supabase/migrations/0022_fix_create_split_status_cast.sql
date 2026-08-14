-- Bug desde a versão original (0006): o "case when ... then 'pago' else
-- 'pendente' end" dentro do insert resolve os literais como text puro, não
-- como o enum split_participant_status da coluna — Postgres recusa com
-- "column status is of type split_participant_status but expression is of
-- type text" (42804). Corrige guardando o resultado numa variável tipada,
-- que força o cast certo.
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
  v_status public.split_participant_status;
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
    v_status := (case
      when v_user_id = auth.uid() then 'pago'
      else 'pendente'
    end)::public.split_participant_status;

    insert into public.split_participants (split_id, user_id, valor_devido, status)
    values (v_split.id, v_user_id, v_valor, v_status);
  end loop;

  return v_split;
end;
$$;
