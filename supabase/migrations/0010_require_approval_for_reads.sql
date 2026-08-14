-- Até aqui, todas as policies de leitura só exigiam `auth.role() = 'authenticated'`,
-- então um morador com cadastro ainda pendente conseguia ler qualquer dado do grupo
-- via API (o middleware só bloqueava a navegação nas telas, não o acesso aos dados).
-- A função `public.is_approved()` já existia desde 0001_init.sql mas nunca era usada.

-- profiles é especial: o próprio morador precisa sempre conseguir ler o próprio
-- registro (é como o middleware e o layout descobrem que ele está pendente e o
-- mandam pra tela de "aguardando aprovação"). Aprovados continuam vendo todo mundo.
alter policy "select_profiles_grupo" on public.profiles
  using (auth.uid() = id or public.is_approved());

alter policy "select_signals_grupo" on public.signals
  using (public.is_approved());

alter policy "select_signal_confirmations_grupo" on public.signal_confirmations
  using (public.is_approved());

alter policy "select_meals_grupo" on public.meals
  using (public.is_approved());

alter policy "select_meal_confirmations_grupo" on public.meal_confirmations
  using (public.is_approved());

alter policy "select_leftovers_grupo" on public.leftovers
  using (public.is_approved());

alter policy "select_sos_requests_grupo" on public.sos_requests
  using (public.is_approved());

alter policy "select_splits_grupo" on public.splits
  using (public.is_approved());

alter policy "select_split_participants_grupo" on public.split_participants
  using (public.is_approved());

alter policy "select_pearls_grupo" on public.pearls
  using (public.is_approved());

alter policy "select_pearl_reactions_grupo" on public.pearl_reactions
  using (public.is_approved());

alter policy "select_food_options_grupo" on public.food_options
  using (public.is_approved());
