import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_checkpoint/main.dart';

void main() {
  testWidgets(
      'LifeCheckpoint app loads 5 tabs, persistent SOS, Account Sync screen, EN/FIL and Dark Mode toggles',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LifeCheckpointApp());
    await tester.pumpAndSettle();

    // App branding & Global SOS button
    expect(find.text('LifeCheckpoint'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Offline-Ready • Tap to Sign In & Sync'), findsOneWidget);

    // 5 NavigationBar tabs in English
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Kit'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);

    // Open Account & Cloud Sync screen
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Account & Cloud Sync'), findsOneWidget);
    expect(find.text('Sign In to Sync Across Devices'), findsOneWidget);

    // Return to Home
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Navigate to Safety Hub tab
    await tester.tap(find.text('Safety'));
    await tester.pumpAndSettle();
    expect(find.text('Safety, Hotlines & Plan'), findsOneWidget);

    // Return to Home tab and toggle EN -> FIL
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('FIL'), findsOneWidget);
    expect(find.text('Tahanan'), findsOneWidget);
    expect(find.text('Kaligtasan'), findsOneWidget);

    // Toggle Light -> Dark Mode
    final darkToggle = find.byIcon(Icons.dark_mode_outlined);
    expect(darkToggle, findsOneWidget);
    await tester.tap(darkToggle);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}
