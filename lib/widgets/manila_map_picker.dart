import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/app_theme.dart';

class ManilaDistrictPreset {
  final String label;
  final String city;
  final LatLng coords;

  const ManilaDistrictPreset(this.label, this.city, this.coords);
}

const List<ManilaDistrictPreset> kManilaDistrictPresets = [
  ManilaDistrictPreset('Ermita / Malate', 'Manila', LatLng(14.5735, 120.9875)),
  ManilaDistrictPreset('Paco', 'Manila', LatLng(14.5794, 120.9936)),
  ManilaDistrictPreset('San Andres', 'Manila', LatLng(14.5701, 120.9918)),
  ManilaDistrictPreset('Tondo / San Nicolas', 'Manila', LatLng(14.6120, 120.9690)),
  ManilaDistrictPreset('Port Area / Baseco', 'Manila', LatLng(14.5889, 120.9622)),
  ManilaDistrictPreset('Sampaloc', 'Manila', LatLng(14.6158, 120.9950)),
  ManilaDistrictPreset('Sta. Mesa / San Miguel', 'Manila', LatLng(14.6020, 121.0125)),
  ManilaDistrictPreset('Sta. Ana / Pandacan', 'Manila', LatLng(14.5812, 121.0128)),
  ManilaDistrictPreset('Quiapo / Sta. Cruz', 'Manila', LatLng(14.6010, 120.9830)),
  ManilaDistrictPreset('Intramuros / Binondo', 'Manila', LatLng(14.5945, 120.9745)),
];

class ManilaPlaceResult {
  final String title;
  final String subtitle;
  final LatLng coords;

  const ManilaPlaceResult({
    required this.title,
    required this.subtitle,
    required this.coords,
  });
}

class ManilaPickedLocation {
  final LatLng coords;
  final String? suggestedAddress;

  const ManilaPickedLocation({
    required this.coords,
    this.suggestedAddress,
  });
}

/// Searches streets, schools, barangays, and landmarks within the City of Manila
/// via OpenStreetMap Nominatim (free, zero API key, gracefully returns empty offline).
Future<List<ManilaPlaceResult>> searchManilaPlaces(String rawQuery) async {
  final q = rawQuery.trim();
  if (q.isEmpty) return [];

  final scoped =
      q.toLowerCase().contains('manila') ? q : '$q, Manila, Philippines';
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'format': 'json',
    'limit': '5',
    'countrycodes': 'ph',
    'viewbox': '120.94,14.65,121.03,14.54',
    'bounded': '1',
    'q': scoped,
  });

  try {
    final resp = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return [];
    final decoded = json.decode(resp.body);
    if (decoded is! List) return [];

    final results = <ManilaPlaceResult>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final lat = double.tryParse((item['lat'] ?? '').toString());
      final lon = double.tryParse((item['lon'] ?? '').toString());
      if (lat == null || lon == null) continue;

      final full = (item['display_name'] ?? '').toString().trim();
      final parts = full
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final title = parts.isNotEmpty ? parts.first : q;
      final subtitle = parts.length > 1
          ? parts.skip(1).take(3).join(', ')
          : 'City of Manila';

      results.add(
        ManilaPlaceResult(
          title: title,
          subtitle: subtitle,
          coords: LatLng(lat, lon),
        ),
      );
    }
    return results;
  } catch (_) {
    return [];
  }
}

/// Full-screen interactive Grab / Google Maps-style pin picker for City of Manila.
/// Zero scroll-conflict: drag the map freely under the center pin, tap anywhere,
/// search a Manila street/school/barangay, or jump to a district.
class ManilaFullScreenMapPicker extends StatefulWidget {
  final LatLng initialPoint;
  final bool isFil;

  const ManilaFullScreenMapPicker({
    super.key,
    required this.initialPoint,
    this.isFil = false,
  });

  static Future<ManilaPickedLocation?> show(
    BuildContext context, {
    required LatLng initialPoint,
    bool isFil = false,
  }) {
    return Navigator.of(context).push<ManilaPickedLocation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ManilaFullScreenMapPicker(
          initialPoint: initialPoint,
          isFil: isFil,
        ),
      ),
    );
  }

  @override
  State<ManilaFullScreenMapPicker> createState() =>
      _ManilaFullScreenMapPickerState();
}

class _ManilaFullScreenMapPickerState extends State<ManilaFullScreenMapPicker> {
  final MapController _mapCtrl = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  late LatLng _centerPoint;
  String? _pickedAddress;
  bool _isSearching = false;
  String? _searchStatus;
  List<ManilaPlaceResult> _results = [];

