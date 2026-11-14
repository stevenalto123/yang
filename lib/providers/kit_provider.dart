import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kit_item.dart';
import '../models/household_profile.dart';
import '../data/default_kit_items.dart';

enum ItemFilterStatus {
  all,
  missing,
  expiringSoon,
  expired,
  packed,
}

class KitProvider extends ChangeNotifier {
  static const String _storageKey = 'lifecheckpoint_kit_items_v1';
  static const String _profileKey = 'lifecheckpoint_household_profile_v1';
  static const String _alertDaysKey = 'lifecheckpoint_expiry_alert_days_v1';

  List<KitItem> _items = [];
  HouseholdProfile _householdProfile = const HouseholdProfile();
  int _expiryAlertDays = 30;
  bool _isLoading = true;
  String _searchQuery = '';
  KitCategory? _selectedCategory;
  ItemFilterStatus _filterStatus = ItemFilterStatus.all;

  KitProvider() {
    loadItems();
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  KitCategory? get selectedCategory => _selectedCategory;
  ItemFilterStatus get filterStatus => _filterStatus;
  HouseholdProfile get householdProfile => _householdProfile;
  int get expiryAlertDays => _expiryAlertDays;

  List<KitItem> get allItems => List.unmodifiable(_items);

  /// Filtered items based on active search, category, and status filter
  List<KitItem> get filteredItems {
    return _items.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }

      switch (_filterStatus) {
        case ItemFilterStatus.missing:
          if (!item.isMissing) return false;
          break;
        case ItemFilterStatus.expiringSoon:
          if (!item.isExpiringWithin(_expiryAlertDays)) return false;
          break;
        case ItemFilterStatus.expired:
          if (!item.isExpired) return false;
          break;
        case ItemFilterStatus.packed:
          if (!item.isComplete) return false;
          break;
        case ItemFilterStatus.all:
          break;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = item.name.toLowerCase().contains(query);
        final matchesNotes = item.notes.toLowerCase().contains(query);
        final matchesCategory =
            item.category.displayName.toLowerCase().contains(query);
        if (!matchesName && !matchesNotes && !matchesCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // --- Analytical Metrics (Guaranteed: packedItemsCount + missingItemsCount == totalItemsCount) ---

  int get totalItemsCount => _items.length;

  int get packedItemsCount => _items.where((item) => item.isComplete).length;

  int get missingItemsCount => _items.where((item) => item.isMissing).length;

  int get expiredItemsCount => _items.where((item) => item.isExpired).length;

  int get expiringSoonItemsCount =>
      _items.where((item) => item.isExpiringWithin(_expiryAlertDays)).length;

  List<KitItem> get expiredItems =>
      _items.where((item) => item.isExpired).toList();

  List<KitItem> get expiringSoonItems =>
      _items.where((item) => item.isExpiringWithin(_expiryAlertDays)).toList();

  List<KitItem> get missingItems =>
      _items.where((item) => item.isMissing).toList();

  /// Items needing immediate attention (expired, expiring soon, or missing)
  List<KitItem> get restockAttentionItems {
    return _items
        .where((item) =>
            item.isExpired ||
            item.isExpiringWithin(_expiryAlertDays) ||
            item.isMissing)
        .toList();
  }

  /// Weighted survival readiness score in percentage (0 - 100%)
  /// Critical supplies (Water, Food, Medical) carry 3x weight; Essential 2x; Important 1x
  double get readinessPercentage {
    if (_items.isEmpty) return 0.0;

    double totalWeight = 0.0;
    double readyWeight = 0.0;
    for (final item in _items) {
      final weight = item.category.priorityWeight.toDouble();
      totalWeight += weight;
      if (!item.isExpired) {
        if (item.isComplete) {
          readyWeight += weight;
        } else if (item.quantity > 0 && item.targetQuantity > 0) {
          readyWeight +=
              weight * (item.quantity / item.targetQuantity).clamp(0.0, 0.85);
        }
      }
    }
    if (totalWeight <= 0) return 0.0;
    return ((readyWeight / totalWeight) * 100.0).clamp(0.0, 100.0);
  }

  /// Unweighted raw percentage of complete, non-expired items
  double get rawCompletionPercentage {
    if (_items.isEmpty) return 0.0;
    final validComplete =
        _items.where((item) => item.isComplete && !item.isExpired).length;
    return ((validComplete / _items.length) * 100.0).clamp(0.0, 100.0);
  }

  String get readinessStatus {
    final score = readinessPercentage;
    if (score >= 90) return 'Fully Prepared';
    if (score >= 70) return 'Substantially Prepared';
    if (score >= 40) return 'Moderately Prepared';
    return 'Action Needed / Vulnerable';
  }

  // --- Filtering & Search Setters ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(KitCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setFilterStatus(ItemFilterStatus status) {
    _filterStatus = status;
    notifyListeners();
  }

  Future<void> setExpiryAlertDays(int days) async {
    _expiryAlertDays = days;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_alertDaysKey, days);
    } catch (e) {
      debugPrint('Failed to save expiry alert days: $e');
    }
  }

