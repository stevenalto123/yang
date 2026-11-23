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
        return '911 / National';
      case ContactCategory.police:
        return 'Manila Police (MPD)';
      case ContactCategory.fire:
        return 'Manila Fire (BFP)';
      case ContactCategory.medicalAndRedCross:
        return 'Medical & Red Cross';
      case ContactCategory.disasterManagement:
        return 'Manila DRRMO';
      case ContactCategory.familyAndPersonal:
        return 'Family & Personal';
    }
  }
}

class SubHotline {
  final String label;
  final String number;
  final bool isRadioOnly;

  const SubHotline({
    required this.label,
    required this.number,
    this.isRadioOnly = false,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'number': number,
        'isRadioOnly': isRadioOnly,
      };

  factory SubHotline.fromMap(Map<String, dynamic> map) {
    return SubHotline(
      label: (map['label'] ?? '').toString(),
      number: (map['number'] ?? '').toString(),
      isRadioOnly: map['isRadioOnly'] == true,
    );
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
  final List<SubHotline> subHotlines;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.agencyOrRelationship,
    required this.phoneNumber,
    this.alternativeNumber = '',
    required this.category,
    this.isDefault = false,
    this.description = '',
    this.subHotlines = const [],
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
      if (subHotlines.isNotEmpty)
        'subHotlines': subHotlines.map((s) => s.toMap()).toList(),
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    final rawIndex = map['category'] is int ? map['category'] as int : 0;
    final safeIndex =
        rawIndex.clamp(0, ContactCategory.values.length - 1).toInt();
    final rawSubs = map['subHotlines'];
    final subs = rawSubs is List
        ? rawSubs
            .whereType<Map>()
            .map((e) => SubHotline.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : const <SubHotline>[];

    return EmergencyContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      agencyOrRelationship: map['agencyOrRelationship'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      alternativeNumber: map['alternativeNumber'] ?? '',
      category: ContactCategory.values[safeIndex],
      isDefault: map['isDefault'] ?? false,
      description: map['description'] ?? '',
      subHotlines: subs,
    );
  }

  String toJson() => json.encode(toMap());

  factory EmergencyContact.fromJson(String source) =>
      EmergencyContact.fromMap(json.decode(source));
}
