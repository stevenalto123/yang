# LifeCheckpoint: Multi-Platform Application in Emergency Monitoring and Disaster Preparedness

**Institution:** Emilio Aguinaldo College (EAC)  
**Authors:** Dela Cruz, A.K.A., Domado, H.D., Guiang, J.A.A., Jumaquio, I.M.A., Manese, L.M.S., Olidan, A.E., Zuniega, H.P.  
**Approved Proposal Reference:** Slides 2–7  

---

## 🎯 Research Questions & System Feature Alignment

| SOP / Research Question (Slide 3) | Implemented Feature Module | Source File |
| :--- | :--- | :--- |
| **Emergency Monitoring (Title & Slide 2 Note)** | Live Metro Manila weather telemetry (Open-Meteo) & Philippine seismic feed (USGS/PH region) with offline cache fallback, defense drill simulator, and household safety check-in log. | [`lib/screens/emergency_monitoring_screen.dart`](lib/screens/emergency_monitoring_screen.dart)<br>[`lib/providers/monitoring_provider.dart`](lib/providers/monitoring_provider.dart) |
| **RQ 1.1 & Smart Recommender (Slide 2 Note)** | 72-hour Go-Bag digital checklist with **Smart Kit Recommender** that scales targets by household size and adds tailored gear for infants, seniors, pets, flood-prone & earthquake zones. | [`lib/screens/kit_management_screen.dart`](lib/screens/kit_management_screen.dart)<br>[`lib/models/household_profile.dart`](lib/models/household_profile.dart) |
| **RQ 1.2: Emergency plans and contact details** | Customizable **Household Emergency Plan** (meeting points, utility shutoffs, family blood/medical profiles) + 1-tap offline telephone dialer & SMS beacon for 911, Red Cross 143, BFP, PNP, NDRRMC, MMDA. | [`lib/screens/emergency_plan_screen.dart`](lib/screens/emergency_plan_screen.dart)<br>[`lib/screens/emergency_contacts_screen.dart`](lib/screens/emergency_contacts_screen.dart) |
| **RQ 1.3: Disaster preparedness safety guidelines** | Offline disaster protocols for **Typhoon (Bagyo)**, **Earthquake (Lindol)**, **Flood (Baha)**, **Fire (Sunog)**, and **Volcano (Bulkan)** across Before, During, and After phases. | [`lib/screens/disaster_guide_screen.dart`](lib/screens/disaster_guide_screen.dart)<br>[`lib/data/disaster_data.dart`](lib/data/disaster_data.dart) |
| **RQ 2.1–2.3: Monitoring availability, expiry & missing items** | Live readiness gauge (0–100%), consistent packed/missing counts, DatePicker expiry tracking, status filters, and 1-tap **Mark Replaced**. | [`lib/providers/kit_provider.dart`](lib/providers/kit_provider.dart)<br>[`lib/models/kit_item.dart`](lib/models/kit_item.dart) |
| **RQ 2.4: Replacement notifications** | **Replacement Alerts & Restock Center** with configurable lead-time warnings (7/14/30/60 days), PWA Web Notification API alerts, and clipboard restock shopping list export. | [`lib/screens/notifications_screen.dart`](lib/screens/notifications_screen.dart)<br>[`lib/utils/notification_helper.dart`](lib/utils/notification_helper.dart) |
| **GPS & Evacuation Map (Slide 2 Note)** | Browser/device GPS detection, offline **Interactive Shelter Radar**, Haversine distance & compass bearing sorting, plus custom barangay shelter storage. | [`lib/screens/evacuation_map_screen.dart`](lib/screens/evacuation_map_screen.dart)<br>[`lib/utils/location_service.dart`](lib/utils/location_service.dart) |
| **RQ 3 & 4 / Slide 6 Instrumentation** | Readiness Self-Checklist audit + interactive **ISO/IEC 25010 Usability & Effectiveness Survey** with full report export. | [`lib/screens/self_assessment_screen.dart`](lib/screens/self_assessment_screen.dart) |

---

## 🚀 How to Run & Test

### 1. Run Live in Browser (PWA)
```bash
flutter run -d chrome
```
Or start the local static server after `flutter build web --base-href /`:
```bash
node serve_web.js
```

### 2. Build Production Android APK
```bash
flutter build apk --release
```
Output APK: `build/app/outputs/flutter-apk/app-release.apk`

### 3. Run Automated Tests
```bash
flutter test
```
