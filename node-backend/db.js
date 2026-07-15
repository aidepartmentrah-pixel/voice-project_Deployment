require("dotenv").config();
const sql = require("mssql");

const REQUIRED_ENV_VARS = ["DB_SERVER", "DB_NAME", "DB_USER", "DB_PASSWORD"];
const missing = REQUIRED_ENV_VARS.filter((name) => !process.env[name]);
if (missing.length > 0) {
  throw new Error(
    `Missing required database environment variable(s): ${missing.join(", ")}. ` +
    `Set them in node-backend/.env (see .env.example).`
  );
}

const config = {
  server:   process.env.DB_SERVER,
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  options: {
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  port: parseInt(process.env.DB_PORT) || 1433,
  pool: {
    max: 20,
    min: 2,
    idleTimeoutMillis: 30000,
  },
};

let pool = null;

async function getPool() {
  if (!pool) {
    try {
      pool = await sql.connect(config);
      console.log("✅ Connected to BloodBankDB");
    } catch (err) {
      console.error("❌ DB Connection failed:", err.message);
      throw err;
    }
  }
  return pool;
}

module.exports = { getPool, sql };