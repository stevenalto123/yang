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

    final isHazardAlert = monitoring.isHazardActive;
    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;
    final appBarIconColor = isDark ? Colors.white : AppTheme.darkSlate;
    final chipBg = isDark ? AppTheme.darkElevated : AppTheme.surfaceBg;
    final chipBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryNavy, AppTheme.primaryAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LifeCheckpoint',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: -0.3,
                            color: headingColor,
                          ),
                        ),
                        Text(
                          s.appSubtitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: () => settings.toggleLanguage(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 42, minHeight: 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: chipBorder),
                      ),
                      child: Text(
                        isFil ? 'FIL' : 'EN',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
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
                    color: appBarIconColor,
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
                                : Icons.person_outline_rounded,
                            color: appBarIconColor,
                          ),
                        )
                      : Icon(
                          auth.isAuthenticated
                              ? Icons.cloud_done_outlined
                              : Icons.person_outline_rounded,
                          color: auth.isAuthenticated
                              ? AppTheme.safeGreen
                              : appBarIconColor,
                        ),
                  tooltip: isFil ? 'Family Backup' : 'Family Backup & Sync',
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
                          child: Icon(
                            Icons.notifications_outlined,
                            color: appBarIconColor,
                          ),
                        )
                      : Icon(
                          Icons.notifications_outlined,
                          color: appBarIconColor,
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
                const SizedBox(width: 4),
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
                  isDesktop ? 32 : 16,
                  isDesktop ? 28 : 16,
                  isDesktop ? 32 : 16,
                  isDesktop ? 40 : 96,
                ),
                child: ResponsiveContainer(
                  maxWidth: 980,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clean Desktop Header
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
                                        ? 'Kahandaan ng Pamilya'
                                        : 'Family Preparedness',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: headingColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isFil
                                        ? 'Suriin ang Go-Bag, lagay ng panahon, at plano ng pamilya kahit walang internet.'
                                        : 'Track your emergency supplies, local alerts, and family plan — even offline.',
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
                                        size: 19,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.notifications_outlined,
                                      size: 19,
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
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(isFil ? 'I-update' : 'Refresh'),
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
                        const SizedBox(height: 22),
                      ],

                      // Hero Go-Bag Readiness Card
                      _buildHeroReadinessCard(
                        context,
                        kit: kit,
                        auth: auth,
                        s: s,
                        readiness: readiness,
                        scoreColor: heroScoreColor,
                        missingCount: missingCount,
                        alertCount: alertCount,
                        isDesktop: isDesktop,
                        isFil: isFil,
                      ),
                      const SizedBox(height: 16),

                      // Today's Local Status Card
                      _buildLocalStatusCard(
                        context,
                        monitoring: monitoring,
                        emergency: emergency,
                        isHazardAlert: isHazardAlert,
                        isDark: isDark,
                        isFil: isFil,
                        headingColor: headingColor,
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

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.quickToolsTitle,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: headingColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.safeGreen
                                  .withAlpha(isDark ? 36 : 18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.offline_pin_outlined,
                                  size: 14,
                                  color: AppTheme.safeGreen,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isFil
                                      ? 'Gumagana Offline'
                                      : 'Works Offline',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.safeGreen,
                                  ),
                                ),
                              ],
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

                      const SizedBox(height: 28),
                      Center(
                        child: Text(
                          isFil
                              ? 'LifeCheckpoint • Gabay ng Pamilya sa Metro Manila (EAC)'
                              : 'LifeCheckpoint • Metro Manila Family Preparedness • EAC',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: subtleText.withAlpha(180),
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

  Widget _buildHeroReadinessCard(
    BuildContext context, {
    required KitProvider kit,
    required AuthProvider auth,
    required AppStrings s,
    required double readiness,
    required Color scoreColor,
    required int missingCount,
    required int alertCount,
    required bool isDesktop,
    required bool isFil,
  }) {
    final totalMembers = kit.householdProfile.totalPeople;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryNavy, AppTheme.primaryNavyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withAlpha(38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Family size pill + Cloud Backup pill
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFil
                          ? 'Kit para sa $totalMembers miyembro'
                          : 'Kit for $totalMembers ${totalMembers == 1 ? 'person' : 'people'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
                        ? AppTheme.safeGreen.withAlpha(160)
                        : Colors.white.withAlpha(18),
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
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          auth.isAuthenticated
                              ? (isFil
                                  ? 'Naka-sync • Code: ${auth.inviteCode ?? '-'}'
                                  : 'Synced • Family Code: ${auth.inviteCode ?? '-'}')
                              : (auth.pendingSyncCount > 0
                                  ? (isFil
                                      ? 'Naka-save dito (${auth.pendingSyncCount} naghihintay)'
                                      : 'Saved on device (${auth.pendingSyncCount} pending)')
                                  : (isFil
                                      ? 'Naka-save dito • Mag-sign in para sa backup'
                                      : 'Saved on device • Sign in to back up')),
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

          // Main Radial Score + Clear Action
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: isDesktop ? 112 : 94,
                height: isDesktop ? 112 : 94,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (readiness / 100).clamp(0.0, 1.0),
                      strokeWidth: 9,
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
                              fontSize: isDesktop ? 27 : 23,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isFil ? 'HANDA' : 'READY',
                            style: TextStyle(
                              fontSize: 10,
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
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
                      isFil
                          ? '${kit.packedItemsCount} sa ${kit.totalItemsCount} gamit ang handa na. $missingCount pa ang kulang.'
                          : '${kit.packedItemsCount} of ${kit.totalItemsCount} essentials packed • $missingCount left to pack.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryNavy,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.backpack_outlined, size: 18),
                      label: Text(
                        isFil ? 'Buksan ang Go-Bag' : 'Update Go-Bag',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => onNavigateTab(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Clean KPI Mini-Tiles
          Row(
            children: [
              Expanded(
                child: _buildHeroMetricTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: isFil ? 'Handa Na' : 'Packed',
                  value: '${kit.packedItemsCount}/${kit.totalItemsCount}',
                  sub: isFil ? 'mga gamit' : 'items ready',
                  accent: const Color(0xFF38BDF8),
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMetricTile(
                  icon: Icons.playlist_add_outlined,
                  label: isFil ? 'Kulang Pa' : 'To Pack',
                  value: '$missingCount',
                  sub: isFil ? 'i-tap para makita' : 'tap to view',
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
                  icon: Icons.schedule_rounded,
                  label: isFil ? 'Palitan' : 'Expiring',
                  value: '$alertCount',
                  sub: alertCount > 0
                      ? (isFil ? 'kailangan palitan' : 'needs review')
                      : (isFil ? 'lahat maayos' : 'all good'),
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
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(22)),
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

  Widget _buildLocalStatusCard(
    BuildContext context, {
    required MonitoringProvider monitoring,
    required EmergencyProvider emergency,
    required bool isHazardAlert,
    required bool isDark,
    required bool isFil,
    required Color headingColor,
    required Color subtleText,
  }) {
    final accent = isHazardAlert
        ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
        : (isDark ? Colors.green.shade300 : AppTheme.safeGreen);

    final areaName = emergency.hasLiveGps
        ? (isFil ? 'Iyong Lokasyon' : 'Your Area')
        : 'Metro Manila';

    final weatherLine = monitoring.weather != null
        ? '$areaName • ${monitoring.weather!.temperatureC.toStringAsFixed(0)}°C • ${monitoring.weather!.conditionText}'
        : (isFil
            ? 'I-tap para makita ang panahon, lindol, at family check-in'
            : 'Tap to view local weather, earthquakes & family check-in');

    return Material(
      color: isHazardAlert
          ? (isDark
              ? AppTheme.dangerRed.withAlpha(36)
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
                  ? AppTheme.dangerRed.withAlpha(150)
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withAlpha(isDark ? 45 : 22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isHazardAlert
                      ? Icons.warning_amber_rounded
                      : Icons.wb_sunny_outlined,
                  color: accent,
                  size: 23,
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
                            monitoring.friendlyStatusLabel(isFil),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weatherLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: subtleText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: subtleText,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hasExpired
            ? (isDark
                ? AppTheme.dangerRed.withAlpha(38)
                : const Color(0xFFFEF2F2))
            : (isDark
                ? AppTheme.warningAmber.withAlpha(38)
                : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(130)),
      ),
      child: Row(
        children: [
          Icon(
            hasExpired ? Icons.error_outline_rounded : Icons.schedule_rounded,
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
                          ? '$expired paso at $expiringSoon malapit ma-expire'
                          : '$expired expired & $expiringSoon expiring soon')
                      : (isFil
                          ? '$expiringSoon gamit ang malapit ma-expire'
                          : '$expiringSoon item(s) expiring within ${kit.expiryAlertDays} days'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFil
                      ? 'Palitan ang lumang tubig, pagkain, o gamot sa Go-Bag.'
                      : 'Check and replace old food, water, or medicine.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppTheme.mutedSlate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  hasExpired ? AppTheme.dangerRed : AppTheme.warningAmber,
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
              isFil ? 'Tingnan' : 'Review',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
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
        subtitle: isFil
            ? 'Bagyo, Baha, Lindol, Sunog'
            : 'Typhoon, Flood, Quake, Fire',
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
        subtitle: isFil
            ? 'Tagpuan at mga emergency roles'
            : 'Meeting places & family roles',
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
        icon: Icons.event_repeat_rounded,
        iconColor: alertCount > 0
            ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
            : (isDark ? Colors.amber.shade300 : AppTheme.warningAmber),
        title: s.replacementAlerts,
        subtitle: alertCount > 0
            ? (isFil ? '$alertCount kailangan palitan' : '$alertCount items need review')
            : (isFil ? '$missingCount kulang pa' : '$missingCount left to pack'),
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
        subtitle: isFil
            ? 'Suriin ang handa at mag-rate'
            : 'Category breakdown & feedback',
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
                    Icons.arrow_forward_rounded,
                    size: 17,
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
