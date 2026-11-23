# LifeCheckpoint: Multi-Platform Application in Emergency Monitoring and Disaster Preparedness

**Geographic Scope:** Metro Manila (National Capital Region)  
**Authors:** Dela Cruz, A.K.A., Domado, H.D., Guiang, J.A.A., Jumaquio, I.M.A., Manese, L.M.S., Olidan, A.E., Zuniega, H.P.  
**Approved Proposal Reference:** Slides 1–7  

---

## Architecture (Netlify + Supabase + Flutter)

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend (Multi-Platform)** | **Flutter** (Web PWA + Android APK) | Offline-first Go-Bag tracker, expiry alerts, disaster protocols, shelter radar, and ISO/IEC 25010 evaluation survey. |
| **Backend API** | **Netlify Functions** ([`netlify/functions/api.mts`](netlify/functions/api.mts)) | Serverless `/api/*` REST API for auth, household invite sync, cached weather/seismic telemetry, shelter updates, and Chapter 4 CSV export. |
| **Database** | **Supabase PostgreSQL** ([`supabase/schema.sql`](supabase/schema.sql)) | Persistent cloud storage for households, kit items, emergency plans, family safety check-ins, shelters, and ISO evaluations. |

---

## Research Questions & System Alignment

| SOP / Research Question (Slide 3) | Implemented Feature Module | Source Files |
| :--- | :--- | :--- |
| **Emergency Monitoring (Title & Slide 2 Note)** | Live GPS-aware weather telemetry (Open-Meteo via backend cache) & Philippine seismic feed (USGS/PH region) with offline fallback, defense drill simulator, and synced household check-ins. | [`lib/screens/emergency_monitoring_screen.dart`](lib/screens/emergency_monitoring_screen.dart)<br>[`lib/providers/monitoring_provider.dart`](lib/providers/monitoring_provider.dart) |
| **RQ 1.1 & Smart Recommender (Slide 2 Note)** | 72-hour Go-Bag digital checklist with **Smart Kit Recommender** scaling targets by household size and special needs. | [`lib/screens/kit_management_screen.dart`](lib/screens/kit_management_screen.dart)<br>[`lib/models/household_profile.dart`](lib/models/household_profile.dart) |
| **RQ 1.2: Emergency plans and contact details** | Synced **Household Emergency Plan** + 1-tap offline telephone dialer & SMS beacon for 911, Red Cross 143, BFP, PNP, NDRRMC, MMDA. | [`lib/screens/emergency_plan_screen.dart`](lib/screens/emergency_plan_screen.dart)<br>[`lib/screens/emergency_contacts_screen.dart`](lib/screens/emergency_contacts_screen.dart) |
| **RQ 1.3: Disaster preparedness safety guidelines** | Offline protocols for **Typhoon**, **Earthquake**, **Flood**, **Fire**, and **Volcano** across Before, During, and After phases. | [`lib/screens/disaster_guide_screen.dart`](lib/screens/disaster_guide_screen.dart)<br>[`lib/data/disaster_data.dart`](lib/data/disaster_data.dart) |
| **RQ 2.1–2.4: Supply monitoring & notifications** | Weighted readiness score (0–100%), expiry tracking, 1-tap **Mark Replaced**, PWA & Android native notifications, and clipboard restock list. | [`lib/providers/kit_provider.dart`](lib/providers/kit_provider.dart)<br>[`lib/screens/notifications_screen.dart`](lib/screens/notifications_screen.dart) |
| **GPS & Evacuation Map (Slide 2 Note)** | Web + native Android GPS (`MainActivity.kt`), offline **Interactive Shelter Radar**, Haversine sorting, and saved shelters. | [`lib/screens/evacuation_map_screen.dart`](lib/screens/evacuation_map_screen.dart)<br>[`lib/utils/location_service.dart`](lib/utils/location_service.dart) |
| **RQ 3 & 4 / Slide 6 Instrumentation** | Readiness Self-Checklist + **ISO/IEC 25010 Survey** synced to Supabase with Admin summary & CSV export for Chapter 4. | [`lib/screens/self_assessment_screen.dart`](lib/screens/self_assessment_screen.dart)<br>[`lib/screens/account_sync_screen.dart`](lib/screens/account_sync_screen.dart) |

---

## Setup & Deployment (Metro Manila Scope)

### 1. Create Supabase PostgreSQL Database
1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run [`supabase/schema.sql`](supabase/schema.sql) (also auto-bootstrapped by the API on first request).
3. Go to **Project Settings -> Database -> Connection string -> Transaction pooler (port 6543)** and copy the PostgreSQL URI.

### 2. Deploy Backend + Web PWA to Netlify
1. Install Node dependencies locally:
   ```bash
   npm install
   ```
2. Build the Flutter Web PWA:
   ```bash
   flutter build web --release --base-href /
   ```
3. In **Netlify** (`Site configuration -> Environment variables`, scope: **Functions**), set:
   - `SUPABASE_DB_URL` = your Supabase Postgres pooler URI
   - `JWT_SECRET` = a random 32+ character secret string
   - `ADMIN_INVITE_CODE` = e.g. `LC-DRRM-2026` (used by administrators to register as Admin and export CSV)
4. Deploy with Netlify CLI:
   ```bash
   npx netlify deploy --prod
   ```
   Send the resulting `https://<your-site>.netlify.app` URL to Metro Manila Web/iOS/Android users.

### 3. Build Production Android APK for Metro Manila Users
Bake your live Netlify URL into the APK so Android users sync to the exact same Supabase database:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<your-site>.netlify.app
```
Output APK: `build/app/outputs/flutter-apk/app-release.apk` (share via Google Drive or GitHub Releases).  
*(Users can also change the server URL anytime inside **Account & Cloud Sync -> Server**.)*

### 4. Run Automated Tests
```bash
npm run typecheck
npm run test:api
flutter test
```
