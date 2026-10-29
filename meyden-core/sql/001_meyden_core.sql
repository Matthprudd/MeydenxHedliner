-- MEYDEN OS — noyau synchronisé indépendant de Hedliner
-- DESTINATION : NOUVEAU projet Supabase dédié à MEYDEN, jamais RAP JUNGLE.
-- Aucun rôle admin n'est attribué automatiquement. Une approbation SQL manuelle initiale est obligatoire.
begin;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;
create schema if not exists meyden_private;
revoke all on schema meyden_private from public, anon;
grant usage on schema meyden_private to authenticated;

create table public.meyden_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','staff','artist','client')),
  email text not null default '',
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function meyden_private.is_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.meyden_access a where a.user_id = auth.uid() and a.approved)
$$;
create or replace function meyden_private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.meyden_access a where a.user_id = auth.uid() and a.approved and a.role = 'admin')
$$;
create or replace function meyden_private.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.meyden_access a where a.user_id = auth.uid() and a.approved and a.role in ('staff','admin'))
$$;
-- À chaque nouvelle inscription Auth, un compte client NON approuvé apparaît.
-- Le premier administrateur doit être explicitement validé depuis le SQL Editor privilégié.
create or replace function meyden_private.register_pending_member()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.meyden_access(user_id, role, email, approved)
  values(new.id, 'client', coalesce(new.email,''), false)
  on conflict(user_id) do nothing;
  return new;
end;
$$;
create trigger meyden_member_signup after insert on auth.users
for each row execute function meyden_private.register_pending_member();
revoke all on function meyden_private.register_pending_member() from public, anon, authenticated;
revoke all on function meyden_private.is_admin() from public, anon;
revoke all on function meyden_private.is_member() from public, anon;
revoke all on function meyden_private.is_staff() from public, anon;
grant execute on function meyden_private.is_admin() to authenticated;
grant execute on function meyden_private.is_member() to authenticated;
grant execute on function meyden_private.is_staff() to authenticated;

