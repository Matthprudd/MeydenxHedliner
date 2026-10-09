-- MEYDEN Ecosystem OS | migration candidate | DO NOT apply to Rap Jungle
-- Dedicated Supabase project only. No automatic data import from browser localStorage.
create extension if not exists pgcrypto;
create table if not exists public.meyden_submissions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  source_app text not null check (source_app in ('os','admin','incubation','services360')),
  client_reference uuid not null,
  request_token_hash text not null unique,
  contact_name text not null check (char_length(contact_name) between 1 and 160),
  contact_email text not null check (char_length(contact_email) between 3 and 254),
  project_name text not null check (char_length(project_name) between 1 and 200),
  detail jsonb not null default '{}'::jsonb check (pg_column_size(detail) < 24000),
  privacy_notice_version text not null,
  submitted_at timestamptz not null default now(),
  status text not null default 'new' check (status in ('new','in_review','quoted','contracted','closed','deleted')),
  archived_at timestamptz,
  retain_until timestamptz,
  consent_marketing boolean not null default false
);
create index if not exists meyden_submissions_client_idx on public.meyden_submissions(client_reference);
create index if not exists meyden_submissions_created_idx on public.meyden_submissions(created_at);
alter table public.meyden_submissions enable row level security;
alter table public.meyden_submissions force row level security;
revoke all on public.meyden_submissions from anon, authenticated;
-- Do not create anon or authenticated SELECT/INSERT/UPDATE/DELETE policies.
-- All public submissions must pass a server-side HTTPS endpoint validating payload,
-- origin, anti-abuse proof, rate limits, idempotency, and sanitized size limits.
-- Admin access must use verified authorization on the server; never expose
-- the service-role key in Vite/HTML, client JS, GitHub, or a public endpoint.
comment on table public.meyden_submissions is
 'Private OS submissions: service role backend only; RLS denied to public.';
