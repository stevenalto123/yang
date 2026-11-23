-- LifeCheckpoint Supabase PostgreSQL Schema
-- Multi-Platform Application in Emergency Monitoring and Disaster Preparedness
-- Apply in Supabase SQL Editor (or let netlify/lib/db.ts auto-bootstrap on first API call).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS households (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT 'My Household',
  invite_code TEXT NOT NULL UNIQUE,
  profile_json JSONB NOT NULL DEFAULT '{"adults":2,"children":0,"infants":0,"seniors":0,"pets":0,"isFloodProne":true,"isEarthquakeZone":true,"hasChronicMedicalNeeds":false}'::jsonb,
  expiry_alert_days INTEGER NOT NULL DEFAULT 30,
  plan_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'household' CHECK (role IN ('household', 'admin')),
  household_id UUID REFERENCES households(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_household
  ON users (household_id);

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
);

CREATE INDEX IF NOT EXISTS idx_kit_items_household
  ON kit_items (household_id, deleted);

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
);

CREATE INDEX IF NOT EXISTS idx_safety_checkins_household
  ON safety_checkins (household_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_safety_checkins_user
  ON safety_checkins (user_id);

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
);

CREATE INDEX IF NOT EXISTS idx_evacuation_centers_household
  ON evacuation_centers (created_by_household_id);

CREATE TABLE IF NOT EXISTS telemetry_cache (
  cache_key TEXT PRIMARY KEY,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  payload_json JSONB NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
);

