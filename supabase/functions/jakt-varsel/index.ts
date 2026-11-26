// Edge Function: sender push-varsel til jaktlaget når det kommer en ny melding.
// Kalles fra en trigger på jakt_meldinger (se oppsett.sql). Uttak går til alle,
// vanlige meldinger bare til dem som har varsel for meldinger på.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const HEMMELIG = Deno.env.get("JAKT_HEMMELIG") ?? "";
webpush.setVapidDetails(
  "https://jlomclovin.github.io/jaktapp/",
  Deno.env.get("VAPID_PUBLIC") ?? "",
  Deno.env.get("VAPID_PRIVATE") ?? "",
);

// Nøkkel med full tilgang (kun på serveren). Nye prosjekter bruker SUPABASE_SECRET_KEYS.
function tjenestenøkkel(): string {
  try {
    const nøkler = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    const første = Object.values(nøkler)[0];
    if (typeof første === "string" && første) return første;
  } catch (_) { /* bruk eldre nøkkel */ }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

Deno.serve(async (req) => {
  if (!HEMMELIG || req.headers.get("x-jakt-hemmelig") !== HEMMELIG) {
    return new Response("Ikke tilgang", { status: 401 });
  }
  const m = await req.json();
  const uttak = String(m.tekst ?? "").startsWith("Uttak!");
  const db = createClient(Deno.env.get("SUPABASE_URL")!, tjenestenøkkel());

  let q = db.from("jakt_push").select("endpoint, abonnement").eq("lag", m.lag).neq("medlem_id", m.avsender_id);
  if (!uttak) q = q.eq("meldinger", true);
  const { data: mottakere } = await q;
  const { data: lagRad } = await db.from("jakt_lag").select("navn").eq("slug", m.lag).maybeSingle();
  const lagNavn = lagRad?.navn ?? m.lag;

  const innhold = JSON.stringify({
    tittel: uttak ? `Uttak! ${m.navn}` : `${m.navn} · ${lagNavn}`,
    tekst: uttak ? `Los i gang · ${lagNavn}` : m.tekst,
    lag: m.lag,
    uttak,
  });

  let sendt = 0;
  await Promise.all((mottakere ?? []).map(async (s) => {
    try {
      await webpush.sendNotification(s.abonnement, innhold, { TTL: 900, urgency: "high" });
      sendt++;
    } catch (e) {
      // Utgått abonnement: fjern det
      if (e?.statusCode === 404 || e?.statusCode === 410) {
        await db.from("jakt_push").delete().eq("endpoint", s.endpoint);
      }
    }
  }));
  return new Response(JSON.stringify({ sendt }), { headers: { "Content-Type": "application/json" } });
});
