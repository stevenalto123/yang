import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/monitoring_provider.dart';
import '../utils/app_theme.dart';
import 'disaster_guide_screen.dart';

class EmergencyMonitoringScreen extends StatelessWidget {
  const EmergencyMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mon = context.watch<MonitoringProvider>();
    final threat = mon.currentThreatLevel;
    final isAlert = mon.drillMode != DrillAlertMode.liveNormal ||
        threat.contains('ALERT') ||
        threat.contains('WARNING');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Monitoring Hub'),
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
            tooltip: 'Sync Live Feeds',
            onPressed: mon.isRefreshing ? null : () => mon.refreshLiveFeeds(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => mon.refreshLiveFeeds(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connectivity / Cache Mode Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mon.isOfflineMode
                    ? Colors.amber.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: mon.isOfflineMode
                      ? Colors.amber.shade300
                      : Colors.green.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    mon.isOfflineMode ? Icons.cloud_off : Icons.cloud_done,
                    size: 18,
                    color: mon.isOfflineMode
                        ? Colors.orange.shade800
                        : AppTheme.safeGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mon.isOfflineMode
                          ? 'Offline Fallback Active • Showing cached hazard telemetry'
                          : 'Connected • Last synced ${mon.lastUpdated != null ? DateFormat('h:mm a').format(mon.lastUpdated!) : 'Just now'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: mon.isOfflineMode
                            ? Colors.orange.shade900
                            : Colors.green.shade900,
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
                      ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
                      : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
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
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT HAZARD STATUS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              threat,
                              style: const TextStyle(
                                fontSize: 17,
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
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.accentAlert,
                      ),
                      icon: const Icon(Icons.menu_book, size: 16),
                      label: const Text('Open Recommended Action Protocol'),
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science_outlined,
                            size: 16, color: AppTheme.primaryCrimson),
                        SizedBox(width: 6),
                        Text(
                          'Emergency Alert Mode (Live / Defense Drill)',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: DrillAlertMode.values.map((mode) {
                        final selected = mon.drillMode == mode;
                        return ChoiceChip(
                          label: Text(mode.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                          selected: selected,
                          selectedColor: mode == DrillAlertMode.liveNormal
                              ? AppTheme.safeGreen
                              : AppTheme.accentAlert,
                          onSelected: (_) => mon.setDrillMode(mode),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Live Metro Manila Weather Telemetry
            const Text(
              'Local Weather Monitoring (Metro Manila)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSlate),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: mon.weather == null
                    ? const Text('Loading local weather telemetry...')
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTelemetryMetric(
                            Icons.thermostat,
                            '${mon.weather!.temperatureC.toStringAsFixed(1)}°C',
                            mon.weather!.conditionText,
                            Colors.orange.shade700,
                          ),
                          _buildTelemetryMetric(
                            Icons.air,
                            '${mon.weather!.windSpeedKmh.toStringAsFixed(1)} km/h',
                            'Surface Wind',
                            Colors.blue.shade700,
                          ),
                          _buildTelemetryMetric(
                            Icons.water_drop,
                            '${mon.weather!.precipitationMm.toStringAsFixed(1)} mm',
                            'Precipitation',
                            Colors.teal.shade700,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Philippine Seismic / Earthquake Feed
            const Text(
              'Recent Philippine Seismic Activity (USGS/PH Region)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSlate),
            ),
            const SizedBox(height: 8),
            if (mon.earthquakes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No recent seismic events recorded.'),
                ),
              )
            else
              ...mon.earthquakes.map((q) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: q.magnitude >= 5.0
                            ? const Color(0xFFFFEBEE)
                            : Colors.orange.shade50,
                        child: Text(
                          q.magnitude.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: q.magnitude >= 5.0
                                ? AppTheme.accentAlert
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      title: Text(
                        q.place,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Depth: ${q.depthKm.toStringAsFixed(0)} km • ${DateFormat('MMM d, h:mm a').format(q.time.toLocal())}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ),
                  )),

            const SizedBox(height: 16),

            // Household Safety Check-In Log (Offline Persistable)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Household Safety Status Log',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkSlate),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_task, size: 16),
                  label: const Text('Log Check-In'),
                  onPressed: () => _showCheckInDialog(context, mon),
                ),
              ],
            ),
            if (mon.safetyLog.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Record household status updates during calamities (saved locally offline).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...mon.safetyLog.take(5).map((entry) {
                final ts = DateTime.tryParse(entry['timestamp'] ?? '');
                final isSafe = entry['status'] == 'SAFE';
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      isSafe ? Icons.check_circle : Icons.sos,
                      color:
                          isSafe ? AppTheme.safeGreen : AppTheme.accentAlert,
                    ),
                    title: Text(
                      '${entry['status']} — ${entry['note']}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      ts != null
                          ? DateFormat('MMM d, yyyy • h:mm a').format(ts)
                          : '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),
            // PAGASA Rainfall & TCWS Offline Quick Reference
            Card(
              color: Colors.blueGrey.shade50,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAGASA Offline Warning Legend',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Yellow Rainfall: Flooding possible in low-lying areas (Monitor).\n'
                      '• Orange Rainfall: Flooding threatening (Prepare to evacuate).\n'
                      '• Red Rainfall: Severe flooding imminent (Immediate evacuation).\n'
                      '• TCWS #3–#5: Destructive typhoon winds; stay inside reinforced shelter.',
                      style: TextStyle(fontSize: 11.5, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryMetric(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
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
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showCheckInDialog(BuildContext context, MonitoringProvider mon) {
    String selectedStatus = 'SAFE';
    final noteCtrl = TextEditingController(text: 'All family members accounted for at home.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Log Household Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'SAFE', child: Text('SAFE / Shelter Secured')),
                  DropdownMenuItem(value: 'EVACUATING', child: Text('EVACUATING to Shelter')),
                  DropdownMenuItem(value: 'NEED ASSISTANCE', child: Text('NEED ASSISTANCE / Supplies')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => selectedStatus = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Status Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                mon.addSafetyCheckIn(selectedStatus, noteCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save Log'),
            ),
          ],
        ),
      ),
    );
  }
}
