const { Pool } = require("pg");

let pool;

async function connect() {
  pool = new Pool({
    host:                    process.env.DB_HOST     || "localhost",
    port:                    parseInt(process.env.DB_PORT || "5432"),
    database:                process.env.DB_NAME     || "lksdb",
    user:                    process.env.DB_USER     || "lksadmin",
    password:                process.env.DB_PASSWORD || "password",
    max:                     10,
    idleTimeoutMillis:       30_000,
    connectionTimeoutMillis: 5_000,
    // RDS PostgreSQL 15 requires SSL. Setting rejectUnauthorized:false
    // accepts the self-signed RDS certificate without needing to bundle the CA.
    ssl: process.env.DB_SSL === "false"
      ? false
      : { rejectUnauthorized: false },
  });

  const client = await pool.connect();
  console.log(JSON.stringify({
    level: "info",
    message: "PostgreSQL connected",
    host: process.env.DB_HOST,
    ssl: process.env.DB_SSL !== "false",
  }));

  await client.query(`
    CREATE TABLE IF NOT EXISTS users (
      id          SERIAL PRIMARY KEY,
      name        VARCHAR(255) NOT NULL,
      email       VARCHAR(255) NOT NULL UNIQUE,
      institution VARCHAR(255),
      position    VARCHAR(255),
      phone       VARCHAR(50),
      created_at  TIMESTAMPTZ DEFAULT NOW(),
      updated_at  TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  client.release();
  console.log(JSON.stringify({ level: "info", message: "Database schema ready" }));
}

function query(text, params) {
  if (!pool) throw new Error("Database not connected — call connect() first");
  return pool.query(text, params);
}

module.exports = { connect, query };
