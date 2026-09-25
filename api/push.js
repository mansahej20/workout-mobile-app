// Sends one rest-timer notification. Called by the Supabase scheduler
// (see supabase/003_rest_alerts.sql), never by the browser.
const webpush = require("web-push");

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST only" });
    return;
  }
  const secret = process.env.PUSH_SECRET;
  if (!secret || req.headers["x-push-secret"] !== secret) {
    res.status(401).json({ error: "unauthorised" });
    return;
  }
  const { VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY } = process.env;
  if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) {
    res.status(500).json({ error: "VAPID keys missing" });
    return;
  }

  let payload = req.body;
  if (typeof payload === "string") {
    try { payload = JSON.parse(payload); } catch (e) { payload = {}; }
  }
  const { subscription, title, body } = payload || {};
  if (!subscription || !subscription.endpoint) {
    res.status(400).json({ error: "missing subscription" });
    return;
  }

  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || "mailto:admin@example.com",
    VAPID_PUBLIC_KEY,
    VAPID_PRIVATE_KEY
  );

  try {
    await webpush.sendNotification(
      subscription,
      JSON.stringify({ title: title || "Rest over", body: body || "Time for your next set." }),
      { TTL: 120, urgency: "high" }
    );
    res.status(200).json({ ok: true });
  } catch (err) {
    const gone = err.statusCode === 404 || err.statusCode === 410;
    res.status(gone ? 410 : 502).json({ error: err.body || err.message });
  }
};
