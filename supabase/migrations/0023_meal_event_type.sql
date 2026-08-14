-- Separa "Refeição" de "Evento" (ex: ida ao shopping) como duas variações
-- do mesmo mural, em vez de forçar todo evento a ter um período de
-- refeição (café/almoço/janta/happy hour), que não faz sentido pra coisas
-- como um passeio. `periodo` vira opcional — só se aplica quando tipo =
-- 'refeicao'.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'meal_kind') then
    create type public.meal_kind as enum ('refeicao', 'evento');
  end if;
end $$;

alter table public.meals add column if not exists tipo public.meal_kind not null default 'refeicao';
alter table public.meals alter column periodo drop not null;
