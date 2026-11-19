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
import '../widgets/responsive_container.dart';

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
    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFil ? 'Malapit na Tulong at Shelter' : 'Nearby Help & Shelters',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: isFil
                ? 'Magdagdag ng Barangay Shelter'
                : 'Add Local Shelter',
            onPressed: () => _showAddShelterDialog(context, emergency, isFil),
          ),
        ],
      ),
      body: Column(
        children: [
          // Clean GPS Location Bar
          Container(
            color: isDark ? AppTheme.darkCard : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ResponsiveContainer(
              maxWidth: 1120,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.teal.withAlpha(isDark ? 45 : 22),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          emergency.hasLiveGps
                              ? Icons.gps_fixed_rounded
                              : Icons.location_on_outlined,
                          size: 20,
                          color: isDark
                              ? Colors.tealAccent
                              : Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emergency.hasLiveGps
                                  ? (isFil
                                      ? 'Aktibo ang GPS (±${(emergency.gpsAccuracyMeters ?? 25).toStringAsFixed(0)}m)'
                                      : 'Live GPS Active (±${(emergency.gpsAccuracyMeters ?? 25).toStringAsFixed(0)}m)')
                                  : (isFil
                                      ? 'Malapit sa Paco, Manila (Offline Ready)'
                                      : 'Near Paco, Manila (Offline Ready)'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: headingColor,
                              ),
                            ),
                            Text(
                              '${emergency.userLat.toStringAsFixed(4)}, ${emergency.userLng.toStringAsFixed(4)}',
                              style: TextStyle(fontSize: 12.5, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: emergency.isLocating
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 17),
                        label: Text(
                          emergency.isLocating
                              ? (isFil ? 'Hinahanap...' : 'Locating...')
                              : (isFil ? 'GPS Ko' : 'Update GPS'),
                          style: const TextStyle(fontSize: 13.5),
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
                                            ? 'Location updated! Showing nearest help first.'
                                            : 'GPS unavailable. Showing Metro Manila reference.',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Facility Type Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFacilityChip(
                          label: isFil ? 'Lahat' : 'All Places',
                          icon: Icons.layers_outlined,
                          selected: emergency.selectedFacilityType == null,
                          color: AppTheme.primaryNavy,
                          isDark: isDark,
                          onTap: () => emergency.setSelectedFacilityType(null),
                        ),
                        const SizedBox(width: 8),
                        _buildFacilityChip(
                          label: isFil ? 'Shelters' : 'Shelters',
                          icon: Icons.roofing_rounded,
                          selected: emergency.selectedFacilityType ==
                              FacilityType.evacuationShelter,
                          color: Colors.teal.shade700,
                          isDark: isDark,
                          onTap: () => emergency.setSelectedFacilityType(
                            FacilityType.evacuationShelter,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildFacilityChip(
                          label: isFil ? 'Ospital' : 'Hospitals',
                          icon: Icons.local_hospital_rounded,
                          selected: emergency.selectedFacilityType ==
                              FacilityType.hospital,
                          color: AppTheme.dangerRed,
                          isDark: isDark,
                          onTap: () => emergency
                              .setSelectedFacilityType(FacilityType.hospital),
                        ),
                        const SizedBox(width: 8),
                        _buildFacilityChip(
                          label: isFil ? 'Pulis at Bumbero' : 'Police & Fire',
                          icon: Icons.local_police_rounded,
                          selected: emergency.selectedFacilityType ==
                              FacilityType.policeFire,
                          color: Colors.indigo.shade600,
                          isDark: isDark,
                          onTap: () => emergency
                              .setSelectedFacilityType(FacilityType.policeFire),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // City Filter Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: cities.map((city) {
                        final isSelected = emergency.selectedCity == city;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            label: Text(
                              city == 'All'
                                  ? (isFil ? 'Lahat ng Lungsod' : 'All Cities')
                                  : city,
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal.shade700,
                            backgroundColor: isDark
                                ? AppTheme.darkElevated
                                : AppTheme.surfaceBg,
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.teal.shade700
                                  : (isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : AppTheme.darkSlate),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                            onSelected: (_) => emergency.setSelectedCity(city),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Radar + Sorted Nearby List
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSplit = constraints.maxWidth >= 820;
                final radarCard = Card(
                  color: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isFil
                                  ? 'OFFLINE NA RADAR'
                                  : 'OFFLINE NEARBY RADAR',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                            Text(
                              isFil ? 'Pinakamalapit una' : 'Nearest first',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: isSplit ? 270 : 185,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _OfflineShelterRadarPainter(
                              userLat: emergency.userLat,
                              userLng: emergency.userLng,
                              centers: centers,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isFil
                              ? 'Asul = Ikaw • Berde/Dilaw = Shelter • Pula = Ospital • Lila = Pulis/Bumbero'
                              : 'Blue = You • Teal/Amber = Shelters • Red = Hospitals • Indigo = Police & Fire',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade200,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final shelterWidgets = centers.isEmpty
                    ? [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isFil
                                  ? 'Walang nahanap na lugar sa napiling filter.'
                                  : 'No places match your selected filters.',
                              style: TextStyle(fontSize: 14, color: subtleText),
                            ),
                          ),
                        ),
                      ]
                    : centers.asMap().entries.map((entry) {
                        return _buildShelterCard(
                          context,
                          entry.value,
                          emergency,
                          entry.key == 0,
                          isDark,
                          isFil,
                        );
                      }).toList();

                if (isSplit) {
                  return ResponsiveContainer(
                    maxWidth: 1120,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 350, child: radarCard),
                        const SizedBox(width: 18),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 36),
                            children: shelterWidgets,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    radarCard,
                    const SizedBox(height: 12),
                    ...shelterWidgets,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : (isDark ? Colors.white70 : color),
      ),
      label: Text(label),
      selected: selected,
      selectedColor: color,
      backgroundColor: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
      side: BorderSide(
        color: selected
            ? color
            : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : (isDark ? Colors.white : AppTheme.darkSlate),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13.5,
      ),
      onSelected: (_) => onTap(),
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

    final isHospital = center.facilityType == FacilityType.hospital;
    final isPoliceFire = center.facilityType == FacilityType.policeFire;

    final Color facilityAccent = isHospital
        ? AppTheme.dangerRed
        : (isPoliceFire ? Colors.indigo.shade600 : Colors.teal.shade700);
    final IconData facilityIcon = isHospital
        ? Icons.local_hospital_rounded
        : (isPoliceFire
            ? Icons.local_police_rounded
            : Icons.roofing_rounded);
    final String typeLabel = isHospital
        ? (isFil ? 'Ospital' : 'Hospital')
        : (isPoliceFire
            ? (isFil ? 'Pulis at Bumbero' : 'Police & Fire')
            : (isFil ? 'Evacuation Shelter' : 'Evacuation Shelter'));

    final titleColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isNearest
            ? BorderSide(color: facilityAccent.withAlpha(180), width: 1.5)
            : BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clean single-row header: Type pill + Nearest + Distance
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: facilityAccent.withAlpha(isDark ? 45 : 20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        facilityIcon,
                        size: 13,
                        color: isDark ? Colors.white : facilityAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : facilityAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNearest) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: facilityAccent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      isFil ? 'Pinakamalapit' : 'Nearest',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${distKm.toStringAsFixed(1)} km • $cardinal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title + Open status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    center.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: center.isOpen
                            ? AppTheme.safeGreen
                            : AppTheme.dangerRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      center.isOpen
                          ? (isFil ? 'Bukas' : 'Open')
                          : (isFil ? 'Standby' : 'Standby'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: center.isOpen
                            ? AppTheme.safeGreen
                            : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${center.address} (${center.city})',
              style: TextStyle(fontSize: 13.5, color: subtleText),
            ),
            const SizedBox(height: 6),
            Text(
              '${center.facilities}${center.capacityPeople > 0 ? ' • ${isFil ? 'Kapasidad' : 'Capacity'}: ${center.capacityPeople}' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: subtleText.withAlpha(210),
              ),
            ),
            const SizedBox(height: 14),

            // 2 Clean Equal Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: Text(isFil ? 'Direksyon' : 'Directions'),
                    onPressed: () => ActionFeedback.openMapWithFeedback(
                      context,
                      emergency,
                      center.latitude,
                      center.longitude,
                      center.name,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(isFil ? 'Tumawag' : 'Call'),
                    onPressed: () => ActionFeedback.callWithFeedback(
                      context,
                      emergency,
                      center.contactNumber,
                      center.contactPerson,
                    ),
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
                decoration: const InputDecoration(
                  labelText: 'Address *',
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
                decoration: const InputDecoration(
                  labelText: 'Barangay Hotline',
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
          FilledButton(
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
                  facilities: 'Saved Local Shelter',
                ),
              );
              Navigator.pop(ctx);
            },
            child: Text(isFil ? 'I-save' : 'Save Offline'),
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

      final Color pinColor = c.facilityType == FacilityType.hospital
          ? Colors.redAccent
          : (c.facilityType == FacilityType.policeFire
              ? Colors.indigoAccent.shade100
              : (i == 0 ? Colors.tealAccent : Colors.amberAccent));
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
