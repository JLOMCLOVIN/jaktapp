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
