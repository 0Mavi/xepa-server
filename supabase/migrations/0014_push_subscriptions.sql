create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  criado_em timestamptz not null default now()
);

create index if not exists push_subscriptions_user_id_idx
  on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

drop policy if exists "select_own_push_subscription" on public.push_subscriptions;
create policy "select_own_push_subscription" on public.push_subscriptions
  for select using (auth.uid() = user_id);

drop policy if exists "insert_own_push_subscription" on public.push_subscriptions;
create policy "insert_own_push_subscription" on public.push_subscriptions
  for insert with check (auth.uid() = user_id and public.is_approved());

drop policy if exists "delete_own_push_subscription" on public.push_subscriptions;
create policy "delete_own_push_subscription" on public.push_subscriptions
  for delete using (auth.uid() = user_id);
