import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../data/evacuation_centers_data.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/action_feedback.dart';
import '../utils/app_theme.dart';
import '../utils/csv_download.dart';
import '../widgets/manila_map_picker.dart';
import '../widgets/responsive_container.dart';

class _CityPreset {
  final String label;
  final String city;
  final LatLng coords;

  const _CityPreset(this.label, this.city, this.coords);
}

const List<_CityPreset> _manilaPresets = [
  _CityPreset('Ermita / Malate', 'Manila', LatLng(14.5735, 120.9875)),
  _CityPreset('Paco', 'Manila', LatLng(14.5794, 120.9936)),
  _CityPreset('San Andres', 'Manila', LatLng(14.5701, 120.9918)),
  _CityPreset('Tondo / San Nicolas', 'Manila', LatLng(14.6120, 120.9690)),
  _CityPreset('Port Area / Baseco', 'Manila', LatLng(14.5889, 120.9622)),
  _CityPreset('Sampaloc', 'Manila', LatLng(14.6158, 120.9950)),
  _CityPreset('Sta. Mesa / San Miguel', 'Manila', LatLng(14.6020, 121.0125)),
  _CityPreset('Sta. Ana / Pandacan', 'Manila', LatLng(14.5812, 121.0128)),
  _CityPreset('Quiapo / Sta. Cruz', 'Manila', LatLng(14.6010, 120.9830)),
  _CityPreset('Intramuros / Binondo', 'Manila', LatLng(14.5945, 120.9745)),
];

class AdminDashboardScreen extends StatefulWidget {
  final bool isRootShell;

  const AdminDashboardScreen({super.key, this.isRootShell = false});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _codeCtrl = TextEditingController();
  final _householdSearchCtrl = TextEditingController();
  final _shelterSearchCtrl = TextEditingController();
  final _checkinSearchCtrl = TextEditingController();
  final _advisoryTitleCtrl = TextEditingController();
  final _advisoryMsgCtrl = TextEditingController();
  final _advisoryAreaCtrl = TextEditingController(text: 'City of Manila');

  String _activeAdminCode = '';
  bool _unlocked = false;
  bool _obscureAdminCode = true;
  bool _isLoading = false;
  bool _isPostingAdvisory = false;
  bool _autoRefreshEnabled = true;
  DateTime? _lastFetchedAt;
  Timer? _autoRefreshTimer;
  String? _error;

