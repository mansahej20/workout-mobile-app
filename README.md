# Set Log

Personal workout tracker: weekly plan, set/weight logging, rest timer, progress charts.
Static site on Vercel, data in Supabase, installable on your phone's home screen.

## 1. Supabase

1. Create a project at supabase.com.
2. **SQL Editor → New query**, paste everything from `supabase/schema.sql`, run it. (It includes the plans tables.)
3. **Authentication → Users → Add user → Create new user**. Enter your email and a password, tick **Auto Confirm User**.
4. **Authentication → Sign In / Providers**: turn **off** "Allow new users to sign up". Only the account you just created can log in.
5. **Project Settings → API**: copy the **Project URL** and the **anon public** key. You'll need both for Vercel.

## 2. GitHub

```bash
cd setlog
git init
git add .
git commit -m "Set Log"
git branch -M main
git remote add origin https://github.com/<you>/setlog.git
git push -u origin main
```

## 3. Vercel

1. **Add New → Project**, import the repo.
2. Framework preset: **Other**. Build command and output directory are read from `vercel.json`, so leave them alone.
3. **Environment Variables**, add:
   - `SUPABASE_URL` = your Project URL
   - `SUPABASE_ANON_KEY` = your anon public key
4. Deploy.

Every push to `main` redeploys automatically.

## 4. Put it on your phone

Open the Vercel URL on your phone and sign in.

- **iPhone (Safari):** Share → Add to Home Screen
- **Android (Chrome):** menu → Install app

It then opens full screen like a normal app.

## Adding friends

Each person gets their own account, their own plans and their own workout history. Sign-ups stay switched off, so only people you add can get in.

1. Supabase → **Authentication → Users → Add user → Create new user**.
2. Enter your friend's email and a temporary password, and tick **Auto Confirm User**.
3. Send them the app link and the temporary password.
4. They sign in, go to **Plans → Account → Change password**, and set their own.

On first sign-in they start with no plans. The Today screen shows a **Create a plan** button, and the first plan they save becomes active.

To remove someone, delete them under Authentication → Users. Their plans and logs are deleted with them.

If a friend forgets their password: Supabase's built-in email only reaches members of your Supabase team, so reset emails won't reach friends. Don't delete and re-add them, because that deletes their data. Instead, set a new temporary password in **SQL Editor** and send it to them:

```sql
update auth.users
set encrypted_password = crypt('NewTempPass123', gen_salt('bf'))
where email = 'friend@example.com';
```

They sign in with it and change it under Plans → Account.

## Rest alerts (notifications)

When a rest ends, the server sends a notification. It arrives with the app closed or the phone locked, uses the phone's own alert sound (or vibrates on silent), and doesn't stop your music.

How it works: ticking a set saves "alert me at 12:03:40" in `rest_alarms`. Every 2 seconds a Supabase cron job sends any due alarms to `/api/push` on Vercel, which delivers the notification.

### One-time setup

1. **Keys.** On your computer, in the `setlog` folder:
   ```bash
   npx web-push generate-vapid-keys
   openssl rand -hex 32
   ```
   The first gives a Public Key and a Private Key. The second is a random secret.
2. **Vercel → Settings → Environment Variables**, add:
   - `VAPID_PUBLIC_KEY` = the Public Key
   - `VAPID_PRIVATE_KEY` = the Private Key
   - `VAPID_SUBJECT` = `mailto:you@example.com` (your email)
   - `PUSH_SECRET` = the random secret

   Then push the code (or redeploy) so the build picks them up.
3. **Supabase → SQL Editor**: run `supabase/003_rest_alerts.sql`, then run this with your own values:
   ```sql
   insert into public.app_config (key, value) values
     ('push_url', 'https://workout-mobile-app.vercel.app/api/push'),
     ('push_secret', 'PASTE_THE_SAME_SECRET_HERE')
   on conflict (key) do update set value = excluded.value;
   ```
4. **On the phone**: Safari → Share → **Add to Home Screen**, open Set Log from the Home Screen, sign in, then **Profile → Turn on rest alerts → Allow**. Use **Send test alert** and lock the phone.

iPhone only allows web notifications for apps opened from the Home Screen. Each phone turns alerts on separately.

### If the test alert doesn't arrive

- Supabase → **Integrations → Cron** (or `select * from cron.job_run_details order by start_time desc limit 5;`) shows whether the job runs.
- `select * from net._http_response order by created desc limit 5;` shows what `/api/push` answered: 401 means the two secrets don't match, 500 means the VAPID keys are missing in Vercel.

## How data works

- Each day is one row in `workout_logs` (`log_date` + a `data` JSON blob).
- Every change saves to the phone first, then syncs to Supabase. With no signal at the gym, sets still save; they sync when you're back online.
- The small dot next to the day's plan name is green when synced, orange when changes are waiting to upload.
- Row Level Security means the anon key can only ever touch rows belonging to the signed-in user. The app also filters every query by user as a second layer.
- The offline cache on the phone is kept separately per account, and signing out clears it, so friends can share a device.

## Run locally

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... npm run dev
```

## Plans

Workout plans live in the **Plans** tab. You can keep several plan profiles, edit any of them day by day, duplicate one as a starting point, and switch which one is active.

Edits in the plan editor are a draft until you press **Save** in the bar at the bottom. Leaving with unsaved edits asks whether to save, discard or keep editing.

- The active plan drives the Today screen.
- Past workouts keep a snapshot of the plan they were done with, so switching or editing plans never changes your history.
- Progress charts match exercises by an internal key, so the same exercise shares history across plans (duplicated plans keep the keys). Renaming an exercise later keeps its history.
- New accounts start with no plans. The first plan someone saves becomes their active plan automatically.

Plans are stored in the `workout_plans` table, and the active plan in `user_settings`. If you set up Supabase before plans existed, run `supabase/002_plans.sql` once in the SQL Editor.
