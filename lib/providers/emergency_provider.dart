import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../models/evacuation_center.dart';
import '../data/emergency_hotlines_data.dart';
import '../data/evacuation_centers_data.dart';

class EmergencyProvider extends ChangeNotifier {
  static const String _personalContactsKey = 'lifecheckpoint_personal_contacts_v1';

  List<EmergencyContact> _defaultContacts = [];
  List<EmergencyContact> _personalContacts = [];
  List<EvacuationCenter> _evacuationCenters = [];
  String _selectedCity = 'All';
  bool _isLoading = true;

  EmergencyProvider() {
    _defaultContacts = getDefaultEmergencyContacts();
    _evacuationCenters = getDefaultEvacuationCenters();
    loadPersonalContacts();
  }

  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;

  List<EmergencyContact> get allContacts => [..._defaultContacts, ..._personalContacts];
  List<EmergencyContact> get defaultContacts => List.unmodifiable(_defaultContacts);
  List<EmergencyContact> get personalContacts => List.unmodifiable(_personalContacts);

  List<String> get availableCities {
    final cities = _evacuationCenters.map((e) => e.city).toSet().toList();
    return ['All', ...cities];
  }

  List<EvacuationCenter> get filteredEvacuationCenters {
    if (_selectedCity == 'All') return _evacuationCenters;
    return _evacuationCenters.where((center) => center.city == _selectedCity).toList();
  }

  void setSelectedCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }

  Future<void> loadPersonalContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_personalContactsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonString);
        _personalContacts = decoded.map((c) => EmergencyContact.fromMap(c)).toList();
      }
    } catch (e) {
      debugPrint('Error loading personal contacts: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _savePersonalContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_personalContacts.map((c) => c.toMap()).toList());
      await prefs.setString(_personalContactsKey, jsonString);
    } catch (e) {
      debugPrint('Error saving personal contacts: $e');
    }
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
    // Strip non-dialable characters except '+'
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
    final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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
