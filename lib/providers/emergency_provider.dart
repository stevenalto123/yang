import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../models/evacuation_center.dart';
import '../models/emergency_plan.dart';
import '../data/emergency_hotlines_data.dart';
import '../data/evacuation_centers_data.dart';
import '../utils/location_service.dart';

class EmergencyProvider extends ChangeNotifier {
  static const String _personalContactsKey =
      'lifecheckpoint_personal_contacts_v1';
  static const String _emergencyPlanKey =
      'lifecheckpoint_emergency_plan_v1';
  static const String _customSheltersKey =
      'lifecheckpoint_custom_shelters_v1';

  List<EmergencyContact> _defaultContacts = [];
  List<EmergencyContact> _personalContacts = [];
  List<EvacuationCenter> _defaultCenters = [];
  List<EvacuationCenter> _customCenters = [];
  HouseholdEmergencyPlan _emergencyPlan = HouseholdEmergencyPlan();

  String _selectedCity = 'All';
  FacilityType? _selectedFacilityType;
  bool _isLoading = true;

  // GPS state (defaults to Paco, Manila reference until live GPS is fetched)
  double _userLat = 14.5822;
  double _userLng = 120.9882;
  bool _hasLiveGps = false;
  bool _isLocating = false;
  double? _gpsAccuracyMeters;

  void Function(Map<String, dynamic> planMap)? onPlanSaved;
  void Function(Map<String, dynamic> shelterMap)? onShelterAdded;
  void Function(String shelterId)? onShelterDeleted;

  EmergencyProvider() {
    _defaultContacts = getDefaultEmergencyContacts();
    _defaultCenters = getDefaultEvacuationCenters();
    _loadAllData();
  }

  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;
  FacilityType? get selectedFacilityType => _selectedFacilityType;
  HouseholdEmergencyPlan get emergencyPlan => _emergencyPlan;

  double get userLat => _userLat;
  double get userLng => _userLng;
  bool get hasLiveGps => _hasLiveGps;
  bool get isLocating => _isLocating;
  double? get gpsAccuracyMeters => _gpsAccuracyMeters;

  List<EmergencyContact> get allContacts =>
      [..._defaultContacts, ..._personalContacts];
  List<EmergencyContact> get defaultContacts =>
      List.unmodifiable(_defaultContacts);
  List<EmergencyContact> get personalContacts =>
      List.unmodifiable(_personalContacts);

  List<EvacuationCenter> get allEvacuationCenters =>
      [..._customCenters, ..._defaultCenters];

  List<String> get availableCities {
    final cities = allEvacuationCenters.map((e) => e.city).toSet().toList();
    return ['All', ...cities];
  }

  /// Returns facilities sorted by nearest Haversine distance from current GPS
  List<EvacuationCenter> get filteredEvacuationCenters {
    final base = allEvacuationCenters.where((center) {
      if (_selectedCity != 'All' && center.city != _selectedCity) {
        return false;
      }
      if (_selectedFacilityType != null &&
          center.facilityType != _selectedFacilityType) {
        return false;
      }
      return true;
    }).toList();

    final sorted = List<EvacuationCenter>.from(base);
    sorted.sort((a, b) {
      final distA =
          LocationService.distanceInKm(_userLat, _userLng, a.latitude, a.longitude);
      final distB =
          LocationService.distanceInKm(_userLat, _userLng, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });
    return sorted;
  }

  double distanceToCenterKm(EvacuationCenter center) {
    return LocationService.distanceInKm(
        _userLat, _userLng, center.latitude, center.longitude);
  }

  String bearingToCenter(EvacuationCenter center) {
    return LocationService.bearingTo(
            _userLat, _userLng, center.latitude, center.longitude)
        .cardinal;
  }

  void setSelectedCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }

  void setSelectedFacilityType(FacilityType? type) {
    _selectedFacilityType = type;
    notifyListeners();
  }

  Future<void> _loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load personal contacts
      final contactsJson = prefs.getString(_personalContactsKey);
      if (contactsJson != null && contactsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(contactsJson);
        _personalContacts =
            decoded.map((c) => EmergencyContact.fromMap(c)).toList();
      }

