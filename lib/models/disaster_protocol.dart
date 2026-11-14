enum DisasterType {
  typhoon,
  earthquake,
  flood,
  fire,
  volcanicEruption,
}

extension DisasterTypeExtension on DisasterType {
  String get title {
    switch (this) {
      case DisasterType.typhoon:
        return 'Typhoon & Tropical Cyclone (Bagyo)';
      case DisasterType.earthquake:
        return 'Earthquake (Lindol)';
      case DisasterType.flood:
        return 'Flooding & Flashflood (Baha)';
      case DisasterType.fire:
        return 'Structural Fire (Sunog)';
      case DisasterType.volcanicEruption:
        return 'Volcanic Eruption (Pagputok ng Bulkan)';
    }
  }

  String get shortName {
    switch (this) {
      case DisasterType.typhoon:
        return 'Typhoon';
      case DisasterType.earthquake:
        return 'Earthquake';
      case DisasterType.flood:
        return 'Flood';
      case DisasterType.fire:
        return 'Fire';
      case DisasterType.volcanicEruption:
        return 'Volcano';
    }
  }

  String get quickTip {
    switch (this) {
      case DisasterType.typhoon:
        return 'Secure roofs, charge devices, and know your LGU evacuation zone.';
      case DisasterType.earthquake:
        return 'Duck, Cover, and Hold! Stay away from glass and heavy objects.';
      case DisasterType.flood:
        return 'Evacuate before waters rise. Cut main electrical circuit breakers.';
      case DisasterType.fire:
        return 'Crawl low under smoke, feel doors before opening, get out and stay out!';
      case DisasterType.volcanicEruption:
        return 'Wear N95 masks, protect eyes, and prepare for ashfall accumulation.';
    }
  }
}

class DisasterGuide {
  final DisasterType type;
  final String overview;
  final List<String> beforeSteps;
  final List<String> duringSteps;
  final List<String> afterSteps;
  final List<String> essentialSupplies;

  const DisasterGuide({
    required this.type,
    required this.overview,
    required this.beforeSteps,
    required this.duringSteps,
    required this.afterSteps,
    required this.essentialSupplies,
  });
}
