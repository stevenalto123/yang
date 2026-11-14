# LifeCheckpoint: Multi-Platform Application in Emergency Monitoring and Disaster Preparedness

**Institution:** Emilio Aguinaldo College (EAC)  
**Authors:** Dela Cruz, A.K.A., Domado, H.D., Guiang, J.A.A., Jumaquio, I.M.A., Manese, L.M.S., Olidan, A.E., Zuniega, H.P.  
**Approved Proposal Reference:** Slides 2–7  

---

## 🎯 Research Questions & System Feature Alignment

| SOP / Research Question (Slide 3) | Implemented Feature Module | Source File |
| :--- | :--- | :--- |
| **RQ 1.1: Digital checklist of essential emergency supplies** | 72-hour survival Go-Bag checklist categorized into Water & Food, First Aid, Tools, Documents, Sanitation, and Clothing. | [`lib/screens/kit_management_screen.dart`](lib/screens/kit_management_screen.dart)<br>[`lib/data/default_kit_items.dart`](lib/data/default_kit_items.dart) |
| **RQ 1.2: Emergency plans and contact details** | 1-tap offline telephone dialer & SMS emergency beacon for National 911, Philippine Red Cross 143, BFP, PNP, NDRRMC, MMDA, and personal family contacts. | [`lib/screens/emergency_contacts_screen.dart`](lib/screens/emergency_contacts_screen.dart)<br>[`lib/data/emergency_hotlines_data.dart`](lib/data/emergency_hotlines_data.dart) |
| **RQ 1.3: Disaster preparedness information & safety guidelines** | Step-by-step offline disaster protocols for **Typhoon (Bagyo)**, **Earthquake (Lindol)**, **Flood (Baha)**, **Fire (Sunog)**, and **Volcano (Bulkan)** with Before, During, and After action phases. | [`lib/screens/disaster_guide_screen.dart`](lib/screens/disaster_guide_screen.dart)<br>[`lib/data/disaster_data.dart`](lib/data/disaster_data.dart) |
| **RQ 2.1: Monitoring availability of emergency supplies** | Live visual readiness score (0–100%), packed vs missing items tracker, and quantity control steppers. | [`lib/providers/kit_provider.dart`](lib/providers/kit_provider.dart) |
| **RQ 2.2: Updating and tracking expiration dates** | Calendar DatePicker integration, countdown of remaining days, and automated shelf-life badges. | [`lib/models/kit_item.dart`](lib/models/kit_item.dart) |
| **RQ 2.3: Identifying missing or expired items** | Instant status chips & visual alerts highlighting expired medications and unpacked rations. | [`lib/screens/kit_management_screen.dart`](lib/screens/kit_management_screen.dart) |
| **RQ 2.4: Sending notifications for necessary replacements** | Dynamic dashboard banner alerts and navigation badges warning households when supplies expire within 30 days or have expired. | [`lib/screens/home_dashboard_screen.dart`](lib/screens/home_dashboard_screen.dart) |
| **RQ 3 & 4: Performance, Usability & Effectiveness Evaluation (Slide 6)** | Built-in **Readiness Self-Assessment Audit & ISO 25010 Usability Testing instrumentation** matching the capstone evaluation criteria. | [`lib/screens/self_assessment_screen.dart`](lib/screens/self_assessment_screen.dart) |
| **Evacuation Center Locator (Slide 2 Note)** | Designated emergency shelters directory (EAC Gym, Paco, Ermita, Quezon City, Cavite) with offline coordinates, facilities, and contact details. | [`lib/screens/evacuation_map_screen.dart`](lib/screens/evacuation_map_screen.dart)<br>[`lib/data/evacuation_centers_data.dart`](lib/data/evacuation_centers_data.dart) |

---

## 🚀 How to Run the Application

### 1. Run Live in Browser (Instant Preview)
```bash
flutter run -d chrome
```
*(Or preview the pre-compiled production build directly from `build/web/index.html` via any local HTTP server like `npx serve build/web`).*

### 2. Run on Connected Android Device or Emulator
```bash
flutter run -d android
```

### 3. Build Production Android APK (For Panel Defense & Usability Testing)
```bash
flutter build apk --release
```
The output APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### 4. Run Automated Test Suite
```bash
flutter test
```
*(All unit and widget tests verify readiness calculations, expiration detectors, and search/filtering algorithms).*

---

## 🏛️ Project Directory Structure

```
lib/
├── data/
│   ├── default_kit_items.dart          # Standard 72-hour survival Go-Bag items (NDRRMC/Red Cross)
│   ├── disaster_data.dart              # Multi-hazard disaster guidelines (Typhoon, Quake, Flood, Fire, Volcano)
│   ├── emergency_hotlines_data.dart    # Philippine national & local emergency hotlines
│   └── evacuation_centers_data.dart    # Evacuation centers (EAC Gym, Manila, QC, Cavite)
├── models/
│   ├── disaster_protocol.dart          # Disaster hazard & phase models
│   ├── emergency_contact.dart          # Contact & hotline models
│   ├── evacuation_center.dart          # Safe zone & shelter models
│   └── kit_item.dart                   # Supply item & expiration logic
├── providers/
│   ├── emergency_provider.dart         # Emergency dialer, SMS beacon & location launcher
│   └── kit_provider.dart               # Offline local persistence (SharedPreferences) & readiness analytics
├── screens/
│   ├── disaster_guide_screen.dart      # Hazard protocols (Before, During, After)
│   ├── emergency_contacts_screen.dart  # 1-tap dialer & ICE family contacts
│   ├── evacuation_map_screen.dart      # Shelter finder with facilities & navigation
│   ├── home_dashboard_screen.dart      # Readiness gauge, critical alert banners & quick SOS
│   ├── kit_management_screen.dart      # Categorized checklist, expiry badges & item CRUD
│   └── self_assessment_screen.dart     # Capstone research instrument & audit report
├── utils/
│   └── app_theme.dart                  # EAC Institutional Crimson & Disaster Alert design system
└── main.dart                           # Entry point with bottom navigation bar & badge alerts
```
