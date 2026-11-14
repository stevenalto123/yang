import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_checkpoint/models/kit_item.dart';
import 'package:life_checkpoint/providers/kit_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LifeCheckpoint KitProvider Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default supplies and calculates metrics', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.totalItemsCount, greaterThan(0));
      expect(provider.packedItemsCount, greaterThan(0));
      expect(provider.readinessPercentage, inInclusiveRange(0.0, 100.0));
    });

    test('Toggles packing status and adjusts readiness score', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final initialScore = provider.readinessPercentage;
      final unpackedItem = provider.allItems.firstWhere((i) => !i.isPacked);

      provider.togglePacked(unpackedItem.id);
      expect(provider.allItems.firstWhere((i) => i.id == unpackedItem.id).isPacked, isTrue);
      expect(provider.readinessPercentage, greaterThanOrEqualTo(initialScore));
    });

    test('Identifies expired and expiring soon items correctly', () {
      final now = DateTime.now();

      final expiredItem = KitItem(
        id: 'test_expired',
        name: 'Expired Antibiotic',
        category: KitCategory.medicalAndFirstAid,
        expirationDate: now.subtract(const Duration(days: 10)),
        isPacked: true,
      );

      final expiringSoonItem = KitItem(
        id: 'test_expiring',
        name: 'Expiring Ration',
        category: KitCategory.waterAndFood,
        expirationDate: now.add(const Duration(days: 15)),
        isPacked: true,
      );

      final freshItem = KitItem(
        id: 'test_fresh',
        name: 'Fresh Canned Tuna',
        category: KitCategory.waterAndFood,
        expirationDate: now.add(const Duration(days: 200)),
        isPacked: true,
      );

      expect(expiredItem.isExpired, isTrue);
      expect(expiringSoonItem.isExpiringSoon, isTrue);
      expect(freshItem.isExpired, isFalse);
      expect(freshItem.isExpiringSoon, isFalse);
    });

    test('Filters items by category and search keyword', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      provider.setSelectedCategory(KitCategory.waterAndFood);
      for (final item in provider.filteredItems) {
        expect(item.category, equals(KitCategory.waterAndFood));
      }

      provider.setSearchQuery('water');
      for (final item in provider.filteredItems) {
        final matches = item.name.toLowerCase().contains('water') ||
            item.notes.toLowerCase().contains('water') ||
            item.category.displayName.toLowerCase().contains('water');
        expect(matches, isTrue);
      }
    });
  });
}
