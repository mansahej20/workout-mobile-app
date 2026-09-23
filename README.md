# Set Log

Personal workout tracker: weekly plan, set/weight logging, rest timer, progress charts.
Static site on Vercel, data in Supabase, installable on your phone's home screen.

## 1. Supabase

1. Create a project at supabase.com.
2. **SQL Editor → New query**, paste everything from `supabase/schema.sql`, run it.
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

## How data works

- Each day is one row in `workout_logs` (`log_date` + a `data` JSON blob).
- Every change saves to the phone first, then syncs to Supabase. With no signal at the gym, sets still save; they sync when you're back online.
- The small dot next to the day's plan name is green when synced, orange when changes are waiting to upload.
- Row Level Security means the anon key can only ever touch rows belonging to the signed-in user.

## Run locally

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... npm run dev
```

## Editing the plan

The weekly program lives in `public/index.html`, in the `PLAN` object near the top of the script. Each exercise has a `key` (keep it stable, it's how history is matched), `name`, `sets`, `reps` and `rest` in seconds.
