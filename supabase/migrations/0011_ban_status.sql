-- Precisa ficar sozinha na migration: valores novos de enum só podem ser
-- usados em queries de uma transação POSTERIOR à que os criou.
alter type public.profile_status add value 'banido';
