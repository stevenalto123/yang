import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disaster_protocol.dart';

class SeismicEvent {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double depthKm;

  const SeismicEvent({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.depthKm,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'magnitude': magnitude,
        'place': place,
        'time': time.toIso8601String(),
        'depthKm': depthKm,
      };

  factory SeismicEvent.fromMap(Map<String, dynamic> map) {
    return SeismicEvent(
      id: map['id'] ?? '',
      magnitude: (map['magnitude'] ?? 0).toDouble(),
      place: map['place'] ?? 'Philippines Region',
      time: DateTime.tryParse(map['time'] ?? '') ?? DateTime.now(),
      depthKm: (map['depthKm'] ?? 10).toDouble(),
    );
  }
}

class WeatherSnapshot {
  final double temperatureC;
  final double windSpeedKmh;
  final double precipitationMm;
  final int weatherCode;
  final String conditionText;

  const WeatherSnapshot({
    required this.temperatureC,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.weatherCode,
    required this.conditionText,
  });

  Map<String, dynamic> toMap() => {
        'temperatureC': temperatureC,
        'windSpeedKmh': windSpeedKmh,
        'precipitationMm': precipitationMm,
        'weatherCode': weatherCode,
        'conditionText': conditionText,
      };

  factory WeatherSnapshot.fromMap(Map<String, dynamic> map) {
    return WeatherSnapshot(
      temperatureC: (map['temperatureC'] ?? 30).toDouble(),
      windSpeedKmh: (map['windSpeedKmh'] ?? 12).toDouble(),
      precipitationMm: (map['precipitationMm'] ?? 0).toDouble(),
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
      area: (map['area'] ?? 'Metro Manila').toString(),
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

  bool get isHazardActive {
    if (_drillMode != DrillAlertMode.liveNormal) return true;
    if (_advisories.any((a) => a.severity == 'critical' || a.severity == 'warning')) {
      return true;
    }
    if (_weather != null &&
        (_weather!.windSpeedKmh >= 60 || _weather!.precipitationMm >= 15)) {
      return true;
    }
    if (_earthquakes.any((q) => q.magnitude >= 5.5)) return true;
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
      return isFil ? 'Opisyal na Kritikal na Abiso (DRRM)' : 'Official Critical DRRM Advisory';
    }
    if (_advisories.any((a) => a.severity == 'warning')) {
      return isFil ? 'Opisyal na Babala (DRRM)' : 'Official DRRM Warning';
    }
    if (_weather != null &&
        (_weather!.windSpeedKmh >= 60 || _weather!.precipitationMm >= 15)) {
      return isFil ? 'Babala sa Masamang Panahon' : 'Weather Advisory';
    }
    if (_earthquakes.any((q) => q.magnitude >= 5.5)) {
      return isFil ? 'Malakas na Lindol Naitala' : 'Recent Strong Earthquake';
    }
    return isFil ? 'Walang Aktibong Alerto' : 'All Clear • No Active Alerts';
  }

  String get currentThreatLevel {
    if (_drillMode == DrillAlertMode.earthquakeAlert) return 'CRITICAL ALERT';
    if (_drillMode == DrillAlertMode.typhoonSignal3) return 'HIGH ALERT (TCWS #3)';
    if (_drillMode == DrillAlertMode.floodRedWarning) return 'RED RAINFALL WARNING';

    if (_weather != null && (_weather!.windSpeedKmh >= 60 || _weather!.precipitationMm >= 15)) {
      return 'ELEVATED WEATHER ADVISORY';
    }
    if (_earthquakes.any((q) => q.magnitude >= 5.5)) {
      return 'SIGNIFICANT SEISMIC ACTIVITY';
    }
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
    // Attempt silent live fetch without blocking UI
    refreshLiveFeeds();
  }

  Future<void> refreshLiveFeeds({double? lat, double? lng}) async {
    if (lat != null) _lastLat = lat;
    if (lng != null) _lastLng = lng;

    _isRefreshing = true;
    notifyListeners();

    bool anySuccess = false;

    // 0. Fetch active official DRRM advisories immediately (never stale-cached)
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

    // 1. Direct Open-Meteo weather fallback for current coordinates
    if (!anySuccess) {
      try {
        final weatherUri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$_lastLat&longitude=$_lastLng&current=temperature_2m,precipitation,wind_speed_10m,weather_code&timezone=Asia%2FManila',
        );
        final resp =
            await http.get(weatherUri).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final current = data['current'];
          if (current != null) {
            final code = (current['weather_code'] ?? 0) as int;
            _weather = WeatherSnapshot(
              temperatureC: (current['temperature_2m'] ?? 29.0).toDouble(),
              windSpeedKmh: (current['wind_speed_10m'] ?? 10.0).toDouble(),
              precipitationMm: (current['precipitation'] ?? 0.0).toDouble(),
              weatherCode: code,
              conditionText: _decodeWmoWeather(code),
            );
            anySuccess = true;
          }
        }
      } catch (_) {}

      // 2. Direct Philippine Earthquakes via USGS GeoJSON Feed
      try {
        final quakeUri = Uri.parse(
          'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=4.5&maxlatitude=21.5&minlongitude=116.0&maxlongitude=127.0&limit=5&orderby=time',
        );
        final resp =
            await http.get(quakeUri).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final features = (data['features'] as List<dynamic>?) ?? [];
          _earthquakes = features.map((f) {
            final props = f['properties'] ?? {};
            final geom = f['geometry'] ?? {};
            final coords =
                (geom['coordinates'] as List<dynamic>?) ?? [0, 0, 10];
            final ms =
                (props['time'] ?? DateTime.now().millisecondsSinceEpoch) as int;
            return SeismicEvent(
              id: (f['id'] ?? '').toString(),
              magnitude: (props['mag'] ?? 0.0).toDouble(),
              place: (props['place'] ?? 'Philippines').toString(),
              time: DateTime.fromMillisecondsSinceEpoch(ms),
              depthKm:
                  coords.length > 2 ? (coords[2] ?? 10.0).toDouble() : 10.0,
            );
          }).toList();
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
      // Seed baseline offline reference snapshot if never fetched before
      _weather = const WeatherSnapshot(
        temperatureC: 30.0,
        windSpeedKmh: 14.0,
        precipitationMm: 0.0,
        weatherCode: 2,
        conditionText: 'Partly Cloudy (Offline Reference)',
      );
      _earthquakes = [
        SeismicEvent(
          id: 'offline_ref_1',
          magnitude: 3.4,
          place: 'Metro Manila / West Valley Fault Baseline Monitor',
          time: DateTime.now().subtract(const Duration(hours: 6)),
          depthKm: 12.0,
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
    final existingKeys = _safetyLog
        .map((e) => '${e['timestamp']}_${e['status']}_${e['note']}')
        .toSet();
    final combined = List<Map<String, String>>.from(_safetyLog);
    for (final r in remote) {
      final entry = <String, String>{
        'status': (r['status'] ?? 'SAFE').toString(),
        'note': (r['note'] ?? '').toString(),
        'authorName': (r['authorName'] ?? 'Family').toString(),
        'timestamp': (r['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
      };
      final key = '${entry['timestamp']}_${entry['status']}_${entry['note']}';
      if (!existingKeys.contains(key)) {
        existingKeys.add(key);
        combined.add(entry);
      }
    }
    combined.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
    _safetyLog = combined.take(20).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_checkInLogKey, json.encode(_safetyLog));
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
