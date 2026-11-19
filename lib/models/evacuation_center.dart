enum FacilityType {
  evacuationShelter,
  hospital,
  policeFire,
}

extension FacilityTypeExtension on FacilityType {
  String get displayName {
    switch (this) {
      case FacilityType.evacuationShelter:
        return 'Evacuation Center';
      case FacilityType.hospital:
        return 'Hospital / Medical';
      case FacilityType.policeFire:
        return 'Police & Fire Station';
    }
  }

  String get shortLabel {
    switch (this) {
      case FacilityType.evacuationShelter:
        return 'Shelters';
      case FacilityType.hospital:
        return 'Hospitals';
      case FacilityType.policeFire:
        return 'Police & Fire';
    }
  }

  static FacilityType fromString(String? value) {
    switch (value) {
      case 'hospital':
        return FacilityType.hospital;
      case 'policeFire':
        return FacilityType.policeFire;
      default:
        return FacilityType.evacuationShelter;
    }
  }
}

class EvacuationCenter {
  final String id;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String contactPerson;
  final String contactNumber;
  final int capacityPeople;
  final bool isOpen;
  final String facilities;
  final FacilityType facilityType;

  const EvacuationCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.contactPerson,
    required this.contactNumber,
    required this.capacityPeople,
    this.isOpen = true,
    required this.facilities,
    this.facilityType = FacilityType.evacuationShelter,
  });
}
