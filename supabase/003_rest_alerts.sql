-- Set Log: rest-timer alerts that arrive even when the app is closed.
-- Safe to run more than once. Run in the Supabase SQL Editor.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

-- One row per phone that has turned on rest alerts.
create table if not exists public.push_subscriptions (
  endpoint text primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  subscription jsonb not null,
  created_at timestamptz not null default now()
);

-- At most one pending alarm per phone.
create table if not exists public.rest_alarms (
  endpoint text primary key
    references public.push_subscriptions (endpoint) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  fire_at timestamptz not null,
  title text not null default 'Rest over',
  body text not null default 'Time for your next set.'
);

create index if not exists rest_alarms_fire_at_idx
  on public.rest_alarms (fire_at);

alter table public.push_subscriptions enable row level security;
alter table public.rest_alarms enable row level security;

drop policy if exists push_select on public.push_subscriptions;
drop policy if exists push_insert on public.push_subscriptions;
drop policy if exists push_update on public.push_subscriptions;
drop policy if exists push_delete on public.push_subscriptions;

create policy push_select on public.push_subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy push_insert on public.push_subscriptions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy push_update on public.push_subscriptions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy push_delete on public.push_subscriptions
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists alarm_select on public.rest_alarms;
drop policy if exists alarm_insert on public.rest_alarms;
drop policy if exists alarm_update on public.rest_alarms;
drop policy if exists alarm_delete on public.rest_alarms;

create policy alarm_select on public.rest_alarms
  for select to authenticated using ((select auth.uid()) = user_id);
create policy alarm_insert on public.rest_alarms
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy alarm_update on public.rest_alarms
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy alarm_delete on public.rest_alarms
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Private settings. RLS is on with no policies, so the app can't read it;
-- only the database function below can.
create table if not exists public.app_config (
  key text primary key,
  value text not null
);
alter table public.app_config enable row level security;

-- Sends every alarm that is due, then removes it.
create or replace function public.send_due_rest_alarms()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  push_url text := (select value from public.app_config where key = 'push_url');
  push_secret text := (select value from public.app_config where key = 'push_secret');
  a record;
begin
  if push_url is null or push_secret is null then
    return;
  end if;
  for a in
    delete from public.rest_alarms r
    using public.push_subscriptions s
    where s.endpoint = r.endpoint
      and r.fire_at <= now()
    returning r.title, r.body, s.subscription
  loop
    perform net.http_post(
      url := push_url,
      body := jsonb_build_object(
        'subscription', a.subscription,
        'title', a.title,
        'body', a.body
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-secret', push_secret
      )
    );
  end loop;
end;
$$;

revoke execute on function public.send_due_rest_alarms() from public, anon, authenticated;

-- Check for due alarms every 2 seconds.
select cron.unschedule(jobid) from cron.job where jobname = 'send-rest-alarms';
select cron.schedule(
  'send-rest-alarms',
  '2 seconds',
  $$select public.send_due_rest_alarms()$$
);
