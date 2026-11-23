import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/advisory_banner.dart';
import '../widgets/responsive_container.dart';
import 'disaster_guide_screen.dart';

class _ManilaFloodHotspot {
  final String corridor;
  final String district;
  final String nearestShelter;

  const _ManilaFloodHotspot(this.corridor, this.district, this.nearestShelter);
}

const List<_ManilaFloodHotspot> _manilaFloodHotspots = [
  _ManilaFloodHotspot(
    'España Blvd & Dapitan St.',
    'Sampaloc',
    'Dapitan Sports Complex',
  ),
  _ManilaFloodHotspot(
    'Taft Ave., UN Ave. & Quirino Ave.',
    'Ermita / Malate',
    'Rizal Memorial / Paraiso Complex',
  ),
  _ManilaFloodHotspot(
    'Pedro Gil, Quirino & San Andres',
    'Paco / San Andres',
    'Paco Arena / San Andres Complex',
  ),
  _ManilaFloodHotspot(
    'Rizal Ave., Delpan & Gagalangin',
    'Tondo / San Nicolas',
    'Delpan / Patricia Sports Complex',
  ),
  _ManilaFloodHotspot(
    'Baseco Compound & Roxas Blvd.',
    'Port Area',
    'Baseco Evacuation Center',
  ),
];

class EmergencyMonitoringScreen extends StatelessWidget {
  final VoidCallback? onOpenNearbyShelters;

  const EmergencyMonitoringScreen({super.key, this.onOpenNearbyShelters});

