require("dotenv").config();
const sql = require("mssql");
const { getConnectionConfig, toMssqlConfig } = require("./settingsStore");

// Fail loud at startup if the required env vars aren't set, same as before
// settingsStore existed. RAH policy: missing config must be a clear startup
// error, not a silent connect-with-empty-string. settingsStore's env
// fallback (envDefaults() in settingsStore.js) defaults missing vars to ""
// rather than throwing, so this check has to happen here too — it's the
// only thing standing between a misconfigured deployment and a confusing
// "ELOGIN failed for user ''" error instead of a clear one.
//
// Connection settings themselves come from settingsStore (Settings page →
// Database tab), which reads these same env vars as its first-run default.
// See settingsStore.js and the ALLOW_RUNTIME_DB_SETTINGS note there for why
// the Settings page can't silently override them in this deployment.
const REQUIRED_ENV_VARS = ["DB_SERVER", "DB_NAME", "DB_USER", "DB_PASSWORD"];
const missing = REQUIRED_ENV_VARS.filter((name) => !process.env[name]);
if (missing.length > 0) {
  throw new Error(
    `Missing required database environment variable(s): ${missing.join(", ")}. ` +
    `Set them in node-backend/.env (see .env.example).`
  );
}

let pool = null;

function buildConfig() {
  return {
    ...getConnectionConfig("bloodbank"),
    pool: { max: 20, min: 2, idleTimeoutMillis: 30000 },
  };
}

async function getPool() {
  if (!pool) {
    try {
      pool = await new sql.ConnectionPool(buildConfig()).connect();
      console.log("✅ Connected to BloodBankDB");
    } catch (err) {
      pool = null;
      console.error("❌ DB Connection failed:", err.message);
      throw err;
    }
  }
  return pool;
}

// Closes the live pool so the next getPool() call reconnects using whatever
// settings are current (called after Settings → Save/Reload changes creds).
async function resetPool() {
  if (pool) {
    try { await pool.close(); } catch { /* already dead — ignore */ }
    pool = null;
  }
}

// One-off connection attempt against arbitrary (not-yet-saved) settings, used
// by the Settings page's "Test Connection" button. Never touches the shared
// pool above, so a bad test can't take down the live connection.
async function testConnection(rawSettings) {
  const cfg = {
    ...toMssqlConfig(rawSettings),
    pool: { max: 1, min: 0, idleTimeoutMillis: 5000 },
    connectionTimeout: 8000,
    requestTimeout: 8000,
  };
  const testPool = new sql.ConnectionPool(cfg);
  try {
    await testPool.connect();
    await testPool.request().query("SELECT 1");
    return { ok: true };
  } catch (err) {
    return { ok: false, error: err.message };
  } finally {
    try { await testPool.close(); } catch { /* ignore */ }
  }
}

module.exports = { getPool, resetPool, testConnection, sql };
