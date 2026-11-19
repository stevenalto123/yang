import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/kit_provider.dart';
import 'providers/monitoring_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/account_sync_screen.dart';
import 'screens/emergency_monitoring_screen.dart';
import 'screens/evacuation_map_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/kit_management_screen.dart';
import 'screens/safety_hub_screen.dart';
import 'utils/app_strings.dart';
import 'utils/app_theme.dart';
import 'utils/sos_sheet.dart';
import 'widgets/responsive_container.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
  bool _syncWired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _syncWired) return;
      _syncWired = true;
      final auth = context.read<AuthProvider>();
      final kit = context.read<KitProvider>();
      final emergency = context.read<EmergencyProvider>();
      final monitoring = context.read<MonitoringProvider>();

      kit.onKitChanged = (payload) => auth.enqueueMutation('upsert_kit', payload);
      kit.onItemDeleted =
          (id) => auth.enqueueMutation('delete_kit', {'id': id});
      emergency.onPlanSaved =
          (planMap) => auth.enqueueMutation('save_plan', planMap);
      emergency.onShelterAdded =
          (shelterMap) => auth.enqueueMutation('add_shelter', shelterMap);
      monitoring.telemetryProxyFetcher = auth.fetchTelemetryProxy;
      monitoring.onCheckinAdded =
          (checkin) => auth.enqueueMutation('add_checkin', checkin);

      auth.attachSyncHandlers(
        kitPayloadReader: kit.exportSyncPayload,
        kitBundleApplier: kit.applyRemoteSync,
        planApplier: emergency.applyRemotePlan,
        sheltersApplier: emergency.applyRemoteShelters,
        checkinsApplier: monitoring.applyRemoteCheckins,
      );
    });
  }

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
    final auth = context.watch<AuthProvider>();

    final isDark = settings.isDarkMode;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final s = AppStrings(settings.isFilipino);

    final alertCount = kit.expiredItemsCount + kit.expiringSoonItemsCount;
    final isDrillActive = monitoring.drillMode != DrillAlertMode.liveNormal;

    final selectedColor =
        isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;
    final navBg = isDark ? AppTheme.darkCard : Colors.white;
    final indicatorColor = isDark
        ? Colors.lightBlue.shade200.withAlpha(45)
        : AppTheme.primaryNavy.withAlpha(28);

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

    final contentWithDrill = isDrillActive
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
        : indexedBody;

    // Desktop / Web Sidebar Shell (>= 860px)
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              currentIndex: _currentIndex,
              onSelectTab: _onNavigateTab,
              alertCount: alertCount,
              isDrillActive: isDrillActive,
              isDark: isDark,
              settings: settings,
              auth: auth,
              s: s,
            ),
            VerticalDivider(
              width: 1,
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
            Expanded(child: contentWithDrill),
          ],
        ),
      );
    }

    // Mobile / Compact Bottom Navigation Shell (< 860px)
    return Scaffold(
      body: contentWithDrill,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'global_sos_fab',
        backgroundColor: AppTheme.dangerRed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.sos_rounded, size: 22),
        label: Text(
          s.sosButtonLabel,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        onPressed: () => SosSheet.show(context),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
          ),
        ),
        child: NavigationBar(
          height: 68,
          elevation: 0,
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
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final int alertCount;
  final bool isDrillActive;
  final bool isDark;
  final SettingsProvider settings;
  final AuthProvider auth;
  final AppStrings s;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onSelectTab,
    required this.alertCount,
    required this.isDrillActive,
    required this.isDark,
    required this.settings,
    required this.auth,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1627) : Colors.white;
    final subtle = isDark ? Colors.white60 : AppTheme.mutedSlate;

    final navItems = [
      (
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: s.navHome,
        badgeCount: 0,
        showDot: false,
      ),
      (
        icon: Icons.checklist_rtl_outlined,
        selectedIcon: Icons.checklist_rtl,
        label: s.navKit,
        badgeCount: alertCount,
        showDot: false,
      ),
      (
        icon: Icons.radar_outlined,
        selectedIcon: Icons.radar,
        label: s.navMonitor,
        badgeCount: 0,
        showDot: isDrillActive,
      ),
      (
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: s.navMap,
        badgeCount: 0,
        showDot: false,
      ),
      (
        icon: Icons.health_and_safety_outlined,
        selectedIcon: Icons.health_and_safety,
        label: s.navSafety,
        badgeCount: 0,
        showDot: false,
      ),
    ];

    return Container(
      width: 248,
      color: bg,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryNavy, AppTheme.primaryAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LifeCheckpoint',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : AppTheme.primaryNavy,
                        ),
                      ),
                      Text(
                        'EAC • Metro Manila',
                        style: TextStyle(fontSize: 12, color: subtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Prominent Emergency SOS Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.sos_rounded, size: 20),
              label: Text(
                settings.isFilipino ? 'Tawag SOS / 911' : 'Emergency SOS',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => SosSheet.show(context),
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              settings.isFilipino ? 'NABIGASYON' : 'NAVIGATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: subtle,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Navigation Destinations
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final item = navItems[idx];
                final active = currentIndex == idx;
                final activeBg = isDark
                    ? Colors.lightBlue.shade200.withAlpha(32)
                    : AppTheme.primaryNavy.withAlpha(18);
                final activeFg =
                    isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;
                final idleFg = isDark ? Colors.white70 : AppTheme.mutedSlate;

                return Material(
                  color: active ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelectTab(idx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            active ? item.selectedIcon : item.icon,
                            size: 21,
                            color: active ? activeFg : idleFg,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: active
                                    ? (isDark
                                        ? Colors.white
                                        : AppTheme.primaryNavy)
                                    : (isDark
                                        ? Colors.white70
                                        : AppTheme.darkSlate),
                              ),
                            ),
                          ),
                          if (item.badgeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerRed,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else if (item.showDot)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppTheme.dangerRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 20),

          // Cloud Sync Quick Status Card
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountSyncScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    auth.isAuthenticated
                        ? Icons.cloud_done
                        : Icons.cloud_off_outlined,
                    size: 18,
                    color: auth.isAuthenticated
                        ? AppTheme.safeGreen
                        : subtle,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isAuthenticated
                              ? (auth.householdName ?? 'Synced')
                              : 'Offline Guest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.darkSlate,
                          ),
                        ),
                        Text(
                          auth.isAuthenticated
                              ? 'Code: ${auth.inviteCode ?? '-'}'
                              : 'Tap to Sign In & Sync',
                          style: TextStyle(fontSize: 11.5, color: subtle),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: subtle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Language & Theme Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => settings.toggleLanguage(),
                  child: Text(
                    settings.isFilipino ? 'FIL' : 'EN',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => settings.toggleDarkMode(),
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 18,
                  ),
                ),
              ),
            ],
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
    for (double x = -size.height;
        x < size.width + size.height;
        x += stripeWidth * 2) {
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
