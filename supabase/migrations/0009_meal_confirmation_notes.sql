alter table public.meal_confirmations add column nota text;

create policy "update_own_meal_confirmation" on public.meal_confirmations
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
