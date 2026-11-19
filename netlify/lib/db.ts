import postgres from 'postgres';
import { getRequiredEnv } from './env.js';

export type SqlClient = ReturnType<typeof postgres>;

let sqlInstance: SqlClient | null = null;
let schemaReadyPromise: Promise<void> | null = null;

export function getSql(): SqlClient {
  if (!sqlInstance) {
    const connectionString = getRequiredEnv('SUPABASE_DB_URL', ['DATABASE_URL']);
    const isLocal =
      connectionString.includes('localhost') || connectionString.includes('127.0.0.1');

    sqlInstance = postgres(connectionString, {
      ssl: isLocal ? false : 'require',
      max: 1,
      idle_timeout: 5,
      connect_timeout: 10,
      prepare: false,
      fetch_types: false,
    });
  }
  return sqlInstance;
}

export async function ensureSchema(): Promise<SqlClient> {
  const sql = getSql();
  if (!schemaReadyPromise) {
    schemaReadyPromise = (async () => {
      const check = await sql`
        SELECT to_regclass('public.iso_evaluations') AS ready
      `;
      if (!check[0]?.ready) {
        await runBootstrap(sql);
      }
    })().catch((err) => {
      schemaReadyPromise = null;
      throw err;
    });
  }
  await schemaReadyPromise;
  return sql;
}

async function runBootstrap(sql: SqlClient): Promise<void> {
  await sql`CREATE EXTENSION IF NOT EXISTS pgcrypto`;

  await sql`
    CREATE TABLE IF NOT EXISTS households (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL DEFAULT 'My Household',
      invite_code TEXT NOT NULL UNIQUE,
      profile_json JSONB NOT NULL DEFAULT '{"adults":2,"children":0,"infants":0,"seniors":0,"pets":0,"isFloodProne":true,"isEarthquakeZone":true,"hasChronicMedicalNeeds":false}'::jsonb,
      expiry_alert_days INTEGER NOT NULL DEFAULT 30,
      plan_json JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'household' CHECK (role IN ('household', 'admin')),
      household_id UUID REFERENCES households(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS kit_items (
      household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      category_index INTEGER NOT NULL DEFAULT 0,
      quantity INTEGER NOT NULL DEFAULT 0,
      target_quantity INTEGER NOT NULL DEFAULT 1,
      unit TEXT NOT NULL DEFAULT 'pcs',
      expiration_date TIMESTAMPTZ NULL,
      is_packed BOOLEAN NOT NULL DEFAULT FALSE,
      notes TEXT NOT NULL DEFAULT '',
      last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      deleted BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (household_id, id)
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS safety_checkins (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      author_name TEXT NOT NULL DEFAULT 'Household Member',
      status TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      latitude DOUBLE PRECISION NULL,
      longitude DOUBLE PRECISION NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS evacuation_centers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      city TEXT NOT NULL,
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      contact_person TEXT NOT NULL,
      contact_number TEXT NOT NULL,
      capacity_people INTEGER NOT NULL DEFAULT 500,
      is_open BOOLEAN NOT NULL DEFAULT TRUE,
      facilities TEXT NOT NULL DEFAULT '',
      is_official BOOLEAN NOT NULL DEFAULT FALSE,
      created_by_household_id UUID REFERENCES households(id) ON DELETE SET NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS telemetry_cache (
      cache_key TEXT PRIMARY KEY,
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      payload_json JSONB NOT NULL,
      fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS iso_evaluations (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      household_id UUID REFERENCES households(id) ON DELETE SET NULL,
      respondent_label TEXT NOT NULL DEFAULT 'Anonymous Household',
      platform TEXT NOT NULL DEFAULT 'web',
      functionality_score INTEGER NOT NULL CHECK (functionality_score BETWEEN 1 AND 5),
      usability_score INTEGER NOT NULL CHECK (usability_score BETWEEN 1 AND 5),
      reliability_score INTEGER NOT NULL CHECK (reliability_score BETWEEN 1 AND 5),
      effectiveness_score INTEGER NOT NULL CHECK (effectiveness_score BETWEEN 1 AND 5),
      readiness_percentage DOUBLE PRECISION NOT NULL DEFAULT 0,
      raw_completion_percentage DOUBLE PRECISION NOT NULL DEFAULT 0,
      comments TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    INSERT INTO evacuation_centers (
      id, name, address, city, latitude, longitude,
      contact_person, contact_number, capacity_people, is_open, facilities, is_official
    ) VALUES
      (
        'manila_rizal_memorial',
        'Rizal Memorial Sports Complex (Official City Shelter)',
        'Pablo Ocampo Sr. St. (Vito Cruz), Malate, Manila',
        'Manila', 14.5633, 120.9922,
        'Manila DRRMO Operations Center', '(02) 8527-5174', 3000, TRUE,
        'Large Indoor Arena, Medical Staging Area, Relief Distribution Hub', TRUE
      ),
      (
        'eac_campus_reference',
        'Emilio Aguinaldo College (Campus Assembly Reference)',
        '1113-1117 San Marcelino St, Paco, Manila',
        'Manila', 14.5822, 120.9882,
        'Manila DRRMO Dispatch', '(02) 8527-5174', 1000, TRUE,
        'Campus Open Grounds, Verify active shelter status with LGU/Admin', TRUE
      ),
      (
        'manila_delpan_complex',
        'Delpan Sports Complex Evacuation Center',
        'Delpan St., San Nicolas / Tondo, Manila',
        'Manila', 14.5988, 120.9647,
        'Manila DRRMO Operations Center', '(02) 8527-5174', 1200, TRUE,
        'Designated City of Manila Typhoon & Fire Evacuation Complex', TRUE
      ),
      (
        'manila_baseco_center',
        'Baseco Evacuation Center',
        'Baseco Compound, Port Area, Manila',
        'Manila', 14.5889, 120.9622,
        'Manila DRRMO Operations Center', '(02) 8527-5174', 1500, TRUE,
        'Coastal Surge & Flood Evacuation Facility, Relief Staging', TRUE
      ),
      (
        'qc_amoranto_stadium',
        'Amoranto Sports Complex',
        'Don A. Roces Ave., Quezon City',
        'Quezon City', 14.6301, 121.0267,
        'Quezon City Helpline (QCDRRMO)', '122', 3500, TRUE,
        'Major QC Emergency Assembly Ground & Relief Hub', TRUE
      )
    ON CONFLICT (id) DO NOTHING
  `;
}