  // Filters & sorting
  String _householdQuery = '';
  String _householdSort = 'LOWEST_READY'; // LOWEST_READY, RECENT, VULNERABLE, LARGEST
  String _shelterQuery = '';
  String _shelterStatusFilter = 'ALL'; // ALL, OPEN, STANDBY
  String _shelterCityFilter = 'ALL';
  String _checkinQuery = '';
  String _checkinFilter = 'ALL'; // ALL, HELP, EVAC, SAFE, ASSISTED
  String _advisorySeverity = 'warning'; // info, warning, critical

  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      _unlocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOverview();
        _startAutoRefresh();
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _codeCtrl.dispose();
    _householdSearchCtrl.dispose();
    _shelterSearchCtrl.dispose();
    _checkinSearchCtrl.dispose();
    _advisoryTitleCtrl.dispose();
    _advisoryMsgCtrl.dispose();
    _advisoryAreaCtrl.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!_autoRefreshEnabled || !_unlocked) return;
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _unlocked && !_isLoading) {
        _loadOverview(silent: true);
      }
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;
    });
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
      _showSnack('Live auto-refresh enabled (every 30s).');
    } else {
      _autoRefreshTimer?.cancel();
      _showSnack('Auto-refresh paused.');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.dangerRed : AppTheme.safeGreen,
      ),
    );
  }

  Future<void> _unlockWithCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your Admin Code.');
      return;
    }
    _activeAdminCode = code;
    await _loadOverview(fromUnlock: true);
    if (_unlocked) _startAutoRefresh();
  }

  Future<void> _loadOverview({
    bool fromUnlock = false,
    bool silent = false,
  }) async {
    final auth = context.read<AuthProvider>();
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final res = await auth.fetchAdminOverview(
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.ok && res.data != null) {
        _overview = res.data;
        _unlocked = true;
        _lastFetchedAt = DateTime.now();
        _error = null;
      } else if (!silent) {
        if (fromUnlock) _unlocked = false;
        _error = res.error ?? 'Invalid Admin Code or server unreachable.';
      }
    });

    // Keep local Nearby Map shelters immediately synced with Admin changes
    if (res.ok && res.data != null && mounted) {
      final rawShelters = res.data!['shelters'];
      if (rawShelters is List) {
        final mapped = rawShelters
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mapped.isNotEmpty) {
          context.read<EmergencyProvider>().applyRemoteShelters(mapped);
        }
      }
    }
  }

  Future<void> _toggleShelterOpen(
    Map<String, dynamic> shelter,
    bool nextOpen,
  ) async {
    final auth = context.read<AuthProvider>();
    final id = (shelter['id'] ?? '').toString();
    final previousOpen = shelter['isOpen'] == true;

    // Optimistic UI update for instant feedback
    setState(() {
      final list = _overview?['shelters'] as List<dynamic>?;
      if (list != null) {
        for (final item in list) {
          if (item is Map && (item['id'] ?? '').toString() == id) {
            item['isOpen'] = nextOpen;
          }
        }
      }
      final counts = _overview?['counts'];
      if (counts is Map && previousOpen != nextOpen) {
        final cur = (counts['openShelters'] ?? 0) as int;
        counts['openShelters'] = (cur + (nextOpen ? 1 : -1)).clamp(0, 9999);
      }
    });

    final res = await auth.updateOfficialShelter(
      id: id,
      isOpen: nextOpen,
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack(
        '${shelter['name']} marked ${nextOpen ? 'OPEN' : 'STANDBY'}.',
      );
      _loadOverview(silent: true);
    } else {
      // Roll back optimistic state on error
      setState(() {
        final list = _overview?['shelters'] as List<dynamic>?;
        if (list != null) {
          for (final item in list) {
            if (item is Map && (item['id'] ?? '').toString() == id) {
              item['isOpen'] = previousOpen;
            }
          }
        }
        final counts = _overview?['counts'];
        if (counts is Map && previousOpen != nextOpen) {
          final cur = (counts['openShelters'] ?? 0) as int;
          counts['openShelters'] =
              (cur + (previousOpen ? 1 : -1)).clamp(0, 9999);
        }
      });
      _showSnack(res.error ?? 'Update failed.', isError: true);
    }
  }

  Future<void> _showShelterEditorDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(
      text: isEdit ? (existing['name'] ?? '').toString() : '',
    );
    final addressCtrl = TextEditingController(
      text: isEdit ? (existing['address'] ?? '').toString() : '',
    );
    final cityCtrl = TextEditingController(
      text: isEdit ? (existing['city'] ?? 'Manila').toString() : 'Manila',
    );
    final contactPersonCtrl = TextEditingController(
      text: isEdit
          ? (existing['contactPerson'] ?? 'Manila DRRMO').toString()
          : 'Manila DRRMO',
    );
    final phoneCtrl = TextEditingController(
      text: isEdit
          ? (existing['contactNumber'] ?? '(02) 8568-6909').toString()
          : '(02) 8568-6909',
    );
    final capCtrl = TextEditingController(
      text: isEdit
          ? (existing['capacityPeople'] ?? 500).toString()
          : '800',
    );
    final facCtrl = TextEditingController(
      text: isEdit
          ? (existing['facilities'] ?? '').toString()
          : 'Covered Court, Relief Distribution, Medical Desk',
    );

    final initialLat = isEdit
        ? ((existing['latitude'] as num?)?.toDouble() ?? 14.5822)
        : 14.5822;
    final initialLng = isEdit
        ? ((existing['longitude'] as num?)?.toDouble() ?? 120.9882)
        : 120.9882;
    final latCtrl = TextEditingController(text: initialLat.toStringAsFixed(5));
    final lngCtrl = TextEditingController(text: initialLng.toStringAsFixed(5));
    final mapSearchCtrl = TextEditingController();
    final dialogScrollCtrl = ScrollController();
    final miniMapController = MapController();
    LatLng pickedPoint = LatLng(initialLat, initialLng);
    bool isPanningMap = false;
    bool isSearchingPlace = false;
    List<ManilaPlaceResult> placeResults = [];
    String? nameError;
    String? placeSearchHint;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void movePin(LatLng point, {double zoom = 14.5}) {
            setDialogState(() {
              pickedPoint = point;
              latCtrl.text = point.latitude.toStringAsFixed(5);
              lngCtrl.text = point.longitude.toStringAsFixed(5);
            });
            try {
              miniMapController.move(point, zoom.clamp(10.0, 18.5));
            } catch (_) {}
          }

          void zoomMiniMap(double delta) {
            try {
              final cam = miniMapController.camera;
              miniMapController.move(
                cam.center,
                (cam.zoom + delta).clamp(10.0, 18.5),
              );
            } catch (_) {}
          }

          Future<void> runPlaceSearch() async {
            final q = mapSearchCtrl.text.trim();
            if (q.isEmpty) {
              setDialogState(() {
                placeResults = [];
                placeSearchHint = null;
              });
              return;
            }
            setDialogState(() {
              isSearchingPlace = true;
              placeSearchHint = null;
            });
            final matches = await searchManilaPlaces(q);
            if (!ctx.mounted) return;
            setDialogState(() {
              isSearchingPlace = false;
              placeResults = matches;
              if (matches.isEmpty) {
                placeSearchHint =
                    'No match found in Manila. Try Full-Screen Map or tap a district.';
              }
            });
          }

          return AlertDialog(
            title: Text(
              isEdit
                  ? 'Edit Evacuation Center'
                  : 'Add Official Evacuation Center',
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                controller: dialogScrollCtrl,
                physics: isPanningMap
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) {
                        if (nameError != null) {
                          setDialogState(() => nameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Shelter / Facility Name *',
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Address *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: capCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Capacity (people)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: contactPersonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Officer / Office',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hotline',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: facCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Facilities / Services',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pin Location in City of Manila',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.open_in_full_rounded, size: 15),
                          label: const Text(
                            'Full-Screen Map',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () async {
                            final picked = await ManilaFullScreenMapPicker.show(
                              ctx,
                              initialPoint: pickedPoint,
                            );
                            if (picked != null && ctx.mounted) {
                              if (picked.suggestedAddress != null &&
                                  addressCtrl.text.trim().isEmpty) {
                                addressCtrl.text = picked.suggestedAddress!;
                              }
                              movePin(picked.coords, zoom: 16.0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mapSearchCtrl,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setDialogState(() {}),
                            onSubmitted: (_) => runPlaceSearch(),
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                              ),
                              hintText:
                                  'Search street, school, or barangay in Manila...',
                              suffixIcon: mapSearchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                      ),
                                      onPressed: () {
                                        mapSearchCtrl.clear();
                                        setDialogState(() {
                                          placeResults = [];
                                          placeSearchHint = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: isSearchingPlace ? null : runPlaceSearch,
                          child: isSearchingPlace
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Find'),
                        ),
                      ],
                    ),
                    if (placeSearchHint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        placeSearchHint!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedSlate,
                        ),
                      ),
                    ],
                    if (placeResults.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(ctx).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: placeResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final p = placeResults[idx];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place_rounded,
                                color: AppTheme.dangerRed,
                                size: 18,
                              ),
                              title: Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                p.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onTap: () {
                                if (addressCtrl.text.trim().isEmpty) {
                                  addressCtrl.text =
                                      '${p.title}, ${p.subtitle}';
                                }
                                setDialogState(() => placeResults = []);
                                movePin(p.coords, zoom: 16.5);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _manilaPresets.map((preset) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                preset.label,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () {
                                cityCtrl.text = preset.city;
                                movePin(preset.coords, zoom: 14.5);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Listener(
                      onPointerDown: (_) =>
                          setDialogState(() => isPanningMap = true),
                      onPointerUp: (_) =>
                          setDialogState(() => isPanningMap = false),
                      onPointerCancel: (_) =>
                          setDialogState(() => isPanningMap = false),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 235,
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: miniMapController,
                                options: MapOptions(
                                  initialCenter: pickedPoint,
                                  initialZoom: 14.0,
                                  minZoom: 10.0,
                                  maxZoom: 18.5,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all &
                                        ~InteractiveFlag.rotate,
                                  ),
                                  onTap: (_, latLng) => movePin(
                                    latLng,
                                    zoom: miniMapController.camera.zoom,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.lifecheckpoint.app',
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
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(165),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Drag freely or tap to move pin',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Column(
                                  children: [
                                    Material(
                                      color: Colors.white,
                                      elevation: 2,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => zoomMiniMap(1.0),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.add_rounded,
                                            size: 20,
                                            color: AppTheme.primaryNavy,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Material(
                                      color: Colors.white,
                                      elevation: 2,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => zoomMiniMap(-1.0),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.remove_rounded,
                                            size: 20,
                                            color: AppTheme.primaryNavy,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                            onChanged: (v) {
                              final p = double.tryParse(v.trim());
                              if (p != null && p >= -90 && p <= 90) {
                                setDialogState(() {
                                  pickedPoint = LatLng(p, pickedPoint.longitude);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                            onChanged: (v) {
                              final p = double.tryParse(v.trim());
                              if (p != null && p >= -180 && p <= 180) {
                                setDialogState(() {
                                  pickedPoint = LatLng(pickedPoint.latitude, p);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setDialogState(
                      () => nameError = 'Please enter a shelter name first.',
                    );
                    if (dialogScrollCtrl.hasClients) {
                      dialogScrollCtrl.animateTo(
                        0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    }
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(isEdit ? 'Save Changes' : 'Publish Shelter'),
              ),
            ],
          );
        },
      ),
    );

    final name = nameCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final contactPerson = contactPersonCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final cap = int.tryParse(capCtrl.text.trim()) ?? 500;
    final lat = double.tryParse(latCtrl.text.trim()) ?? pickedPoint.latitude;
    final lng = double.tryParse(lngCtrl.text.trim()) ?? pickedPoint.longitude;
    final facilities = facCtrl.text.trim();

    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      addressCtrl.dispose();
      cityCtrl.dispose();
      contactPersonCtrl.dispose();
      phoneCtrl.dispose();
      capCtrl.dispose();
      facCtrl.dispose();
      latCtrl.dispose();
      lngCtrl.dispose();
      mapSearchCtrl.dispose();
      dialogScrollCtrl.dispose();
    });

    if (submitted != true || !mounted) return;
    final auth = context.read<AuthProvider>();

    if (isEdit) {
      final res = await auth.updateOfficialShelter(
        id: (existing['id'] ?? '').toString(),
        name: name,
        address: address.isEmpty ? 'City of Manila' : address,
        city: city.isEmpty ? 'Manila' : city,
        contactPerson: contactPerson,
        contactNumber: phone,
        capacityPeople: cap,
        latitude: lat,
        longitude: lng,
        facilities: facilities,
        adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
      );
      if (!mounted) return;
      if (res.ok) {
        _showSnack('Updated "$name" successfully.');
        await _loadOverview();
      } else {
        _showSnack(res.error ?? 'Could not update shelter.', isError: true);
      }
    } else {
      final res = await auth.createOfficialShelter(
        adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
        shelter: {
          'name': name,
          'address': address.isEmpty ? 'City of Manila' : address,
          'city': city.isEmpty ? 'Manila' : city,
          'contactPerson': contactPerson,
          'contactNumber': phone,
          'capacityPeople': cap,
          'latitude': lat,
          'longitude': lng,
          'facilities': facilities,
          'isOpen': true,
        },
      );
      if (!mounted) return;
      if (res.ok) {
        _showSnack('Official shelter published to Supabase!');
        await _loadOverview();
      } else {
        _showSnack(res.error ?? 'Could not add shelter.', isError: true);
      }
    }
  }

  Future<void> _confirmDeleteShelter(Map<String, dynamic> shelter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Shelter?'),
        content: Text(
          'Remove "${shelter['name']}" from the cloud shelter directory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final res = await auth.deleteOfficialShelter(
      id: (shelter['id'] ?? '').toString(),
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack('Shelter removed.');
      await _loadOverview();
    } else {
      _showSnack(res.error ?? 'Could not remove shelter.', isError: true);
    }
  }

  Future<void> _toggleCheckinAcknowledged(
    Map<String, dynamic> checkin,
    bool nextAck,
  ) async {
    final auth = context.read<AuthProvider>();
    final id = (checkin['id'] ?? '').toString();
    final res = await auth.acknowledgeCheckin(
      id: id,
      acknowledged: nextAck,
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack(
        nextAck
            ? 'Marked check-in as assisted.'
            : 'Reopened check-in for follow-up.',
      );
      await _loadOverview(silent: true);
    } else {
      _showSnack(res.error ?? 'Could not update check-in.', isError: true);
    }
  }

  Future<void> _publishAdvisory() async {
    final title = _advisoryTitleCtrl.text.trim();
    final message = _advisoryMsgCtrl.text.trim();
    final area = _advisoryAreaCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) {
      _showSnack('Please enter both an advisory title and message.',
          isError: true);
      return;
    }

    setState(() => _isPostingAdvisory = true);
    final auth = context.read<AuthProvider>();
    final monitoring = context.read<MonitoringProvider>();
    final res = await auth.createAdvisory(
      title: title,
      message: message,
      severity: _advisorySeverity,
      area: area.isEmpty ? 'City of Manila' : area,
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    setState(() => _isPostingAdvisory = false);

    if (res.ok) {
      _advisoryTitleCtrl.clear();
      _advisoryMsgCtrl.clear();
      _showSnack('Official advisory published to all households!');
      await _loadOverview(silent: true);
      monitoring.refreshAdvisoriesOnly();
    } else {
      _showSnack(res.error ?? 'Could not publish advisory.', isError: true);
    }
  }

  Future<void> _toggleAdvisoryActive(
    Map<String, dynamic> advisory,
    bool nextActive,
  ) async {
    final auth = context.read<AuthProvider>();
    final monitoring = context.read<MonitoringProvider>();
    final id = (advisory['id'] ?? '').toString();

    setState(() {
      final list = _overview?['advisories'] as List<dynamic>?;
      if (list != null) {
        for (final item in list) {
          if (item is Map && (item['id'] ?? '').toString() == id) {
            item['isActive'] = nextActive;
          }
        }
      }
    });

    final res = await auth.updateAdvisory(
      id: id,
      isActive: nextActive,
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack(
        nextActive ? 'Advisory reactivated.' : 'Advisory marked resolved.',
      );
      _loadOverview(silent: true);
      monitoring.refreshAdvisoriesOnly();
    } else {
      _showSnack(res.error ?? 'Update failed.', isError: true);
      _loadOverview(silent: true);
    }
  }

  Future<void> _deleteAdvisory(Map<String, dynamic> advisory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Advisory?'),
        content: Text('Delete "${advisory['title']}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final monitoring = context.read<MonitoringProvider>();
    final res = await auth.deleteAdvisory(
      id: (advisory['id'] ?? '').toString(),
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack('Advisory deleted.');
      await _loadOverview(silent: true);
      monitoring.refreshAdvisoriesOnly();
    } else {
      _showSnack(res.error ?? 'Could not delete advisory.', isError: true);
    }
  }

  Future<void> _copyCsv() async {
    final auth = context.read<AuthProvider>();
    final res = await auth.exportEvaluationsCsv(
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok && res.csv != null) {
      await Clipboard.setData(ClipboardData(text: res.csv!));
      _showSnack('ISO/IEC 25010 CSV dataset copied to clipboard!');
    } else {
      _showSnack(res.error ?? 'Unable to export CSV.', isError: true);
    }
  }

  Future<void> _downloadCsvFile() async {
    final auth = context.read<AuthProvider>();
    final res = await auth.exportEvaluationsCsv(
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok && res.csv != null) {
      final downloaded = downloadTextFile(
        filename: 'lifecheckpoint_iso25010_evaluations.csv',
        content: res.csv!,
      );
      if (downloaded) {
        _showSnack('Downloaded lifecheckpoint_iso25010_evaluations.csv!');
      } else {
        await Clipboard.setData(ClipboardData(text: res.csv!));
        _showSnack('CSV copied to clipboard (file download is web-only).');
      }
    } else {
      _showSnack(res.error ?? 'Unable to export CSV.', isError: true);
    }
  }

  ({String label, Color color}) _likertInterpretation(double score) {
    if (score <= 0) {
      return (label: 'No Responses', color: AppTheme.mutedSlate);
    }
    if (score >= 4.5) {
      return (label: 'Highly Acceptable', color: AppTheme.safeGreen);
    }
    if (score >= 3.5) {
      return (label: 'Acceptable', color: Colors.teal.shade700);
    }
    if (score >= 2.5) {
      return (label: 'Moderately Acceptable', color: AppTheme.warningAmber);
    }
    if (score >= 1.5) {
      return (label: 'Fairly Acceptable', color: Colors.deepOrange);
    }
    return (label: 'Needs Improvement', color: AppTheme.dangerRed);
  }

  int _vulnerabilityScore(Map<String, dynamic> h) {
    final p = Map<String, dynamic>.from(h['profile'] as Map? ?? {});
    int score = 0;
    if (((p['seniors'] ?? 0) as num) > 0) score += 3;
    if (((p['infants'] ?? 0) as num) > 0) score += 3;
    if (p['hasChronicMedicalNeeds'] == true) score += 4;
    if (p['isFloodProne'] == true) score += 1;
    if (p['isEarthquakeZone'] == true) score += 1;
    return score;
  }

  void _showHouseholdDetailSheet(
    Map<String, dynamic> h,
    bool isDark,
    Color headingColor,
    Color subtleText,
  ) {
    final profile = Map<String, dynamic>.from(h['profile'] as Map? ?? {});
    final adults = (profile['adults'] ?? 2) as num;
    final children = (profile['children'] ?? 0) as num;
    final infants = (profile['infants'] ?? 0) as num;
    final seniors = (profile['seniors'] ?? 0) as num;
    final pets = (profile['pets'] ?? 0) as num;
    final isFlood = profile['isFloodProne'] == true;
    final isQuake = profile['isEarthquakeZone'] == true;
    final hasMed = profile['hasChronicMedicalNeeds'] == true;

    final readiness = ((h['readinessPct'] ?? 0) as num).toDouble();
    final barColor = readiness >= 80
        ? AppTheme.safeGreen
        : (readiness >= 50 ? AppTheme.warningAmber : AppTheme.dangerRed);
    final updatedAt = DateTime.tryParse((h['updatedAt'] ?? '').toString());
    final primaryMeet = (h['primaryMeetingPoint'] ?? '').toString().trim();
    final secondaryMeet = (h['secondaryMeetingPoint'] ?? '').toString().trim();
    final code = (h['inviteCode'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (h['name'] ?? 'Household').toString(),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Invite Code: $code • ${h['accountCount'] ?? 1} ${(h['accountCount'] ?? 1) == 1 ? 'account' : 'accounts'} linked',
                              style: TextStyle(fontSize: 13, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: barColor.withAlpha(isDark ? 45 : 22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${readiness.toStringAsFixed(0)}% Ready',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: barColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (readiness / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          isDark ? AppTheme.darkElevated : AppTheme.lightBorder,
                      color: barColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${h['packedCount'] ?? 0} of ${h['itemCount'] ?? 0} Go-Bag items packed${updatedAt != null ? ' • Last synced ${DateFormat('MMM d, h:mm a').format(updatedAt.toLocal())}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: subtleText),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Household Size & Composition',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoPill('Adults: $adults', AppTheme.primaryAccent, isDark),
                      _infoPill('Children: $children', Colors.indigo, isDark),
                      _infoPill(
                        'Infants: $infants',
                        infants > 0 ? AppTheme.dangerRed : subtleText,
                        isDark,
                      ),
                      _infoPill(
                        'Seniors: $seniors',
                        seniors > 0 ? AppTheme.warningAmber : subtleText,
                        isDark,
                      ),
                      _infoPill('Pets: $pets', Colors.teal, isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'DRRM Vulnerability & Hazard Flags',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasMed)
                        _infoPill(
                          'Chronic Medical Needs',
                          AppTheme.dangerRed,
                          isDark,
                          icon: Icons.medical_services_outlined,
                        ),
                      if (seniors > 0)
                        _infoPill(
                          'Senior Citizens Present',
                          AppTheme.warningAmber,
                          isDark,
                          icon: Icons.elderly_rounded,
                        ),
                      if (infants > 0)
                        _infoPill(
                          'Infants Present',
                          AppTheme.dangerRed,
                          isDark,
                          icon: Icons.child_friendly_rounded,
                        ),
                      if (isFlood)
                        _infoPill(
                          'Flood-Prone Zone',
                          Colors.blue.shade700,
                          isDark,
                          icon: Icons.water_rounded,
                        ),
                      if (isQuake)
                        _infoPill(
                          'Earthquake Zone',
                          Colors.deepOrange,
                          isDark,
                          icon: Icons.sensors_rounded,
                        ),
                      if (!hasMed &&
                          seniors == 0 &&
                          infants == 0 &&
                          !isFlood &&
                          !isQuake)
                        _infoPill(
                          'No special vulnerability flags',
                          AppTheme.safeGreen,
                          isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saved Family Meeting Points',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Primary: ${primaryMeet.isEmpty ? 'Not configured yet' : primaryMeet}',
                    style: TextStyle(fontSize: 13.5, color: headingColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Secondary: ${secondaryMeet.isEmpty ? 'Not configured yet' : secondaryMeet}',
                    style: TextStyle(fontSize: 13.5, color: subtleText),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(String text, Color color, bool isDark, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 45 : 20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = settings.isDarkMode;
    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;
    final activeTabColor =
        isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin & DRRM Portal')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryNavy,
                                  AppTheme.primaryAccent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Portal Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                                Text(
                                  'Authorized DRRM Staff & System Administrators',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: subtleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enter your authorized Admin Code to manage City of Manila evacuation centers, broadcast advisories, monitor emergency check-ins, and export ISO/IEC 25010 research surveys.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: subtleText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeCtrl,
                        obscureText: _obscureAdminCode,
                        onSubmitted: (_) => _unlockWithCode(),
                        decoration: InputDecoration(
                          labelText: 'Admin Access Code',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureAdminCode
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscureAdminCode
                                ? 'Show admin code'
                                : 'Hide admin code',
                            onPressed: () => setState(
                              () => _obscureAdminCode = !_obscureAdminCode,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.dangerRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text(
                            _isLoading ? 'Verifying...' : 'Unlock Admin Portal',
                          ),
                          onPressed: _isLoading ? null : _unlockWithCode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final counts =
        Map<String, dynamic>.from(_overview?['counts'] as Map? ?? {});
    final needHelp = (counts['checkinsNeedingHelp'] ?? 0) as int;
    final activeAdvisories = (counts['activeAdvisories'] ?? 0) as int;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isRootShell,
        title: Row(
          children: [
            if (widget.isRootShell) ...[
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
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isRootShell
                        ? 'LifeCheckpoint Admin Portal'
                        : 'Admin & DRRM Portal',
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_lastFetchedAt != null)
                    Text(
                      '${auth.isAdmin && (auth.fullName ?? '').isNotEmpty ? '${auth.fullName} • ' : ''}Updated ${DateFormat('h:mm:ss a').format(_lastFetchedAt!)} • ${_autoRefreshEnabled ? 'Auto-sync 30s' : 'Manual'}',
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
          IconButton(
            icon: Icon(
              _autoRefreshEnabled
                  ? Icons.sync_rounded
                  : Icons.sync_disabled_rounded,
              color: _autoRefreshEnabled ? AppTheme.safeGreen : subtleText,
            ),
            tooltip: _autoRefreshEnabled
                ? 'Auto-Refresh ON (30s) — Tap to Pause'
                : 'Auto-Refresh OFF — Tap to Enable',
            onPressed: _toggleAutoRefresh,
          ),
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: activeTabColor,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Live Data',
            onPressed: _isLoading ? null : () => _loadOverview(),
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => settings.toggleDarkMode(),
          ),
          if (auth.isAdmin)
            MediaQuery.of(context).size.width >= 600
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () async {
                        _autoRefreshTimer?.cancel();
                        await auth.logout();
                        if (!context.mounted) return;
                        if (!widget.isRootShell && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.dangerRed,
                    ),
                    tooltip: 'Sign Out of Admin Account',
                    onPressed: () async {
                      _autoRefreshTimer?.cancel();
                      await auth.logout();
                      if (!context.mounted) return;
                      if (!widget.isRootShell && Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  )
          else
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Lock Admin Portal',
              onPressed: () {
                _autoRefreshTimer?.cancel();
                setState(() {
                  _unlocked = false;
                  _activeAdminCode = '';
                  _codeCtrl.clear();
                  _overview = null;
                });
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: activeTabColor,
          indicatorWeight: 3,
          labelColor: activeTabColor,
          unselectedLabelColor: subtleText,
          dividerColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            const Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Overview'),
                ],
              ),
            ),
            const Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.roofing_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Shelters'),
                ],
              ),
            ),
            Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.health_and_safety_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Check-Ins'),
                  if (needHelp > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$needHelp',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Advisories'),
                  if (activeAdvisories > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$activeAdvisories',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Survey'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading && _overview == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isDark, headingColor, subtleText),
                _buildSheltersTab(isDark, headingColor, subtleText),
                _buildCheckinsTab(isDark, headingColor, subtleText),
                _buildAdvisoriesTab(isDark, headingColor, subtleText),
                _buildSurveyTab(isDark, headingColor, subtleText),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(bool isDark, Color headingColor, Color subtleText) {
    final counts =
        Map<String, dynamic>.from(_overview?['counts'] as Map? ?? {});
    final rawHouseholds = (_overview?['households'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final evalSummary =
        Map<String, dynamic>.from(_overview?['evaluationSummary'] as Map? ?? {});
    final means = Map<String, dynamic>.from(evalSummary['means'] as Map? ?? {});
    final needHelp = (counts['checkinsNeedingHelp'] ?? 0) as int;
    final activeAdvisories = (counts['activeAdvisories'] ?? 0) as int;

    // Filter + sort households
    final q = _householdQuery.trim().toLowerCase();
    final households = rawHouseholds.where((h) {
      if (q.isEmpty) return true;
      final name = (h['name'] ?? '').toString().toLowerCase();
      final code = (h['inviteCode'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    households.sort((a, b) {
      if (_householdSort == 'LOWEST_READY') {
        final ra = ((a['readinessPct'] ?? 0) as num).toDouble();
        final rb = ((b['readinessPct'] ?? 0) as num).toDouble();
        return ra.compareTo(rb);
      }
      if (_householdSort == 'VULNERABLE') {
        return _vulnerabilityScore(b).compareTo(_vulnerabilityScore(a));
      }
      if (_householdSort == 'LARGEST') {
        final ma = ((a['memberCount'] ?? 1) as num).toInt();
        final mb = ((b['memberCount'] ?? 1) as num).toInt();
        return mb.compareTo(ma);
      }
      return (b['updatedAt'] ?? '')
          .toString()
          .compareTo((a['updatedAt'] ?? '').toString());
    });

    final avgReadinessPct = rawHouseholds.isEmpty
        ? 0.0
        : rawHouseholds
                .map((h) => ((h['readinessPct'] ?? 0) as num).toDouble())
                .reduce((a, b) => a + b) /
            rawHouseholds.length;

    final kpiCards = [
      _kpiCard(
        isDark: isDark,
        icon: Icons.groups_rounded,
        color: AppTheme.primaryAccent,
        label: 'Households',
        value: '${counts['households'] ?? 0}',
        sub: rawHouseholds.isNotEmpty
            ? 'Avg ${avgReadinessPct.toStringAsFixed(0)}% ready • ${counts['users'] ?? 0} user(s)'
            : '${counts['users'] ?? 0} registered user(s)',
        headingColor: headingColor,
        subtleText: subtleText,
        onTap: () {
          setState(() {
            _householdQuery = '';
            _householdSearchCtrl.clear();
          });
        },
      ),
      _kpiCard(
        isDark: isDark,
        icon: Icons.roofing_rounded,
        color: Colors.teal.shade700,
        label: 'Open Shelters',
        value: '${counts['openShelters'] ?? 0}/${counts['totalShelters'] ?? 0}',
        sub: 'Tap to manage centers',
        headingColor: headingColor,
        subtleText: subtleText,
        onTap: () => _tabController.animateTo(1),
      ),
      _kpiCard(
        isDark: isDark,
        icon: Icons.sos_rounded,
        color: needHelp > 0 ? AppTheme.dangerRed : AppTheme.safeGreen,
        label: 'Active SOS',
        value: '$needHelp',
        sub: '${counts['checkinsTotal'] ?? 0} total check-ins',
        headingColor: headingColor,
        subtleText: subtleText,
        onTap: () {
          setState(() => _checkinFilter = needHelp > 0 ? 'HELP' : 'ALL');
          _tabController.animateTo(2);
        },
      ),
      _kpiCard(
        isDark: isDark,
        icon: Icons.star_rate_rounded,
        color: AppTheme.warningAmber,
        label: 'Survey Rating',
        value: '${means['overallMean'] ?? 0} / 5',
        sub: '${counts['evaluationsTotal'] ?? 0} respondent(s)',
        headingColor: headingColor,
        subtleText: subtleText,
        onTap: () => _tabController.animateTo(4),
      ),
    ];

    return RefreshIndicator(
      onRefresh: () => _loadOverview(),
      child: ResponsiveContainer(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (needHelp > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.dangerRed.withAlpha(42)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.dangerRed.withAlpha(170),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sos_rounded,
                      color: AppTheme.dangerRed,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$needHelp Household${needHelp == 1 ? '' : 's'} Requesting Assistance',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.dangerRed,
                            ),
                          ),
                          Text(
                            'Unacknowledged emergency check-ins need DRRM review.',
                            style: TextStyle(fontSize: 12.5, color: subtleText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() => _checkinFilter = 'HELP');
                        _tabController.animateTo(2);
                      },
                      child: const Text('Respond'),
                    ),
                  ],
                ),
              ),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 760) {
                  return Row(
                    children: [
                      Expanded(child: kpiCards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: kpiCards[1]),
                      const SizedBox(width: 12),
                      Expanded(child: kpiCards[2]),
                      const SizedBox(width: 12),
                      Expanded(child: kpiCards[3]),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: kpiCards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: kpiCards[1]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: kpiCards[2]),
                        const SizedBox(width: 10),
                        Expanded(child: kpiCards[3]),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // Quick DRRM Advisory Broadcast Shortcut Strip
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (activeAdvisories > 0
                            ? AppTheme.warningAmber
                            : AppTheme.primaryAccent)
                        .withAlpha(isDark ? 45 : 20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: activeAdvisories > 0
                        ? AppTheme.warningAmber
                        : AppTheme.primaryAccent,
                  ),
                ),
                title: Text(
                  activeAdvisories > 0
                      ? '$activeAdvisories Active Official Advisory Broadcast${activeAdvisories == 1 ? '' : 's'}'
                      : 'Official DRRM Advisories',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: headingColor,
                  ),
                ),
                subtitle: Text(
                  activeAdvisories > 0
                      ? 'Visible right now on every City of Manila household dashboard.'
                      : 'Broadcast flood, typhoon, or shelter announcements to all families.',
                  style: TextStyle(fontSize: 12.5, color: subtleText),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _tabController.animateTo(3),
                  child: Text(activeAdvisories > 0 ? 'Manage' : 'Post Alert'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Synced Households (${households.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                ),
                Text(
                  'Tap a card for triage details',
                  style: TextStyle(fontSize: 12, color: subtleText),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _householdSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search household name or family invite code...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _householdQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _householdSearchCtrl.clear();
                          setState(() => _householdQuery = '');
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _householdQuery = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _sortChip('Lowest Ready', 'LOWEST_READY', headingColor),
                _sortChip('Vulnerable First', 'VULNERABLE', headingColor),
                _sortChip('Most Recent', 'RECENT', headingColor),
                _sortChip('Largest Family', 'LARGEST', headingColor),
              ],
            ),
            const SizedBox(height: 12),
            if (households.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    rawHouseholds.isEmpty
                        ? 'No households have signed in for cloud sync yet. As City of Manila families create accounts and sync their Go-Bag, their readiness progress will appear here.'
                        : 'No households match "$_householdQuery".',
                    style: TextStyle(fontSize: 13.5, color: subtleText),
                  ),
                ),
              )
            else
              ...households.map((h) {
                final readiness = ((h['readinessPct'] ?? 0) as num).toDouble();
                final barColor = readiness >= 80
                    ? AppTheme.safeGreen
                    : (readiness >= 50
                        ? AppTheme.warningAmber
                        : AppTheme.dangerRed);
                final profile =
                    Map<String, dynamic>.from(h['profile'] as Map? ?? {});
                final hasSeniors = ((profile['seniors'] ?? 0) as num) > 0;
                final hasInfants = ((profile['infants'] ?? 0) as num) > 0;
                final hasMed = profile['hasChronicMedicalNeeds'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showHouseholdDetailSheet(
                      h,
                      isDark,
                      headingColor,
                      subtleText,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (h['name'] ?? 'Household').toString(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: barColor.withAlpha(isDark ? 45 : 22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${readiness.toStringAsFixed(0)}% Ready',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: barColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 19,
                                color: subtleText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Code: ${h['inviteCode'] ?? '-'} • Household size: ${h['memberCount'] ?? 2} • ${h['accountCount'] ?? 1} ${(h['accountCount'] ?? 1) == 1 ? 'account' : 'accounts'} • ${h['packedCount'] ?? 0}/${h['itemCount'] ?? 0} packed',
                            style: TextStyle(fontSize: 13, color: subtleText),
                          ),
                          if (hasMed || hasSeniors || hasInfants) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (hasMed)
                                  _infoPill(
                                    'Medical Needs',
                                    AppTheme.dangerRed,
                                    isDark,
                                  ),
                                if (hasSeniors)
                                  _infoPill(
                                    'Seniors (${profile['seniors']})',
                                    AppTheme.warningAmber,
                                    isDark,
                                  ),
                                if (hasInfants)
                                  _infoPill(
                                    'Infants (${profile['infants']})',
                                    AppTheme.dangerRed,
                                    isDark,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (readiness / 100).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? AppTheme.darkElevated
                                  : AppTheme.lightBorder,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, String key, Color headingColor) {
    final selected = _householdSort == key;
    return ChoiceChip(
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: selected,
      selectedColor: AppTheme.primaryNavy,
      labelStyle: TextStyle(color: selected ? Colors.white : headingColor),
      onSelected: (_) => setState(() => _householdSort = key),
    );
  }

  Widget _buildSheltersTab(bool isDark, Color headingColor, Color subtleText) {
    final allShelters = (_overview?['shelters'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final districts = <String>['ALL', ...manilaDistrictFilters.keys];

    final q = _shelterQuery.trim().toLowerCase();
    final shelters = allShelters.where((s) {
      final isOpen = s['isOpen'] == true;
      if (_shelterStatusFilter == 'OPEN' && !isOpen) return false;
      if (_shelterStatusFilter == 'STANDBY' && isOpen) return false;
      final hay =
          '${s['name']} ${s['address']} ${s['city']} ${s['facilities']}'
              .toLowerCase();
      if (_shelterCityFilter != 'ALL') {
        final d = manilaDistrictFilters[_shelterCityFilter];
        if (d != null) {
          if (!d.keywords.any((kw) => hay.contains(kw))) return false;
        } else if ((s['city'] ?? '').toString().trim() != _shelterCityFilter) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      return hay.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadOverview(),
      child: ResponsiveContainer(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'City of Manila Shelters (${shelters.length}/${allShelters.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                        ),
                      ),
                      Text(
                        'Instant Open / Standby switches, full editing, and map pin placement.',
                        style: TextStyle(fontSize: 13, color: subtleText),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Add Shelter'),
                  onPressed: () => _showShelterEditorDialog(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shelterSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search shelter name, address, or facilities...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _shelterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _shelterSearchCtrl.clear();
                          setState(() => _shelterQuery = '');
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _shelterQuery = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  label: const Text('All Status'),
                  selected: _shelterStatusFilter == 'ALL',
                  selectedColor: AppTheme.primaryNavy,
                  labelStyle: TextStyle(
                    color: _shelterStatusFilter == 'ALL'
                        ? Colors.white
                        : headingColor,
                  ),
                  onSelected: (_) =>
                      setState(() => _shelterStatusFilter = 'ALL'),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  label: const Text('Open'),
                  selected: _shelterStatusFilter == 'OPEN',
                  selectedColor: AppTheme.safeGreen,
                  labelStyle: TextStyle(
                    color: _shelterStatusFilter == 'OPEN'
                        ? Colors.white
                        : headingColor,
                  ),
                  onSelected: (_) =>
                      setState(() => _shelterStatusFilter = 'OPEN'),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  label: const Text('Standby'),
                  selected: _shelterStatusFilter == 'STANDBY',
                  selectedColor: AppTheme.dangerRed,
                  labelStyle: TextStyle(
                    color: _shelterStatusFilter == 'STANDBY'
                        ? Colors.white
                        : headingColor,
                  ),
                  onSelected: (_) =>
                      setState(() => _shelterStatusFilter = 'STANDBY'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: districts.map((district) {
                  final sel = _shelterCityFilter == district;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      label: Text(district == 'ALL' ? 'All Manila' : district),
                      selected: sel,
                      selectedColor: Colors.teal.shade700,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: sel ? Colors.white : headingColor,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) =>
                          setState(() => _shelterCityFilter = district),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (shelters.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No shelters match your filter.',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                ),
              )
            else
              ...shelters.map((s) {
                final isOpen = s['isOpen'] == true;
                final isOfficial = s['isOfficial'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isOfficial
                                                  ? AppTheme.primaryAccent
                                                  : AppTheme.warningAmber)
                                              .withAlpha(isDark ? 45 : 22),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isOfficial ? 'Official' : 'Community',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: isOfficial
                                                ? (isDark
                                                    ? Colors.lightBlue.shade200
                                                    : AppTheme.primaryAccent)
                                                : AppTheme.warningAmber,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (s['city'] ?? '').toString(),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: subtleText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (s['name'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: headingColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (s['address'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subtleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Switch(
                                  value: isOpen,
                                  activeTrackColor: AppTheme.safeGreen,
                                  onChanged: (v) => _toggleShelterOpen(s, v),
                                ),
                                Text(
                                  isOpen ? 'OPEN' : 'STANDBY',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isOpen
                                        ? AppTheme.safeGreen
                                        : AppTheme.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Capacity: ${s['capacityPeople'] ?? 0} • Hotline: ${s['contactNumber'] ?? '-'}',
                              style: TextStyle(fontSize: 13, color: subtleText),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text(
                                'Edit Shelter',
                                style: TextStyle(fontSize: 12.5),
                              ),
                              onPressed: () =>
                                  _showShelterEditorDialog(existing: s),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                foregroundColor: AppTheme.dangerRed,
                                side: BorderSide(
                                  color: AppTheme.dangerRed.withAlpha(130),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Remove',
                                style: TextStyle(fontSize: 12.5),
                              ),
                              onPressed: () => _confirmDeleteShelter(s),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinsTab(bool isDark, Color headingColor, Color subtleText) {
    final allCheckins = (_overview?['recentCheckins'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final q = _checkinQuery.trim().toLowerCase();
    final filtered = allCheckins.where((c) {
      final st = (c['status'] ?? '').toString().toUpperCase();
      final isAck = c['acknowledgedAt'] != null;
      if (_checkinFilter == 'HELP') {
        if (!((st.contains('ASSIST') || st.contains('HELP')) && !isAck)) {
          return false;
        }
      } else if (_checkinFilter == 'EVAC') {
        if (!st.contains('EVAC')) return false;
      } else if (_checkinFilter == 'SAFE') {
        if (st != 'SAFE') return false;
      } else if (_checkinFilter == 'ASSISTED') {
        if (!isAck) return false;
      }
      if (q.isEmpty) return true;
      final hay = '${c['authorName']} ${c['householdName']} ${c['note']}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();

    final pendingHelpCount = allCheckins.where((c) {
      final st = (c['status'] ?? '').toString().toUpperCase();
      return c['acknowledgedAt'] == null &&
          (st.contains('ASSIST') || st.contains('HELP'));
    }).length;
    final assistedCount =
        allCheckins.where((c) => c['acknowledgedAt'] != null).length;

    return RefreshIndicator(
      onRefresh: () => _loadOverview(),
      child: ResponsiveContainer(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            TextField(
              controller: _checkinSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by family, resident name, or note...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _checkinQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _checkinSearchCtrl.clear();
                          setState(() => _checkinQuery = '');
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _checkinQuery = v),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  label: Text('All (${allCheckins.length})'),
                  selected: _checkinFilter == 'ALL',
                  selectedColor: AppTheme.primaryNavy,
                  labelStyle: TextStyle(
                    color:
                        _checkinFilter == 'ALL' ? Colors.white : headingColor,
                  ),
                  onSelected: (_) => setState(() => _checkinFilter = 'ALL'),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  label: Text('Need Help ($pendingHelpCount)'),
                  selected: _checkinFilter == 'HELP',
                  selectedColor: AppTheme.dangerRed,
                  labelStyle: TextStyle(
                    color:
                        _checkinFilter == 'HELP' ? Colors.white : headingColor,
                  ),
                  onSelected: (_) => setState(() => _checkinFilter = 'HELP'),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('Evacuating'),
                  selected: _checkinFilter == 'EVAC',
                  selectedColor: AppTheme.warningAmber,
                  labelStyle: TextStyle(
                    color:
                        _checkinFilter == 'EVAC' ? Colors.white : headingColor,
                  ),
                  onSelected: (_) => setState(() => _checkinFilter = 'EVAC'),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('Safe'),
                  selected: _checkinFilter == 'SAFE',
                  selectedColor: AppTheme.safeGreen,
                  labelStyle: TextStyle(
                    color:
                        _checkinFilter == 'SAFE' ? Colors.white : headingColor,
                  ),
                  onSelected: (_) => setState(() => _checkinFilter = 'SAFE'),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  label: Text('Assisted ($assistedCount)'),
                  selected: _checkinFilter == 'ASSISTED',
                  selectedColor: Colors.teal.shade700,
                  labelStyle: TextStyle(
                    color: _checkinFilter == 'ASSISTED'
                        ? Colors.white
                        : headingColor,
                  ),
                  onSelected: (_) =>
                      setState(() => _checkinFilter = 'ASSISTED'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No household check-ins in this category yet.',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                ),
              )
            else
              ...filtered.map((c) {
                final st = (c['status'] ?? 'SAFE').toString().toUpperCase();
                final isSafe = st == 'SAFE';
                final isHelp = st.contains('ASSIST') || st.contains('HELP');
                final isAck = c['acknowledgedAt'] != null;
                final ackBy = (c['acknowledgedBy'] ?? 'DRRM Admin').toString();
                final ackAt =
                    DateTime.tryParse((c['acknowledgedAt'] ?? '').toString());

                final badgeColor = isAck
                    ? Colors.teal.shade700
                    : (isSafe
                        ? AppTheme.safeGreen
                        : (isHelp ? AppTheme.dangerRed : AppTheme.warningAmber));
                final ts = DateTime.tryParse((c['timestamp'] ?? '').toString());
                final hasGps = c['latitude'] != null && c['longitude'] != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: (isHelp && !isAck)
                          ? AppTheme.dangerRed.withAlpha(170)
                          : (isDark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder),
                      width: (isHelp && !isAck) ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: badgeColor.withAlpha(isDark ? 45 : 22),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isAck
                                    ? Icons.verified_rounded
                                    : (isSafe
                                        ? Icons.check_circle_rounded
                                        : (isHelp
                                            ? Icons.sos_rounded
                                            : Icons.directions_run_rounded)),
                                color: badgeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${c['authorName'] ?? 'Member'} • ${c['householdName'] ?? 'Household'}',
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: headingColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor
                                              .withAlpha(isDark ? 45 : 22),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          isAck ? 'ASSISTED ✓' : st,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((c['note'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      (c['note'] ?? '').toString(),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: headingColor,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    '${ts != null ? DateFormat('MMM d, yyyy • h:mm a').format(ts.toLocal()) : ''}${hasGps ? ' • GPS: ${(c['latitude'] as num).toStringAsFixed(4)}, ${(c['longitude'] as num).toStringAsFixed(4)}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtleText,
                                    ),
                                  ),
                                  if (isAck) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Acknowledged by $ackBy${ackAt != null ? ' at ${DateFormat('MMM d, h:mm a').format(ackAt.toLocal())}' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (hasGps)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text(
                                  'Open in Maps',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                                onPressed: () {
                                  final emergency =
                                      context.read<EmergencyProvider>();
                                  ActionFeedback.openMapWithFeedback(
                                    context,
                                    emergency,
                                    (c['latitude'] as num).toDouble(),
                                    (c['longitude'] as num).toDouble(),
                                    '${c['householdName'] ?? 'Household'} (${c['authorName'] ?? 'Member'})',
                                  );
                                },
                              ),
                            if (!isAck)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isHelp
                                      ? AppTheme.safeGreen
                                      : AppTheme.primaryNavy,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.task_alt_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  isHelp ? 'Mark Assisted' : 'Acknowledge',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                                onPressed: () =>
                                    _toggleCheckinAcknowledged(c, true),
                              )
                            else
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.undo_rounded, size: 16),
                                label: const Text(
                                  'Reopen',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                                onPressed: () =>
                                    _toggleCheckinAcknowledged(c, false),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoriesTab(bool isDark, Color headingColor, Color subtleText) {
    final advisories = (_overview?['advisories'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return RefreshIndicator(
      onRefresh: () => _loadOverview(),
      child: ResponsiveContainer(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent
                                .withAlpha(isDark ? 45 : 20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: AppTheme.primaryAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Broadcast Official DRRM Advisory',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: headingColor,
                                ),
                              ),
                              Text(
                                'Active advisories appear immediately on every household Home & Alerts screen.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: subtleText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Quick Manila DRRMO Templates:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: subtleText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.water_drop_outlined,
                            size: 15,
                            color: AppTheme.warningAmber,
                          ),
                          label: const Text(
                            'Flood Watch',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _advisorySeverity = 'warning';
                              _advisoryTitleCtrl.text =
                                  'City of Manila Flood Watch — España, Taft & Paco';
                              _advisoryMsgCtrl.text =
                                  'Heavy rainfall detected over Manila. Monitor low-lying streets, prepare Go-Bags, and move to designated City of Manila evacuation centers if water rises. Manila DRRMO: (02) 8568-6909.';
                              _advisoryAreaCtrl.text = 'City of Manila';
                            });
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.thermostat_rounded,
                            size: 15,
                            color: AppTheme.dangerRed,
                          ),
                          label: const Text(
                            'Heat Index Danger',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _advisorySeverity = 'warning';
                              _advisoryTitleCtrl.text =
                                  'PAGASA Danger Heat Index Advisory (42°C+)';
                              _advisoryMsgCtrl.text =
                                  'Dangerous heat index recorded in the City of Manila. Limit outdoor activity between 10 AM and 4 PM, hydrate frequently, and check on seniors and infants.';
                              _advisoryAreaCtrl.text = 'City of Manila';
                            });
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.roofing_rounded,
                            size: 15,
                            color: Colors.teal.shade700,
                          ),
                          label: const Text(
                            'Shelters Open',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _advisorySeverity = 'critical';
                              _advisoryTitleCtrl.text =
                                  'Manila Evacuation Shelters OPEN — Pre-Emptive Evacuation';
                              _advisoryMsgCtrl.text =
                                  'Official City of Manila evacuation centers (Rizal Memorial, Paco Arena, San Andres, Delpan, Baseco, Dapitan, Patricia) are OPEN. Proceed safely with your Go-Bag. Emergency: (02) 8568-6909 / 911.';
                              _advisoryAreaCtrl.text = 'City of Manila';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          showCheckmark: false,
                          label: const Text('Info'),
                          selected: _advisorySeverity == 'info',
                          selectedColor: AppTheme.primaryAccent,
                          labelStyle: TextStyle(
                            color: _advisorySeverity == 'info'
                                ? Colors.white
                                : headingColor,
                          ),
                          onSelected: (_) =>
                              setState(() => _advisorySeverity = 'info'),
                        ),
                        ChoiceChip(
                          showCheckmark: false,
                          label: const Text('Warning'),
                          selected: _advisorySeverity == 'warning',
                          selectedColor: AppTheme.warningAmber,
                          labelStyle: TextStyle(
                            color: _advisorySeverity == 'warning'
                                ? Colors.white
                                : headingColor,
                          ),
                          onSelected: (_) =>
                              setState(() => _advisorySeverity = 'warning'),
                        ),
                        ChoiceChip(
                          showCheckmark: false,
                          label: const Text('Critical Alert'),
                          selected: _advisorySeverity == 'critical',
                          selectedColor: AppTheme.dangerRed,
                          labelStyle: TextStyle(
                            color: _advisorySeverity == 'critical'
                                ? Colors.white
                                : headingColor,
                          ),
                          onSelected: (_) =>
                              setState(() => _advisorySeverity = 'critical'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _advisoryTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Headline / Title *',
                        hintText:
                            'e.g. City of Manila Flood Watch — Evacuation Shelters OPEN',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _advisoryMsgCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Advisory Details & Instructions *',
                        hintText:
                            'Tell households what is happening and what action to take.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _advisoryAreaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Affected Area (City of Manila)',
                        hintText: 'City of Manila, Ermita / Malate, Paco, Tondo, Sampaloc',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'City of Manila',
                        'Ermita & Malate',
                        'Paco & San Andres',
                        'Tondo & San Nicolas',
                        'Port Area / Baseco',
                        'Sampaloc',
                        'Sta. Ana & Pandacan',
                        'Quiapo / Sta. Cruz',
                        'Intramuros / Binondo',
                      ].map((preset) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            preset,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () =>
                              setState(() => _advisoryAreaCtrl.text = preset),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _advisorySeverity == 'critical'
                              ? AppTheme.dangerRed
                              : (_advisorySeverity == 'warning'
                                  ? AppTheme.warningAmber
                                  : AppTheme.primaryNavy),
                          foregroundColor: Colors.white,
                        ),
                        icon: _isPostingAdvisory
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _isPostingAdvisory
                              ? 'Publishing...'
                              : 'Publish Official Advisory',
                        ),
                        onPressed:
                            _isPostingAdvisory ? null : _publishAdvisory,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Published Advisories (${advisories.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 10),
            if (advisories.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No advisories published yet. Use the form above to broadcast official City of Manila DRRM updates to households.',
                    style: TextStyle(fontSize: 13.5, color: subtleText),
                  ),
                ),
              )
            else
              ...advisories.map((a) {
                final isActive = a['isActive'] == true;
                final sev = (a['severity'] ?? 'warning').toString();
                final sevColor = sev == 'critical'
                    ? AppTheme.dangerRed
                    : (sev == 'info'
                        ? AppTheme.primaryAccent
                        : AppTheme.warningAmber);
                final created =
                    DateTime.tryParse((a['createdAt'] ?? '').toString());

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: sevColor
                                              .withAlpha(isDark ? 45 : 22),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sev.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: sevColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${a['area'] ?? 'City of Manila'}${created != null ? ' • ${DateFormat('MMM d, h:mm a').format(created.toLocal())}' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subtleText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (a['title'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: headingColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (a['message'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: subtleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Switch(
                                  value: isActive,
                                  activeTrackColor: AppTheme.safeGreen,
                                  onChanged: (v) =>
                                      _toggleAdvisoryActive(a, v),
                                ),
                                Text(
                                  isActive ? 'LIVE' : 'RESOLVED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? AppTheme.safeGreen
                                        : subtleText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Posted by ${a['authorName'] ?? 'DRRM Admin'}',
                              style: TextStyle(fontSize: 12, color: subtleText),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.dangerRed,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 17,
                              ),
                              label: const Text('Delete'),
                              onPressed: () => _deleteAdvisory(a),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyTab(bool isDark, Color headingColor, Color subtleText) {
    final evalSummary =
        Map<String, dynamic>.from(_overview?['evaluationSummary'] as Map? ?? {});
    final means = Map<String, dynamic>.from(evalSummary['means'] as Map? ?? {});
    final recent = (evalSummary['recent'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final overallVal = ((means['overallMean'] ?? 0) as num).toDouble();
    final overallInterp = _likertInterpretation(overallVal);

    return RefreshIndicator(
      onRefresh: () => _loadOverview(),
      child: ResponsiveContainer(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ISO/IEC 25010 Evaluation Results',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                            Text(
                              'Total Respondents: ${evalSummary['totalRespondents'] ?? 0} • Avg Kit Readiness: ${means['averageReadinessPct'] ?? 0}%',
                              style: TextStyle(fontSize: 13, color: subtleText),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              label: const Text('Copy CSV'),
                              onPressed: _copyCsv,
                            ),
                            FilledButton.icon(
                              icon:
                                  const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Download .csv'),
                              onPressed: _downloadCsvFile,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    _scoreBar(
                      '1. Functionality',
                      means['functionality'],
                      isDark,
                      headingColor,
                    ),
                    _scoreBar(
                      '2. Usability',
                      means['usability'],
                      isDark,
                      headingColor,
                    ),
                    _scoreBar(
                      '3. Offline Reliability',
                      means['offlineReliability'],
                      isDark,
                      headingColor,
                    ),
                    _scoreBar(
                      '4. Preparedness Effectiveness',
                      means['effectiveness'],
                      isDark,
                      headingColor,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withAlpha(isDark ? 70 : 14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overall Weighted Mean',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Verbal Interpretation: ${overallInterp.label}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: overallInterp.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${overallVal.toStringAsFixed(2)} / 5.00',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.lightBlue.shade200
                                  : AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '5-Point Likert Scale: 4.50–5.00 Highly Acceptable • 3.50–4.49 Acceptable • 2.50–3.49 Moderately Acceptable • 1.50–2.49 Fairly Acceptable • 1.00–1.49 Needs Improvement',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subtleText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Respondent Submissions (${recent.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No survey responses submitted yet.',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                ),
              )
            else
              ...recent.map((r) {
                final mean = ((((r['functionalityScore'] ?? 0) as num) +
                            ((r['usabilityScore'] ?? 0) as num) +
                            ((r['reliabilityScore'] ?? 0) as num) +
                            ((r['effectivenessScore'] ?? 0) as num)) /
                        4.0)
                    .toStringAsFixed(2);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      '${r['respondentLabel'] ?? 'Anonymous'} (${r['platform'] ?? 'web'})',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: headingColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'F:${r['functionalityScore']} • U:${r['usabilityScore']} • R:${r['reliabilityScore']} • E:${r['effectivenessScore']} • Kit: ${r['readinessPercentage']}%',
                          style: TextStyle(fontSize: 12.5, color: subtleText),
                        ),
                        if ((r['comments'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '"${r['comments']}"',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: headingColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.safeGreen.withAlpha(isDark ? 45 : 20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$mean/5',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.safeGreen,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(String label, dynamic val, bool isDark, Color headingColor) {
    final score = ((val ?? 0) as num).toDouble();
    final interp = _likertInterpretation(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: interp.color.withAlpha(isDark ? 45 : 20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  interp.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: interp.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${score.toStringAsFixed(2)} / 5.00',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (score / 5.0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor:
                  isDark ? AppTheme.darkElevated : AppTheme.lightBorder,
              color: score > 0 ? interp.color : AppTheme.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
    required Color headingColor,
    required Color subtleText,
    VoidCallback? onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 45 : 20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: subtleText.withAlpha(160),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: headingColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: subtleText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
