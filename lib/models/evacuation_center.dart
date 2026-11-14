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
  });
}
