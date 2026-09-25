// Copies public/ to dist/ and writes dist/config.js from environment variables.
// Vercel runs this on every deploy (see vercel.json).
const fs = require("fs");
const path = require("path");

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variable.");
  process.exit(1);
}

const src = path.join(__dirname, "public");
const out = path.join(__dirname, "dist");

fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(src, out, { recursive: true });

fs.writeFileSync(
  path.join(out, "config.js"),
  "window.SETLOG_CONFIG = " +
    JSON.stringify({
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      // Public half of the push key pair; safe to ship to the browser.
      vapidPublicKey: process.env.VAPID_PUBLIC_KEY || ""
    }) +
    ";\n"
);

// Stamp the service worker cache name so each deploy ships fresh files.
const swPath = path.join(out, "sw.js");
const sw = fs.readFileSync(swPath, "utf8").replace("__BUILD_ID__", Date.now().toString(36));
fs.writeFileSync(swPath, sw);

console.log("Built to dist/");
