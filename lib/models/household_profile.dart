import 'dart:convert';

class HouseholdProfile {
  final int adults;
  final int children;
  final int infants;
  final int seniors;
  final int pets;
  final bool isFloodProne;
  final bool isEarthquakeZone;
  final bool hasChronicMedicalNeeds;

  const HouseholdProfile({
    this.adults = 2,
    this.children = 0,
    this.infants = 0,
    this.seniors = 0,
    this.pets = 0,
    this.isFloodProne = true,
    this.isEarthquakeZone = true,
    this.hasChronicMedicalNeeds = false,
  });

  int get totalPeople => (adults + children + infants + seniors).clamp(1, 50);

  Map<String, dynamic> toMap() {
    return {
      'adults': adults,
      'children': children,
      'infants': infants,
      'seniors': seniors,
      'pets': pets,
      'isFloodProne': isFloodProne,
      'isEarthquakeZone': isEarthquakeZone,
      'hasChronicMedicalNeeds': hasChronicMedicalNeeds,
    };
  }

  factory HouseholdProfile.fromMap(Map<String, dynamic> map) {
    return HouseholdProfile(
      adults: map['adults'] ?? 2,
      children: map['children'] ?? 0,
      infants: map['infants'] ?? 0,
      seniors: map['seniors'] ?? 0,
      pets: map['pets'] ?? 0,
      isFloodProne: map['isFloodProne'] ?? true,
      isEarthquakeZone: map['isEarthquakeZone'] ?? true,
      hasChronicMedicalNeeds: map['hasChronicMedicalNeeds'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory HouseholdProfile.fromJson(String source) =>
      HouseholdProfile.fromMap(json.decode(source));
}