      // Load emergency plan
      final planJson = prefs.getString(_emergencyPlanKey);
      if (planJson != null && planJson.isNotEmpty) {
        _emergencyPlan = HouseholdEmergencyPlan.fromJson(planJson);
      }

      // Load custom shelters
      final sheltersJson = prefs.getString(_customSheltersKey);
      if (sheltersJson != null && sheltersJson.isNotEmpty) {
        final List<dynamic> decodedShelters = json.decode(sheltersJson);
        _customCenters = decodedShelters
            .map((s) => EvacuationCenter(
                  id: s['id'] ?? '',
                  name: s['name'] ?? '',
                  address: s['address'] ?? '',
                  city: s['city'] ?? 'Local',
                  latitude: (s['latitude'] ?? 14.5822).toDouble(),
                  longitude: (s['longitude'] ?? 120.9882).toDouble(),
                  contactPerson: s['contactPerson'] ?? 'Barangay Officer',
                  contactNumber: s['contactNumber'] ?? '911',
                  capacityPeople: s['capacityPeople'] ?? 500,
                  isOpen: s['isOpen'] ?? true,
                  facilities: s['facilities'] ?? 'Community Shelter',
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading emergency data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _savePersonalContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString =
          json.encode(_personalContacts.map((c) => c.toMap()).toList());
      await prefs.setString(_personalContactsKey, jsonString);
    } catch (e) {
      debugPrint('Error saving personal contacts: $e');
    }
  }

  Future<void> saveEmergencyPlan(HouseholdEmergencyPlan plan) async {
    _emergencyPlan = plan;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emergencyPlanKey, plan.toJson());
    } catch (e) {
      debugPrint('Error saving emergency plan: $e');
    }
    onPlanSaved?.call(plan.toMap());
  }

  Future<void> applyRemotePlan(Map<String, dynamic> planMap) async {
    final remote = HouseholdEmergencyPlan.fromMap(planMap);
    if (!remote.lastUpdated.isBefore(_emergencyPlan.lastUpdated) ||
        (_emergencyPlan.homeAddress.isEmpty && remote.homeAddress.isNotEmpty)) {
      _emergencyPlan = remote;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_emergencyPlanKey, remote.toJson());
      } catch (_) {}
      notifyListeners();
    }
  }

  bool isCustomCenter(String id) => _customCenters.any((c) => c.id == id);

  Future<void> removeCustomEvacuationCenter(String id) async {
    final removed = _customCenters.any((c) => c.id == id);
    if (!removed) return;
    _customCenters.removeWhere((c) => c.id == id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customCenters
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'address': c.address,
                'city': c.city,
                'latitude': c.latitude,
                'longitude': c.longitude,
                'contactPerson': c.contactPerson,
                'contactNumber': c.contactNumber,
                'capacityPeople': c.capacityPeople,
                'isOpen': c.isOpen,
                'facilities': c.facilities,
              })
          .toList();
      await prefs.setString(_customSheltersKey, json.encode(list));
    } catch (e) {
      debugPrint('Error removing custom shelter: $e');
    }
    onShelterDeleted?.call(id);
  }

  Future<void> addCustomEvacuationCenter(EvacuationCenter center) async {
    _customCenters.insert(0, center);
    notifyListeners();
    final centerMap = {
      'id': center.id,
      'name': center.name,
      'address': center.address,
      'city': center.city,
      'latitude': center.latitude,
      'longitude': center.longitude,
      'contactPerson': center.contactPerson,
      'contactNumber': center.contactNumber,
      'capacityPeople': center.capacityPeople,
      'isOpen': center.isOpen,
      'facilities': center.facilities,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customCenters
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'address': c.address,
                'city': c.city,
                'latitude': c.latitude,
                'longitude': c.longitude,
                'contactPerson': c.contactPerson,
                'contactNumber': c.contactNumber,
                'capacityPeople': c.capacityPeople,
                'isOpen': c.isOpen,
                'facilities': c.facilities,
              })
          .toList();
      await prefs.setString(_customSheltersKey, json.encode(list));
    } catch (e) {
      debugPrint('Error saving custom shelter: $e');
    }
    onShelterAdded?.call(centerMap);
  }

  Future<void> applyRemoteShelters(List<Map<String, dynamic>> shelters) async {
    if (shelters.isEmpty) return;

    final officialList = <EvacuationCenter>[];
    final customList = <EvacuationCenter>[];

    for (final s in shelters) {
      final center = EvacuationCenter(
        id: (s['id'] ?? '').toString(),
        name: (s['name'] ?? '').toString(),
        address: (s['address'] ?? '').toString(),
        city: (s['city'] ?? 'Manila').toString(),
        latitude: (s['latitude'] as num?)?.toDouble() ?? 14.5822,
        longitude: (s['longitude'] as num?)?.toDouble() ?? 120.9882,
        contactPerson: (s['contactPerson'] ?? 'DRRMO Officer').toString(),
        contactNumber: (s['contactNumber'] ?? '911').toString(),
        capacityPeople: (s['capacityPeople'] as num?)?.toInt() ?? 500,
        isOpen: s['isOpen'] == null ? true : s['isOpen'] == true,
        facilities: (s['facilities'] ?? '').toString(),
      );
      if (s['isOfficial'] == true) {
        officialList.add(center);
      } else {
        customList.add(center);
      }
    }

    if (officialList.isNotEmpty) {
      final mergedDefaults = {for (final c in _defaultCenters) c.id: c};
      for (final c in officialList) {
        if (c.id == 'eac_campus_reference') continue;
        mergedDefaults[c.id] = c;
      }
      mergedDefaults.remove('eac_campus_reference');
      _defaultCenters = mergedDefaults.values.toList();
    }
    if (customList.isNotEmpty) {
      final merged = {for (final c in _customCenters) c.id: c};
      for (final c in customList) {
        merged[c.id] = c;
      }
      _customCenters = merged.values.toList();
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = _customCenters
            .map((c) => {
                  'id': c.id,
                  'name': c.name,
                  'address': c.address,
                  'city': c.city,
                  'latitude': c.latitude,
                  'longitude': c.longitude,
                  'contactPerson': c.contactPerson,
                  'contactNumber': c.contactNumber,
                  'capacityPeople': c.capacityPeople,
                  'isOpen': c.isOpen,
                  'facilities': c.facilities,
                })
            .toList();
        await prefs.setString(_customSheltersKey, json.encode(list));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> detectLiveGps() async {
    _isLocating = true;
    notifyListeners();

    final pos = await LocationService.getCurrentPosition();
    _isLocating = false;

    if (pos != null) {
      _userLat = pos.lat;
      _userLng = pos.lng;
      _gpsAccuracyMeters = pos.accuracy;
      _hasLiveGps = true;
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  void setManualLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _hasLiveGps = false;
    notifyListeners();
  }

  void addPersonalContact(EmergencyContact contact) {
    _personalContacts.add(contact);
    _savePersonalContacts();
    notifyListeners();
  }

  void removePersonalContact(String id) {
    _personalContacts.removeWhere((c) => c.id == id);
    _savePersonalContacts();
    notifyListeners();
  }

  /// Launch phone dialer directly (Works offline via native cellular telecommunications)
  Future<bool> makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri callUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(callUri)) {
        return await launchUrl(callUri);
      }
    } catch (e) {
      debugPrint('Cannot launch dialer: $e');
    }
    return false;
  }

  /// Send emergency SMS broadcast beacon with location info
  Future<bool> sendEmergencySms({
    required String phoneNumber,
    required String message,
  }) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanNumber,
      queryParameters: <String, String>{
        'body': message,
      },
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      }
    } catch (e) {
      debugPrint('Cannot launch SMS: $e');
    }
    return false;
  }

  /// Open coordinates in Maps app or browser
  Future<bool> openMapLocation(double lat, double lng, String label) async {
    final Uri mapUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(mapUri)) {
        return await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Cannot launch maps: $e');
    }
    return false;
  }
}
