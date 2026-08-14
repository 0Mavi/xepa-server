// Disparada por trigger de banco via pg_net (ver migration 0015) sempre que
// um Signal ou S.O.S é criado. Não é chamada pelo client — roda com a
// service role key.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

webpush.setVapidDetails(
  "mailto:contato@xepa.app",
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY,
);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type WebhookPayload = {
  type: "INSERT";
  table: "signals" | "sos_requests";
  record: Record<string, unknown>;
};

type PushPreference = {
  user_id: string;
  notificar_signals: boolean;
  notificar_sos: boolean;
};

function montarNotificacao(payload: WebhookPayload, autorNome: string) {
  if (payload.table === "signals") {
    return {
      title: `🚨 Xepa Signal de ${autorNome}`,
      body: `${payload.record.tipo} em ${payload.record.local}`,
      url: "/",
    };
  }

  return {
    title: `🆘 S.O.S de ${autorNome}`,
    body: String(payload.record.descricao),
    url: "/sos",
  };
}

Deno.serve(async (req) => {
  const payload: WebhookPayload = await req.json();
  const autorId = payload.record.autor_id as string;

  const { data: autor } = await supabase
    .from("profiles")
    .select("nome")
    .eq("id", autorId)
    .single();

  const notificacao = montarNotificacao(payload, autor?.nome ?? "um vizinho");

  const { data: allSubscriptions } = await supabase
    .from("push_subscriptions")
    .select("id, user_id, endpoint, p256dh, auth")
    .neq("user_id", autorId);

  if (!allSubscriptions?.length) {
    return new Response(JSON.stringify({ enviados: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: preferences } = await supabase
    .from("push_preferences")
    .select("user_id, notificar_signals, notificar_sos")
    .in(
      "user_id",
      allSubscriptions.map((subscription) => subscription.user_id),
    );

  const preferenciasPorUsuario = new Map<string, PushPreference>(
    (preferences as PushPreference[] | null)?.map((preference) => [
      preference.user_id,
      preference,
    ]) ?? [],
  );

  // Sem linha em push_preferences = usuário nunca desativou nada, então
  // continua recebendo (default true).
  const campoPreferencia: keyof Pick<
    PushPreference,
    "notificar_signals" | "notificar_sos"
  > = payload.table === "signals" ? "notificar_signals" : "notificar_sos";

  const subscriptions = allSubscriptions.filter((subscription) => {
    const preference = preferenciasPorUsuario.get(subscription.user_id);
    return preference ? preference[campoPreferencia] !== false : true;
  });

  if (!subscriptions.length) {
    return new Response(JSON.stringify({ enviados: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const resultados = await Promise.allSettled(
    subscriptions.map((subscription) =>
      webpush.sendNotification(
        {
          endpoint: subscription.endpoint,
          keys: { p256dh: subscription.p256dh, auth: subscription.auth },
        },
        JSON.stringify(notificacao),
      ),
    ),
  );

  // Subscription expirada/revogada no navegador — limpa pra não ficar
  // tentando enviar pra sempre (nada mais fazia essa faxina hoje).
  const idsExpirados = subscriptions
    .filter((_, index) => {
      const resultado = resultados[index];
      return (
        resultado.status === "rejected" &&
        [404, 410].includes(resultado.reason?.statusCode)
      );
    })
    .map((subscription) => subscription.id);

  if (idsExpirados.length > 0) {
    await supabase.from("push_subscriptions").delete().in("id", idsExpirados);
  }

  const enviados = resultados.filter(
    (resultado) => resultado.status === "fulfilled",
  ).length;

  return new Response(JSON.stringify({ enviados }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
