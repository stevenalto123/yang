import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_checkpoint/models/kit_item.dart';
import 'package:life_checkpoint/models/household_profile.dart';
import 'package:life_checkpoint/providers/kit_provider.dart';
import 'package:life_checkpoint/utils/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LifeCheckpoint KitProvider Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with consistent packed + missing == total counts', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.totalItemsCount, greaterThan(0));
      expect(provider.packedItemsCount + provider.missingItemsCount,
          equals(provider.totalItemsCount));
      expect(provider.readinessPercentage, inInclusiveRange(0.0, 100.0));
    });

    test('Toggles packing status and enforces consistent quantity', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final initialScore = provider.readinessPercentage;
      final missingItem = provider.missingItems.first;

      provider.togglePacked(missingItem.id);
      final updated = provider.allItems.firstWhere((i) => i.id == missingItem.id);
      expect(updated.isComplete, isTrue);
      expect(updated.quantity, greaterThanOrEqualTo(updated.targetQuantity));
      expect(provider.packedItemsCount + provider.missingItemsCount,
          equals(provider.totalItemsCount));
      expect(provider.readinessPercentage, greaterThanOrEqualTo(initialScore));
    });

    test('Identifies expired and expiring soon items and supports clearing expiry', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final now = DateTime.now();
      final expiredItem = KitItem(
        id: 'test_expired',
        name: 'Expired Antibiotic',
        category: KitCategory.medicalAndFirstAid,
        quantity: 1,
        targetQuantity: 1,
        expirationDate: now.subtract(const Duration(days: 10)),
        isPacked: true,
      );

      final expiringSoonItem = KitItem(
        id: 'test_expiring',
        name: 'Expiring Ration',
        category: KitCategory.waterAndFood,
        quantity: 1,
        targetQuantity: 1,
        expirationDate: now.add(const Duration(days: 15)),
        isPacked: true,
      );

      expect(expiredItem.isExpired, isTrue);
      expect(expiringSoonItem.isExpiringSoon, isTrue);

      provider.addItem(expiredItem);
      provider.updateExpirationDate('test_expired', null);
      final cleared = provider.allItems.firstWhere((i) => i.id == 'test_expired');
      expect(cleared.expirationDate, isNull);
      expect(cleared.isExpired, isFalse);
    });

    test('Mark item replaced sets valid expiry and marks complete', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final expired = provider.expiredItems.first;
      final newDate = DateTime.now().add(const Duration(days: 365));
      provider.markItemReplaced(expired.id, newDate);

      final updated = provider.allItems.firstWhere((i) => i.id == expired.id);
      expect(updated.isExpired, isFalse);
      expect(updated.isComplete, isTrue);
    });

    test('Smart Kit Recommender scales targets and adds tailored items', () async {
      final provider = KitProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final initialTotal = provider.totalItemsCount;
      const profile = HouseholdProfile(
        adults: 2,
        children: 1,
        infants: 1,
        seniors: 1,
        pets: 1,
        isFloodProne: true,
        isEarthquakeZone: true,
        hasChronicMedicalNeeds: true,
      );

      final result = await provider.applySmartRecommendations(profile);
      expect(result.addedCount, greaterThanOrEqualTo(5));
      expect(provider.totalItemsCount, greaterThan(initialTotal));

      final water = provider.allItems.firstWhere((i) => i.id == 'water_bottles');
      expect(water.targetQuantity, equals(profile.totalPeople * 3));
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

    test('Offline Haversine GPS distance and bearing calculates accurately', () {
      // Distance from EAC Manila (14.5822, 120.9882) to Paco Hall (14.5804, 120.9931)
      final distKm = LocationService.distanceInKm(14.5822, 120.9882, 14.5804, 120.9931);
      expect(distKm, inInclusiveRange(0.4, 0.8));

      final bearing = LocationService.bearingTo(14.5822, 120.9882, 14.5804, 120.9931);
      expect(bearing.cardinal, equals('E'));

      final qcBearing = LocationService.bearingTo(14.5822, 120.9882, 14.6301, 121.0267);
      expect(qcBearing.cardinal, equals('NE'));
    });
  });
}
