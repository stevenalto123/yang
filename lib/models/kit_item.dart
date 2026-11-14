import 'dart:convert';

enum KitCategory {
  waterAndFood,
  medicalAndFirstAid,
  toolsAndLighting,
  documentsAndCash,
  sanitationAndHygiene,
  clothingAndBedding,
  specialNeeds,
}

extension KitCategoryExtension on KitCategory {
  String get displayName {
    switch (this) {
      case KitCategory.waterAndFood:
        return 'Water & Food';
      case KitCategory.medicalAndFirstAid:
        return 'First Aid & Medicine';
      case KitCategory.toolsAndLighting:
        return 'Tools & Lighting';
      case KitCategory.documentsAndCash:
        return 'Documents & Cash';
      case KitCategory.sanitationAndHygiene:
        return 'Sanitation & Hygiene';
      case KitCategory.clothingAndBedding:
        return 'Clothing & Warmth';
      case KitCategory.specialNeeds:
        return 'Special Needs & Infants';
    }
  }

  String get iconName {
    switch (this) {
      case KitCategory.waterAndFood:
        return 'restaurant';
      case KitCategory.medicalAndFirstAid:
        return 'medical_services';
      case KitCategory.toolsAndLighting:
        return 'flashlight_on';
      case KitCategory.documentsAndCash:
        return 'folder_shared';
      case KitCategory.sanitationAndHygiene:
        return 'clean_hands';
      case KitCategory.clothingAndBedding:
        return 'checkroom';
      case KitCategory.specialNeeds:
        return 'child_care';
    }
  }
}

class KitItem {
  final String id;
  String name;
  KitCategory category;
  int quantity;
  int targetQuantity;
  String unit;
  DateTime? expirationDate;
  bool isPacked;
  String notes;
  DateTime lastUpdated;

  KitItem({
    required this.id,
    required this.name,
    required this.category,
    this.quantity = 0,
    this.targetQuantity = 1,
    this.unit = 'pcs',
    this.expirationDate,
    this.isPacked = false,
    this.notes = '',
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Check if the item is past its expiration date
  bool get isExpired {
    if (expirationDate == null) return false;
    final now = DateTime.now();
    return expirationDate!.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Check if item will expire within [thresholdDays] (default 30 days)
  bool isExpiringWithin(int thresholdDays) {
    if (expirationDate == null || isExpired) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(
        expirationDate!.year, expirationDate!.month, expirationDate!.day);
    final difference = expDay.difference(today).inDays;
    return difference >= 0 && difference <= thresholdDays;
  }

  /// Default 30-day expiring soon check
  bool get isExpiringSoon => isExpiringWithin(30);

  /// Item is completely packed with sufficient quantity
  bool get isComplete => isPacked && quantity >= targetQuantity;

  /// Item has some quantity packed, but still short of target
  bool get isPartial => quantity > 0 && quantity < targetQuantity;

  /// Check if the item is missing or quantity is below target
  bool get isMissing => !isPacked || quantity < targetQuantity;

  /// Returns days remaining before expiration (null if no expiration)
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(
        expirationDate!.year, expirationDate!.month, expirationDate!.day);
    return expDay.difference(today).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.index,
      'quantity': quantity,
      'targetQuantity': targetQuantity,
      'unit': unit,
      'expirationDate': expirationDate?.toIso8601String(),
      'isPacked': isPacked,
      'notes': notes,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory KitItem.fromMap(Map<String, dynamic> map) {
    final qty = map['quantity'] ?? 0;
    final target = map['targetQuantity'] ?? 1;
    final packed = map['isPacked'] ?? false;
    return KitItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: KitCategory.values[map['category'] ?? 0],
      quantity: qty,
      targetQuantity: target,
      unit: map['unit'] ?? 'pcs',
      expirationDate: map['expirationDate'] != null
          ? DateTime.tryParse(map['expirationDate'])
          : null,
      // Enforce consistency: an item is packed only if quantity meets target
      isPacked: packed && qty >= target,
      notes: map['notes'] ?? '',
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory KitItem.fromJson(String source) =>
      KitItem.fromMap(json.decode(source));

  KitItem copyWith({
    String? id,
    String? name,
    KitCategory? category,
    int? quantity,
    int? targetQuantity,
    String? unit,
    DateTime? expirationDate,
    bool clearExpirationDate = false,
    bool? isPacked,
    String? notes,
    DateTime? lastUpdated,
  }) {
    return KitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      targetQuantity: targetQuantity ?? this.targetQuantity,
      unit: unit ?? this.unit,
      expirationDate: clearExpirationDate
          ? null
          : (expirationDate ?? this.expirationDate),
      isPacked: isPacked ?? this.isPacked,
      notes: notes ?? this.notes,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}
