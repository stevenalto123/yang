import 'dart:convert';

class FamilyMemberProfile {
  final String id;
  final String name;
  final String roleOrAge;
  final String bloodType;
  final String medicalConditions;

  const FamilyMemberProfile({
    required this.id,
    required this.name,
    this.roleOrAge = '',
    this.bloodType = 'Unknown',
    this.medicalConditions = 'None',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'roleOrAge': roleOrAge,
        'bloodType': bloodType,
        'medicalConditions': medicalConditions,
      };

  factory FamilyMemberProfile.fromMap(Map<String, dynamic> map) {
    return FamilyMemberProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      roleOrAge: map['roleOrAge'] ?? '',
      bloodType: map['bloodType'] ?? 'Unknown',
      medicalConditions: map['medicalConditions'] ?? 'None',
    );
  }
}

class HouseholdEmergencyPlan {
  final String householdName;
  final String homeAddress;
  final String primaryMeetingPoint;
  final String secondaryEvacuationSite;
  final String goBagLocation;
  final String mainBreakerLocation;
  final String lpgValveLocation;
  final String waterValveLocation;
  final List<FamilyMemberProfile> members;
  final DateTime lastUpdated;

  HouseholdEmergencyPlan({
    this.householdName = 'My Household',
    this.homeAddress = '',
    this.primaryMeetingPoint = 'Outside front gate / Barangay Covered Court',
    this.secondaryEvacuationSite = 'EAC Sports Gymnasium / Local School Shelter',
    this.goBagLocation = 'Hallway closet beside the main exit door',
    this.mainBreakerLocation = 'Near kitchen / utility panel',
    this.lpgValveLocation = 'Under kitchen counter stove',
    this.waterValveLocation = 'Front yard meter box',
    this.members = const [],
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'householdName': householdName,
        'homeAddress': homeAddress,
        'primaryMeetingPoint': primaryMeetingPoint,
        'secondaryEvacuationSite': secondaryEvacuationSite,
        'goBagLocation': goBagLocation,
        'mainBreakerLocation': mainBreakerLocation,
        'lpgValveLocation': lpgValveLocation,
        'waterValveLocation': waterValveLocation,
        'members': members.map((m) => m.toMap()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory HouseholdEmergencyPlan.fromMap(Map<String, dynamic> map) {
    return HouseholdEmergencyPlan(
      householdName: map['householdName'] ?? 'My Household',
      homeAddress: map['homeAddress'] ?? '',
      primaryMeetingPoint: map['primaryMeetingPoint'] ??
          'Outside front gate / Barangay Covered Court',
      secondaryEvacuationSite: map['secondaryEvacuationSite'] ??
          'EAC Sports Gymnasium / Local School Shelter',
      goBagLocation: map['goBagLocation'] ??
          'Hallway closet beside the main exit door',
      mainBreakerLocation:
          map['mainBreakerLocation'] ?? 'Near kitchen / utility panel',
      lpgValveLocation:
          map['lpgValveLocation'] ?? 'Under kitchen counter stove',
      waterValveLocation: map['waterValveLocation'] ?? 'Front yard meter box',
      members: (map['members'] as List<dynamic>?)
              ?.map((e) => FamilyMemberProfile.fromMap(e))
              .toList() ??
          [],
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory HouseholdEmergencyPlan.fromJson(String source) =>
      HouseholdEmergencyPlan.fromMap(json.decode(source));
}
