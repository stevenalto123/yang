import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/kit_provider.dart';
import 'providers/monitoring_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/account_sync_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/emergency_monitoring_screen.dart';
import 'screens/evacuation_map_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/kit_management_screen.dart';
import 'screens/safety_hub_screen.dart';
import 'utils/app_strings.dart';
import 'utils/app_theme.dart';
import 'utils/pwa_bridge.dart';
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
  bool _isOnline = true;
  void Function()? _disposeConnectivity;

  @override
  void initState() {
    super.initState();
    _isOnline = isDeviceOnline();
    _disposeConnectivity = listenConnectivity((online) {
      if (!mounted) return;
      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);
      if (online && wasOffline) {
        final auth = context.read<AuthProvider>();
        final monitoring = context.read<MonitoringProvider>();
        final emergency = context.read<EmergencyProvider>();
        if (auth.isAuthenticated || auth.pendingSyncCount > 0) {
          auth.syncNow(pushLocalKitFirst: false);
        }
        monitoring.refreshLiveFeeds(
          lat: emergency.userLat,
          lng: emergency.userLng,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.safeGreen,
            content: Text('Back online — syncing your updates!'),
          ),
        );
      }
    });
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
      emergency.onShelterDeleted =
          (id) => auth.enqueueMutation('delete_shelter', {'id': id});
      monitoring.telemetryProxyFetcher = auth.fetchTelemetryProxy;
      monitoring.advisoriesFetcher = auth.fetchPublicAdvisories;
      monitoring.onCheckinAdded =
          (checkin) => auth.enqueueMutation('add_checkin', checkin);
      monitoring.refreshAdvisoriesOnly();

      auth.attachSyncHandlers(
        kitPayloadReader: kit.exportSyncPayload,
        kitBundleApplier: kit.applyRemoteSync,
        planApplier: emergency.applyRemotePlan,
        sheltersApplier: emergency.applyRemoteShelters,
        checkinsApplier: monitoring.applyRemoteCheckins,
      );
    });
  }

  @override
  void dispose() {
    _disposeConnectivity?.call();
    super.dispose();
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
        ? Colors.lightBlue.shade200.withAlpha(36)
        : AppTheme.primaryNavy.withAlpha(22);

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

    final hasTopBanner = isDrillActive || !_isOnline;
    final contentWithDrill = hasTopBanner
        ? Column(
            children: [
              if (!_isOnline)
                _OfflineModeBanner(isFil: settings.isFilipino),
              if (isDrillActive)
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

    return Scaffold(
      body: contentWithDrill,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'global_sos_fab',
        backgroundColor: AppTheme.dangerRed,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.emergency_rounded, size: 21),
        label: Text(
          s.sosButtonLabel,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
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
          height: 66,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavigateTab,
          backgroundColor: navBg,
          indicatorColor: indicatorColor,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: selectedColor),
              label: s.navHome,
            ),
            NavigationDestination(
              icon: alertCount > 0
                  ? Badge(
                      label: Text('$alertCount'),
                      backgroundColor: AppTheme.dangerRed,
                      child: const Icon(Icons.backpack_outlined),
                    )
                  : const Icon(Icons.backpack_outlined),
              selectedIcon: Icon(Icons.backpack_rounded, color: selectedColor),
              label: s.navKit,
            ),
            NavigationDestination(
              icon: isDrillActive
                  ? const Badge(
                      backgroundColor: AppTheme.dangerRed,
                      child: Icon(Icons.notifications_active_outlined),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              selectedIcon:
                  Icon(Icons.notifications_active_rounded, color: selectedColor),
              label: s.navMonitor,
            ),
            NavigationDestination(
              icon: const Icon(Icons.location_on_outlined),
              selectedIcon:
                  Icon(Icons.location_on_rounded, color: selectedColor),
              label: s.navMap,
            ),
            NavigationDestination(
              icon: const Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded, color: selectedColor),
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
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final subtle = isDark ? Colors.white60 : AppTheme.mutedSlate;

    final navItems = [
      (
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: s.navHome,
        badgeCount: 0,
        showDot: false,
      ),
      (
        icon: Icons.backpack_outlined,
        selectedIcon: Icons.backpack_rounded,
        label: s.navKit,
        badgeCount: alertCount,
        showDot: false,
      ),
      (
        icon: Icons.notifications_active_outlined,
        selectedIcon: Icons.notifications_active_rounded,
        label: s.navMonitor,
        badgeCount: 0,
        showDot: isDrillActive,
      ),
      (
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on_rounded,
        label: s.navMap,
        badgeCount: 0,
        showDot: false,
      ),
      (
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield_rounded,
        label: s.navSafety,
        badgeCount: 0,
        showDot: false,
      ),
    ];

    return Container(
      width: 244,
      color: bg,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Logo Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryNavy, AppTheme.primaryAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Colors.white,
                    size: 21,
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
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : AppTheme.primaryNavy,
                        ),
                      ),
                      Text(
                        s.appSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: subtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Prominent Panic-Proof Emergency SOS Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.emergency_rounded, size: 20),
              label: Text(
                settings.isFilipino ? 'Tawag SOS / 911' : 'Emergency SOS',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => SosSheet.show(context),
            ),
          ),
          const SizedBox(height: 18),

          // Clean Nav Items
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final item = navItems[idx];
                final active = currentIndex == idx;
                final activeBg = isDark
                    ? Colors.lightBlue.shade200.withAlpha(28)
                    : AppTheme.primaryNavy.withAlpha(14);
                final activeFg =
                    isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;
                final idleFg = isDark ? Colors.white60 : AppTheme.mutedSlate;

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
                              width: 8,
                              height: 8,
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

          const Divider(height: 18),

          // Admin Portal Shortcut (ONLY visible when signed in as Admin)
          if (auth.isAdmin) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings_rounded, size: 19),
                label: const Text(
                  'Admin Portal',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Family Backup & Sync Tile
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
                    auth.isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : (auth.isAuthenticated
                            ? Icons.cloud_done_rounded
                            : Icons.person_outline_rounded),
                    size: 19,
                    color: auth.isAdmin
                        ? AppTheme.primaryAccent
                        : (auth.isAuthenticated ? AppTheme.safeGreen : subtle),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isAdmin
                              ? (auth.fullName ?? 'Admin Account')
                              : (auth.isAuthenticated
                                  ? (auth.householdName ?? 'Family Synced')
                                  : (settings.isFilipino
                                      ? 'I-save sa Cloud'
                                      : 'Family Backup')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.darkSlate,
                          ),
                        ),
                        Text(
                          auth.isAdmin
                              ? 'Administrator'
                              : (auth.isAuthenticated
                                  ? 'Code: ${auth.inviteCode ?? '-'}'
                                  : (settings.isFilipino
                                      ? 'Mag-sign in o mag-sync'
                                      : 'Sign in to share & sync')),
                          style: TextStyle(fontSize: 11.5, color: subtle),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: subtle),
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
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => settings.toggleLanguage(),
                  child: Text(
                    settings.isFilipino ? 'FIL' : 'EN',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => settings.toggleDarkMode(),
                  child: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
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
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF59E0B), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF92400E),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF78350F),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF92400E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: onExit,
                child: Text(
                  exitLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineModeBanner extends StatelessWidget {
  final bool isFil;

  const _OfflineModeBanner({required this.isFil});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E3A5F),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF93C5FD),
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFil
                      ? 'Offline Mode • Gumagana pa rin ang Go-Bag, Gabay, Hotlines at Plano. Awtomatikong magsi-sync kapag may signal.'
                      : 'Offline Mode • Your Go-Bag, Guides, Hotlines & Plan still work. Updates will sync when signal returns.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