create table public.meyden_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  organization text not null default '',
  contact_email text not null default '',
  phone text not null default '',
  project_name text not null default '',
  project_notes text not null default '',
  updated_at timestamptz not null default now()
);
create table public.meyden_artists (
  id uuid primary key default gen_random_uuid(),
  stage_name text not null,
  style text not null default '',
  city text not null default '',
  description text not null default '',
  hedliner_url text not null default '', -- simple référence facultative, aucune synchronisation Hedliner
  video_url text not null default '',
  status text not null default 'draft' check(status in ('draft','active','paused')),
  owner_id uuid references auth.users(id) on delete set null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.meyden_venues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null default '',
  capacity integer check(capacity is null or capacity >= 0),
  timezone text not null default 'America/Toronto',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.meyden_booking_slots (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.meyden_venues(id) on delete restrict,
  artist_id uuid references public.meyden_artists(id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'available' check(status in ('available','held','confirmed','blocked')),
  title text not null default '',
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  constraint booking_slot_time_valid check (ends_at > starts_at),
  constraint booking_slot_no_overlap exclude using gist (
    venue_id with =, tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status in ('confirmed','blocked'))
);
create table public.meyden_booking_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id),
  artist_id uuid references public.meyden_artists(id),
  venue_id uuid references public.meyden_venues(id),
  requested_date date not null,
  subject text not null default '',
  details text not null default '',
  status text not null default 'submitted' check (status in ('submitted','reviewing','approved','declined','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.meyden_dossiers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  artist_id uuid references public.meyden_artists(id),
  name text not null,
  needs text not null default '',
  notes text not null default '',
  status text not null default 'draft' check(status in ('draft','active','completed','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function meyden_private.touch_updated()
returns trigger language plpgsql set search_path='' as $$ begin new.updated_at = now(); return new; end; $$;
create trigger touch_profiles before update on public.meyden_profiles for each row execute function meyden_private.touch_updated();
create trigger touch_artists before update on public.meyden_artists for each row execute function meyden_private.touch_updated();
create trigger touch_venues before update on public.meyden_venues for each row execute function meyden_private.touch_updated();
create trigger touch_slots before update on public.meyden_booking_slots for each row execute function meyden_private.touch_updated();
create trigger touch_requests before update on public.meyden_booking_requests for each row execute function meyden_private.touch_updated();
create trigger touch_dossiers before update on public.meyden_dossiers for each row execute function meyden_private.touch_updated();

alter table public.meyden_access enable row level security;
alter table public.meyden_profiles enable row level security;
alter table public.meyden_artists enable row level security;
alter table public.meyden_venues enable row level security;
alter table public.meyden_booking_slots enable row level security;
alter table public.meyden_booking_requests enable row level security;
alter table public.meyden_dossiers enable row level security;

revoke all on public.meyden_access, public.meyden_profiles, public.meyden_artists, public.meyden_venues, public.meyden_booking_slots, public.meyden_booking_requests, public.meyden_dossiers from anon;
grant select, update on public.meyden_access to authenticated;
grant select, insert, update on public.meyden_profiles to authenticated;
grant select, insert, update, delete on public.meyden_artists to authenticated;
grant select, insert, update, delete on public.meyden_venues to authenticated;
grant select, insert, update, delete on public.meyden_booking_slots to authenticated;
grant select, insert, update on public.meyden_booking_requests to authenticated;
grant select, insert, update, delete on public.meyden_dossiers to authenticated;

create policy access_own on public.meyden_access for select to authenticated using(
  user_id = (select auth.uid()) or meyden_private.is_admin());
create policy access_admin_update on public.meyden_access for update to authenticated
using(meyden_private.is_admin()) with check(meyden_private.is_admin());
create policy profile_read on public.meyden_profiles for select to authenticated using(
  meyden_private.is_member() and (user_id = (select auth.uid()) or meyden_private.is_staff()));
create policy profile_insert on public.meyden_profiles for insert to authenticated with check(
  meyden_private.is_member() and user_id = (select auth.uid()));
create policy profile_update on public.meyden_profiles for update to authenticated using(
  meyden_private.is_member() and (user_id = (select auth.uid()) or meyden_private.is_staff())) with check(
  meyden_private.is_member() and (user_id = (select auth.uid()) or meyden_private.is_staff()));

create policy artists_read on public.meyden_artists for select to authenticated using(meyden_private.is_member());
create policy artists_insert on public.meyden_artists for insert to authenticated with check(meyden_private.is_staff() and created_by=(select auth.uid()));
create policy artists_update on public.meyden_artists for update to authenticated using(meyden_private.is_staff()) with check(meyden_private.is_staff());
create policy artists_delete on public.meyden_artists for delete to authenticated using(meyden_private.is_staff());

create policy venues_read on public.meyden_venues for select to authenticated using(meyden_private.is_member());
create policy venues_insert on public.meyden_venues for insert to authenticated with check(meyden_private.is_staff());
create policy venues_update on public.meyden_venues for update to authenticated using(meyden_private.is_staff()) with check(meyden_private.is_staff());
create policy venues_delete on public.meyden_venues for delete to authenticated using(meyden_private.is_staff());

create policy slots_read on public.meyden_booking_slots for select to authenticated using(meyden_private.is_member());
create policy slots_insert on public.meyden_booking_slots for insert to authenticated with check(meyden_private.is_staff());
create policy slots_update on public.meyden_booking_slots for update to authenticated using(meyden_private.is_staff()) with check(meyden_private.is_staff());
create policy slots_delete on public.meyden_booking_slots for delete to authenticated using(meyden_private.is_staff());

create policy requests_read on public.meyden_booking_requests for select to authenticated using(
  meyden_private.is_member() and (requester_id=(select auth.uid()) or meyden_private.is_staff()));
create policy requests_insert on public.meyden_booking_requests for insert to authenticated with check(
  meyden_private.is_member() and requester_id=(select auth.uid()) and status='submitted');
create policy requests_update on public.meyden_booking_requests for update to authenticated using(meyden_private.is_staff()) with check(meyden_private.is_staff());

create policy dossiers_read on public.meyden_dossiers for select to authenticated using(
  meyden_private.is_member() and (owner_id=(select auth.uid()) or meyden_private.is_staff()));
create policy dossiers_insert on public.meyden_dossiers for insert to authenticated with check(
  meyden_private.is_member() and owner_id=(select auth.uid()));
create policy dossiers_update on public.meyden_dossiers for update to authenticated using(
  meyden_private.is_member() and (owner_id=(select auth.uid()) or meyden_private.is_staff())) with check(
  meyden_private.is_member() and (owner_id=(select auth.uid()) or meyden_private.is_staff()));
create policy dossiers_delete on public.meyden_dossiers for delete to authenticated using(
  meyden_private.is_member() and (owner_id=(select auth.uid()) or meyden_private.is_staff()));

-- Realtime: changements Postgres permis uniquement aux utilisateurs autorisés par RLS.
-- À activer une seule fois pour chaque table dans la publication 'supabase_realtime'.
do $$ begin
  alter publication supabase_realtime add table public.meyden_access;
  alter publication supabase_realtime add table public.meyden_artists;
  alter publication supabase_realtime add table public.meyden_venues;
  alter publication supabase_realtime add table public.meyden_booking_slots;
  alter publication supabase_realtime add table public.meyden_booking_requests;
  alter publication supabase_realtime add table public.meyden_dossiers;
exception when duplicate_object then null;
end $$;
commit;