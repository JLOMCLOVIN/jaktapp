-- Jaktapp: posisjoner for jaktlaget. Kjøres i Supabase SQL Editor (Hytteboka-prosjektet).
-- Alle objekter har prefikset jakt_ for å holde dem adskilt fra andre prosjekter.

create table if not exists public.jakt_posisjoner (
  id          uuid primary key,
  lag         text not null,
  navn        text not null,
  lat         double precision not null,
  lng         double precision not null,
  noyaktighet real,
  oppdatert   timestamptz not null default now()
);

create index if not exists jakt_posisjoner_lag_idx on public.jakt_posisjoner (lag);

-- Helt åpent til å begynne med: alle med lenken kan lese og skrive
alter table public.jakt_posisjoner enable row level security;
drop policy if exists "jakt åpen lesing"   on public.jakt_posisjoner;
drop policy if exists "jakt åpen skriving" on public.jakt_posisjoner;
drop policy if exists "jakt åpen endring"  on public.jakt_posisjoner;
drop policy if exists "jakt åpen sletting" on public.jakt_posisjoner;
create policy "jakt åpen lesing"   on public.jakt_posisjoner for select to anon, authenticated using (true);
create policy "jakt åpen skriving" on public.jakt_posisjoner for insert to anon, authenticated with check (true);
create policy "jakt åpen endring"  on public.jakt_posisjoner for update to anon, authenticated using (true) with check (true);
create policy "jakt åpen sletting" on public.jakt_posisjoner for delete to anon, authenticated using (true);
grant select, insert, update, delete on public.jakt_posisjoner to anon, authenticated;

-- Sanntid
alter table public.jakt_posisjoner replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'jakt_posisjoner') then
    alter publication supabase_realtime add table public.jakt_posisjoner;
  end if;
end $$;

notify pgrst, 'reload schema';

-- Valgfritt: slett posisjoner eldre enn ett døgn hver natt kl. 03
-- (krever at pg_cron er slått på under Database > Extensions)
-- select cron.schedule('jakt-rydd-posisjoner', '0 3 * * *',
--   $$delete from public.jakt_posisjoner where oppdatert < now() - interval '1 day'$$);

-- ===== Versjon 2: jaktlag med grenser, og meldinger =====

create table if not exists public.jakt_lag (
  slug      text primary key,
  navn      text not null,
  grense    jsonb,               -- GeoJSON Polygon/MultiPolygon, [lng, lat]
  opprettet timestamptz not null default now()
);
alter table public.jakt_lag enable row level security;
drop policy if exists "jakt_lag lesing"   on public.jakt_lag;
drop policy if exists "jakt_lag oppretting" on public.jakt_lag;
create policy "jakt_lag lesing"     on public.jakt_lag for select to anon, authenticated using (true);
create policy "jakt_lag oppretting" on public.jakt_lag for insert to anon, authenticated with check (true);
grant select, insert on public.jakt_lag to anon, authenticated;

create table if not exists public.jakt_meldinger (
  id          bigint generated always as identity primary key,
  lag         text not null,
  avsender_id uuid not null,
  navn        text not null,
  tekst       text not null check (length(tekst) between 1 and 1000),
  sendt       timestamptz not null default now()
);
create index if not exists jakt_meldinger_lag_idx on public.jakt_meldinger (lag, sendt desc);
alter table public.jakt_meldinger enable row level security;
drop policy if exists "jakt_meldinger lesing"  on public.jakt_meldinger;
drop policy if exists "jakt_meldinger sending" on public.jakt_meldinger;
create policy "jakt_meldinger lesing"  on public.jakt_meldinger for select to anon, authenticated using (true);
create policy "jakt_meldinger sending" on public.jakt_meldinger for insert to anon, authenticated with check (true);
grant select, insert on public.jakt_meldinger to anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'jakt_meldinger') then
    alter publication supabase_realtime add table public.jakt_meldinger;
  end if;
end $$;

notify pgrst, 'reload schema';

