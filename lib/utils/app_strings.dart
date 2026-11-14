import '../models/kit_item.dart';

class AppStrings {
  final bool fil;

  const AppStrings(this.fil);

  // Navigation Tabs
  String get navHome => fil ? 'Tahanan' : 'Home';
  String get navKit => fil ? 'Go-Bag' : 'Kit';
  String get navMonitor => fil ? 'Bantay' : 'Monitor';
  String get navMap => fil ? 'Mapa' : 'Map';
  String get navSafety => fil ? 'Kaligtasan' : 'Safety';

  // Dashboard
  String get appSubtitle => fil
      ? 'Bantay-Sakuna at Kahandaan sa Bahay'
      : 'Emergency Monitoring & Preparedness';
  String get weightedScoreLabel =>
      fil ? 'MARKA NG KAHANDAAN' : 'WEIGHTED READINESS SCORE';
  String get weightedExplain => fil
      ? 'Mas mabigat ang marka ng Tubig, Pagkain at Gamot (3×)'
      : 'Critical survival items (Water, Food, Meds) weighted 3×';
  String get quickToolsTitle =>
      fil ? 'Mabilisang Serbisyo' : 'Preparedness Tools';
  String get replacementAlerts =>
      fil ? 'Mga Palitan at Abiso' : 'Replacement Alerts';
  String get readinessAudit =>
      fil ? 'Pagsusuri at Survey' : 'Self-Assessment & Survey';
  String get householdPlan =>
      fil ? 'Plano ng Pamilya' : 'My Emergency Plan';
  String get disasterGuides =>
      fil ? 'Gabay sa Sakuna' : 'Disaster Guides';

  // Readiness Status
  String readinessStatus(double score) {
    if (score >= 90) return fil ? 'Handang-Handa' : 'Fully Prepared';
    if (score >= 70) {
      return fil ? 'Sapat ang Kahandaan' : 'Substantially Prepared';
    }
    if (score >= 40) {
      return fil ? 'Katamtamang Kahandaan' : 'Moderately Prepared';
    }
    return fil ? 'Kailangan ng Aksyon' : 'Action Needed';
  }

  // Categories
  String categoryName(KitCategory cat) {
    if (!fil) return cat.displayName;
    switch (cat) {
      case KitCategory.waterAndFood:
        return 'Tubig at Pagkain';
      case KitCategory.medicalAndFirstAid:
        return 'Paunang Lunas at Gamot';
      case KitCategory.toolsAndLighting:
        return 'Kagamitan at Ilaw';
      case KitCategory.documentsAndCash:
        return 'Dokumento at Pera';
      case KitCategory.sanitationAndHygiene:
        return 'Kalinisan at Kalusugan';
      case KitCategory.clothingAndBedding:
        return 'Damit at Panlamig';
      case KitCategory.specialNeeds:
        return 'Sanggol, Senior at Alaga';
    }
  }

  // Drill & SOS
  String get drillBannerText => fil
      ? 'PAGSASANAY (DRILL MODE) — HINDI ITO TOTOONG SAKUNA'
      : 'SIMULATION / DRILL MODE — NOT A REAL EMERGENCY';
  String get exitDrill => fil ? 'Itigil' : 'Exit Drill';
  String get sosDispatchTitle =>
      fil ? 'Mabilisang Tawag at SOS' : 'Instant Emergency Dispatch';
  String get sosButtonLabel => 'SOS';
}
