-- Set Log: one row per user per day. The whole day's log lives in `data` (jsonb).
create table if not exists public.workout_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade default auth.uid(),
  log_date    date not null,
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  unique (user_id, log_date)
);

create index if not exists workout_logs_user_date_idx
  on public.workout_logs (user_id, log_date desc);

-- Row Level Security: each signed-in user can only see and change their own rows.
alter table public.workout_logs enable row level security;

create policy "Read own logs"
  on public.workout_logs for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Insert own logs"
  on public.workout_logs for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Update own logs"
  on public.workout_logs for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Delete own logs"
  on public.workout_logs for delete
  to authenticated
  using ((select auth.uid()) = user_id);