CREATE INDEX IF NOT EXISTS idx_iso_evaluations_created
  ON iso_evaluations (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_iso_evaluations_household
  ON iso_evaluations (household_id);

-- Enable RLS & revoke direct anon/authenticated PostgREST privileges;
-- server-side Netlify Functions connect securely using SUPABASE_DB_URL.
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE kit_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE safety_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE evacuation_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE iso_evaluations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE households FROM anon, authenticated;
REVOKE ALL ON TABLE users FROM anon, authenticated;
REVOKE ALL ON TABLE kit_items FROM anon, authenticated;
REVOKE ALL ON TABLE safety_checkins FROM anon, authenticated;
REVOKE ALL ON TABLE evacuation_centers FROM anon, authenticated;
REVOKE ALL ON TABLE telemetry_cache FROM anon, authenticated;
REVOKE ALL ON TABLE iso_evaluations FROM anon, authenticated;

-- Seed Official Metro Manila / Quezon City Evacuation Centers
INSERT INTO evacuation_centers (
  id, name, address, city, latitude, longitude,
  contact_person, contact_number, capacity_people, is_open, facilities, is_official
) VALUES
  (
    'manila_rizal_memorial',
    'Rizal Memorial Sports Complex (Official City Shelter)',
    'Pablo Ocampo Sr. St. (Vito Cruz), Malate, Manila',
    'Manila',
    14.5633, 120.9922,
    'Manila DRRMO Operations Center', '(02) 8527-5174', 3000, TRUE,
    'Large Indoor Arena, Medical Staging Area, Relief Distribution Hub', TRUE
  ),
  (
    'manila_paco_arena',
    'Paco Arena & Sports Complex (City Evacuation Center)',
    'Paz St. cor. Perdigon St., Paco, Manila',
    'Manila',
    14.5794, 120.9936,
    'Manila DRRMO Dispatch', '(02) 8527-5174', 1000, TRUE,
    'Multi-Purpose Covered Arena, Community Assembly & Relief Staging', TRUE
  ),
  (
    'manila_delpan_complex',
    'Delpan Sports Complex Evacuation Center',
    'Delpan St., San Nicolas / Tondo, Manila',
    'Manila',
    14.5988, 120.9647,
    'Manila DRRMO Operations Center', '(02) 8527-5174', 1200, TRUE,
    'Designated City of Manila Typhoon & Fire Evacuation Complex', TRUE
  ),
  (
    'manila_baseco_center',
    'Baseco Evacuation Center',
    'Baseco Compound, Port Area, Manila',
    'Manila',
    14.5889, 120.9622,
    'Manila DRRMO Operations Center', '(02) 8527-5174', 1500, TRUE,
    'Coastal Surge & Flood Evacuation Facility, Relief Staging', TRUE
  ),
  (
    'qc_amoranto_stadium',
    'Amoranto Sports Complex',
    'Don A. Roces Ave., Quezon City',
    'Quezon City',
    14.6301, 121.0267,
    'Quezon City Helpline (QCDRRMO)', '122', 3500, TRUE,
    'Major QC Emergency Assembly Ground & Relief Hub', TRUE
  ),
  (
    'qc_memorial_circle',
    'Quezon Memorial Circle Open Assembly Grounds',
    'Elliptical Rd., Diliman, Quezon City',
    'Quezon City',
    14.6514, 121.0493,
    'QCDRRMO Emergency Operations Center', '122', 5000, TRUE,
    'Earthquake Open-Air Assembly Zone, Field Triage & Relief Staging', TRUE
  ),
  (
    'marikina_sports_center',
    'Marikina Sports Center (Main Flood & Quake Shelter)',
    'Sumulong Hwy cor. Shoe Ave., Sto. Niño, Marikina',
    'Marikina',
    14.6353, 121.0977,
    'Marikina Rescue 161 Command Center', '161', 4000, TRUE,
    '24/7 Flood Evacuation Complex, Medical Triage, Community Kitchen', TRUE
  ),
  (
    'pasig_sports_center',
    'Pasig City Sports Center Evacuation Hub',
    'Caruncho Ave., Brgy. San Nicolas, Pasig',
    'Pasig',
    14.5605, 121.0764,
    'Pasig City DRRMO Emergency Command', '(02) 8643-0000', 2500, TRUE,
    'Central Indoor Evacuation Arena, Relief Goods & Medical Desk', TRUE
  ),
  (
    'makati_coliseum',
    'Makati Coliseum Evacuation & Relief Center',
    'Mascardo St., Brgy. Singkamas, Makati',
    'Makati',
    14.5692, 121.0152,
    'Makati DRRMO Search & Rescue', '168', 2200, TRUE,
    'Indoor Arena, Emergency Medical Station, Relief Operations', TRUE
  ),
  (
    'taguig_lakeshore_hall',
    'Taguig Lakeshore Mega Evacuation Center',
    'C-6 Road, Lower Bicutan, Taguig',
    'Taguig',
    14.5021, 121.0645,
    'Taguig CDRRMO Rescue', '(02) 8789-3200', 2500, TRUE,
    'Multi-Purpose Evacuation Complex, Family Cubicles & Medical Post', TRUE
  ),
  (
    'pasay_cuneta_astrodome',
    'Cuneta Astrodome Official Evacuation Center',
    'Roxas Blvd. cor. Derham St., Pasay',
    'Pasay',
    14.5425, 120.9912,
    'Pasay CDRRMO Operations Center', '(02) 8551-7777', 3000, TRUE,
    'Large Covered Arena, Coastal Storm Surge & Fire Evacuation Hub', TRUE
  ),
  (
    'caloocan_sports_complex',
    'Caloocan Sports Complex Evacuation Center',
    'Bagumbong Rd., North Caloocan',
    'Caloocan',
    14.7566, 121.0315,
    'Caloocan DRRMO Command Center', '(02) 5310-7536', 2800, TRUE,
    'Indoor Sports Arena, Emergency Shelter & Relief Staging', TRUE
  ),
  (
    'mandaluyong_city_gym',
    'Mandaluyong City Gymnasium Evacuation Hub',
    'Maysilo Circle, Plainview, Mandaluyong',
    'Mandaluyong',
    14.5777, 121.0338,
    'Mandaluyong CDRRMO Hotline', '(02) 8533-2225', 1500, TRUE,
    'City Hall Complex Gymnasium, First-Aid & Relief Hub', TRUE
  ),
  (
    'paranaque_sports_complex',
    'Parañaque City Sports Complex Evacuation Center',
    'Dr. A. Santos Ave. (Sucat Rd.), San Antonio, Parañaque',
    'Parañaque',
    14.4694, 121.0185,
    'Parañaque DRRMO Operations', '(02) 8820-7783', 2000, TRUE,
    'Covered Gymnasium, Medical Triage & Emergency Relief Center', TRUE
  ),
  (
    'muntinlupa_sports_center',
    'Muntinlupa Sports Center Evacuation Facility',
    'Civic Drive / Tunasan, Muntinlupa',
    'Muntinlupa',
    14.3792, 121.0475,
    'Muntinlupa DDRM Command Center', '137-175', 2200, TRUE,
    'Multi-Purpose Arena, Laguna Lake Flood Evacuation & Relief Hub', TRUE
  ),
  (
    'valenzuela_wes_arena',
    'Valenzuela City WES Arena Evacuation Center',
    'Punturin Rd., Brgy. Punturin, Valenzuela',
    'Valenzuela',
    14.7161, 120.9854,
    'Valenzuela CDRRMO Alert Center', '(02) 8352-5000', 2000, TRUE,
    'Modern Indoor Arena, Flood Evacuation & Emergency Medical Post', TRUE
  ),
  (
    'las_pinas_verdant_court',
    'Las Piñas City Disaster Evacuation Center',
    'Alabang-Zapote Rd., Pamplona Tres, Las Piñas',
    'Las Piñas',
    14.4506, 120.9828,
    'Las Piñas CDRRMO Hotline', '(02) 8290-6500', 1500, TRUE,
    'Covered Evacuation Facility, Relief Distribution & First-Aid', TRUE
  ),
  (
    'malabon_oreta_sports',
    'Malabon City Oreta Sports Complex Shelter',
    'C-4 Rd., Brgy. Longos, Malabon',
    'Malabon',
    14.6562, 120.9585,
    'Malabon MDRRMO Command Center', '(02) 8921-6009', 1800, TRUE,
    'High-Ground Flood & Tidal Surge Evacuation Arena', TRUE
  ),
  (
    'navotas_sports_complex',
    'Navotas City Sports Complex & Coastal Shelter',
    'M. Naval St., Brgy. Sipac-Almacen, Navotas',
    'Navotas',
    14.6667, 120.9469,
    'Navotas CDRRMO Hotline', '(02) 8281-1111', 1600, TRUE,
    'Coastal Storm Surge Evacuation Complex & Relief Center', TRUE
  ),
  (
    'san_juan_gym_shelter',
    'San Juan City Gymnasium Evacuation Center',
    'Pinaglabanan St., Corazon de Jesus, San Juan',
    'San Juan',
    14.6042, 121.0332,
    'San Juan CDRRMO Operations', '(02) 7729-0005', 1500, TRUE,
    'Indoor Evacuation Gym, Pinaglabanan Shrine Open Assembly Grounds', TRUE
  ),
  (
    'pateros_municipal_court',
    'Pateros Municipal Covered Court & Evacuation Hub',
    'G. de Borja St., Brgy. Aguho, Pateros',
    'Pateros',
    14.5446, 121.0667,
    'Pateros MDRRMO Rescue', '(02) 8642-5159', 900, TRUE,
    'Municipal Covered Court, Community Kitchen & First-Aid Station', TRUE
  )
ON CONFLICT (id) DO NOTHING;
