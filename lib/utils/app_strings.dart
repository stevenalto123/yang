import '../models/kit_item.dart';

class AppStrings {
  final bool fil;

  const AppStrings(this.fil);

  // Navigation Tabs (Clear, everyday language)
  String get navHome => fil ? 'Tahanan' : 'Home';
  String get navKit => fil ? 'Go-Bag' : 'Go-Bag';
  String get navMonitor => fil ? 'Alerto' : 'Alerts';
  String get navMap => fil ? 'Malapit' : 'Nearby';
  String get navSafety => fil ? 'Gabay' : 'Safety';

  // Dashboard
  String get appSubtitle =>
      fil ? 'Kahandaan ng Pamilya' : 'Family Preparedness';
  String get weightedScoreLabel =>
      fil ? 'KAHANDAAN NG GO-BAG' : 'GO-BAG READINESS';
  String get weightedExplain => fil
      ? 'Unahin ang Tubig, Pagkain, at Gamot para sa 72 oras'
      : 'Prioritizes Water, Food, and Medicine for 72 hours';
  String get quickToolsTitle =>
      fil ? 'Mabilisang Aksyon' : 'Quick Actions';
  String get replacementAlerts =>
      fil ? 'Palitan at Expiration' : 'Expiring & Missing';
  String get readinessAudit =>
      fil ? 'Pagsusuri at Feedback' : 'Readiness & Feedback';
  String get householdPlan =>
      fil ? 'Plano ng Pamilya' : 'Family Plan';
  String get disasterGuides =>
      fil ? 'Gabay sa Sakuna' : 'Disaster Guides';

  // Readiness Status
  String readinessStatus(double score) {
    if (score >= 90) return fil ? 'Handang-Handa' : 'Ready for Emergencies';
    if (score >= 70) {
      return fil ? 'Halos Handa Na' : 'Almost Ready';
    }
    if (score >= 40) {
      return fil ? 'May Kulang Pa' : 'In Progress';
    }
    return fil ? 'Kailangan Ihanda' : 'Needs Attention';
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

  // Practice Drill & SOS
  String get drillBannerText => fil
      ? 'PRACTICE DRILL LAMANG — HINDI ITO TOTOONG SAKUNA'
      : 'PRACTICE DRILL ACTIVE — NOT A REAL EMERGENCY';
  String get exitDrill => fil ? 'Tapusin' : 'End Drill';
  String get sosDispatchTitle =>
      fil ? 'Mabilisang Tawag at SOS' : 'Emergency Help & SOS';
  String get sosButtonLabel => 'SOS';
}