-- ===== Versjon 3: medlemmer i jaktlaget =====
create table if not exists public.jakt_medlemmer (
  lag        text not null,
  medlem_id  uuid not null,
  navn       text not null,
  sist_aktiv timestamptz not null default now(),
  primary key (lag, medlem_id)
);
create index if not exists jakt_medlemmer_medlem_idx on public.jakt_medlemmer (medlem_id);
alter table public.jakt_medlemmer enable row level security;
drop policy if exists "jakt_medlemmer lesing"   on public.jakt_medlemmer;
drop policy if exists "jakt_medlemmer innmelding" on public.jakt_medlemmer;
drop policy if exists "jakt_medlemmer endring"  on public.jakt_medlemmer;
drop policy if exists "jakt_medlemmer utmelding" on public.jakt_medlemmer;
create policy "jakt_medlemmer lesing"     on public.jakt_medlemmer for select to anon, authenticated using (true);
create policy "jakt_medlemmer innmelding" on public.jakt_medlemmer for insert to anon, authenticated with check (true);
create policy "jakt_medlemmer endring"    on public.jakt_medlemmer for update to anon, authenticated using (true) with check (true);
create policy "jakt_medlemmer utmelding"  on public.jakt_medlemmer for delete to anon, authenticated using (true);
grant select, insert, update, delete on public.jakt_medlemmer to anon, authenticated;
notify pgrst, 'reload schema';

-- ===== Versjon 4: hunder og uttak =====
create table if not exists public.jakt_hunder (
  lag        text not null,
  hund       text not null,
  lat        double precision,
  lng        double precision,
  hos_medlem uuid,                 -- satt når hunden følger en jeger
  satt_av    text not null,
  oppdatert  timestamptz not null default now(),
  primary key (lag, hund)
);
create table if not exists public.jakt_hendelser (
  id        bigint generated always as identity primary key,
  lag       text not null,
  type      text not null default 'uttak',
  lat       double precision not null,
  lng       double precision not null,
  navn      text not null,
  notat     text,
  tid       timestamptz not null default now()
);
create index if not exists jakt_hendelser_lag_idx on public.jakt_hendelser (lag, tid desc);
alter table public.jakt_hunder enable row level security;
alter table public.jakt_hendelser enable row level security;
drop policy if exists "jakt_hunder alt" on public.jakt_hunder;
drop policy if exists "jakt_hendelser alt" on public.jakt_hendelser;
create policy "jakt_hunder alt"    on public.jakt_hunder    for all to anon, authenticated using (true) with check (true);
create policy "jakt_hendelser alt" on public.jakt_hendelser for all to anon, authenticated using (true) with check (true);
grant select, insert, update, delete on public.jakt_hunder, public.jakt_hendelser to anon, authenticated;
alter table public.jakt_hunder replica identity full;
alter table public.jakt_hendelser replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'jakt_hunder') then
    alter publication supabase_realtime add table public.jakt_hunder;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'jakt_hendelser') then
    alter publication supabase_realtime add table public.jakt_hendelser;
  end if;
end $$;
notify pgrst, 'reload schema';

-- ===== Versjon 5: push-varsler =====
create table if not exists public.jakt_push (
  endpoint   text not null,
  lag        text not null,
  medlem_id  uuid not null,
  abonnement jsonb not null,
  meldinger  boolean not null default true,
  oppdatert  timestamptz not null default now(),
  primary key (endpoint, lag)
);
alter table public.jakt_push enable row level security;
revoke all on public.jakt_push from anon, authenticated;

create or replace function public.jakt_lagre_push(p_endpoint text, p_lag text, p_medlem uuid, p_abonnement jsonb, p_meldinger boolean)
returns void language sql security definer set search_path = public as $$
  insert into jakt_push (endpoint, lag, medlem_id, abonnement, meldinger, oppdatert)
  values (p_endpoint, p_lag, p_medlem, p_abonnement, p_meldinger, now())
  on conflict (endpoint, lag) do update
    set medlem_id = excluded.medlem_id, abonnement = excluded.abonnement,
        meldinger = excluded.meldinger, oppdatert = now();
$$;
create or replace function public.jakt_slett_push(p_endpoint text, p_lag text)
returns void language sql security definer set search_path = public as $$
  delete from jakt_push where endpoint = p_endpoint and lag = p_lag;
$$;
grant execute on function public.jakt_lagre_push(text, text, uuid, jsonb, boolean) to anon, authenticated;
grant execute on function public.jakt_slett_push(text, text) to anon, authenticated;

create extension if not exists pg_net with schema extensions;
create or replace function public.jakt_varsle() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://hmutcnvixydixymfldut.supabase.co/functions/v1/jakt-varsel',
    body := to_jsonb(new),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-jakt-hemmelig', 'HEMMELIG_HER')
  );
  return new;
end $$;
drop trigger if exists jakt_meldinger_varsel on public.jakt_meldinger;
create trigger jakt_meldinger_varsel after insert on public.jakt_meldinger
  for each row execute function public.jakt_varsle();
notify pgrst, 'reload schema';