  @override
  Widget build(BuildContext context) {
    final mon = context.watch<MonitoringProvider>();
    final settings = context.watch<SettingsProvider>();
    final emergency = context.watch<EmergencyProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;

    final isAlert = mon.isHazardActive;
    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;
    final accentNavy = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    final areaLabel = emergency.hasLiveGps
        ? (isFil ? 'Iyong Lokasyon (Maynila)' : 'Your Location (Manila)')
        : (isFil ? 'Lungsod ng Maynila' : 'City of Manila');

    final syncText = mon.isOfflineMode
        ? (isFil ? 'Offline • Naka-save na datos' : 'Offline • Showing saved info')
        : (isFil
            ? 'Updated ${mon.lastUpdated != null ? DateFormat('h:mm a').format(mon.lastUpdated!) : 'Ngayon'}'
            : 'Updated ${mon.lastUpdated != null ? DateFormat('h:mm a').format(mon.lastUpdated!) : 'Just now'}');

    return Scaffold(
      appBar: AppBar(
        title: Text(isFil ? 'Panahon at Alerto' : 'Weather & Alerts'),
        actions: [
          IconButton(
            icon: mon.isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentNavy,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: isFil ? 'I-update ang Alerto' : 'Refresh Weather & Alerts',
            onPressed: mon.isRefreshing
                ? null
                : () => mon.refreshLiveFeeds(
                      lat: emergency.userLat,
                      lng: emergency.userLng,
                    ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => mon.refreshLiveFeeds(
          lat: emergency.userLat,
          lng: emergency.userLng,
        ),
        child: ResponsiveContainer(
          maxWidth: 960,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // 1. Clean Top Status Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAlert
                        ? [const Color(0xFF991B1B), AppTheme.dangerRed]
                        : [const Color(0xFF065F46), AppTheme.safeGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(28),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAlert
                                ? Icons.warning_amber_rounded
                                : Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mon.friendlyStatusLabel(isFil),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    mon.isOfflineMode
                                        ? Icons.cloud_off_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '$areaLabel • $syncText',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isAlert) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.dangerRed,
                              minimumSize: const Size(0, 42),
                            ),
                            icon: const Icon(Icons.menu_book_rounded, size: 18),
                            label: Text(
                              isFil
                                  ? 'Gabay sa Pagtugon'
                                  : 'What To Do Guide',
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DisasterGuideScreen(),
                                ),
                              );
                            },
                          ),
                          if (onOpenNearbyShelters != null)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                minimumSize: const Size(0, 42),
                              ),
                              icon: const Icon(Icons.roofing_rounded, size: 18),
                              label: Text(
                                isFil
                                    ? 'Pinakamalapit na Shelter'
                                    : 'Nearest Manila Shelter',
                              ),
                              onPressed: onOpenNearbyShelters,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Official Manila DRRMO Advisories (Always visible status strip or live banners)
              if (mon.advisories.isNotEmpty) ...[
                DrrmAdvisoryBannerList(
                  advisories: mon.advisories,
                  isDark: isDark,
                  isFil: isFil,
                  maxItems: 5,
                ),
                const SizedBox(height: 4),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.safeGreen.withAlpha(isDark ? 45 : 20),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.campaign_outlined,
                          size: 18,
                          color: AppTheme.safeGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFil
                                  ? 'Opisyal na Abiso (Manila DRRMO)'
                                  : 'Manila DRRMO Official Advisories',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                            Text(
                              isFil
                                  ? 'Aktibo ang monitoring • Walang kasalukuyang babala sa Maynila.'
                                  : 'Live channel active • No active Manila advisories right now.',
                              style: TextStyle(fontSize: 12.5, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. 1-Tap Family Safety Check-In Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.family_restroom_rounded,
                            size: 20,
                            color: accentNavy,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFil
                                  ? 'Check-In ng Pamilya'
                                  : 'Family Safety Check-In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showCheckInDialog(
                              context,
                              mon,
                              emergency,
                              auth,
                              isFil,
                            ),
                            child: Text(isFil ? '+ Magdagdag' : '+ Add Note'),
                          ),
                        ],
                      ),
                      Text(
                        isFil
                            ? 'Ipaalam sa pamilya kung ligtas ka o kailangan ng tulong (naka-save kahit offline).'
                            : 'Let your family know your status with one tap — works offline and syncs automatically.',
                        style: TextStyle(fontSize: 13.5, color: subtleText),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.safeGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                              ),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                              ),
                              label: Text(
                                isFil ? 'Ligtas Kami' : "I'm Safe",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () async {
                                await mon.addSafetyCheckIn(
                                  'SAFE',
                                  isFil
                                      ? 'Ligtas ang lahat ng kasama sa bahay.'
                                      : 'Everyone is safe and accounted for.',
                                  latitude: emergency.userLat,
                                  longitude: emergency.userLng,
                                  authorName:
                                      auth.fullName ?? 'Family Member',
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFil
                                          ? 'Naitala: Ligtas kami.'
                                          : "Check-in saved: I'm Safe.",
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.dangerRed,
                                side: BorderSide(
                                  color: AppTheme.dangerRed.withAlpha(160),
                                ),
                                minimumSize: const Size(0, 48),
                              ),
                              icon: const Icon(Icons.emergency_rounded, size: 20),
                              label: Text(
                                isFil ? 'Kailangan ng Tulong' : 'Need Help',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => _showCheckInDialog(
                                context,
                                mon,
                                emergency,
                                auth,
                                isFil,
                                initialStatus: 'NEED ASSISTANCE',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (mon.safetyLog.isNotEmpty) ...[
                        const Divider(height: 24),
                        ...mon.safetyLog.take(4).map((entry) {
                          final ts = DateTime.tryParse(entry['timestamp'] ?? '');
                          final isSafe = entry['status'] == 'SAFE';
                          final isAssisted =
                              (entry['acknowledgedAt'] ?? '').isNotEmpty;
                          final ackBy = (entry['acknowledgedBy'] ?? '').trim();
                          final author = (entry['authorName'] ?? '').trim();
                          final badgeColor = isAssisted
                              ? Colors.teal.shade700
                              : (isSafe
                                  ? AppTheme.safeGreen
                                  : AppTheme.dangerRed);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isAssisted
                                      ? Icons.verified_rounded
                                      : (isSafe
                                          ? Icons.check_circle_rounded
                                          : Icons.error_rounded),
                                  size: 20,
                                  color: badgeColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            author.isNotEmpty
                                                ? '$author • ${entry['status']}'
                                                : '${entry['status']}',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: headingColor,
                                            ),
                                          ),
                                          if (isAssisted)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.teal
                                                    .withAlpha(isDark ? 55 : 24),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isFil
                                                    ? 'DRRM Tinugunan ✓'
                                                    : 'DRRM Assisted ✓',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.tealAccent
                                                      : Colors.teal.shade800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if ((entry['note'] ?? '').isNotEmpty)
                                        Text(
                                          entry['note']!,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: subtleText,
                                          ),
                                        ),
                                      if (isAssisted && ackBy.isNotEmpty)
                                        Text(
                                          isFil
                                              ? 'Kinumpirma ni $ackBy'
                                              : 'Acknowledged by $ackBy',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.tealAccent
                                                : Colors.teal.shade700,
                                          ),
                                        ),
                                      if (ts != null)
                                        Text(
                                          DateFormat('MMM d • h:mm a')
                                              .format(ts),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtleText.withAlpha(180),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Local Weather, PAGASA Heat Index & Next 6-Hour Rain Risk
              Text(
                isFil
                    ? 'Panahon at Heat Index ($areaLabel)'
                    : 'Local Weather & Heat Index ($areaLabel)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildWeatherCard(
                mon: mon,
                isDark: isDark,
                isFil: isFil,
                headingColor: headingColor,
                subtleText: subtleText,
              ),
              const SizedBox(height: 14),

              // 5. City of Manila Flood-Watch Hotspots Card (Offline-Ready)
              _buildManilaFloodWatchCard(
                context: context,
                mon: mon,
                isDark: isDark,
                isFil: isFil,
                headingColor: headingColor,
                subtleText: subtleText,
              ),
              const SizedBox(height: 18),

              // 6. Recent Earthquakes (Manila & Luzon with Distance from Manila)
              Text(
                isFil
                    ? 'Mga Lindol Malapit sa Maynila (Luzon)'
                    : 'Recent Earthquakes (Manila & Luzon)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),
              if (mon.earthquakes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      isFil
                          ? 'Walang naitalang lindol malapit sa Maynila.'
                          : 'No recent earthquakes recorded near Manila.',
                      style: TextStyle(fontSize: 14, color: subtleText),
                    ),
                  ),
                )
              else
                ...mon.earthquakes.map((q) {
                  final strong = q.magnitude >= 5.0;
                  final distKm = q.distanceFromManilaKm();
                  final bearing = q.bearingFromManila();
                  final isNearManila = distKm != null && distKm <= 160;
                  final magColor = strong
                      ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
                      : (isDark
                          ? Colors.amber.shade300
                          : AppTheme.warningAmber);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: magColor.withAlpha(isDark ? 45 : 22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'M${q.magnitude.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: magColor,
                          ),
                        ),
                      ),
                      title: Text(
                        q.place,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${isFil ? 'Lalim' : 'Depth'}: ${q.depthKm.toStringAsFixed(0)} km • ${DateFormat('MMM d, h:mm a').format(q.time.toLocal())}',
                            style: TextStyle(fontSize: 12.5, color: subtleText),
                          ),
                          if (distKm != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (isNearManila
                                        ? AppTheme.warningAmber
                                        : AppTheme.mutedSlate)
                                    .withAlpha(isDark ? 45 : 20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                distKm < 5
                                    ? (isFil
                                        ? 'Sa loob ng Maynila'
                                        : 'City of Manila Area')
                                    : '${distKm.toStringAsFixed(0)} km${bearing != null ? ' $bearing' : ''} ${isFil ? 'mula sa Maynila' : 'from Manila'}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isNearManila
                                      ? (isDark
                                          ? Colors.amber.shade200
                                          : const Color(0xFFB45309))
                                      : subtleText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 16),

              // 7. PAGASA Rainfall & Typhoon Guide (Offline)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: accentNavy,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isFil
                                ? 'Gabay sa Babala ng PAGASA'
                                : 'PAGASA Rainfall & Storm Guide',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPagasaLegendRow(
                        color: const Color(0xFFCA8A04),
                        badge: 'YELLOW',
                        description: isFil
                            ? 'Posibleng bumaha sa mabababang lugar ng Maynila — magbantay.'
                            : 'Flooding possible in low-lying Manila streets — stay alert.',
                        subtleText: subtleText,
                      ),
                      const SizedBox(height: 8),
                      _buildPagasaLegendRow(
                        color: const Color(0xFFEA580C),
                        badge: 'ORANGE',
                        description: isFil
                            ? 'Nagbabanta ang baha — ihanda ang Go-Bag at ruta.'
                            : 'Flooding threatening — prepare Go-Bag & evacuation route.',
                        subtleText: subtleText,
                      ),
                      const SizedBox(height: 8),
                      _buildPagasaLegendRow(
                        color: AppTheme.dangerRed,
                        badge: 'RED',
                        description: isFil
                            ? 'Matinding baha — lumikas agad sa pinakamalapit na shelter sa Maynila.'
                            : 'Severe flooding imminent — evacuate to nearest Manila shelter.',
                        subtleText: subtleText,
                      ),
                      const SizedBox(height: 8),
                      _buildPagasaLegendRow(
                        color: const Color(0xFF7C3AED),
                        badge: 'SIGNAL #3+',
                        description: isFil
                            ? 'Malakas na hangin ng bagyo — manatili sa matibay na silungan.'
                            : 'Damaging typhoon winds — stay indoors away from windows.',
                        subtleText: subtleText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 8. Practice a Disaster Drill (Collapsed by default so households never get confused)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded:
                        mon.drillMode != DrillAlertMode.liveNormal,
                    leading: Icon(
                      Icons.play_circle_outline_rounded,
                      color: accentNavy,
                    ),
                    title: Text(
                      isFil
                          ? 'Magsanay ng Disaster Drill'
                          : 'Practice a Disaster Drill',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: headingColor,
                      ),
                    ),
                    subtitle: Text(
                      isFil
                          ? 'Subukan kung paano gumagana ang alerto kasama ang pamilya'
                          : 'Rehearse emergency alerts safely with your family',
                      style: TextStyle(fontSize: 12.5, color: subtleText),
                    ),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DrillAlertMode.values.map((mode) {
                          final selected = mon.drillMode == mode;
                          final isNormal = mode == DrillAlertMode.liveNormal;
                          return ChoiceChip(
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            label: Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: selected ? Colors.white : headingColor,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            selectedColor: isNormal
                                ? AppTheme.safeGreen
                                : AppTheme.warningAmber,
                            backgroundColor: isDark
                                ? AppTheme.darkElevated
                                : AppTheme.surfaceBg,
                            onSelected: (_) => mon.setDrillMode(mode),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard({
    required MonitoringProvider mon,
    required bool isDark,
    required bool isFil,
    required Color headingColor,
    required Color subtleText,
  }) {
    final w = mon.weather;
    if (w == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isFil ? 'Kinukuha ang lagay ng panahon...' : 'Checking local weather...',
            style: TextStyle(fontSize: 14, color: subtleText),
          ),
        ),
      );
    }

    final hi = w.apparentTemperatureC;
    final Color hiColor;
    final String hiLabel;
    if (hi >= 42) {
      hiColor = AppTheme.dangerRed;
      hiLabel = isFil ? 'DANGER HEAT INDEX' : 'DANGER HEAT';
    } else if (hi >= 33) {
      hiColor = AppTheme.warningAmber;
      hiLabel = isFil ? 'EXTREME CAUTION' : 'EXTREME CAUTION';
    } else {
      hiColor = AppTheme.safeGreen;
      hiLabel = isFil ? 'NORMAL NA INIT' : 'NORMAL HEAT';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeatherMetric(
                  Icons.thermostat_rounded,
                  '${w.temperatureC.toStringAsFixed(0)}°C',
                  mon.localizedWeatherCondition(isFil),
                  Colors.orange.shade500,
                  headingColor,
                  subtleText,
                ),
                _buildWeatherMetric(
                  Icons.wb_sunny_rounded,
                  '${hi.toStringAsFixed(0)}°C',
                  isFil ? 'Init (Feels Like)' : 'Heat Index',
                  hiColor,
                  headingColor,
                  subtleText,
                ),
                _buildWeatherMetric(
                  Icons.air_rounded,
                  '${w.windSpeedKmh.toStringAsFixed(0)} km/h',
                  isFil ? 'Hangin' : 'Wind',
                  Colors.blue.shade500,
                  headingColor,
                  subtleText,
                ),
                _buildWeatherMetric(
                  Icons.water_drop_outlined,
                  '${w.precipitationMm.toStringAsFixed(1)} mm',
                  isFil ? 'Ulan Ngayon' : 'Rain Now',
                  Colors.teal.shade500,
                  headingColor,
                  subtleText,
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hiColor.withAlpha(isDark ? 45 : 22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.device_thermostat_rounded,
                          size: 14, color: hiColor),
                      const SizedBox(width: 5),
                      Text(
                        'PAGASA $hiLabel (${hi.toStringAsFixed(0)}°C)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: hiColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(isDark ? 40 : 18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.umbrella_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.lightBlue.shade200
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isFil
                            ? 'Susunod na 6h Ulan: ${w.rainChance6hPct}%${w.rainExpected6hMm > 0 ? ' (${w.rainExpected6hMm} mm)' : ''} • RH ${w.humidityPct}%'
                            : 'Next 6h Rain: ${w.rainChance6hPct}%${w.rainExpected6hMm > 0 ? ' (${w.rainExpected6hMm} mm)' : ''} • RH ${w.humidityPct}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.lightBlue.shade200
                              : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManilaFloodWatchCard({
    required BuildContext context,
    required MonitoringProvider mon,
    required bool isDark,
    required bool isFil,
    required Color headingColor,
    required Color subtleText,
  }) {
    final elevated = mon.isFloodRiskElevated;
    final riskColor = elevated ? AppTheme.warningAmber : AppTheme.safeGreen;
    final riskBadge = elevated
        ? (isFil ? 'MAGBANTAY SA BAHA' : 'FLOOD WATCH')
        : (isFil ? 'MABABA / TUYO' : 'LOW RISK');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: elevated,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: riskColor.withAlpha(isDark ? 45 : 22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.water_rounded, color: riskColor, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  isFil
                      ? 'Flood-Watch Hotspots (Maynila)'
                      : 'Manila Flood-Watch Hotspots',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: headingColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(isDark ? 45 : 22),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  riskBadge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            isFil
                ? 'Mga madalas bahain sa Maynila at pinakamalapit na evacuation shelter'
                : 'Known Manila flood corridors & nearest official evacuation centers',
            style: TextStyle(fontSize: 12.5, color: subtleText),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            ..._manilaFloodHotspots.map((h) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: riskColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${h.corridor} (${h.district})',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: headingColor,
                            ),
                          ),
                          Text(
                            '${isFil ? 'Malapit na Shelter' : 'Nearest Shelter'}: ${h.nearestShelter}',
                            style: TextStyle(fontSize: 12.5, color: subtleText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (onOpenNearbyShelters != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(
                    isFil
                        ? 'Buksan ang Mapa ng Manila Shelters'
                        : 'Open City of Manila Evacuation Map',
                  ),
                  onPressed: onOpenNearbyShelters,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPagasaLegendRow({
    required Color color,
    required String badge,
    required String description,
    required Color subtleText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 86,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(120)),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: TextStyle(fontSize: 13.5, height: 1.35, color: subtleText),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherMetric(
    IconData icon,
    String value,
    String label,
    Color color,
    Color headingColor,
    Color subtleText,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: subtleText),
          ),
        ],
      ),
    );
  }

  void _showCheckInDialog(
    BuildContext context,
    MonitoringProvider mon,
    EmergencyProvider emergency,
    AuthProvider auth,
    bool isFil, {
    String initialStatus = 'SAFE',
  }) {
    String selectedStatus = initialStatus;
    final noteCtrl = TextEditingController(
      text: initialStatus == 'SAFE'
          ? (isFil
              ? 'Ligtas ang lahat ng miyembro ng pamilya sa bahay.'
              : 'Everyone in the household is safe at home.')
          : (isFil
              ? 'Kailangan ng tulong o gamit sa aming lokasyon.'
              : 'Need assistance or supplies at our current location.'),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isFil ? 'Check-In ng Pamilya' : 'Family Safety Check-In',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: InputDecoration(
                  labelText: isFil ? 'Kalagayan' : 'Status',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'SAFE',
                    child: Text(isFil ? 'Ligtas Kami' : "I'm Safe"),
                  ),
                  DropdownMenuItem(
                    value: 'EVACUATING',
                    child: Text(
                      isFil ? 'Lumilikas na sa Shelter' : 'Moving to Shelter',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'NEED ASSISTANCE',
                    child: Text(
                      isFil ? 'Kailangan ng Tulong' : 'Need Help / Supplies',
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => selectedStatus = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isFil ? 'Mensahe (Opsyonal)' : 'Note (Optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isFil ? 'Kanselahin' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                mon.addSafetyCheckIn(
                  selectedStatus,
                  noteCtrl.text.trim(),
                  latitude: emergency.userLat,
                  longitude: emergency.userLng,
                  authorName: auth.fullName ?? 'Family Member',
                );
                Navigator.pop(ctx);
              },
              child: Text(isFil ? 'I-save' : 'Save Check-In'),
            ),
          ],
        ),
      ),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 400), noteCtrl.dispose);
    });
  }
}
