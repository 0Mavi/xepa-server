-- is_approved() só olhava status/role, então um síndico ou admin banido
-- continuava sendo tratado como aprovado (o cargo bastava). Fecha esse buraco.
create or replace function public.is_approved()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and status <> 'banido'
      and (status = 'aprovado' or role in ('sindico', 'admin'))
  );
$$;

-- Até aqui, as policies de insert só checavam "auth.uid() = autor_id" — um
-- morador pendente ou banido, mesmo sem conseguir NAVEGAR no app, ainda
-- conseguia criar conteúdo direto pela API. Fecha isso em todas as tabelas.
alter policy "insert_own_signal" on public.signals
  with check (auth.uid() = autor_id and public.is_approved());

alter policy "insert_own_signal_confirmation" on public.signal_confirmations
  with check (auth.uid() = user_id and public.is_approved());

alter policy "insert_own_meal" on public.meals
  with check (auth.uid() = autor_id and public.is_approved());

alter policy "insert_own_meal_confirmation" on public.meal_confirmations
  with check (auth.uid() = user_id and public.is_approved());

alter policy "insert_own_leftover" on public.leftovers
  with check (auth.uid() = autor_id and public.is_approved());

alter policy "reserve_available_leftover" on public.leftovers
  using (
    auth.role() = 'authenticated' and status = 'disponivel' and public.is_approved()
  ) with check (
    status = 'reservado' and reservado_por = auth.uid()
  );

alter policy "insert_own_sos_request" on public.sos_requests
  with check (auth.uid() = autor_id and public.is_approved());

alter policy "resolve_active_sos_request" on public.sos_requests
  using (
    auth.role() = 'authenticated' and status = 'ativo' and public.is_approved()
  ) with check (
    status = 'resolvido' and resolvido_por = auth.uid()
  );

alter policy "insert_own_split" on public.splits
  with check (auth.uid() = autor_id and public.is_approved());

alter policy "insert_own_pearl" on public.pearls
  with check (auth.uid() = autor_id and public.is_approved());

alter policy "insert_own_pearl_reaction" on public.pearl_reactions
  with check (auth.uid() = user_id and public.is_approved());

alter policy "insert_food_option" on public.food_options
  with check (auth.uid() = criado_por and public.is_approved());

alter policy "insert_invites_moderacao" on public.invites
  with check (
    auth.uid() = criado_por
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('sindico', 'admin')
    )
    and public.is_approved()
  );
