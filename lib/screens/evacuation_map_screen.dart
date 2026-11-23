import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/evacuation_centers_data.dart';
import '../models/evacuation_center.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/action_feedback.dart';
import '../utils/app_theme.dart';
import '../utils/location_service.dart';
import '../widgets/responsive_container.dart';

class EvacuationMapScreen extends StatefulWidget {
  const EvacuationMapScreen({super.key});

  @override
  State<EvacuationMapScreen> createState() => _EvacuationMapScreenState();
}

class _EvacuationMapScreenState extends State<EvacuationMapScreen> {
  static const LatLng _metroManilaCenter = LatLng(14.5822, 120.9882);

  final MapController _mapController = MapController();
  EvacuationCenter? _selectedCenter;
  bool _unlockMobileMapPan = false;

  void _safeMove(LatLng target, double zoom) {
    try {
      _mapController.move(target, zoom.clamp(5.0, 18.0));
    } catch (_) {
      // MapController may not be attached yet before first frame
    }
  }

  void _zoomBy(double delta) {
    try {
      final cam = _mapController.camera;
      _mapController.move(cam.center, (cam.zoom + delta).clamp(5.0, 18.0));
    } catch (_) {}
  }

  void _focusCenter(EvacuationCenter center) {
    setState(() => _selectedCenter = center);
    _safeMove(LatLng(center.latitude, center.longitude), 15.2);
  }

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

    final distFromManilaKm = LocationService.distanceInKm(
      emergency.userLat,
      emergency.userLng,
      _metroManilaCenter.latitude,
      _metroManilaCenter.longitude,
    );
    final isFarFromManila = distFromManilaKm > 50.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFil ? 'Mapa ng Tulong at Shelter' : 'Nearby Map & Shelters',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: isFil
                ? 'I-save ang Barangay / Family Shelter'
                : 'Save Barangay / Family Shelter',
            onPressed: () => _showAddShelterDialog(context, emergency, isFil),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSplit = constraints.maxWidth >= 860;

