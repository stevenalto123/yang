import 'dart:convert';

enum ContactCategory {
  nationalHotline,
  police,
  fire,
  medicalAndRedCross,
  disasterManagement,
  familyAndPersonal,
}

extension ContactCategoryExtension on ContactCategory {
  String get displayName {
    switch (this) {
      case ContactCategory.nationalHotline:
        return 'National Emergency';
      case ContactCategory.police:
        return 'Philippine National Police (PNP)';
      case ContactCategory.fire:
        return 'Bureau of Fire Protection (BFP)';
      case ContactCategory.medicalAndRedCross:
        return 'Medical & Philippine Red Cross';
      case ContactCategory.disasterManagement:
        return 'Disaster Council (NDRRMC / LGU)';
      case ContactCategory.familyAndPersonal:
        return 'Family & Personal Contacts';
    }
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String agencyOrRelationship;
  final String phoneNumber;
  final String alternativeNumber;
  final ContactCategory category;
  final bool isDefault;
  final String description;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.agencyOrRelationship,
    required this.phoneNumber,
    this.alternativeNumber = '',
    required this.category,
    this.isDefault = false,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'agencyOrRelationship': agencyOrRelationship,
      'phoneNumber': phoneNumber,
      'alternativeNumber': alternativeNumber,
      'category': category.index,
      'isDefault': isDefault,
      'description': description,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      agencyOrRelationship: map['agencyOrRelationship'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      alternativeNumber: map['alternativeNumber'] ?? '',
      category: ContactCategory.values[map['category'] ?? 0],
      isDefault: map['isDefault'] ?? false,
      description: map['description'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory EmergencyContact.fromJson(String source) =>
      EmergencyContact.fromMap(json.decode(source));
}
