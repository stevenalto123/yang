import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disaster_protocol.dart';
import '../utils/location_service.dart';

class SeismicEvent {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double depthKm;
  final double? latitude;
  final double? longitude;

  const SeismicEvent({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.depthKm,
    this.latitude,
    this.longitude,
  });

  double? distanceFromManilaKm() {
    if (latitude == null || longitude == null) return null;
    return LocationService.distanceInKm(14.5822, 120.9882, latitude!, longitude!);
  }

  String? bearingFromManila() {
    if (latitude == null || longitude == null) return null;
    return LocationService.bearingTo(14.5822, 120.9882, latitude!, longitude!)
        .cardinal;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'magnitude': magnitude,
        'place': place,
        'time': time.toIso8601String(),
        'depthKm': depthKm,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory SeismicEvent.fromMap(Map<String, dynamic> map) {
    return SeismicEvent(
      id: map['id'] ?? '',
      magnitude: (map['magnitude'] ?? 0).toDouble(),
      place: map['place'] ?? 'Philippines Region',
      time: DateTime.tryParse(map['time'] ?? '') ?? DateTime.now(),
      depthKm: (map['depthKm'] ?? 10).toDouble(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}

class WeatherSnapshot {
  final double temperatureC;
  final double apparentTemperatureC;
  final int humidityPct;
  final double windSpeedKmh;
  final double precipitationMm;
  final int rainChance6hPct;
  final double rainExpected6hMm;
  final int weatherCode;
  final String conditionText;

  const WeatherSnapshot({
    required this.temperatureC,
    double? apparentTemperatureC,
    this.humidityPct = 70,
    required this.windSpeedKmh,
    required this.precipitationMm,
    this.rainChance6hPct = 0,
    this.rainExpected6hMm = 0.0,
    required this.weatherCode,
    required this.conditionText,
  }) : apparentTemperatureC = apparentTemperatureC ?? temperatureC;

  Map<String, dynamic> toMap() => {
        'temperatureC': temperatureC,
        'apparentTemperatureC': apparentTemperatureC,
        'humidityPct': humidityPct,
        'windSpeedKmh': windSpeedKmh,
        'precipitationMm': precipitationMm,
        'rainChance6hPct': rainChance6hPct,
        'rainExpected6hMm': rainExpected6hMm,
        'weatherCode': weatherCode,
        'conditionText': conditionText,
      };

  factory WeatherSnapshot.fromMap(Map<String, dynamic> map) {
    final temp = (map['temperatureC'] ?? 30).toDouble();
    return WeatherSnapshot(
      temperatureC: temp,
      apparentTemperatureC:
          (map['apparentTemperatureC'] as num?)?.toDouble() ?? temp,
      humidityPct: (map['humidityPct'] as num?)?.round() ?? 70,
      windSpeedKmh: (map['windSpeedKmh'] ?? 12).toDouble(),
      precipitationMm: (map['precipitationMm'] ?? 0).toDouble(),
      rainChance6hPct: (map['rainChance6hPct'] as num?)?.round() ?? 0,
      rainExpected6hMm: (map['rainExpected6hMm'] as num?)?.toDouble() ?? 0.0,
      weatherCode: map['weatherCode'] ?? 0,
      conditionText: map['conditionText'] ?? 'Partly Cloudy',
    );
  }
}

enum DrillAlertMode {
  liveNormal,
  typhoonSignal3,
  earthquakeAlert,
  floodRedWarning,
}

extension DrillAlertModeExt on DrillAlertMode {
  String get label {
    switch (this) {
      case DrillAlertMode.liveNormal:
        return 'Live Monitoring (Normal)';
      case DrillAlertMode.typhoonSignal3:
        return 'Typhoon Signal #3';
      case DrillAlertMode.earthquakeAlert:
        return 'Earthquake (M6.2)';
      case DrillAlertMode.floodRedWarning:
        return 'Red Flood Warning';
    }
  }

  DisasterType? get linkedDisaster {
    switch (this) {
      case DrillAlertMode.liveNormal:
        return null;
      case DrillAlertMode.typhoonSignal3:
        return DisasterType.typhoon;
      case DrillAlertMode.earthquakeAlert:
        return DisasterType.earthquake;
      case DrillAlertMode.floodRedWarning:
        return DisasterType.flood;
    }
  }
}

class DrrmAdvisory {
  final String id;
  final String title;
  final String message;
  final String severity; // 'info' | 'warning' | 'critical'
  final String area;
  final String authorName;
  final DateTime createdAt;

  const DrrmAdvisory({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.area,
    required this.authorName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'severity': severity,
        'area': area,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DrrmAdvisory.fromMap(Map<String, dynamic> map) {
    return DrrmAdvisory(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? 'DRRM Advisory').toString(),
      message: (map['message'] ?? '').toString(),
      severity: (map['severity'] ?? 'warning').toString().toLowerCase(),
      area: (map['area'] ?? 'City of Manila').toString(),
      authorName: (map['authorName'] ?? 'DRRM Admin').toString(),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class MonitoringProvider extends ChangeNotifier {
  static const String _cacheKey = 'lifecheckpoint_monitoring_cache_v1';
  static const String _checkInLogKey = 'lifecheckpoint_safety_log_v1';

  bool _isRefreshing = false;
  bool _isOfflineMode = false;
  DateTime? _lastUpdated;
  WeatherSnapshot? _weather;
  List<SeismicEvent> _earthquakes = [];
  List<DrrmAdvisory> _advisories = [];
  DrillAlertMode _drillMode = DrillAlertMode.liveNormal;
  List<Map<String, String>> _safetyLog = [];
  double _lastLat = 14.5822;
  double _lastLng = 120.9882;

  Future<Map<String, dynamic>?> Function(double lat, double lng)?
      telemetryProxyFetcher;
  Future<List<Map<String, dynamic>>> Function()? advisoriesFetcher;
  void Function(Map<String, dynamic> checkin)? onCheckinAdded;

  MonitoringProvider() {
    _loadCachedData();
  }

  bool get isRefreshing => _isRefreshing;
  bool get isOfflineMode => _isOfflineMode;
  DateTime? get lastUpdated => _lastUpdated;
  WeatherSnapshot? get weather => _weather;
  List<SeismicEvent> get earthquakes => List.unmodifiable(_earthquakes);
  List<DrrmAdvisory> get advisories => List.unmodifiable(_advisories);
  DrillAlertMode get drillMode => _drillMode;
  List<Map<String, String>> get safetyLog => List.unmodifiable(_safetyLog);

  bool _hasSignificantManilaQuake() {
    return _earthquakes.any((q) {
      final dist = q.distanceFromManilaKm();
      if (dist != null) {
        return (q.magnitude >= 5.5 && dist <= 350) || q.magnitude >= 6.5;
      }
      return q.magnitude >= 5.8;
    });
  }

  bool get isHeatDanger =>
      _weather != null && _weather!.apparentTemperatureC >= 42.0;

  bool get isFloodRiskElevated {
    if (_drillMode == DrillAlertMode.floodRedWarning ||
        _drillMode == DrillAlertMode.typhoonSignal3) {
      return true;
    }
    if (_weather == null) return false;
    return _weather!.precipitationMm >= 5.0 ||
        _weather!.rainExpected6hMm >= 15.0 ||
        _weather!.rainChance6hPct >= 75;
  }

  bool get isHazardActive {
    if (_drillMode != DrillAlertMode.liveNormal) return true;
    if (_advisories
        .any((a) => a.severity == 'critical' || a.severity == 'warning')) {
      return true;
    }
    if (_weather != null &&
        (_weather!.windSpeedKmh >= 60 ||
            _weather!.precipitationMm >= 15 ||
            _weather!.apparentTemperatureC >= 42)) {
      return true;
    }
    if (_hasSignificantManilaQuake()) return true;
    return false;
  }

  String friendlyStatusLabel(bool isFil) {
    if (_drillMode == DrillAlertMode.earthquakeAlert) {
      return isFil ? 'Practice: Alerto sa Lindol' : 'Practice: Earthquake Alert';
    }
    if (_drillMode == DrillAlertMode.typhoonSignal3) {
      return isFil ? 'Practice: Bagyo Signal #3' : 'Practice: Typhoon Signal #3';
    }
    if (_drillMode == DrillAlertMode.floodRedWarning) {
      return isFil ? 'Practice: Red Flood Warning' : 'Practice: Red Flood Warning';
    }
    if (_advisories.any((a) => a.severity == 'critical')) {
      return isFil
          ? 'Opisyal na Kritikal na Abiso (Manila DRRMO)'
          : 'Official Critical DRRM Advisory';
    }
    if (_advisories.any((a) => a.severity == 'warning')) {
      return isFil
          ? 'Opisyal na Babala (Manila DRRMO)'
          : 'Official Manila DRRMO Warning';
    }
    if (_weather != null &&
        (_weather!.windSpeedKmh >= 60 || _weather!.precipitationMm >= 15)) {
      return isFil ? 'Babala sa Masamang Panahon' : 'Heavy Weather Advisory';
    }
    if (isHeatDanger) {
      return isFil
          ? 'Babala sa Matinding Init (Heat Index)'
          : 'PAGASA Danger Heat Index Advisory';
    }
    if (_hasSignificantManilaQuake()) {
      return isFil
          ? 'Malakas na Lindol Malapit sa Maynila'
          : 'Strong Earthquake Near Manila';
    }
    return isFil ? 'Walang Aktibong Alerto' : 'All Clear • No Active Alerts';
  }

  String get currentThreatLevel {
    if (_drillMode == DrillAlertMode.earthquakeAlert) return 'CRITICAL ALERT';
    if (_drillMode == DrillAlertMode.typhoonSignal3) return 'HIGH ALERT (TCWS #3)';
    if (_drillMode == DrillAlertMode.floodRedWarning) return 'RED RAINFALL WARNING';

    if (_weather != null &&
        (_weather!.windSpeedKmh >= 60 || _weather!.precipitationMm >= 15)) {
      return 'ELEVATED WEATHER ADVISORY';
    }
    if (isHeatDanger) return 'DANGER HEAT INDEX';
    if (_hasSignificantManilaQuake()) return 'SIGNIFICANT SEISMIC ACTIVITY';
    return 'All Clear';
  }

  void setDrillMode(DrillAlertMode mode) {
    _drillMode = mode;
    notifyListeners();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_cacheKey);
      if (cacheStr != null && cacheStr.isNotEmpty) {
        final map = json.decode(cacheStr) as Map<String, dynamic>;
        _lastUpdated = DateTime.tryParse(map['lastUpdated'] ?? '');
        if (map['weather'] != null) {
          _weather = WeatherSnapshot.fromMap(map['weather']);
        }
        if (map['earthquakes'] != null) {
          _earthquakes = (map['earthquakes'] as List<dynamic>)
              .map((e) => SeismicEvent.fromMap(e))
              .toList();
        }
        if (map['advisories'] is List) {
          _advisories = (map['advisories'] as List<dynamic>)
              .map((e) => DrrmAdvisory.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      final logStr = prefs.getString(_checkInLogKey);
      if (logStr != null && logStr.isNotEmpty) {
        final decoded = json.decode(logStr) as List<dynamic>;
        _safetyLog = decoded.map((e) => Map<String, String>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Failed loading monitoring cache: $e');
    }
    notifyListeners();
    refreshLiveFeeds();
  }

  Future<void> refreshLiveFeeds({double? lat, double? lng}) async {
    if (lat != null) _lastLat = lat;
    if (lng != null) _lastLng = lng;

    _isRefreshing = true;
    notifyListeners();

    bool anySuccess = false;

    // 0. Fetch active official Manila DRRMO advisories immediately
    await refreshAdvisoriesOnly(notify: false);

    // 1. Try low-bandwidth cached backend proxy first when configured
    if (telemetryProxyFetcher != null) {
      try {
        final proxyData = await telemetryProxyFetcher!(_lastLat, _lastLng);
        if (proxyData != null) {
          if (proxyData['weather'] is Map) {
            _weather = WeatherSnapshot.fromMap(
              Map<String, dynamic>.from(proxyData['weather']),
            );
            anySuccess = true;
          }
          if (proxyData['earthquakes'] is List) {
            _earthquakes = (proxyData['earthquakes'] as List<dynamic>)
                .map((e) => SeismicEvent.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            anySuccess = true;
          }
        }
      } catch (_) {}
    }

    // 2. Direct Open-Meteo weather + Heat Index + 6h Rain Risk fallback
    if (!anySuccess) {
      try {
        final weatherUri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$_lastLat&longitude=$_lastLng&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,wind_speed_10m,weather_code&hourly=precipitation_probability,precipitation&forecast_hours=6&timezone=Asia%2FManila',
        );
        final resp =
            await http.get(weatherUri).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final current = data['current'];
          final hourly = data['hourly'];
          if (current != null) {
            final code = (current['weather_code'] ?? 0) as int;
            final tempC = (current['temperature_2m'] ?? 29.0).toDouble();
            int maxProb = 0;
            double sumRain = 0.0;
            if (hourly is Map) {
              final probs = (hourly['precipitation_probability'] as List?) ?? [];
              for (final p in probs) {
                final v = (p as num?)?.round() ?? 0;
                if (v > maxProb) maxProb = v;
              }
              final rains = (hourly['precipitation'] as List?) ?? [];
              for (final r in rains) {
                sumRain += (r as num?)?.toDouble() ?? 0.0;
              }
            }
            _weather = WeatherSnapshot(
              temperatureC: tempC,
              apparentTemperatureC:
                  (current['apparent_temperature'] as num?)?.toDouble() ?? tempC,
              humidityPct:
                  (current['relative_humidity_2m'] as num?)?.round() ?? 70,
              windSpeedKmh: (current['wind_speed_10m'] ?? 10.0).toDouble(),
              precipitationMm: (current['precipitation'] ?? 0.0).toDouble(),
              rainChance6hPct: maxProb,
              rainExpected6hMm: double.parse(sumRain.toStringAsFixed(1)),
              weatherCode: code,
              conditionText: _decodeWmoWeather(code),
            );
            anySuccess = true;
          }
        }
      } catch (_) {}

      // 3. Direct USGS Earthquakes (Prioritize Luzon / Manila bounding box)
      try {
        Future<List<SeismicEvent>> fetchQuakes(String url) async {
          final resp =
              await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
          if (resp.statusCode != 200) return [];
          final data = json.decode(resp.body);
          final features = (data['features'] as List<dynamic>?) ?? [];
          return features.map((f) {
            final props = f['properties'] ?? {};
            final geom = f['geometry'] ?? {};
            final coords =
                (geom['coordinates'] as List<dynamic>?) ?? [120.9882, 14.5822, 10];
            final ms =
                (props['time'] ?? DateTime.now().millisecondsSinceEpoch) as int;
            return SeismicEvent(
              id: (f['id'] ?? '').toString(),
              magnitude: (props['mag'] ?? 0.0).toDouble(),
              place: (props['place'] ?? 'Philippines').toString(),
              time: DateTime.fromMillisecondsSinceEpoch(ms),
              depthKm:
                  coords.length > 2 ? (coords[2] ?? 10.0).toDouble() : 10.0,
              longitude:
                  coords.isNotEmpty ? (coords[0] as num?)?.toDouble() : null,
              latitude:
                  coords.length > 1 ? (coords[1] as num?)?.toDouble() : null,
            );
          }).toList();
        }

        var quakes = await fetchQuakes(
          'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=11.5&maxlatitude=18.8&minlongitude=118.5&maxlongitude=124.5&limit=6&orderby=time',
        );
        if (quakes.isEmpty) {
          quakes = await fetchQuakes(
            'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=4.5&maxlatitude=21.5&minlongitude=116.0&maxlongitude=127.0&limit=5&orderby=time',
          );
        }
        if (quakes.isNotEmpty) {
          _earthquakes = quakes;
          anySuccess = true;
        }
      } catch (_) {}
    }

    _isRefreshing = false;
    _isOfflineMode = !anySuccess;
    if (anySuccess) {
      _lastUpdated = DateTime.now();
      await _saveCache();
    } else if (_weather == null && _earthquakes.isEmpty) {
      _weather = const WeatherSnapshot(
        temperatureC: 30.0,
        apparentTemperatureC: 34.0,
        humidityPct: 72,
        windSpeedKmh: 14.0,
        precipitationMm: 0.0,
        rainChance6hPct: 20,
        rainExpected6hMm: 0.0,
        weatherCode: 2,
        conditionText: 'Partly Cloudy (Offline Reference)',
      );
      _earthquakes = [
        SeismicEvent(
          id: 'offline_ref_1',
          magnitude: 3.4,
          place: 'City of Manila / West Valley Fault Baseline Monitor',
          time: DateTime.now().subtract(const Duration(hours: 6)),
          depthKm: 12.0,
          latitude: 14.5822,
          longitude: 120.9882,
        ),
      ];
    }

    notifyListeners();
  }

  Future<void> refreshAdvisoriesOnly({bool notify = true}) async {
    if (advisoriesFetcher == null) return;
    try {
      final raw = await advisoriesFetcher!();
      _advisories = raw.map(DrrmAdvisory.fromMap).toList();
      await _saveCache();
      if (notify) notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = json.encode({
        'lastUpdated': _lastUpdated?.toIso8601String(),
        'weather': _weather?.toMap(),
        'earthquakes': _earthquakes.map((e) => e.toMap()).toList(),
        'advisories': _advisories.map((a) => a.toMap()).toList(),
      });
      await prefs.setString(_cacheKey, payload);
    } catch (_) {}
  }

  Future<void> addSafetyCheckIn(
    String status,
    String note, {
    double? latitude,
    double? longitude,
    String authorName = 'Household Member',
  }) async {
    final ts = DateTime.now().toIso8601String();
    _safetyLog.insert(0, {
      'status': status,
      'note': note,
      'authorName': authorName,
      'timestamp': ts,
    });
    if (_safetyLog.length > 20) {
      _safetyLog = _safetyLog.sublist(0, 20);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_checkInLogKey, json.encode(_safetyLog));
    } catch (_) {}

    onCheckinAdded?.call({
      'status': status,
      'note': note,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  Future<void> applyRemoteCheckins(List<Map<String, dynamic>> remote) async {
    if (remote.isEmpty) return;
    final combined = List<Map<String, String>>.from(_safetyLog);
    for (final r in remote) {
      final entry = <String, String>{
        if (r['id'] != null) 'id': r['id'].toString(),
        'status': (r['status'] ?? 'SAFE').toString(),
        'note': (r['note'] ?? '').toString(),
        'authorName': (r['authorName'] ?? 'Family').toString(),
        'timestamp':
            (r['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
        if (r['acknowledgedAt'] != null)
          'acknowledgedAt': r['acknowledgedAt'].toString(),
        if (r['acknowledgedBy'] != null)
          'acknowledgedBy': r['acknowledgedBy'].toString(),
      };

      final rTime = DateTime.tryParse(entry['timestamp'] ?? '');
      final matchIdx = combined.indexWhere((existing) {
        if (entry['id'] != null &&
            existing['id'] != null &&
            existing['id'] == entry['id']) {
          return true;
        }
        if (existing['status'] == entry['status'] &&
            existing['note'] == entry['note']) {
          if (existing['timestamp'] == entry['timestamp']) return true;
          final eTime = DateTime.tryParse(existing['timestamp'] ?? '');
          if (eTime != null &&
              rTime != null &&
              eTime.difference(rTime).abs().inMinutes <= 2) {
            return true;
          }
        }
        return false;
      });

      if (matchIdx != -1) {
        combined[matchIdx] = entry;
      } else {
        combined.add(entry);
      }
    }
    combined
        .sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
    _safetyLog = combined.take(20).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_checkInLogKey, json.encode(_safetyLog));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearLocalSafetyLog() async {
    _safetyLog = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_checkInLogKey);
    } catch (_) {}
    notifyListeners();
  }

  String _decodeWmoWeather(int code) {
    if (code == 0) return 'Clear Sky';
    if (code <= 3) return 'Partly Cloudy / Overcast';
    if (code <= 48) return 'Fog / Haze';
    if (code <= 57) return 'Light Drizzle';
    if (code <= 67) return 'Moderate to Heavy Rain';
    if (code <= 82) return 'Heavy Rain Showers';
    if (code >= 95) return 'Thunderstorm / Squall';
    return 'Active Weather';
  }
}
