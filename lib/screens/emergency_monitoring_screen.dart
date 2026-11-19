import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'disaster_guide_screen.dart';

class EmergencyMonitoringScreen extends StatelessWidget {
  const EmergencyMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mon = context.watch<MonitoringProvider>();
    final settings = context.watch<SettingsProvider>();
    final emergency = context.watch<EmergencyProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;

    final threat = mon.currentThreatLevel;
    final isAlert = mon.drillMode != DrillAlertMode.liveNormal ||
        threat.contains('ALERT') ||
        threat.contains('WARNING');

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;
    final accentNavy = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFil ? 'Pagsubaybay sa Sakuna' : 'Emergency Monitoring Hub'),
        actions: [
          IconButton(
            icon: mon.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: isFil ? 'I-sync ang Live Feeds' : 'Sync Live Feeds',
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
            // Connectivity / Cache Mode Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: mon.isOfflineMode
                    ? (isDark
                        ? Colors.amber.withAlpha(35)
                        : Colors.amber.shade50)
                    : (isDark
                        ? AppTheme.safeGreen.withAlpha(35)
                        : Colors.green.shade50),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: mon.isOfflineMode
                      ? (isDark ? Colors.amber.shade400 : Colors.amber.shade300)
                      : (isDark ? Colors.green.shade400 : Colors.green.shade300),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    mon.isOfflineMode ? Icons.cloud_off : Icons.cloud_done,
                    size: 20,
                    color: mon.isOfflineMode
                        ? (isDark ? Colors.amber.shade200 : Colors.orange.shade800)
                        : (isDark ? Colors.green.shade200 : AppTheme.safeGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mon.isOfflineMode
                          ? (isFil
                              ? 'Offline Fallback Aktibo • Gamit ang naka-cache na datos'
                              : 'Offline Fallback Active • Showing cached hazard telemetry')
                          : (isFil
                              ? 'Nakakonekta • Huling sync ${mon.lastUpdated != null ? DateFormat('h:mm a').format(mon.lastUpdated!) : 'Ngayon'}'
                              : 'Connected • Last synced ${mon.lastUpdated != null ? DateFormat('h:mm a').format(mon.lastUpdated!) : 'Just now'}'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: mon.isOfflineMode
                            ? (isDark
                                ? Colors.amber.shade100
                                : Colors.orange.shade900)
                            : (isDark
                                ? Colors.green.shade100
                                : Colors.green.shade900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Threat Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAlert
                      ? [const Color(0xFF991B1B), AppTheme.dangerRed]
                      : [const Color(0xFF14532D), AppTheme.safeGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAlert
                            ? Icons.warning_amber_rounded
                            : Icons.verified_user,
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFil
                                  ? 'KASALUKUYANG ANTAS NG PANGANIB'
                                  : 'CURRENT HAZARD STATUS',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              threat,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (mon.drillMode.linkedDisaster != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.dangerRed,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.menu_book, size: 18),
                      label: Text(
                        isFil
                            ? 'Buksan ang Gabay sa Pagtugon'
                            : 'Open Recommended Action Protocol',
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Drill / Defense Simulation Mode Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science_outlined, size: 20, color: accentNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isFil
                                ? 'Emergency Alert Mode (Live / Pagsasanay)'
                                : 'Emergency Alert Mode (Live / Defense Drill)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: headingColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DrillAlertMode.values.map((mode) {
                        final selected = mon.drillMode == mode;
                        return ChoiceChip(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          label: Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected ? Colors.white : headingColor,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: selected,
                          selectedColor: mode == DrillAlertMode.liveNormal
                              ? AppTheme.safeGreen
                              : AppTheme.dangerRed,
                          backgroundColor:
                              isDark ? AppTheme.darkBg : Colors.grey.shade100,
                          side: BorderSide(
                            color: selected
                                ? (mode == DrillAlertMode.liveNormal
                                    ? AppTheme.safeGreen
                                    : AppTheme.dangerRed)
                                : (isDark
                                    ? AppTheme.darkBorder
                                    : Colors.grey.shade300),
                          ),
                          onSelected: (_) => mon.setDrillMode(mode),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Dynamic GPS / Metro Manila Weather Telemetry
            Text(
              isFil
                  ? 'Lokal na Lagay ng Panahon (${emergency.hasLiveGps ? 'Live GPS' : 'Metro Manila'})'
                  : 'Local Weather Monitoring (${emergency.hasLiveGps ? 'Live GPS' : 'Metro Manila'})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: mon.weather == null
                    ? Text(
                        isFil
                            ? 'Kinukuha ang lagay ng panahon...'
                            : 'Loading local weather telemetry...',
                        style: const TextStyle(fontSize: 14),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTelemetryMetric(
                            Icons.thermostat,
                            '${mon.weather!.temperatureC.toStringAsFixed(1)}°C',
                            mon.weather!.conditionText,
                            Colors.orange.shade400,
                            subtleText,
                          ),
                          _buildTelemetryMetric(
                            Icons.air,
                            '${mon.weather!.windSpeedKmh.toStringAsFixed(1)} km/h',
                            isFil ? 'Hangin' : 'Surface Wind',
                            Colors.blue.shade400,
                            subtleText,
                          ),
                          _buildTelemetryMetric(
                            Icons.water_drop,
                            '${mon.weather!.precipitationMm.toStringAsFixed(1)} mm',
                            isFil ? 'Ulan' : 'Precipitation',
                            Colors.teal.shade400,
                            subtleText,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Philippine Seismic / Earthquake Feed
            Text(
              isFil
                  ? 'Kamakailang Lindol (USGS / Rehiyon ng PH)'
                  : 'Recent Philippine Seismic Activity (USGS/PH Region)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 8),
            if (mon.earthquakes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    isFil
                        ? 'Walang kamakailang lindol na naitala.'
                        : 'No recent seismic events recorded.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
            else
              ...mon.earthquakes.map((q) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: q.magnitude >= 5.0
                            ? (isDark
                                ? AppTheme.dangerRed.withAlpha(60)
                                : const Color(0xFFFFEBEE))
                            : (isDark
                                ? Colors.orange.withAlpha(60)
                                : Colors.orange.shade50),
                        child: Text(
                          q.magnitude.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: q.magnitude >= 5.0
                                ? (isDark
                                    ? Colors.red.shade200
                                    : AppTheme.dangerRed)
                                : (isDark
                                    ? Colors.orange.shade200
                                    : Colors.orange.shade800),
                          ),
                        ),
                      ),
                      title: Text(
                        q.place,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: headingColor,
                        ),
                      ),
                      subtitle: Text(
                        'Depth: ${q.depthKm.toStringAsFixed(0)} km • ${DateFormat('MMM d, h:mm a').format(q.time.toLocal())}',
                        style: TextStyle(fontSize: 14, color: subtleText),
                      ),
                    ),
                  )),

            const SizedBox(height: 16),

            // Household Safety Check-In Log (Offline Persistable)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isFil
                        ? 'Talaan ng Kaligtasan ng Pamilya'
                        : 'Household Safety Status Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headingColor,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: accentNavy,
                  ),
                  icon: const Icon(Icons.add_task, size: 18),
                  label: Text(isFil ? 'Mag-check In' : 'Log Check-In'),
                  onPressed: () =>
                      _showCheckInDialog(context, mon, emergency, auth, isFil),
                ),
              ],
            ),
            if (mon.safetyLog.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    isFil
                        ? 'Itala ang kalagayan ng pamilya habang may sakuna (naka-save offline).'
                        : 'Record household status updates during calamities (saved locally & synced).',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                ),
              )
            else
              ...mon.safetyLog.take(5).map((entry) {
                final ts = DateTime.tryParse(entry['timestamp'] ?? '');
                final isSafe = entry['status'] == 'SAFE';
                final author = (entry['authorName'] ?? '').trim();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      isSafe ? Icons.check_circle : Icons.sos,
                      color:
                          isSafe ? AppTheme.safeGreen : AppTheme.dangerRed,
                    ),
                    title: Text(
                      author.isNotEmpty
                          ? '${entry['status']} ($author) — ${entry['note']}'
                          : '${entry['status']} — ${entry['note']}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: headingColor,
                      ),
                    ),
                    subtitle: Text(
                      ts != null
                          ? DateFormat('MMM d, yyyy • h:mm a').format(ts)
                          : '',
                      style: TextStyle(fontSize: 14, color: subtleText),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),
            // PAGASA Rainfall & TCWS Offline Quick Reference
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: accentNavy),
                        const SizedBox(width: 8),
                        Text(
                          isFil
                              ? 'PAGASA Offline Gabay sa Babala'
                              : 'PAGASA Offline Warning Legend',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: headingColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPagasaLegendRow(
                      color: const Color(0xFFEAB308),
                      badge: 'YELLOW',
                      description:
                          'Flooding possible in low-lying areas — monitor updates.',
                      headingColor: headingColor,
                      subtleText: subtleText,
                    ),
                    const SizedBox(height: 8),
                    _buildPagasaLegendRow(
                      color: const Color(0xFFF97316),
                      badge: 'ORANGE',
                      description:
                          'Flooding threatening — prepare Go-Bag & evacuation route.',
                      headingColor: headingColor,
                      subtleText: subtleText,
                    ),
                    const SizedBox(height: 8),
                    _buildPagasaLegendRow(
                      color: AppTheme.dangerRed,
                      badge: 'RED',
                      description:
                          'Severe flooding imminent — evacuate to designated shelter.',
                      headingColor: headingColor,
                      subtleText: subtleText,
                    ),
                    const SizedBox(height: 8),
                    _buildPagasaLegendRow(
                      color: Colors.purple,
                      badge: 'TCWS #3–5',
                      description:
                          'Destructive typhoon winds — stay inside reinforced shelter.',
                      headingColor: headingColor,
                      subtleText: subtleText,
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

  Widget _buildPagasaLegendRow({
    required Color color,
    required String badge,
    required String description,
    required Color headingColor,
    required Color subtleText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withAlpha(32),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(140)),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11.5,
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

  Widget _buildTelemetryMetric(
    IconData icon,
    String value,
    String label,
    Color color,
    Color subtleText,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: subtleText),
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
    bool isFil,
  ) {
    String selectedStatus = 'SAFE';
    final noteCtrl = TextEditingController(
      text: isFil
          ? 'Ligtas ang lahat ng miyembro ng pamilya sa bahay.'
          : 'All family members accounted for at home.',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isFil ? 'Itala ang Kalagayan' : 'Log Household Status',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: InputDecoration(
                  labelText: isFil ? 'Kalagayan' : 'Status',
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'SAFE', child: Text('SAFE / Shelter Secured')),
                  DropdownMenuItem(
                      value: 'EVACUATING',
                      child: Text('EVACUATING to Shelter')),
                  DropdownMenuItem(
                      value: 'NEED ASSISTANCE',
                      child: Text('NEED ASSISTANCE / Supplies')),
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
                  labelText: isFil ? 'Tala' : 'Status Note',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isFil ? 'Kanselahin' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                mon.addSafetyCheckIn(
                  selectedStatus,
                  noteCtrl.text.trim(),
                  latitude: emergency.userLat,
                  longitude: emergency.userLng,
                  authorName: auth.fullName ?? 'Household Member',
                );
                Navigator.pop(ctx);
              },
              child: Text(isFil ? 'I-save' : 'Save Log'),
            ),
          ],
        ),
      ),
    );
  }
}
