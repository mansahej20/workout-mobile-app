-- Profile photos: a small square JPEG (data URL) on each user's settings row.
-- Safe to run more than once.
alter table public.user_settings add column if not exists avatar text;
alter table public.user_settings drop constraint if exists user_settings_avatar_size;
alter table public.user_settings add constraint user_settings_avatar_size
  check (avatar is null or (length(avatar) < 300000 and avatar like 'data:image/%'));
