import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/kit_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
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
    final s = AppStrings(isFil);

    final readiness = kit.readinessPercentage;
    final rawReadiness = kit.rawCompletionPercentage;
    final expiredCount = kit.expiredItemsCount;
    final expiringSoonCount = kit.expiringSoonItemsCount;
    final missingCount = kit.missingItemsCount;
    final alertCount = expiredCount + expiringSoonCount;

    Color scoreColor;
    if (readiness >= 85) {
      scoreColor = isDark ? Colors.green.shade300 : AppTheme.safeGreen;
    } else if (readiness >= 50) {
      scoreColor = isDark ? Colors.amber.shade300 : AppTheme.warningAmber;
    } else {
      scoreColor = isDark ? Colors.red.shade300 : AppTheme.dangerRed;
    }

    final isHazardAlert =
        monitoring.drillMode != DrillAlertMode.liveNormal ||
            monitoring.currentThreatLevel.contains('ALERT') ||
            monitoring.currentThreatLevel.contains('WARNING');

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LifeCheckpoint',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    s.appSubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
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
          // EN / FIL Language Toggle (minimum 48dp height)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              onTap: () => settings.toggleLanguage(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(32),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: Text(
                  isFil ? 'FIL' : 'EN',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => settings.toggleDarkMode(),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
            tooltip: isFil ? 'Account at Cloud Sync' : 'Account & Cloud Sync',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountSyncScreen()),
              );
            },
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtle EAC Institutional Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.eacCrimson.withAlpha(isDark ? 55 : 18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.eacCrimson.withAlpha(isDark ? 140 : 60),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school,
                            size: 16,
                            color: isDark
                                ? Colors.pink.shade200
                                : AppTheme.eacCrimson,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Emilio Aguinaldo College • Disaster Preparedness',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.pink.shade100
                                    : AppTheme.eacCrimson,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSyncScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: auth.isAuthenticated
                              ? AppTheme.safeGreen.withAlpha(isDark ? 45 : 20)
                              : (isDark
                                  ? AppTheme.darkCard
                                  : Colors.blueGrey.shade50),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: auth.isAuthenticated
                                ? AppTheme.safeGreen.withAlpha(110)
                                : (isDark
                                    ? AppTheme.darkBorder
                                    : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              auth.isAuthenticated
                                  ? Icons.cloud_done
                                  : Icons.cloud_off_outlined,
                              size: 15,
                              color: auth.isAuthenticated
                                  ? (isDark
                                      ? Colors.green.shade200
                                      : AppTheme.safeGreen)
                                  : subtleText,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: auth.isAuthenticated
                                      ? (isDark
                                          ? Colors.green.shade200
                                          : AppTheme.safeGreen)
                                      : subtleText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Top Urgent Alert / Monitoring Status Strip
                    InkWell(
                      onTap: () => onNavigateTab(2),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isHazardAlert
                              ? (isDark
                                  ? AppTheme.dangerRed.withAlpha(45)
                                  : const Color(0xFFFFEBEE))
                              : (isDark
                                  ? AppTheme.safeGreen.withAlpha(35)
                                  : const Color(0xFFE8F5E9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHazardAlert
                                ? AppTheme.dangerRed
                                : (isDark
                                    ? Colors.green.shade400
                                    : Colors.green.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isHazardAlert
                                  ? Icons.warning_amber_rounded
                                  : Icons.radar,
                              color: isHazardAlert
                                  ? (isDark
                                      ? Colors.red.shade200
                                      : AppTheme.dangerRed)
                                  : (isDark
                                      ? Colors.green.shade200
                                      : AppTheme.safeGreen),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    monitoring.currentThreatLevel,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isHazardAlert
                                          ? (isDark
                                              ? Colors.red.shade200
                                              : AppTheme.dangerRed)
                                          : (isDark
                                              ? Colors.green.shade200
                                              : Colors.green.shade900),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    monitoring.weather != null
                                        ? 'Metro Manila: ${monitoring.weather!.temperatureC.toStringAsFixed(0)}°C • ${monitoring.weather!.conditionText} (${monitoring.earthquakes.length} PH quakes)'
                                        : (isFil
                                            ? 'I-tap para sa lagay ng panahon at lindol'
                                            : 'Tap for weather, PH seismic feed & check-in'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: subtleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: subtleText),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Weighted Readiness Score Card
                    _buildReadinessCard(
                      context,
                      kit,
                      s,
                      readiness,
                      rawReadiness,
                      scoreColor,
                      isDark,
                      isFil,
                      headingColor,
                      subtleText,
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

                    const SizedBox(height: 18),
                    Text(
                      s.quickToolsTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: headingColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Clean 2x2 Preparedness Tools Grid (IntrinsicHeight avoids overflow)
                    _buildQuickToolsGrid(
                      context,
                      s,
                      missingCount,
                      alertCount,
                      isDark,
                      isFil,
                      headingColor,
                      subtleText,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReadinessCard(
    BuildContext context,
    KitProvider kit,
    AppStrings s,
    double readiness,
    double rawReadiness,
    Color scoreColor,
    bool isDark,
    bool isFil,
    Color headingColor,
    Color subtleText,
  ) {
    final linkColor = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: (readiness / 100).clamp(0.0, 1.0),
                        strokeWidth: 9,
                        backgroundColor:
                            isDark ? AppTheme.darkBg : Colors.grey.shade200,
                        color: scoreColor,
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          '${readiness.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.weightedScoreLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subtleText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.readinessStatus(readiness),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${kit.packedItemsCount}/${kit.totalItemsCount} ${isFil ? 'kumpleto' : 'packed'} (${rawReadiness.toStringAsFixed(0)}% raw) • ${kit.householdProfile.totalPeople} pax',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: headingColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              s.weightedExplain,
              style: TextStyle(fontSize: 14, color: subtleText),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: linkColor,
                      side: BorderSide(color: linkColor),
                    ),
                    icon: const Icon(Icons.checklist_rtl, size: 18),
                    label: Text(
                      isFil ? 'Ayusin ang Kit' : 'Update Go-Bag Kit',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onPressed: () => onNavigateTab(1),
                  ),
                ),
              ],
            ),
          ],
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
        ? (isDark ? Colors.red.shade200 : AppTheme.dangerRed)
        : (isDark ? Colors.amber.shade200 : AppTheme.warningAmber);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasExpired
            ? (isDark ? AppTheme.dangerRed.withAlpha(45) : const Color(0xFFFFEBEE))
            : (isDark
                ? AppTheme.warningAmber.withAlpha(45)
                : const Color(0xFFFFF3E0)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasExpired ? AppTheme.dangerRed : AppTheme.warningAmber,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasExpired ? Icons.error_outline : Icons.schedule,
            color: accent,
            size: 26,
          ),
          const SizedBox(width: 10),
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
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFil
                      ? 'Pindutin ang Palitan para mag-update.'
                      : 'Tap Replace to review and rotate supplies.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: accent,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: Text(
              isFil ? 'Palitan' : 'Replace',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToolsGrid(
    BuildContext context,
    AppStrings s,
    int missingCount,
    int alertCount,
    bool isDark,
    bool isFil,
    Color headingColor,
    Color subtleText,
  ) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildToolCard(
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                  icon: Icons.menu_book_rounded,
                  iconColor: isDark ? Colors.purple.shade200 : Colors.purple.shade700,
                  title: s.disasterGuides,
                  subtitle: isFil ? 'Bagyo, Lindol, Sunog' : 'Typhoon, Quake, Fire',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DisasterGuideScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToolCard(
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                  icon: Icons.home_work_outlined,
                  iconColor: isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy,
                  title: s.householdPlan,
                  subtitle: isFil ? 'Tagpuan at mga shutoff' : 'Meeting spots & shutoffs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyPlanScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildToolCard(
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                  icon: Icons.notifications_active_outlined,
                  iconColor: alertCount > 0
                      ? (isDark ? Colors.red.shade200 : AppTheme.dangerRed)
                      : (isDark ? Colors.amber.shade200 : AppTheme.warningAmber),
                  title: s.replacementAlerts,
                  subtitle: alertCount > 0
                      ? (isFil ? '$alertCount paalala ngayon' : '$alertCount active alerts')
                      : (isFil ? '$missingCount kulang pa' : '$missingCount items missing'),
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildToolCard(
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                  icon: Icons.fact_check_outlined,
                  iconColor: isDark ? Colors.tealAccent : Colors.teal.shade700,
                  title: s.readinessAudit,
                  subtitle: isFil ? 'ISO survey at grado' : 'Category score & survey',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelfAssessmentScreen(),
                      ),
                    );
                  },
                ),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(isDark ? 45 : 24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: subtleText),
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
