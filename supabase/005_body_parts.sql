-- Body parts the user picked for exercises the app couldn't sort itself: { exerciseKey: "Legs", ... }
-- Safe to run more than once.
alter table public.user_settings add column if not exists body_parts jsonb not null default '{}'::jsonb;
alter table public.user_settings drop constraint if exists user_settings_body_parts_check;
alter table public.user_settings add constraint user_settings_body_parts_check
  check (jsonb_typeof(body_parts) = 'object' and pg_column_size(body_parts) < 50000);
