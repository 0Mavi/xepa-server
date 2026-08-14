-- pg_net é a extensão padrão do Supabase pra fazer requisições HTTP a partir
-- do banco (é o que a UI de "Database Webhooks" usa por baixo dos panos).
-- Preferimos chamar ela direto a depender do schema supabase_functions, que
-- só é provisionado quando um webhook é criado manualmente pelo dashboard.
create extension if not exists pg_net;

create or replace function public.notificar_push()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://lqivtlnzkrgltdycxgrh.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', TG_TABLE_NAME,
      'record', to_jsonb(new)
    )
  );
  return new;
end;
$$;

drop trigger if exists send_push_on_new_signal on public.signals;
create trigger send_push_on_new_signal
  after insert on public.signals
  for each row
  execute function public.notificar_push();

drop trigger if exists send_push_on_new_sos_request on public.sos_requests;
create trigger send_push_on_new_sos_request
  after insert on public.sos_requests
  for each row
  execute function public.notificar_push();
