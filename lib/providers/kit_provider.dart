import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kit_item.dart';
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

  List<KitItem> _items = [];
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

  List<KitItem> get allItems => List.unmodifiable(_items);

  /// Filtered items based on active search, category, and status filter
  List<KitItem> get filteredItems {
    return _items.where((item) {
      // Category filter
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }

      // Status filter
      switch (_filterStatus) {
        case ItemFilterStatus.missing:
          if (!item.isMissing) return false;
          break;
        case ItemFilterStatus.expiringSoon:
          if (!item.isExpiringSoon) return false;
          break;
        case ItemFilterStatus.expired:
          if (!item.isExpired) return false;
          break;
        case ItemFilterStatus.packed:
          if (!item.isPacked) return false;
          break;
        case ItemFilterStatus.all:
          break;
      }

      // Search query
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

  // --- Analytical Metrics (For SOP / Research Questions 2.1-2.4) ---

  int get totalItemsCount => _items.length;

  int get packedItemsCount => _items.where((item) => item.isPacked).length;

  int get missingItemsCount => _items.where((item) => item.isMissing).length;

  int get expiredItemsCount => _items.where((item) => item.isExpired).length;

  int get expiringSoonItemsCount =>
      _items.where((item) => item.isExpiringSoon).length;

  List<KitItem> get expiredItems =>
      _items.where((item) => item.isExpired).toList();

  List<KitItem> get expiringSoonItems =>
      _items.where((item) => item.isExpiringSoon).toList();

  List<KitItem> get missingItems =>
      _items.where((item) => item.isMissing).toList();

  /// Overall readiness score in percentage (0 - 100%)
  /// Considers packing completion and penalizes expired supplies
  double get readinessPercentage {
    if (_items.isEmpty) return 0.0;

    int validPacked = _items.where((item) => item.isPacked && !item.isExpired).length;
    double score = (validPacked / _items.length) * 100.0;
    return score.clamp(0.0, 100.0);
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
      final newPacked = !item.isPacked;
      // If marked packed and quantity was 0, default to target
      int newQty = item.quantity;
      if (newPacked && newQty <= 0) {
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
      _items[index] = _items[index].copyWith(expirationDate: newDate);
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
}