  // --- Item Modifications & Persistence ---

  Future<void> loadItems() {
    _isLoading = true;
    notifyListeners();

    return SharedPreferences.getInstance().then((prefs) {
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(jsonString);
          _items = decoded.map((itemMap) => KitItem.fromMap(itemMap)).toList();
        } catch (e) {
          _items = getDefaultKitItems();
        }
      } else {
        _items = getDefaultKitItems();
        _saveToStorage();
      }

      final profileJson = prefs.getString(_profileKey);
      if (profileJson != null && profileJson.isNotEmpty) {
        try {
          _householdProfile = HouseholdProfile.fromJson(profileJson);
        } catch (_) {}
      }

      _expiryAlertDays = prefs.getInt(_alertDaysKey) ?? 30;
      _isLoading = false;
      notifyListeners();
    }).catchError((_) {
      _items = getDefaultKitItems();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString =
          json.encode(_items.map((item) => item.toMap()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Failed to save kit items: $e');
    }
  }

  void togglePacked(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      final newPacked = !item.isComplete;
      // Ensure packing marks quantity complete (>= targetQuantity) so counts stay consistent
      int newQty = item.quantity;
      if (newPacked && newQty < item.targetQuantity) {
        newQty = item.targetQuantity;
      }
      _items[index] = item.copyWith(
        isPacked: newPacked,
        quantity: newQty,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  void updateQuantity(String id, int quantity) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      final validQty = quantity < 0 ? 0 : quantity;
      _items[index] = item.copyWith(
        quantity: validQty,
        isPacked: validQty >= item.targetQuantity,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  void updateExpirationDate(String id, DateTime? newDate) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        expirationDate: newDate,
        clearExpirationDate: newDate == null,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  /// Marks an expired or expiring item as freshly replaced with a new shelf-life
  void markItemReplaced(String id, DateTime? newExpiryDate) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      _items[index] = item.copyWith(
        quantity: math.max(item.quantity, item.targetQuantity),
        isPacked: true,
        expirationDate: newExpiryDate,
        clearExpirationDate: newExpiryDate == null,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  void addItem(KitItem newItem) {
    _items.add(newItem);
    _saveToStorage();
    notifyListeners();
  }

  void editItem(KitItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      _saveToStorage();
      notifyListeners();
    }
  }

  void deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveToStorage();
    notifyListeners();
  }

  void resetToDefault() {
    _items = getDefaultKitItems();
    _saveToStorage();
    notifyListeners();
  }

  /// Smart Kit Recommender: scales essential quantities by household size & adds specialized gear
  Future<({int updatedCount, int addedCount})> applySmartRecommendations(
      HouseholdProfile profile) async {
    _householdProfile = profile;
    int updated = 0;
    int added = 0;
    final people = profile.totalPeople;
    final now = DateTime.now();

    void scaleTarget(String id, int newTarget) {
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx != -1 && _items[idx].targetQuantity != newTarget) {
        final item = _items[idx];
        _items[idx] = item.copyWith(
          targetQuantity: newTarget,
          isPacked: item.quantity >= newTarget,
        );
        updated++;
      }
    }

    void addIfMissing(KitItem newItem) {
      if (!_items.any((e) => e.id == newItem.id)) {
        _items.add(newItem);
        added++;
      }
    }

    // Scale core supplies for 72 hours per person
    scaleTarget('water_bottles', people * 3);
    scaleTarget('canned_goods', people * 6);
    scaleTarget('energy_biscuits', people * 4);
    scaleTarget('n95_masks', people * 3);
    scaleTarget('thermal_blanket', math.max(2, people));
    scaleTarget('extra_clothes', people);

    // Tailor special-needs items
    if (profile.infants > 0) {
      addIfMissing(KitItem(
        id: 'rec_infant_kit',
        name: 'Infant Formula, Feeding Bottles & Diapers (3-day supply)',
        category: KitCategory.specialNeeds,
        quantity: 0,
        targetQuantity: profile.infants * 18,
        unit: 'diapers',
        expirationDate: now.add(const Duration(days: 180)),
        isPacked: false,
        notes: 'Recommended for ${profile.infants} infant(s) in household.',
      ));
    }

    if (profile.seniors > 0) {
      addIfMissing(KitItem(
        id: 'rec_senior_kit',
        name: 'Senior Care Pack (Extra Eyeglasses, Hearing Batteries, Cane)',
        category: KitCategory.specialNeeds,
        quantity: 0,
        targetQuantity: profile.seniors,
        unit: 'sets',
        isPacked: false,
        notes: 'Recommended for ${profile.seniors} senior citizen(s).',
      ));
    }

    if (profile.pets > 0) {
      addIfMissing(KitItem(
        id: 'rec_pet_kit',
        name: 'Pet Food, Collapsible Bowl & Spare Leash/Carrier',
        category: KitCategory.specialNeeds,
        quantity: 0,
        targetQuantity: profile.pets * 3,
        unit: 'days supply',
        expirationDate: now.add(const Duration(days: 240)),
        isPacked: false,
        notes: 'Recommended for ${profile.pets} household pet(s).',
      ));
    }

    if (profile.isFloodProne) {
      addIfMissing(KitItem(
        id: 'rec_flood_boots',
        name: 'Waterproof Rain Boots & Heavy-Duty Dry Bag',
        category: KitCategory.clothingAndBedding,
        quantity: 0,
        targetQuantity: math.max(1, profile.adults),
        unit: 'pairs',
        isPacked: false,
        notes: 'Recommended for flood-prone barangays (leptospirosis protection).',
      ));
    }

    if (profile.isEarthquakeZone) {
      addIfMissing(KitItem(
        id: 'rec_quake_gloves',
        name: 'Sturdy Closed-Toe Shoes & Heavy Work Gloves',
        category: KitCategory.toolsAndLighting,
        quantity: 0,
        targetQuantity: people,
        unit: 'pairs',
        isPacked: false,
        notes: 'Recommended for safe evacuation over shattered glass/debris.',
      ));
    }

    if (profile.hasChronicMedicalNeeds) {
      addIfMissing(KitItem(
        id: 'rec_chronic_meds',
        name: 'Emergency Prescription Copies & Cold-Pack Pouch',
        category: KitCategory.medicalAndFirstAid,
        quantity: 0,
        targetQuantity: 1,
        unit: 'pouch',
        isPacked: false,
        notes: 'Recommended for household members with chronic conditions.',
      ));
    }

    await _saveToStorage();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, profile.toJson());
    } catch (_) {}

    notifyListeners();
    return (updatedCount: updated, addedCount: added);
  }

  /// Generates a formatted shopping/restock list for clipboard export
  String generateRestockSummaryText() {
    final buffer = StringBuffer();
    buffer.writeln('LIFECHECKPOINT RESTOCK & REPLACEMENT LIST');
    buffer.writeln('Readiness Score: ${readinessPercentage.toStringAsFixed(0)}% ($readinessStatus)');
    buffer.writeln('');

    if (expiredItems.isNotEmpty) {
      buffer.writeln('[URGENT - EXPIRED ITEMS]');
      for (final item in expiredItems) {
        buffer.writeln('- ${item.name} (Expired)');
      }
      buffer.writeln('');
    }

    if (expiringSoonItems.isNotEmpty) {
      buffer.writeln('[WARNING - EXPIRING WITHIN $_expiryAlertDays DAYS]');
      for (final item in expiringSoonItems) {
        buffer.writeln('- ${item.name} (${item.daysUntilExpiration} days left)');
      }
      buffer.writeln('');
    }

    if (missingItems.isNotEmpty) {
      buffer.writeln('[MISSING / LOW QUANTITY ITEMS]');
      for (final item in missingItems) {
        final needed = (item.targetQuantity - item.quantity).clamp(1, 999);
        buffer.writeln('- ${item.name}: Need $needed more ${item.unit} (Have ${item.quantity}/${item.targetQuantity})');
      }
    }

    if (expiredItems.isEmpty && expiringSoonItems.isEmpty && missingItems.isEmpty) {
      buffer.writeln('All supplies are packed and within valid shelf-life!');
    }

    return buffer.toString();
  }
}
