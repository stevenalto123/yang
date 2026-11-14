import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/evacuation_center.dart';
import '../providers/emergency_provider.dart';
import '../utils/action_feedback.dart';
import '../utils/app_theme.dart';
import '../utils/location_service.dart';

class EvacuationMapScreen extends StatelessWidget {
  const EvacuationMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final centers = emergency.filteredEvacuationCenters;
    final cities = emergency.availableCities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS & Evacuation Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            tooltip: 'Add Local Barangay Shelter',
            onPressed: () => _showAddShelterDialog(context, emergency),
          ),
        ],
      ),
      body: Column(
        children: [
          // GPS Location & Offline Status Bar
          Container(
            color: const Color(0xFFE0F2F1),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  emergency.hasLiveGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                  size: 18,
                  color: Colors.teal.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emergency.hasLiveGps
                            ? 'Live GPS Active (±${(emergency.gpsAccuracyMeters ?? 25).toStringAsFixed(0)}m)'
                            : 'Reference GPS: Paco, Manila (Offline Ready)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      Text(
                        'Lat: ${emergency.userLat.toStringAsFixed(4)}, Lng: ${emergency.userLng.toStringAsFixed(4)}',
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.teal.shade800),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  icon: emergency.isLocating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 14),
                  label: Text(emergency.isLocating ? 'Locating...' : 'Locate Me'),
                  onPressed: emergency.isLocating
                      ? null
                      : () async {
                          final ok = await emergency.detectLiveGps();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'GPS location updated! Shelters sorted by nearest distance.'
                                      : 'GPS unavailable or permission denied. Using cached reference coordinates.',
                                ),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ),

          // City Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: cities.map((city) {
                final isSelected = emergency.selectedCity == city;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(city == 'All' ? 'All Locations' : city),
                    selected: isSelected,
                    selectedColor: Colors.teal.shade700,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => emergency.setSelectedCity(city),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Scrollable Radar + Sorted Evacuation Shelters
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              children: [
                // Offline Interactive Compass & Shelter Radar
                Card(
                  color: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'OFFLINE SHELTER RADAR',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Sorted Nearest First',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 190,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _OfflineShelterRadarPainter(
                              userLat: emergency.userLat,
                              userLng: emergency.userLng,
                              centers: centers,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (centers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No evacuation shelters found for selected area.'),
                    ),
                  )
                else
                  ...centers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final center = entry.value;
                    return _buildShelterCard(
                        context, center, emergency, idx == 0);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelterCard(
    BuildContext context,
    EvacuationCenter center,
    EmergencyProvider emergency,
    bool isNearest,
  ) {
    final distKm = emergency.distanceToCenterKm(center);
    final cardinal = emergency.bearingToCenter(center);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNearest
            ? BorderSide(color: Colors.teal.shade600, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  radius: 20,
                  child: Icon(Icons.roofing_rounded,
                      color: Colors.teal.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isNearest)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEAREST',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              center.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.place,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              center.address,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: center.isOpen
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        center.isOpen ? 'ACTIVE' : 'STANDBY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: center.isOpen
                              ? AppTheme.safeGreen
                              : AppTheme.accentAlert,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${distKm.toStringAsFixed(1)} km • $cardinal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline,
                              size: 15, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Text(
                            'Capacity: ${center.capacityPeople} individuals',
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        'City: ${center.city}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Facilities: ${center.facilities}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.directions, size: 16),
                    label: const Text('Open Map Route',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => ActionFeedback.openMapWithFeedback(
                      context,
                      emergency,
                      center.latitude,
                      center.longitude,
                      center.name,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade800,
                    side: BorderSide(color: Colors.teal.shade700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.call, size: 16),
                  label:
                      const Text('Call Officer', style: TextStyle(fontSize: 12)),
                  onPressed: () => ActionFeedback.callWithFeedback(
                    context,
                    emergency,
                    center.contactNumber,
                    center.contactPerson,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddShelterDialog(
      BuildContext context, EmergencyProvider emergency) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Manila');
    final contactCtrl = TextEditingController(text: '911');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Local Barangay Shelter'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Shelter / Covered Court Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Address *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'City / Municipality'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Barangay Hotline'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              emergency.addCustomEvacuationCenter(
                EvacuationCenter(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty
                      ? 'Local Barangay Site'
                      : addrCtrl.text.trim(),
                  city: cityCtrl.text.trim().isEmpty
                      ? 'Local'
                      : cityCtrl.text.trim(),
                  // Place near current user GPS coordinates so distance works offline
                  latitude: emergency.userLat + 0.004,
                  longitude: emergency.userLng + 0.003,
                  contactPerson: 'Barangay DRRM Officer',
                  contactNumber: contactCtrl.text.trim(),
                  capacityPeople: 400,
                  facilities: 'Custom Saved Local Shelter',
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save Offline'),
          ),
        ],
      ),
    );
  }
}

class _OfflineShelterRadarPainter extends CustomPainter {
  final double userLat;
  final double userLng;
  final List<EvacuationCenter> centers;

  _OfflineShelterRadarPainter({
    required this.userLat,
    required this.userLng,
    required this.centers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 14;

    final ringPaint = Paint()
      ..color = Colors.tealAccent.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final factor in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, maxRadius * factor, ringPaint);
    }

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      ringPaint,
    );

    // Compass labels
    const labelStyle = TextStyle(
        color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold);
    _drawText(canvas, 'N', Offset(center.dx - 4, center.dy - maxRadius - 12),
        labelStyle);
    _drawText(canvas, 'S', Offset(center.dx - 3, center.dy + maxRadius + 1),
        labelStyle);
    _drawText(canvas, 'E', Offset(center.dx + maxRadius + 4, center.dy - 6),
        labelStyle);
    _drawText(canvas, 'W', Offset(center.dx - maxRadius - 14, center.dy - 6),
        labelStyle);

    // Draw shelter pins scaled up to max 15 km radius (or relative max distance)
    double maxDist = 10.0;
    for (final c in centers) {
      final d = LocationService.distanceInKm(
          userLat, userLng, c.latitude, c.longitude);
      if (d > maxDist) maxDist = d;
    }

    for (int i = 0; i < centers.length; i++) {
      final c = centers[i];
      final d = LocationService.distanceInKm(
          userLat, userLng, c.latitude, c.longitude);
      final bearing = LocationService.bearingTo(
              userLat, userLng, c.latitude, c.longitude)
          .degrees;
      final rad = (bearing - 90) * (math.pi / 180.0);
      final normDist = (d / maxDist).clamp(0.12, 0.95);
      final px = center.dx + math.cos(rad) * maxRadius * normDist;
      final py = center.dy + math.sin(rad) * maxRadius * normDist;

      final pinColor = i == 0 ? Colors.tealAccent : Colors.amberAccent;
      canvas.drawCircle(
        Offset(px, py),
        i == 0 ? 6 : 4.5,
        Paint()..color = pinColor,
      );
      _drawText(
        canvas,
        '${d.toStringAsFixed(1)}km',
        Offset(px + 7, py - 6),
        TextStyle(color: pinColor, fontSize: 9.5, fontWeight: FontWeight.bold),
      );
    }

    // User location marker at center
    canvas.drawCircle(
      center,
      10,
      Paint()..color = Colors.blueAccent.withAlpha(70),
    );
    canvas.drawCircle(
      center,
      5,
      Paint()..color = Colors.lightBlueAccent,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _OfflineShelterRadarPainter oldDelegate) {
    return oldDelegate.userLat != userLat ||
        oldDelegate.userLng != userLng ||
        oldDelegate.centers.length != centers.length;
  }
}
