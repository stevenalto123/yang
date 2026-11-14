import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/kit_provider.dart';
import 'providers/monitoring_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/emergency_monitoring_screen.dart';
import 'screens/evacuation_map_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/kit_management_screen.dart';
import 'screens/safety_hub_screen.dart';
import 'utils/app_strings.dart';
import 'utils/app_theme.dart';
import 'utils/sos_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeCheckpointApp());
}

class LifeCheckpointApp extends StatelessWidget {
  const LifeCheckpointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => KitProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyProvider()),
        ChangeNotifierProvider(create: (_) => MonitoringProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'LifeCheckpoint',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainNavigationScreen(),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onNavigateTab(int index) {
    setState(() {
      _currentIndex = index.clamp(0, 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final monitoring = context.watch<MonitoringProvider>();
    final settings = context.watch<SettingsProvider>();

    final isDark = settings.isDarkMode;
    final s = AppStrings(settings.isFilipino);

    final alertCount = kit.expiredItemsCount + kit.expiringSoonItemsCount;
    final isDrillActive = monitoring.drillMode != DrillAlertMode.liveNormal;

    final selectedColor =
        isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;
    final navBg = isDark ? AppTheme.darkCard : Colors.white;
    final indicatorColor =
        isDark ? Colors.lightBlue.shade200.withAlpha(45) : AppTheme.primaryNavy.withAlpha(32);

    final List<Widget> screens = [
      HomeDashboardScreen(onNavigateTab: _onNavigateTab),
      const KitManagementScreen(),
      const EmergencyMonitoringScreen(),
      const EvacuationMapScreen(),
      const SafetyHubScreen(),
    ];

    final indexedBody = IndexedStack(
      index: _currentIndex,
      children: screens,
    );

    return Scaffold(
      body: isDrillActive
          ? Column(
              children: [
                _DrillModeBanner(
                  label: '${s.drillBannerText}: ${monitoring.drillMode.label}',
                  exitLabel: s.exitDrill,
                  onExit: () =>
                      monitoring.setDrillMode(DrillAlertMode.liveNormal),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: indexedBody,
                  ),
                ),
              ],
            )
          : indexedBody,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'global_sos_fab',
        backgroundColor: AppTheme.dangerRed,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.sos_rounded, size: 22),
        label: Text(
          s.sosButtonLabel,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: () => SosSheet.show(context),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigateTab,
        backgroundColor: navBg,
        indicatorColor: indicatorColor,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: selectedColor),
            label: s.navHome,
          ),
          NavigationDestination(
            icon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    backgroundColor: AppTheme.dangerRed,
                    child: const Icon(Icons.checklist_rtl_outlined),
                  )
                : const Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl, color: selectedColor),
            label: s.navKit,
          ),
          NavigationDestination(
            icon: isDrillActive
                ? const Badge(
                    backgroundColor: AppTheme.dangerRed,
                    child: Icon(Icons.radar_outlined),
                  )
                : const Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar, color: selectedColor),
            label: s.navMonitor,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: selectedColor),
            label: s.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety, color: selectedColor),
            label: s.navSafety,
          ),
        ],
      ),
    );
  }
}

class _DrillModeBanner extends StatelessWidget {
  final String label;
  final String exitLabel;
  final VoidCallback onExit;

  const _DrillModeBanner({
    required this.label,
    required this.exitLabel,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HazardStripePainter(),
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xE60F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.science_rounded,
                  color: Colors.amberAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    minimumSize: const Size(48, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: onExit,
                  child: Text(
                    exitLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()..color = AppTheme.warningAmber;
    const stripeWidth = 14.0;
    for (double x = -size.height; x < size.width + size.height; x += stripeWidth * 2) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
