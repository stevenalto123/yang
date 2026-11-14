import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_checkpoint/main.dart';

void main() {
  testWidgets('LifeCheckpoint app loads and displays title', (WidgetTester tester) async {
    // Mock initial shared preferences
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LifeCheckpointApp());
    await tester.pumpAndSettle();

    // Verify app title is displayed on dashboard
    expect(find.text('LifeCheckpoint'), findsOneWidget);
  });
}
