import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_checkpoint/main.dart';

void main() {
  testWidgets(
      'LifeCheckpoint loads 5 clean tabs, persistent SOS, Family Backup screen, EN/FIL and Dark Mode toggles',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LifeCheckpointApp());
    await tester.pumpAndSettle();

    // App branding & Global SOS button
    expect(find.text('LifeCheckpoint'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Saved on device • Sign in to back up'), findsOneWidget);

    // 5 NavigationBar tabs in English
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Go-Bag'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);

    // Open Family Backup & Sync screen
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Family Backup & Sync'), findsOneWidget);
    expect(find.text('Sign In to Back Up & Share'), findsOneWidget);

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
    expect(find.text('Gabay'), findsOneWidget);

    // Toggle Light -> Dark Mode
    final darkToggle = find.byIcon(Icons.dark_mode_outlined);
    expect(darkToggle, findsOneWidget);
    await tester.tap(darkToggle);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}
