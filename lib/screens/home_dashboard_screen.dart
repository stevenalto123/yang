import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/kit_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'account_sync_screen.dart';
import 'disaster_guide_screen.dart';
import 'emergency_plan_screen.dart';
import 'notifications_screen.dart';
import 'self_assessment_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final monitoring = context.watch<MonitoringProvider>();
    final settings = context.watch<SettingsProvider>();
    final emergency = context.watch<EmergencyProvider>();
    final auth = context.watch<AuthProvider>();

    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final s = AppStrings(isFil);

    final readiness = kit.readinessPercentage;
    final rawReadiness = kit.rawCompletionPercentage;
    final expiredCount = kit.expiredItemsCount;
    final expiringSoonCount = kit.expiringSoonItemsCount;
    final missingCount = kit.missingItemsCount;
    final alertCount = expiredCount + expiringSoonCount;

    Color heroScoreColor;
    if (readiness >= 85) {
      heroScoreColor = const Color(0xFF4ADE80);
    } else if (readiness >= 50) {
      heroScoreColor = const Color(0xFFFBBF24);
    } else {
      heroScoreColor = const Color(0xFFF87171);
    }

    final isHazardAlert =
        monitoring.drillMode != DrillAlertMode.liveNormal ||
            monitoring.currentThreatLevel.contains('ALERT') ||
            monitoring.currentThreatLevel.contains('WARNING');

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              titleSpacing: 12,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'LifeCheckpoint',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          s.appSubtitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.normal,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    onTap: () => settings.toggleLanguage(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 46, minHeight: 38),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(28),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        isFil ? 'FIL' : 'EN',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: Colors.white,
                  ),
                  tooltip:
                      isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  onPressed: () => settings.toggleDarkMode(),
                ),
                IconButton(
                  icon: auth.pendingSyncCount > 0
                      ? Badge(
                          label: Text('${auth.pendingSyncCount}'),
                          backgroundColor: AppTheme.warningAmber,
                          child: Icon(
                            auth.isAuthenticated
                                ? Icons.cloud_sync_outlined
                                : Icons.account_circle_outlined,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          auth.isAuthenticated
                              ? Icons.cloud_done_outlined
                              : Icons.account_circle_outlined,
                          color: Colors.white,
                        ),
                  tooltip:
                      isFil ? 'Account at Cloud Sync' : 'Account & Cloud Sync',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountSyncScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: alertCount > 0
                      ? Badge(
                          label: Text('$alertCount'),
                          backgroundColor: AppTheme.dangerRed,
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                  tooltip: s.replacementAlerts,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: kit.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await kit.loadItems();
                await monitoring.refreshLiveFeeds(
                  lat: emergency.userLat,
                  lng: emergency.userLng,
                );
                if (auth.isAuthenticated) {
                  await auth.syncNow();
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 28 : 16,
                  isDesktop ? 24 : 14,
                  isDesktop ? 28 : 16,
                  isDesktop ? 40 : 96,
                ),
                child: ResponsiveContainer(
                  maxWidth: 1020,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Desktop Welcome Header
                      if (isDesktop) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFil
                                        ? 'Sentro ng Kahandaan sa Sakuna'
                                        : 'Household Preparedness Command Center',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: headingColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.appSubtitle,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      color: subtleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: alertCount > 0
                                  ? Badge(
                                      label: Text('$alertCount'),
                                      backgroundColor: AppTheme.dangerRed,
                                      child: const Icon(
                                        Icons.notifications_outlined,
                                        size: 20,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.notifications_outlined,
                                      size: 20,
                                    ),
                              label: Text(s.replacementAlerts),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.sync, size: 18),
                              label: Text(isFil ? 'I-refresh' : 'Refresh'),
                              onPressed: () async {
                                await monitoring.refreshLiveFeeds(
                                  lat: emergency.userLat,
                                  lng: emergency.userLng,
                                );
                                if (auth.isAuthenticated) {
                                  await auth.syncNow();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Hero Readiness Command Card
                      _buildHeroReadinessCard(
                        context,
                        kit: kit,
                        auth: auth,
                        s: s,
                        readiness: readiness,
                        rawReadiness: rawReadiness,
                        scoreColor: heroScoreColor,
                        missingCount: missingCount,
                        alertCount: alertCount,
                        isDesktop: isDesktop,
                        isFil: isFil,
                      ),
                      const SizedBox(height: 14),

                      // Live Hazard Telemetry Strip
                      _buildHazardStrip(
                        context,
                        monitoring: monitoring,
                        emergency: emergency,
                        isHazardAlert: isHazardAlert,
                        isDark: isDark,
                        isFil: isFil,
                        subtleText: subtleText,
                      ),

                      if (expiredCount > 0 || expiringSoonCount > 0) ...[
                        const SizedBox(height: 12),
                        _buildAlertBanner(
                          context,
                          kit,
                          expiredCount,
                          expiringSoonCount,
                          isDark,
                          isFil,
                        ),
                      ],

                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.quickToolsTitle,
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: headingColor,
                            ),
                          ),
                          Text(
                            isFil ? 'Offline-Ready' : '100% Offline-Ready',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: subtleText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildQuickToolsGrid(
                        context,
                        s: s,
                        missingCount: missingCount,
                        alertCount: alertCount,
                        isDark: isDark,
                        isDesktop: isDesktop,
                        isFil: isFil,
                        headingColor: headingColor,
                        subtleText: subtleText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroReadinessCard(
    BuildContext context, {
    required KitProvider kit,
    required AuthProvider auth,
    required AppStrings s,
    required double readiness,
    required double rawReadiness,
    required Color scoreColor,
    required int missingCount,
    required int alertCount,
    required bool isDesktop,
    required bool isFil,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF152F56), Color(0xFF0C1D36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withAlpha(45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top institutional + cloud sync badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.eacCrimson.withAlpha(180),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Emilio Aguinaldo College • Disaster Preparedness',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSyncScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: auth.isAuthenticated
                        ? AppTheme.safeGreen.withAlpha(150)
                        : Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: auth.isAuthenticated
                          ? const Color(0xFF86EFAC)
                          : Colors.white30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        auth.isAuthenticated
                            ? Icons.cloud_done
                            : Icons.cloud_off_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          auth.isAuthenticated
                              ? 'Synced • Family Code: ${auth.inviteCode ?? '-'}'
                              : (auth.pendingSyncCount > 0
                                  ? 'Offline Mode (${auth.pendingSyncCount} pending) • Tap to Sync'
                                  : 'Offline-Ready • Tap to Sign In & Sync'),
                          overflow: TextOverflow.ellipsis,
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
            ],
          ),
          const SizedBox(height: 20),

          // Main Radial Score + Action
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: isDesktop ? 116 : 98,
                height: isDesktop ? 116 : 98,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (readiness / 100).clamp(0.0, 1.0),
                      strokeWidth: 10,
                      backgroundColor: Colors.white.withAlpha(24),
                      color: scoreColor,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${readiness.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: isDesktop ? 28 : 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFil ? 'HANDA' : 'READY',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isDesktop ? 24 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.weightedScoreLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.readinessStatus(readiness),
                      style: TextStyle(
                        fontSize: isDesktop ? 22 : 19,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.weightedExplain,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryNavy,
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.checklist_rtl, size: 18),
                          label: Text(
                            isFil ? 'Ayusin ang Kit' : 'Update Go-Bag Kit',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => onNavigateTab(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 KPI Mini-Tiles inside Hero
          Row(
            children: [
              Expanded(
                child: _buildHeroMetricTile(
                  icon: Icons.inventory_2_outlined,
                  label: isFil ? 'Kumpleto' : 'Packed Items',
                  value: '${kit.packedItemsCount}/${kit.totalItemsCount}',
                  sub: '${rawReadiness.toStringAsFixed(0)}% raw',
                  accent: const Color(0xFF38BDF8),
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMetricTile(
                  icon: Icons.playlist_remove_rounded,
                  label: isFil ? 'Kulang' : 'Missing',
                  value: '$missingCount',
                  sub: '${kit.householdProfile.totalPeople} pax kit',
                  accent: const Color(0xFFFBBF24),
                  onTap: () {
                    kit.setFilterStatus(ItemFilterStatus.missing);
                    onNavigateTab(1);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMetricTile(
                  icon: Icons.event_busy_outlined,
                  label: isFil ? 'Palitan' : 'Expiry Alerts',
                  value: '$alertCount',
                  sub: alertCount > 0
                      ? (isFil ? 'Kailangan palitan' : 'Action needed')
                      : (isFil ? 'Lahat sariwa' : 'All fresh'),
                  accent: alertCount > 0
                      ? const Color(0xFFF87171)
                      : const Color(0xFF4ADE80),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHazardStrip(
    BuildContext context, {
    required MonitoringProvider monitoring,
    required EmergencyProvider emergency,
    required bool isHazardAlert,
    required bool isDark,
    required bool isFil,
    required Color subtleText,
  }) {
    final accent = isHazardAlert
        ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
        : (isDark ? Colors.green.shade300 : AppTheme.safeGreen);

    return Material(
      color: isHazardAlert
          ? (isDark
              ? AppTheme.dangerRed.withAlpha(38)
              : const Color(0xFFFEF2F2))
          : (isDark ? AppTheme.darkCard : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onNavigateTab(2),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHazardAlert
                  ? AppTheme.dangerRed.withAlpha(160)
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withAlpha(isDark ? 45 : 22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isHazardAlert ? Icons.warning_amber_rounded : Icons.radar,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            monitoring.currentThreatLevel,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      monitoring.weather != null
                          ? '${emergency.hasLiveGps ? 'Local GPS' : 'Metro Manila'}: ${monitoring.weather!.temperatureC.toStringAsFixed(0)}°C • ${monitoring.weather!.conditionText} • ${monitoring.earthquakes.length} PH quakes'
                          : (isFil
                              ? 'I-tap para sa lagay ng panahon at lindol'
                              : 'Tap for live weather, PH seismic feed & check-in'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: subtleText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: subtleText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBanner(
    BuildContext context,
    KitProvider kit,
    int expired,
    int expiringSoon,
    bool isDark,
    bool isFil,
  ) {
    final hasExpired = expired > 0;
    final accent = hasExpired
        ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
        : (isDark ? Colors.amber.shade300 : AppTheme.warningAmber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: hasExpired
            ? (isDark
                ? AppTheme.dangerRed.withAlpha(40)
                : const Color(0xFFFEF2F2))
            : (isDark
                ? AppTheme.warningAmber.withAlpha(40)
                : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(140)),
      ),
      child: Row(
        children: [
          Icon(
            hasExpired ? Icons.error_outline : Icons.schedule,
            color: accent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasExpired
                      ? (isFil
                          ? '$expired paso at $expiringSoon malapit ma-expire!'
                          : '$expired expired & $expiringSoon expiring item(s)!')
                      : (isFil
                          ? '$expiringSoon gamit ang malapit ma-expire sa ${kit.expiryAlertDays} araw!'
                          : '$expiringSoon item(s) expiring within ${kit.expiryAlertDays} days!'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFil
                      ? 'Pindutin ang Palitan para mag-update ng shelf-life.'
                      : 'Review and rotate expiring emergency supplies.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppTheme.mutedSlate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: hasExpired ? AppTheme.dangerRed : AppTheme.warningAmber,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: Text(
              isFil ? 'Palitan' : 'Replace',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToolsGrid(
    BuildContext context, {
    required AppStrings s,
    required int missingCount,
    required int alertCount,
    required bool isDark,
    required bool isDesktop,
    required bool isFil,
    required Color headingColor,
    required Color subtleText,
  }) {
    final cards = [
      _buildToolCard(
        isDark: isDark,
        headingColor: headingColor,
        subtleText: subtleText,
        icon: Icons.menu_book_rounded,
        iconColor: isDark ? Colors.purple.shade200 : const Color(0xFF7C3AED),
        title: s.disasterGuides,
        subtitle: isFil ? 'Bagyo, Lindol, Sunog' : 'Typhoon, Quake, Fire',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DisasterGuideScreen()),
          );
        },
      ),
      _buildToolCard(
        isDark: isDark,
        headingColor: headingColor,
        subtleText: subtleText,
        icon: Icons.home_work_outlined,
        iconColor: isDark ? Colors.lightBlue.shade200 : AppTheme.primaryAccent,
        title: s.householdPlan,
        subtitle: isFil ? 'Tagpuan at mga shutoff' : 'Meeting spots & shutoffs',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmergencyPlanScreen()),
          );
        },
      ),
      _buildToolCard(
        isDark: isDark,
        headingColor: headingColor,
        subtleText: subtleText,
        icon: Icons.notifications_active_outlined,
        iconColor: alertCount > 0
            ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
            : (isDark ? Colors.amber.shade300 : AppTheme.warningAmber),
        title: s.replacementAlerts,
        subtitle: alertCount > 0
            ? (isFil ? '$alertCount paalala ngayon' : '$alertCount active alerts')
            : (isFil ? '$missingCount kulang pa' : '$missingCount items missing'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
      _buildToolCard(
        isDark: isDark,
        headingColor: headingColor,
        subtleText: subtleText,
        icon: Icons.fact_check_outlined,
        iconColor: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
        title: s.readinessAudit,
        subtitle: isFil ? 'ISO survey at grado' : 'Category score & survey',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelfAssessmentScreen()),
          );
        },
      ),
    ];

    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 14),
            Expanded(child: cards[1]),
            const SizedBox(width: 14),
            Expanded(child: cards[2]),
            const SizedBox(width: 14),
            Expanded(child: cards[3]),
          ],
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required bool isDark,
    required Color headingColor,
    required Color subtleText,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(isDark ? 42 : 20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: subtleText.withAlpha(150),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: subtleText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
