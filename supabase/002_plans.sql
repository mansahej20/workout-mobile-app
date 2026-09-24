-- Set Log: workout plan profiles. Run this once in the Supabase SQL Editor.

create table if not exists public.workout_plans (
  id          uuid primary key,
  user_id     uuid not null references auth.users (id) on delete cascade default auth.uid(),
  name        text not null,
  data        jsonb not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists workout_plans_user_idx on public.workout_plans (user_id, created_at);

create table if not exists public.user_settings (
  user_id         uuid primary key references auth.users (id) on delete cascade default auth.uid(),
  active_plan_id  uuid references public.workout_plans (id) on delete set null,
  updated_at      timestamptz not null default now()
);

alter table public.workout_plans enable row level security;
alter table public.user_settings enable row level security;

create policy "Read own plans"   on public.workout_plans for select to authenticated using ((select auth.uid()) = user_id);
create policy "Insert own plans" on public.workout_plans for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Update own plans" on public.workout_plans for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Delete own plans" on public.workout_plans for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Read own settings"   on public.user_settings for select to authenticated using ((select auth.uid()) = user_id);
create policy "Insert own settings" on public.user_settings for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Update own settings" on public.user_settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