  @override
  void initState() {
    super.initState();
    _centerPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _moveMap(LatLng target, {double? zoom}) {
    final nextZoom = (zoom ?? _safeCurrentZoom()).clamp(11.0, 18.5);
    setState(() => _centerPoint = target);
    try {
      _mapCtrl.move(target, nextZoom);
    } catch (_) {}
  }

  double _safeCurrentZoom() {
    try {
      return _mapCtrl.camera.zoom;
    } catch (_) {
      return 15.0;
    }
  }

  void _zoomBy(double delta) {
    try {
      final cam = _mapCtrl.camera;
      _mapCtrl.move(cam.center, (cam.zoom + delta).clamp(11.0, 18.5));
    } catch (_) {}
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searchStatus = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchStatus = null;
    });
    final matches = await searchManilaPlaces(q);
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _results = matches;
      if (matches.isEmpty) {
        _searchStatus = widget.isFil
            ? 'Walang nahanap sa Maynila. I-drag ang mapa o pumili ng distrito.'
            : 'No match found in Manila. Drag the map freely or pick a district.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFil
              ? 'Pumili ng Lokasyon sa Maynila'
              : 'Pick Shelter Location (Manila)',
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              widget.isFil ? 'Gamitin' : 'Use Pin',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              Navigator.pop(
                context,
                ManilaPickedLocation(
                  coords: _centerPoint,
                  suggestedAddress: _pickedAddress,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full-screen smooth interactive OpenStreetMap
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: widget.initialPoint,
              initialZoom: 15.0,
              minZoom: 11.0,
              maxZoom: 18.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _centerPoint = camera.center;
                    if (_results.isNotEmpty) _results = [];
                  });
                }
              },
              onTap: (_, latLng) {
                setState(() => _results = []);
                _moveMap(latLng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lifecheckpoint.app',
              ),
            ],
          ),

          // 2. Fixed center pin (Grab / Google Maps style — drag map smoothly underneath)
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withAlpha(225),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        widget.isFil ? 'I-drag ang mapa' : 'Drag map to aim pin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_pin,
                      color: AppTheme.dangerRed,
                      size: 46,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    Container(
                      width: 10,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Search Bar + District Quick-Jump Chips
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      color: cardBg,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                textInputAction: TextInputAction.search,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _runSearch(),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: widget.isFil
                                      ? 'Maghanap ng kalye, paaralan, o barangay sa Maynila...'
                                      : 'Search Manila street, school, or barangay...',
                                ),
                              ),
                            ),
                            if (_searchCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _results = [];
                                    _searchStatus = null;
                                  });
                                },
                              ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: _isSearching ? null : _runSearch,
                              child: _isSearching
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(widget.isFil ? 'Hanap' : 'Search'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_searchStatus != null) ...[
                      const SizedBox(height: 6),
                      Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(10),
                        color: cardBg,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            _searchStatus!,
                            style: TextStyle(fontSize: 12.5, color: subtleText),
                          ),
                        ),
                      ),
                    ],
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Material(
                        elevation: 5,
                        borderRadius: BorderRadius.circular(12),
                        color: cardBg,
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, idx) {
                              final place = _results[idx];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.place_rounded,
                                  color: AppTheme.dangerRed,
                                  size: 20,
                                ),
                                title: Text(
                                  place.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  place.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  setState(() {
                                    _pickedAddress =
                                        '${place.title}, ${place.subtitle}';
                                    _results = [];
                                    _searchStatus = null;
                                  });
                                  _moveMap(place.coords, zoom: 16.5);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: kManilaDistrictPresets.map((preset) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              backgroundColor: cardBg.withAlpha(240),
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                preset.label,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                setState(() => _results = []);
                                _moveMap(preset.coords, zoom: 14.8);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Right-Side Big + / - Zoom Controls
          Positioned(
            right: 14,
            bottom: 148,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'picker_zoom_in',
                  backgroundColor: cardBg,
                  foregroundColor: isDark ? Colors.white : AppTheme.primaryNavy,
                  onPressed: () => _zoomBy(1.0),
                  child: const Icon(Icons.add_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'picker_zoom_out',
                  backgroundColor: cardBg,
                  foregroundColor: isDark ? Colors.white : AppTheme.primaryNavy,
                  onPressed: () => _zoomBy(-1.0),
                  child: const Icon(Icons.remove_rounded),
                ),
              ],
            ),
          ),

          // 5. Bottom Confirm Card
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    color: cardBg,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.my_location_rounded,
                                size: 18,
                                color: AppTheme.dangerRed,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickedAddress ??
                                          (widget.isFil
                                              ? 'Napiling Lokasyon sa Maynila'
                                              : 'Selected Pin in City of Manila'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      'GPS: ${_centerPoint.latitude.toStringAsFixed(5)}, ${_centerPoint.longitude.toStringAsFixed(5)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtleText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 19),
                            label: Text(
                              widget.isFil
                                  ? 'Gamitin ang Lokasyong Ito'
                                  : 'Confirm Pin Location',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(
                                context,
                                ManilaPickedLocation(
                                  coords: _centerPoint,
                                  suggestedAddress: _pickedAddress,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
