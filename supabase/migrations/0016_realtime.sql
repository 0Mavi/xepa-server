-- Habilita Realtime (postgres_changes) nas tabelas que alimentam listas
-- vivas no app (Signals, S.O.S, Sobras, Refeições, Rachas, Pérolas,
-- opções de comida, perfis e convites). `alter publication ... add table`
-- não é idempotente (dá erro se a tabela já estiver na publicação), então
-- checamos pg_publication_tables antes de cada add pra poder rodar de novo
-- no SQL Editor sem quebrar.
do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'signals',
    'signal_confirmations',
    'sos_requests',
    'leftovers',
    'meals',
    'meal_confirmations',
    'splits',
    'split_participants',
    'food_options',
    'pearls',
    'pearl_reactions',
    'profiles',
    'invites'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = tabela
    ) then
      execute format('alter publication supabase_realtime add table public.%I', tabela);
    end if;
  end loop;
end $$;
