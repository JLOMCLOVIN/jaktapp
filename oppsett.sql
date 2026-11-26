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
