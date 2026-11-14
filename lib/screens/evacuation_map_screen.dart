import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/evacuation_center.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/action_feedback.dart';
import '../utils/app_theme.dart';
import '../utils/location_service.dart';

class EvacuationMapScreen extends StatelessWidget {
  const EvacuationMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;

    final centers = emergency.filteredEvacuationCenters;
    final cities = emergency.availableCities;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFil ? 'GPS at Mapa ng Evacuation' : 'GPS & Evacuation Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            tooltip: isFil
                ? 'Magdagdag ng Barangay Shelter'
                : 'Add Local Barangay Shelter',
            onPressed: () => _showAddShelterDialog(context, emergency, isFil),
          ),
        ],
      ),
      body: Column(
        children: [
          // GPS Location & Offline Status Bar
          Container(
            color: isDark ? const Color(0xFF0F2E2C) : const Color(0xFFE0F2F1),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  emergency.hasLiveGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                  size: 20,
                  color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emergency.hasLiveGps
                            ? 'Live GPS Active (±${(emergency.gpsAccuracyMeters ?? 25).toStringAsFixed(0)}m)'
                            : (isFil
                                ? 'Reference GPS: Paco, Manila (Offline Ready)'
                                : 'Reference GPS: Paco, Manila (Offline Ready)'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.teal.shade100
                              : Colors.teal.shade900,
                        ),
                      ),
                      Text(
                        'Lat: ${emergency.userLat.toStringAsFixed(4)}, Lng: ${emergency.userLng.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.teal.shade200
                              : Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  icon: emergency.isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(
                    emergency.isLocating
                        ? (isFil ? 'Hinahanap...' : 'Locating...')
                        : (isFil ? 'Lokasyon' : 'Locate Me'),
                  ),
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
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    label: Text(
                      city == 'All'
                          ? (isFil ? 'Lahat ng Lugar' : 'All Locations')
                          : city,
                    ),
                    selected: isSelected,
                    selectedColor: Colors.teal.shade700,
                    backgroundColor:
                        isDark ? AppTheme.darkCard : Colors.grey.shade100,
                    side: BorderSide(
                      color: isSelected
                          ? Colors.teal.shade700
                          : (isDark
                              ? AppTheme.darkBorder
                              : Colors.grey.shade300),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.darkSlate),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
              children: [
                // Offline Interactive Compass & Shelter Radar
                Card(
                  color: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              isFil ? 'Pinakamalapit Una' : 'Sorted Nearest First',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 14,
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
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isFil
                            ? 'Walang nahanap na evacuation shelter sa napiling lugar.'
                            : 'No evacuation shelters found for selected area.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                else
                  ...centers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final center = entry.value;
                    return _buildShelterCard(
                      context,
                      center,
                      emergency,
                      idx == 0,
                      isDark,
                      isFil,
                    );
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
    bool isDark,
    bool isFil,
  ) {
    final distKm = emergency.distanceToCenterKm(center);
    final cardinal = emergency.bearingToCenter(center);

    final isCampusRef = center.id == 'eac_campus_reference';
    final isOfficialLgu =
        center.id.startsWith('manila_') || center.id.startsWith('qc_');

    final titleColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNearest
            ? BorderSide(color: Colors.teal.shade500, width: 1.5)
            : BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isNearest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFil ? 'PINAKAMALAPIT' : 'NEAREST',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isCampusRef
                        ? AppTheme.eacCrimson.withAlpha(isDark ? 70 : 24)
                        : (isOfficialLgu
                            ? AppTheme.primaryNavy.withAlpha(isDark ? 90 : 20)
                            : Colors.indigo.withAlpha(isDark ? 70 : 20)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCampusRef
                          ? AppTheme.eacCrimson.withAlpha(120)
                          : (isDark
                              ? Colors.lightBlue.shade200.withAlpha(90)
                              : AppTheme.primaryNavy.withAlpha(70)),
                    ),
                  ),
                  child: Text(
                    isCampusRef
                        ? (isFil
                            ? 'CAMPUS ASSEMBLY REFERENCE'
                            : 'CAMPUS REFERENCE')
                        : (isOfficialLgu
                            ? (isFil
                                ? 'OPISYAL NA LGU CENTER'
                                : 'OFFICIAL LGU CENTER')
                            : (isFil ? 'BARANGAY / SARILING TALA' : 'SAVED LOCAL SHELTER')),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCampusRef
                          ? (isDark
                              ? Colors.pink.shade200
                              : AppTheme.eacCrimson)
                          : (isDark
                              ? Colors.lightBlue.shade200
                              : AppTheme.primaryNavy),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isDark
                      ? Colors.teal.withAlpha(50)
                      : Colors.teal.shade50,
                  radius: 22,
                  child: Icon(
                    Icons.roofing_rounded,
                    color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place, size: 16, color: subtleText),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              center.address,
                              style: TextStyle(fontSize: 14, color: subtleText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: center.isOpen
                            ? (isDark
                                ? AppTheme.safeGreen.withAlpha(45)
                                : const Color(0xFFE8F5E9))
                            : (isDark
                                ? AppTheme.dangerRed.withAlpha(45)
                                : const Color(0xFFFFEBEE)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        center.isOpen ? 'ACTIVE' : 'STANDBY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: center.isOpen
                              ? (isDark
                                  ? Colors.green.shade200
                                  : AppTheme.safeGreen)
                              : (isDark
                                  ? Colors.red.shade200
                                  : AppTheme.dangerRed),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${distKm.toStringAsFixed(1)} km • $cardinal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.tealAccent
                            : Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBg : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: subtleText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${isFil ? 'Kapasidad' : 'Capacity'}: ${center.capacityPeople}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        center.city,
                        style: TextStyle(fontSize: 14, color: subtleText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${isFil ? 'Pasilidad' : 'Facilities'}: ${center.facilities}',
                          style: TextStyle(fontSize: 14, color: subtleText),
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
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: Text(
                      isFil ? 'Ruta sa Mapa' : 'Open Map Route',
                      style: const TextStyle(fontSize: 14),
                    ),
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
                    foregroundColor:
                        isDark ? Colors.tealAccent : Colors.teal.shade800,
                    side: BorderSide(
                      color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                    ),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(
                    isFil ? 'Tumawag' : 'Call Officer',
                    style: const TextStyle(fontSize: 14),
                  ),
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
    BuildContext context,
    EmergencyProvider emergency,
    bool isFil,
  ) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Manila');
    final contactCtrl = TextEditingController(text: '911');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFil ? 'Magdagdag ng Barangay Shelter' : 'Add Local Barangay Shelter',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isFil
                      ? 'Pangalan ng Shelter / Covered Court *'
                      : 'Shelter / Covered Court Name *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                decoration: InputDecoration(
                  labelText: isFil ? 'Address *' : 'Address *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityCtrl,
                decoration: InputDecoration(
                  labelText:
                      isFil ? 'Lungsod / Munisipyo' : 'City / Municipality',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: InputDecoration(
                  labelText: isFil ? 'Barangay Hotline' : 'Barangay Hotline',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFil ? 'Kanselahin' : 'Cancel'),
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
            child: Text(isFil ? 'I-save Offline' : 'Save Offline'),
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

    const labelStyle = TextStyle(
      color: Colors.white54,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );
    _drawText(
      canvas,
      'N',
      Offset(center.dx - 4, center.dy - maxRadius - 12),
      labelStyle,
    );
    _drawText(
      canvas,
      'S',
      Offset(center.dx - 3, center.dy + maxRadius + 1),
      labelStyle,
    );
    _drawText(
      canvas,
      'E',
      Offset(center.dx + maxRadius + 4, center.dy - 6),
      labelStyle,
    );
    _drawText(
      canvas,
      'W',
      Offset(center.dx - maxRadius - 14, center.dy - 6),
      labelStyle,
    );

    double maxDist = 10.0;
    for (final c in centers) {
      final d = LocationService.distanceInKm(
        userLat,
        userLng,
        c.latitude,
        c.longitude,
      );
      if (d > maxDist) maxDist = d;
    }

    for (int i = 0; i < centers.length; i++) {
      final c = centers[i];
      final d = LocationService.distanceInKm(
        userLat,
        userLng,
        c.latitude,
        c.longitude,
      );
      final bearing = LocationService.bearingTo(
        userLat,
        userLng,
        c.latitude,
        c.longitude,
      ).degrees;
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
        TextStyle(color: pinColor, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }

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