          final headerPanel = Container(
            color: isDark ? AppTheme.darkCard : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ResponsiveContainer(
              maxWidth: 1160,
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
                                  : 'Metro Manila (National Capital Region)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: headingColor,
                              ),
                            ),
                            Text(
                              '${emergency.userLat.toStringAsFixed(4)}, ${emergency.userLng.toStringAsFixed(4)}',
                              style:
                                  TextStyle(fontSize: 12.5, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isFarFromManila) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon:
                              const Icon(Icons.location_city_rounded, size: 17),
                          label: const Text(
                            'Metro Manila',
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            emergency.setManualLocation(
                              _metroManilaCenter.latitude,
                              _metroManilaCenter.longitude,
                            );
                            setState(() => _selectedCenter = null);
                            _safeMove(_metroManilaCenter, 13.0);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
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
                              : (isFil ? 'GPS Ko' : 'My GPS'),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        onPressed: emergency.isLocating
                            ? null
                            : () async {
                                final ok = await emergency.detectLiveGps();
                                if (!context.mounted) return;
                                if (ok) {
                                  _safeMove(
                                    LatLng(
                                      emergency.userLat,
                                      emergency.userLng,
                                    ),
                                    14.0,
                                  );
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Location updated on map!'
                                          : 'GPS unavailable. Showing Metro Manila map.',
                                    ),
                                  ),
                                );
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
                          onTap: () {
                            setState(() => _selectedCenter = null);
                            emergency.setSelectedFacilityType(null);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFacilityChip(
                          label: 'Shelters',
                          icon: Icons.roofing_rounded,
                          selected: emergency.selectedFacilityType ==
                              FacilityType.evacuationShelter,
                          color: Colors.teal.shade700,
                          isDark: isDark,
                          onTap: () {
                            setState(() => _selectedCenter = null);
                            emergency.setSelectedFacilityType(
                              FacilityType.evacuationShelter,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFacilityChip(
                          label: isFil ? 'Ospital' : 'Hospitals',
                          icon: Icons.local_hospital_rounded,
                          selected: emergency.selectedFacilityType ==
                              FacilityType.hospital,
                          color: AppTheme.dangerRed,
                          isDark: isDark,
                          onTap: () {
                            setState(() => _selectedCenter = null);
                            emergency
                                .setSelectedFacilityType(FacilityType.hospital);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFacilityChip(
                          label: isFil ? 'Pulis at Bumbero' : 'Police & Fire',
                          icon: Icons.local_police_rounded,
                          selected: emergency.selectedFacilityType ==
                              FacilityType.policeFire,
                          color: Colors.indigo.shade600,
                          isDark: isDark,
                          onTap: () {
                            setState(() => _selectedCenter = null);
                            emergency.setSelectedFacilityType(
                              FacilityType.policeFire,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // City Filter Row (All 17 Metro Manila LGUs)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: cities.map((city) {
                        final isSelected = emergency.selectedCity == city;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            label: Text(
                              city == 'All'
                                  ? (isFil ? 'Lahat ng Lungsod (17)' : 'All Metro Manila (17)')
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
                            onSelected: (_) {
                              setState(() => _selectedCenter = null);
                              emergency.setSelectedCity(city);
                              if (city == 'All') {
                                _safeMove(
                                  emergency.hasLiveGps
                                      ? LatLng(
                                          emergency.userLat,
                                          emergency.userLng,
                                        )
                                      : _metroManilaCenter,
                                  12.0,
                                );
                              } else {
                                final coords = metroManilaCityCoords[city];
                                if (coords != null) {
                                  _safeMove(
                                    LatLng(coords.lat, coords.lng),
                                    13.8,
                                  );
                                } else {
                                  final firstMatch = emergency
                                      .filteredEvacuationCenters
                                      .firstOrNull;
                                  if (firstMatch != null) {
                                    _safeMove(
                                      LatLng(
                                        firstMatch.latitude,
                                        firstMatch.longitude,
                                      ),
                                      13.8,
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildNearestOpenShelterStrip(
                    context,
                    emergency,
                    isDark,
                    isFil,
                    headingColor,
                    subtleText,
                  ),
                ],
              ),
            ),
          );

          final mapWidget = _buildInteractiveMap(
            context: context,
            emergency: emergency,
            centers: centers,
            isDark: isDark,
            isFil: isFil,
            isFarFromManila: isFarFromManila,
            isSplit: isSplit,
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
            return Column(
              children: [
                headerPanel,
                const Divider(height: 1),
                Expanded(
                  child: ResponsiveContainer(
                    maxWidth: 1160,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: mapWidget,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 10,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 36),
                            children: shelterWidgets,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Narrow Stacked View: entire screen scrolls smoothly together
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              headerPanel,
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 245,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: mapWidget,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFil
                          ? 'Mga Malapit na Lugar (${centers.length})'
                          : 'Nearby Places (${centers.length})',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: headingColor,
                      ),
                    ),
                    Text(
                      isFil ? 'Pinakamalapit muna' : 'Nearest first',
                      style: TextStyle(fontSize: 12, color: subtleText),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: shelterWidgets),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInteractiveMap({
    required BuildContext context,
    required EmergencyProvider emergency,
    required List<EvacuationCenter> centers,
    required bool isDark,
    required bool isFil,
    required bool isFarFromManila,
    required bool isSplit,
  }) {
    final userPoint = LatLng(emergency.userLat, emergency.userLng);
    final initialFocus =
        isFarFromManila ? _metroManilaCenter : userPoint;

    final markers = <Marker>[
      // Facility Pins
      ...centers.map((center) {
        final isSelected = _selectedCenter?.id == center.id;
        final isHospital = center.facilityType == FacilityType.hospital;
        final isPoliceFire = center.facilityType == FacilityType.policeFire;
        final Color pinColor = isHospital
            ? AppTheme.dangerRed
            : (isPoliceFire ? Colors.indigo.shade600 : Colors.teal.shade700);
        final IconData pinIcon = isHospital
            ? Icons.local_hospital_rounded
            : (isPoliceFire
                ? Icons.local_police_rounded
                : Icons.roofing_rounded);

        return Marker(
          point: LatLng(center.latitude, center.longitude),
          width: isSelected ? 48 : 38,
          height: isSelected ? 48 : 38,
          child: GestureDetector(
            onTap: () => _focusCenter(center),
            child: Tooltip(
              message: center.name,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 3 : 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: isSelected ? 10 : 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  pinIcon,
                  color: Colors.white,
                  size: isSelected ? 22 : 18,
                ),
              ),
            ),
          ),
        );
      }),
      // User Location Blue Dot
      Marker(
        point: userPoint,
        width: 32,
        height: 32,
        child: Tooltip(
          message: isFil ? 'Iyong Lokasyon' : 'Your Location',
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withAlpha(55),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
        ),
      ),
    ];

    final allowPanAndWheel = isSplit || _unlockMobileMapPan;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialFocus,
            initialZoom: 13.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            interactionOptions: InteractionOptions(
              flags: allowPanAndWheel
                  ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
                  : (InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            onTap: (_, __) {
              if (_selectedCenter != null) {
                setState(() => _selectedCenter = null);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.lifecheckpoint.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // Mobile-only Map Pan Unlock Pill so vertical page scrolling never gets trapped
        if (!isSplit)
          Positioned(
            top: 12,
            left: 12,
            child: Material(
              color: _unlockMobileMapPan
                  ? Colors.teal.shade700
                  : (isDark ? AppTheme.darkCard : Colors.white).withAlpha(240),
              elevation: 2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(
                  () => _unlockMobileMapPan = !_unlockMobileMapPan,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _unlockMobileMapPan
                            ? Icons.lock_open_rounded
                            : Icons.pan_tool_alt_outlined,
                        size: 15,
                        color: _unlockMobileMapPan
                            ? Colors.white
                            : (isDark ? Colors.white : AppTheme.darkSlate),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _unlockMobileMapPan
                            ? (isFil ? 'Tapos Gumalaw' : 'Done Moving')
                            : (isFil ? 'Igalaw ang Mapa' : 'Move Map'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _unlockMobileMapPan
                              ? Colors.white
                              : (isDark ? Colors.white : AppTheme.darkSlate),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Top-right Map Controls (+, -, My Location, Metro Manila)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _mapControlButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom In',
                isDark: isDark,
                onTap: () => _zoomBy(1.0),
              ),
              const SizedBox(height: 6),
              _mapControlButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom Out',
                isDark: isDark,
                onTap: () => _zoomBy(-1.0),
              ),
              const SizedBox(height: 6),
              _mapControlButton(
                icon: Icons.my_location_rounded,
                tooltip: isFil ? 'Punta sa GPS Ko' : 'Center on Me',
                isDark: isDark,
                onTap: () => _safeMove(userPoint, 14.5),
              ),
              const SizedBox(height: 6),
              _mapControlButton(
                icon: Icons.location_city_rounded,
                tooltip: 'Center on Metro Manila',
                isDark: isDark,
                onTap: () => _safeMove(_metroManilaCenter, 13.0),
              ),
            ],
          ),
        ),

        // Bottom-left Compact Legend + OpenStreetMap Attribution
        if (_selectedCenter == null)
          Positioned(
            left: 10,
            bottom: 10,
            right: 10,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkCard : Colors.white)
                        .withAlpha(235),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _legendDot(
                        const Color(0xFF2563EB),
                        isFil ? 'Ikaw' : 'You',
                        isDark,
                      ),
                      _legendDot(
                        Colors.teal.shade700,
                        'Shelter',
                        isDark,
                      ),
                      _legendDot(
                        AppTheme.dangerRed,
                        isFil ? 'Ospital' : 'Hospital',
                        isDark,
                      ),
                      _legendDot(
                        Colors.indigo.shade600,
                        isFil ? 'Pulis/Bumbero' : 'Police/Fire',
                        isDark,
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
                    color: (isDark ? AppTheme.darkCard : Colors.white)
                        .withAlpha(220),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : AppTheme.mutedSlate,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Selected Facility Floating Popup Card on Map
        if (_selectedCenter != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildMapPopupCard(
              context,
              _selectedCenter!,
              emergency,
              isDark,
              isFil,
            ),
          ),
      ],
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: (isDark ? AppTheme.darkCard : Colors.white).withAlpha(240),
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white : AppTheme.darkSlate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.darkSlate,
          ),
        ),
      ],
    );
  }

  Future<void> _shareShelterPin(
    BuildContext context,
    EvacuationCenter center,
    bool isFil,
  ) async {
    final lat = center.latitude.toStringAsFixed(5);
    final lng = center.longitude.toStringAsFixed(5);
    final text =
        'Meet at ${center.name}\nAddress: ${center.address}\nMap: https://maps.google.com/?q=$lat,$lng\nHotline: ${center.contactNumber}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.safeGreen,
        content: Text(
          isFil
              ? 'Nakopya ang lokasyon ng shelter — i-paste sa Messenger o SMS!'
              : 'Shelter meeting pin copied — paste into Messenger or SMS!',
        ),
      ),
    );
  }

  Widget _buildNearestOpenShelterStrip(
    BuildContext context,
    EmergencyProvider emergency,
    bool isDark,
    bool isFil,
    Color headingColor,
    Color subtleText,
  ) {
    final openShelters = emergency.allEvacuationCenters
        .where(
          (c) => c.facilityType == FacilityType.evacuationShelter && c.isOpen,
        )
        .toList();
    if (openShelters.isEmpty) return const SizedBox.shrink();

    openShelters.sort(
      (a, b) => emergency
          .distanceToCenterKm(a)
          .compareTo(emergency.distanceToCenterKm(b)),
    );
    final nearest = openShelters.first;
    final distKm = emergency.distanceToCenterKm(nearest);

    return Material(
      color: Colors.teal.withAlpha(isDark ? 36 : 16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _focusCenter(nearest),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.teal.withAlpha(isDark ? 90 : 55),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFil ? 'PINAKAMALAPIT' : 'NEAREST OPEN',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${nearest.name} (${distKm.toStringAsFixed(1)} km)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.tealAccent : Colors.teal.shade800,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: Text(
                  isFil ? 'Ruta' : 'Go',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => ActionFeedback.openMapWithFeedback(
                  context,
                  emergency,
                  nearest.latitude,
                  nearest.longitude,
                  nearest.name,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPopupCard(
    BuildContext context,
    EvacuationCenter center,
    EmergencyProvider emergency,
    bool isDark,
    bool isFil,
  ) {
    final distKm = emergency.distanceToCenterKm(center);
    final titleColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    center.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${distKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _selectedCenter = null),
                  child: Icon(Icons.close_rounded, size: 19, color: subtleText),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              center.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: subtleText),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: Text(
                      isFil ? 'Direksyon' : 'Directions',
                      style: const TextStyle(fontSize: 13),
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
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(
                    isFil ? 'Tawag' : 'Call',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: () => ActionFeedback.callWithFeedback(
                    context,
                    emergency,
                    center.contactNumber,
                    center.contactPerson,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(
                    isFil ? 'Ibahagi' : 'Share',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: () => _shareShelterPin(context, center, isFil),
                ),
              ],
            ),
          ],
        ),
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
      showCheckmark: false,
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
    final isSelected = _selectedCenter?.id == center.id;
    final isFamilySaved = emergency.isCustomCenter(center.id);

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
            : 'Evacuation Shelter');

    final titleColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected || isNearest
            ? BorderSide(
                color: facilityAccent.withAlpha(isSelected ? 230 : 150),
                width: isSelected ? 2 : 1.3,
              )
            : BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _focusCenter(center),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  if (isFamilySaved) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withAlpha(isDark ? 55 : 26),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        isFil ? 'Pamilya' : 'Family Saved',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.amber.shade200
                              : const Color(0xFFB45309),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      center.name,
                      style: TextStyle(
                        fontSize: 15.5,
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
                            : 'Standby',
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
                  const SizedBox(width: 8),
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
                  if (isFamilySaved) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.dangerRed,
                      ),
                      tooltip: isFil
                          ? 'Burahin ang Naka-save na Shelter'
                          : 'Delete Family Shelter',
                      onPressed: () => _confirmDeleteFamilyShelter(
                        context,
                        emergency,
                        center,
                        isFil,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFamilyShelter(
    BuildContext context,
    EmergencyProvider emergency,
    EvacuationCenter center,
    bool isFil,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFil ? 'Burahin ang Shelter ng Pamilya?' : 'Remove Family Shelter?',
        ),
        content: Text(
          isFil
              ? 'Aalisin ang "${center.name}" sa naka-save na listahan ng iyong pamilya.'
              : 'Remove "${center.name}" from your family\'s saved shelter list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFil ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isFil ? 'Burahin' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      if (_selectedCenter?.id == center.id) {
        setState(() => _selectedCenter = null);
      }
      await emergency.removeCustomEvacuationCenter(center.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFil
                ? 'Nabura ang "${center.name}".'
                : 'Removed "${center.name}".',
          ),
        ),
      );
    }
  }

  Future<void> _showAddShelterDialog(
    BuildContext context,
    EmergencyProvider emergency,
    bool isFil,
  ) async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Manila');
    final contactCtrl = TextEditingController(text: '911');
    final miniMapCtrl = MapController();

    LatLng pickedPoint = LatLng(emergency.userLat, emergency.userLng);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void setPin(LatLng target, {double? zoom}) {
            setDialogState(() => pickedPoint = target);
            try {
              miniMapCtrl.move(target, zoom ?? miniMapCtrl.camera.zoom);
            } catch (_) {}
          }

          return AlertDialog(
            title: Text(
              isFil
                  ? 'I-save ang Barangay / Family Shelter'
                  : 'Save Barangay / Family Shelter',
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppTheme.primaryAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFil
                                  ? 'Pribado para sa iyong pamilya at naka-sync na kamag-anak — hindi binabago ang opisyal na LGU shelters.'
                                  : 'Saved privately for your household & synced relatives — does not alter official LGU shelters.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: isFil
                            ? 'Pangalan ng Covered Court / Safe Place *'
                            : 'Barangay Hall / Covered Court / Safe Place *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address / Landmark *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: InputDecoration(
                              labelText: isFil ? 'Lungsod' : 'City',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: contactCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hotline / Contact',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: metroManilaCityCoords.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () {
                                cityCtrl.text = entry.key;
                                setPin(
                                  LatLng(entry.value.lat, entry.value.lng),
                                  zoom: 13.8,
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isFil
                                ? 'I-tap ang mapa para ituro ang eksaktong lugar:'
                                : 'Tap the map to pin exact location:',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(Icons.my_location_rounded, size: 15),
                          label: Text(
                            isFil ? 'GPS Ko' : 'Use My GPS',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            await emergency.detectLiveGps();
                            setPin(
                              LatLng(emergency.userLat, emergency.userLng),
                              zoom: 15.0,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 185,
                        child: FlutterMap(
                          mapController: miniMapCtrl,
                          options: MapOptions(
                            initialCenter: pickedPoint,
                            initialZoom: 14.0,
                            minZoom: 5.0,
                            maxZoom: 18.0,
                            interactionOptions: const InteractionOptions(
                              flags:
                                  InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                            onTap: (_, latLng) => setPin(latLng),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.lifecheckpoint.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pickedPoint,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: AppTheme.dangerRed,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pinned GPS: ${pickedPoint.latitude.toStringAsFixed(5)}, ${pickedPoint.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.mutedSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isFil ? 'Kanselahin' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(isFil ? 'I-save para sa Pamilya' : 'Save for Family'),
              ),
            ],
          );
        },
      ),
    );

    final name = nameCtrl.text.trim();
    final addr = addrCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final phone = contactCtrl.text.trim();

    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      addrCtrl.dispose();
      cityCtrl.dispose();
      contactCtrl.dispose();
    });

    if (saved == true && mounted) {
      final newCenter = EvacuationCenter(
        id: const Uuid().v4(),
        name: name,
        address: addr.isEmpty ? 'Local Barangay Site' : addr,
        city: city.isEmpty ? 'Manila' : city,
        latitude: pickedPoint.latitude,
        longitude: pickedPoint.longitude,
        contactPerson: 'Barangay / Family Contact',
        contactNumber: phone.isEmpty ? '911' : phone,
        capacityPeople: 0,
        facilities: 'Family-Saved Barangay Shelter / Safe Spot',
      );
      await emergency.addCustomEvacuationCenter(newCenter);
      _focusCenter(newCenter);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.safeGreen,
            content: Text(
              isFil
                  ? 'Nai-save ang "$name" para sa iyong pamilya!'
                  : 'Saved "$name" privately for your family!',
            ),
          ),
        );
      }
    }
  }
}
