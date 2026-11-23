# LifeCheckpoint: Multi-Platform Application in Emergency Monitoring and Disaster Preparedness

**Geographic Scope:** City of Manila  
**Authors:** Dela Cruz, A.K.A., Domado, H.D., Guiang, J.A.A., Jumaquio, I.M.A., Manese, L.M.S., Olidan, A.E., Zuniega, H.P.  
**Approved Proposal Reference:** Slides 1–7  

---

## Architecture (Vercel + Supabase + Flutter)

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend (Multi-Platform)** | **Flutter** (Web PWA + Android APK) | Offline-first Go-Bag tracker, expiry alerts, disaster protocols, City of Manila shelter map, and ISO/IEC 25010 evaluation survey. |
| **Backend API** | **Vercel Serverless API** ([`api/index.ts`](api/index.ts) + [`netlify/lib/`](netlify/lib/)) | Serverless `/api/*` REST API for auth, household invite sync, cached weather/seismic telemetry, official Manila DRRMO advisories & shelters, RA 10173 account erasure, and Chapter 4 CSV export. |
| **Database** | **Supabase PostgreSQL** ([`supabase/schema.sql`](supabase/schema.sql)) | Persistent cloud storage with Row-Level Security (RLS) for households, kit items, emergency plans, family safety check-ins, shelters, advisories, and ISO evaluations. |

---

## Research Questions & System Alignment

| SOP / Research Question (Slide 3) | Implemented Feature Module | Source Files |
| :--- | :--- | :--- |
| **Emergency Monitoring (Title & Slide 2 Note)** | Live GPS-aware City of Manila weather, PAGASA Heat Index & 6-hour rain forecast (Open-Meteo via backend cache), Luzon/Manila seismic feed (USGS), Manila flood-watch corridors, official DRRM advisories, defense drill simulator, and synced household check-ins. | [`lib/screens/emergency_monitoring_screen.dart`](lib/screens/emergency_monitoring_screen.dart)<br>[`lib/providers/monitoring_provider.dart`](lib/providers/monitoring_provider.dart) |
| **RQ 1.1 & Smart Recommender (Slide 2 Note)** | 72-hour Go-Bag digital checklist with **Smart Kit Recommender** scaling targets by household size and special needs. | [`lib/screens/kit_management_screen.dart`](lib/screens/kit_management_screen.dart)<br>[`lib/models/household_profile.dart`](lib/models/household_profile.dart) |
| **RQ 1.2: Emergency plans and contact details** | Synced **Household Emergency Plan** & ICE card + 1-tap offline dialer & SMS beacon for 911, Red Cross 143, Manila DRRMO `(02) 8568-6909`, BFP Manila Fire District (19 units), and MPD Command & 11 stations + PCP sub-stations. | [`lib/screens/emergency_plan_screen.dart`](lib/screens/emergency_plan_screen.dart)<br>[`lib/screens/emergency_contacts_screen.dart`](lib/screens/emergency_contacts_screen.dart) |
| **RQ 1.3: Disaster preparedness safety guidelines** | Offline protocols for **Typhoon**, **Earthquake**, **Flood**, **Fire**, **Landslide**, and **Volcano** across Before, During, and After phases with interactive step progress. | [`lib/screens/disaster_guide_screen.dart`](lib/screens/disaster_guide_screen.dart)<br>[`lib/data/disaster_data.dart`](lib/data/disaster_data.dart) |
| **RQ 2.1–2.4: Supply monitoring & notifications** | Weighted readiness score (0–100%), expiry tracking, 1-tap **Mark Replaced**, PWA & Android native notifications, and clipboard restock list. | [`lib/providers/kit_provider.dart`](lib/providers/kit_provider.dart)<br>[`lib/screens/notifications_screen.dart`](lib/screens/notifications_screen.dart) |
| **GPS & Evacuation Map (Slide 2 Note)** | Web + native Android GPS (`MainActivity.kt`), offline **Interactive City of Manila Shelter Map** (37 facilities), Haversine sorting, walk/drive ETA, and full-screen Manila location picker. | [`lib/screens/evacuation_map_screen.dart`](lib/screens/evacuation_map_screen.dart)<br>[`lib/widgets/manila_map_picker.dart`](lib/widgets/manila_map_picker.dart) |
| **RQ 3 & 4 / Slide 6 Instrumentation** | Readiness Self-Checklist + **ISO/IEC 25010 Survey** synced to Supabase with dedicated Admin Portal summary & CSV export for Chapter 4. | [`lib/screens/self_assessment_screen.dart`](lib/screens/self_assessment_screen.dart)<br>[`lib/screens/admin_dashboard_screen.dart`](lib/screens/admin_dashboard_screen.dart) |

---

## Setup & Deployment (City of Manila Scope)

### 1. Create Supabase PostgreSQL Database
1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run [`supabase/schema.sql`](supabase/schema.sql) (also auto-bootstrapped by the API on first request).
3. Go to **Project Settings -> Database -> Connection string -> Transaction pooler (port 6543)** and copy the PostgreSQL URI.

### 2. Deploy Backend + Web PWA to Vercel
1. Connect the GitHub repository (`master` production branch) to **Vercel** (uses [`vercel.json`](vercel.json) and [`scripts/build-web.mjs`](scripts/build-web.mjs)).
2. In **Vercel** (`Settings -> Environment Variables`), set:
   - `SUPABASE_DB_URL` = your Supabase Postgres pooler URI
   - `JWT_SECRET` = a random 32+ character secret string
   - `ADMIN_INVITE_CODE` = administrator access code
3. Push to `master` (or run [`push_only.bat`](push_only.bat)) — Vercel builds and publishes to `https://lifecheckpoint.vercel.app`.

### 3. Build Production Android APK for City of Manila Users
Bake your live Vercel URL into the APK so Android users sync to the exact same Supabase database:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://lifecheckpoint.vercel.app
```
Output APK: `build/app/outputs/flutter-apk/app-release.apk`.  
*(Users can also change the server URL anytime inside **Family Backup & Sync -> Server**.)*

### 4. Run Automated Tests
```bash
npm run typecheck
npm run test:api
flutter test
```
