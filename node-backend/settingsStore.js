// Persists admin-editable connection settings (currently: the two SQL Server
// connections — BloodBankDB and eDelphyn) to a local JSON file, so credentials
// can be changed from the Settings page in the UI instead of hand-editing
// .env and restarting for every deployment.
//
// .env values are used as the *first-run* defaults (see envDefaults()) and,
// in this RAH offline deployment, remain the ONLY source of truth — see
// RUNTIME_SETTINGS_ENABLED below. Persisting UI-edited credentials to
// config/db-settings.json was upstream's original design (the file would
// take over from .env once saved), but that conflicts with this repo's
// "config is external, env-var-only, and discoverable through the
// operational Vault — never a second undocumented file the container can
// drift into" deployment model (see RAH Application Release & Deployment
// Standard §7.4/§7.5, RAH Software Engineering Standard §4.5). Writing is
// therefore off by default; nothing in docker-compose.yml,
// release/compose/docker-compose.yml, .env.example, or .env.offline.template
// turns it on. The read-only "Test Connection" button is unaffected — it
// never persists anything, so it stays available as an operator diagnostic
// tool regardless of this flag.
const fs   = require("fs");
const path = require("path");

const CONFIG_DIR  = path.join(__dirname, "config");
const CONFIG_FILE = path.join(CONFIG_DIR, "db-settings.json");

const RUNTIME_SETTINGS_ENABLED = process.env.ALLOW_RUNTIME_DB_SETTINGS === "true";

function envDefaults() {
  return {
    bloodbank: {
      server:                 process.env.DB_SERVER   || "",
      port:                   parseInt(process.env.DB_PORT) || 1433,
      database:               process.env.DB_NAME     || "BloodBankDB",
      user:                   process.env.DB_USER     || "",
      password:               process.env.DB_PASSWORD || "",
      windowsAuth:            false,
      trustServerCertificate: true,
    },
    edelphyn: {
      server:                 process.env.EDELPHYN_DB_SERVER   || "",
      port:                   parseInt(process.env.EDELPHYN_DB_PORT) || 1433,
      database:               process.env.EDELPHYN_DB_NAME     || "eDelphyn",
      user:                   process.env.EDELPHYN_DB_USER     || "",
      password:               process.env.EDELPHYN_DB_PASSWORD || "",
      windowsAuth:            false,
      trustServerCertificate: true,
    },
  };
}

let cache = null;

function readFile() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf8"));
  } catch {
    return null; // missing or corrupt — fall back to .env defaults
  }
}

// Returns { bloodbank, edelphyn }. Pass { fresh: true } to bypass the
// in-memory cache and re-read the file from disk (used by "Reload & Test").
function loadSettings({ fresh = false } = {}) {
  if (cache && !fresh) return cache;
  const fromFile = readFile();
  const defaults = envDefaults();
  cache = {
    bloodbank: { ...defaults.bloodbank, ...(fromFile?.bloodbank || {}) },
    edelphyn:  { ...defaults.edelphyn,  ...(fromFile?.edelphyn  || {}) },
  };
  return cache;
}

function saveSettings(next) {
  if (!RUNTIME_SETTINGS_ENABLED) {
    const err = new Error(
      "Saving database credentials from the Settings page is disabled in this " +
      "deployment. Database credentials are configured through node-backend/.env " +
      "(see .env.example) so they stay externally configurable and match what's " +
      "recorded in the deployment's operational documentation. Set " +
      "ALLOW_RUNTIME_DB_SETTINGS=true to override — not recommended for the " +
      "offline production deployment."
    );
    err.code = "RUNTIME_SETTINGS_DISABLED";
    throw err;
  }
  const current = loadSettings();
  const merged = {
    bloodbank: { ...current.bloodbank, ...(next.bloodbank || {}) },
    edelphyn:  { ...current.edelphyn,  ...(next.edelphyn  || {}) },
  };
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(merged, null, 2), "utf8");
  cache = merged;
  return merged;
}

// Converts our settings shape into the config object `mssql` expects.
function toMssqlConfig(s) {
  return {
    server:   s.server,
    database: s.database,
    user:     s.user,
    password: s.password,
    port:     parseInt(s.port) || 1433,
    options: {
      trustServerCertificate: s.trustServerCertificate !== false,
      enableArithAbort: true,
    },
  };
}

function getConnectionConfig(which) {
  return toMssqlConfig(loadSettings()[which]);
}

module.exports = { loadSettings, saveSettings, getConnectionConfig, toMssqlConfig, CONFIG_FILE };
