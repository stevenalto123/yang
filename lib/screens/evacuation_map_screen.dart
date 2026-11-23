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
  static const LatLng _manilaCenter = LatLng(14.5900, 120.9820);

  final MapController _mapController = MapController();
  final ScrollController _mobileScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _mapSectionKey = GlobalKey();

  EvacuationCenter? _selectedCenter;
  bool _unlockMobileMapPan = false;

  @override
  void dispose() {
    _mobileScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  void _focusCenter(EvacuationCenter center, {bool scrollToMap = false}) {
    setState(() => _selectedCenter = center);
    _safeMove(LatLng(center.latitude, center.longitude), 15.0);
    if (scrollToMap && _mapSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _mapSectionKey.currentContext!,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    }
  }

  String _formatEta(double distKm, bool isFil) {
    final walkMin = (distKm / 4.5 * 60).round().clamp(1, 999);
    final driveMin = (distKm / 18.0 * 60).round().clamp(1, 999);
    if (distKm > 15.0) {
      return isFil ? '~$driveMin min biyahe' : '~$driveMin min drive';
    }
    return isFil
        ? '~$walkMin min lakad • ~$driveMin min biyahe'
        : '~$walkMin min walk • ~$driveMin min drive';
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
      _manilaCenter.latitude,
      _manilaCenter.longitude,
    );
    final isFarFromManila = distFromManilaKm > 18.0;

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
                                  : (isFil
                                      ? 'Lungsod ng Maynila (City of Manila)'
                                      : 'City of Manila'),
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
                          label: Text(
                            isFil ? 'Maynila' : 'City of Manila',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            emergency.setManualLocation(
                              _manilaCenter.latitude,
                              _manilaCenter.longitude,
                            );
                            setState(() => _selectedCenter = null);
                            _safeMove(_manilaCenter, 13.0);
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
                                          ? (isFil
                                              ? 'Na-update ang lokasyon sa mapa!'
                                              : 'Location updated on map!')
                                          : (isFil
                                              ? 'Hindi makuha ang GPS. Ipinapakita ang mapa ng Lungsod ng Maynila.'
                                              : 'GPS unavailable. Showing City of Manila map.'),
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar for Manila Shelters, Hospitals, Police & Fire Stations
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _selectedCenter = null);
                      emergency.setShelterSearchQuery(val);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: emergency.shelterSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 17),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _selectedCenter = null);
                                emergency.setShelterSearchQuery('');
                              },
                            )
                          : null,
                      hintText: isFil
                          ? 'Hanapin ang shelter, ospital, MPD/BFP, o kalye sa Maynila...'
                          : 'Search Manila shelter, hospital, MPD/BFP, or street...',
                      filled: true,
                      fillColor:
                          isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Facility Type Filter Chips + Open Only Toggle
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
                        const SizedBox(width: 8),
                        FilterChip(
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          avatar: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: emergency.onlyOpenFacilities
                                ? Colors.white
                                : AppTheme.safeGreen,
                          ),
                          label: Text(isFil ? 'Bukas Lang' : 'Open Only'),
                          selected: emergency.onlyOpenFacilities,
                          selectedColor: AppTheme.safeGreen,
                          backgroundColor: isDark
                              ? AppTheme.darkElevated
                              : AppTheme.surfaceBg,
                          side: BorderSide(
                            color: emergency.onlyOpenFacilities
                                ? AppTheme.safeGreen
                                : (isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.lightBorder),
                          ),
                          labelStyle: TextStyle(
                            color: emergency.onlyOpenFacilities
                                ? Colors.white
                                : (isDark ? Colors.white : AppTheme.darkSlate),
                            fontWeight: emergency.onlyOpenFacilities
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                          onSelected: (val) {
                            setState(() => _selectedCenter = null);
                            emergency.setOnlyOpenFacilities(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // District Filter Row (All City of Manila Districts)
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
                                  ? (isFil ? 'Buong Maynila' : 'All Manila')
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
                                  emergency.hasLiveGps && !isFarFromManila
                                      ? LatLng(
                                          emergency.userLat,
                                          emergency.userLng,
                                        )
                                      : _manilaCenter,
                                  13.0,
                                );
                              } else {
                                final district = manilaDistrictFilters[city];
                                if (district != null) {
                                  _safeMove(
                                    LatLng(district.lat, district.lng),
                                    14.5,
                                  );
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
                    isSplit,
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
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 30,
                            color: subtleText,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFil
                                ? 'Walang nahanap na lugar sa napiling filter.'
                                : 'No Manila places match your selected filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: subtleText),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _selectedCenter = null);
                              emergency.setShelterSearchQuery('');
                              emergency.setSelectedCity('All');
                              emergency.setSelectedFacilityType(null);
                              emergency.setOnlyOpenFacilities(false);
                              _safeMove(_manilaCenter, 13.0);
                            },
                            child: Text(
                              isFil ? 'I-reset ang Filter' : 'Reset Filters',
                            ),
                          ),
                        ],
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
                    isSplit,
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
            controller: _mobileScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              headerPanel,
              const Divider(height: 1),
              Padding(
                key: _mapSectionKey,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 255,
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
                          : 'Nearby Manila Places (${centers.length})',
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
    final initialFocus = isFarFromManila ? _manilaCenter : userPoint;
    final hasStandbyCenters = centers.any((c) => !c.isOpen);

    final markers = <Marker>[
      // Facility Pins
      ...centers.map((center) {
        final isSelected = _selectedCenter?.id == center.id;
        final isHospital = center.facilityType == FacilityType.hospital;
        final isPoliceFire = center.facilityType == FacilityType.policeFire;
        final Color pinColor = !center.isOpen
            ? Colors.blueGrey.shade500
            : (isHospital
                ? AppTheme.dangerRed
                : (isPoliceFire
                    ? Colors.indigo.shade600
                    : Colors.teal.shade700));
        final IconData pinIcon = !center.isOpen
            ? Icons.pause_circle_outline_rounded
            : (isHospital
                ? Icons.local_hospital_rounded
                : (isPoliceFire
                    ? Icons.local_police_rounded
                    : Icons.roofing_rounded));

        return Marker(
          point: LatLng(center.latitude, center.longitude),
          width: isSelected ? 48 : 38,
          height: isSelected ? 48 : 38,
          child: GestureDetector(
            onTap: () => _focusCenter(center),
            child: Tooltip(
              message:
                  '${center.name}${center.isOpen ? '' : ' (Standby)'}',
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
    final showGuideLine = _selectedCenter != null &&
        emergency.distanceToCenterKm(_selectedCenter!) <= 30.0;

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
            if (showGuideLine)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      userPoint,
                      LatLng(
                        _selectedCenter!.latitude,
                        _selectedCenter!.longitude,
                      ),
                    ],
                    strokeWidth: 3.5,
                    color: _selectedCenter!.isOpen
                        ? Colors.teal.shade700
                        : Colors.blueGrey.shade500,
                    pattern: StrokePattern.dashed(
                      segments: const [10, 7],
                      patternFit: PatternFit.scaleUp,
                    ),
                  ),
                ],
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

        // Top-right Map Controls (+, -, My Location, City of Manila)
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
                tooltip: isFil
                    ? 'I-center sa Lungsod ng Maynila'
                    : 'Center on City of Manila',
                isDark: isDark,
                onTap: () => _safeMove(_manilaCenter, 13.0),
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
                      if (hasStandbyCenters)
                        _legendDot(
                          Colors.blueGrey.shade500,
                          'Standby',
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
    bool isSplit,
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
        onTap: () => _focusCenter(nearest, scrollToMap: !isSplit),
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
    final cardinal = emergency.bearingToCenter(center);
    final etaText = _formatEta(distKm, isFil);
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
                  '${distKm.toStringAsFixed(1)} km $cardinal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.tealAccent : Colors.teal.shade700,
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
              '${center.address} • $etaText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subtleText),
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
    bool isSplit,
  ) {
    final distKm = emergency.distanceToCenterKm(center);
    final cardinal = emergency.bearingToCenter(center);
    final etaText = _formatEta(distKm, isFil);
    final isSelected = _selectedCenter?.id == center.id;
    final isFamilySaved = emergency.isCustomCenter(center.id);

    final isHospital = center.facilityType == FacilityType.hospital;
    final isPoliceFire = center.facilityType == FacilityType.policeFire;

    final Color facilityAccent = !center.isOpen
        ? Colors.blueGrey.shade500
        : (isHospital
            ? AppTheme.dangerRed
            : (isPoliceFire ? Colors.indigo.shade600 : Colors.teal.shade700));
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
        onTap: () => _focusCenter(center, scrollToMap: !isSplit),
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
              const SizedBox(height: 4),
              Text(
                etaText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                ),
              ),
              const SizedBox(height: 4),
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
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    icon: const Icon(Icons.share_rounded, size: 19),
                    tooltip: isFil
                        ? 'Ibahagi ang Lokasyon sa Pamilya'
                        : 'Share Meeting Pin',
                    onPressed: () => _shareShelterPin(context, center, isFil),
                  ),
                  if (isFamilySaved) ...[
                    const SizedBox(width: 4),
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
    final contactCtrl = TextEditingController(text: '(02) 8568-6909');
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
                                  ? 'Pribado para sa iyong pamilya at naka-sync na kamag-anak — hindi binabago ang opisyal na Manila shelters.'
                                  : 'Saved privately for your household & synced relatives — does not alter official Manila shelters.',
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
                        labelText: 'Address / Barangay / Landmark *',
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
                        children: manilaDistrictFilters.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () {
                                cityCtrl.text = 'Manila';
                                if (addrCtrl.text.trim().isEmpty) {
                                  addrCtrl.text = '${entry.key}, Manila';
                                }
                                setPin(
                                  LatLng(entry.value.lat, entry.value.lng),
                                  zoom: 14.8,
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
                child: Text(
                  isFil ? 'I-save para sa Pamilya' : 'Save for Family',
                ),
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
        address: addr.isEmpty ? 'Local Manila Barangay Site' : addr,
        city: city.isEmpty ? 'Manila' : city,
        latitude: pickedPoint.latitude,
        longitude: pickedPoint.longitude,
        contactPerson: 'Barangay / Family Contact',
        contactNumber: phone.isEmpty ? '(02) 8568-6909' : phone,
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
