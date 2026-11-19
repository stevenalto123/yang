import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/offline_sync_queue.dart';

class AuthProvider extends ChangeNotifier {
  static const String _sessionKey = 'lifecheckpoint_auth_session_v1';
  static const String _apiUrlKey = 'lifecheckpoint_api_url_v1';

  final ApiClient _api = ApiClient();
  final OfflineSyncQueue _queue = OfflineSyncQueue();

  String? _token;
  String? _userId;
  String? _email;
  String? _fullName;
  String _role = 'household';
  String? _householdId;
  String? _householdName;
  String? _inviteCode;
  String _customServerUrl = '';

  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  String? _lastSyncError;

  Map<String, dynamic> Function()? _kitPayloadReader;
  Future<void> Function(
    List<Map<String, dynamic>> items,
    Map<String, dynamic>? profile,
    int? expiryAlertDays,
  )? _kitBundleApplier;
  Future<void> Function(Map<String, dynamic> plan)? _planApplier;
  Future<void> Function(List<Map<String, dynamic>> shelters)? _sheltersApplier;
  Future<void> Function(List<Map<String, dynamic>> checkins)? _checkinsApplier;

  AuthProvider() {
    _init();
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  bool get hasCloudEndpoint => _api.hasEndpoint;
  String? get resolvedApiBaseUrl => ApiConfig.resolveBaseUrl(_customServerUrl);
  String get customServerUrl => _customServerUrl;

  String? get userId => _userId;
  String? get email => _email;
  String? get fullName => _fullName;
  String get role => _role;
  String? get householdId => _householdId;
  String? get householdName => _householdName;
  String? get inviteCode => _inviteCode;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastSyncError => _lastSyncError;
  int get pendingSyncCount => _queue.length;

  void attachSyncHandlers({
    required Map<String, dynamic> Function() kitPayloadReader,
    required Future<void> Function(
      List<Map<String, dynamic>> items,
      Map<String, dynamic>? profile,
      int? expiryAlertDays,
    ) kitBundleApplier,
    required Future<void> Function(Map<String, dynamic> plan) planApplier,
    required Future<void> Function(List<Map<String, dynamic>> shelters)
        sheltersApplier,
    required Future<void> Function(List<Map<String, dynamic>> checkins)
        checkinsApplier,
  }) {
    _kitPayloadReader = kitPayloadReader;
    _kitBundleApplier = kitBundleApplier;
    _planApplier = planApplier;
    _sheltersApplier = sheltersApplier;
    _checkinsApplier = checkinsApplier;
  }

  Future<void> _init() async {
    await _queue.load();
    try {
      final prefs = await SharedPreferences.getInstance();
      _customServerUrl = prefs.getString(_apiUrlKey) ?? '';
      _api.runtimeBaseUrlOverride = _customServerUrl;

      final raw = prefs.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final map = json.decode(raw) as Map<String, dynamic>;
        _token = map['token'] as String?;
        _userId = map['userId'] as String?;
        _email = map['email'] as String?;
        _fullName = map['fullName'] as String?;
        _role = (map['role'] ?? 'household').toString();
        _householdId = map['householdId'] as String?;
        _householdName = map['householdName'] as String?;
        _inviteCode = map['inviteCode'] as String?;
        final syncedStr = map['lastSyncedAt'] as String?;
        if (syncedStr != null) _lastSyncedAt = DateTime.tryParse(syncedStr);
      }
    } catch (_) {}
    notifyListeners();

    if (isAuthenticated && hasCloudEndpoint) {
      syncNow(pushLocalKitFirst: false);
    }
  }

  Future<void> setCustomServerUrl(String url) async {
    _customServerUrl = url.trim();
    _api.runtimeBaseUrlOverride = _customServerUrl;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_customServerUrl.isEmpty) {
        await prefs.remove(_apiUrlKey);
      } else {
        await prefs.setString(_apiUrlKey, _customServerUrl);
      }
    } catch (_) {}
  }

  Future<({bool ok, String? error})> register({
    required String email,
    required String password,
    required String fullName,
    String householdName = '',
    String inviteCode = '',
    String adminCode = '',
  }) async {
    final res = await _api.request(
      'POST',
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        if (householdName.trim().isNotEmpty) 'householdName': householdName.trim(),
        if (inviteCode.trim().isNotEmpty) 'inviteCode': inviteCode.trim().toUpperCase(),
        if (adminCode.trim().isNotEmpty) 'adminCode': adminCode.trim(),
      },
    );

    if (!res.ok || res.data == null) {
      return (ok: false, error: res.error ?? 'Registration failed.');
    }

    await _applyAuthPayload(res.data!);
    final joinedExisting = inviteCode.trim().isNotEmpty;
    await syncNow(pushLocalKitFirst: !joinedExisting);
    return (ok: true, error: null);
  }

  Future<({bool ok, String? error})> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.request(
      'POST',
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (!res.ok || res.data == null) {
      return (ok: false, error: res.error ?? 'Sign in failed.');
    }

    await _applyAuthPayload(res.data!);
    await syncNow(pushLocalKitFirst: false);
    return (ok: true, error: null);
  }

  Future<({bool ok, String? error})> joinHousehold(String code) async {
    if (!isAuthenticated) {
      return (ok: false, error: 'Sign in first to join a family household.');
    }
    final res = await _api.request(
      'POST',
      '/households/join',
      token: _token,
      body: {'inviteCode': code.trim().toUpperCase()},
    );
    if (!res.ok || res.data == null) {
      return (ok: false, error: res.error ?? 'Unable to join household.');
    }

    _token = res.data!['token']?.toString() ?? _token;
    final hh = res.data!['household'] as Map<String, dynamic>?;
    if (hh != null) {
      _householdId = hh['id']?.toString();
      _householdName = hh['name']?.toString();
      _inviteCode = hh['inviteCode']?.toString();
    }
    await _persistSession();
    await syncNow(pushLocalKitFirst: false);
    return (ok: true, error: null);
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _email = null;
    _fullName = null;
    _role = 'household';
    _householdId = null;
    _householdName = null;
    _inviteCode = null;
    _lastSyncError = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  Future<void> enqueueMutation(String type, Map<String, dynamic> payload) async {
    await _queue.enqueue(type, payload);
    notifyListeners();
    if (hasCloudEndpoint && (isAuthenticated || type == 'submit_evaluation')) {
      syncNow(pushLocalKitFirst: false);
    }
  }

  Future<({bool ok, String? error})> syncNow({bool pushLocalKitFirst = true}) async {
    if (_isSyncing) return (ok: true, error: null);
    if (!hasCloudEndpoint) {
      return (ok: false, error: 'No cloud server URL configured.');
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      if (pushLocalKitFirst && isAuthenticated && _kitPayloadReader != null) {
        final kitPayload = _kitPayloadReader!();
        await _queue.enqueue('upsert_kit', kitPayload);
      }

      final pending = List<SyncMutation>.from(_queue.items);
      for (final mutation in pending) {
        final handled = await _dispatchMutation(mutation);
        if (handled.sent) {
          await _queue.removeById(mutation.id);
        } else if (handled.networkError) {
          _lastSyncError = 'Offline: ${pending.length} update(s) queued';
          _isSyncing = false;
          notifyListeners();
          return (ok: false, error: _lastSyncError);
        }
      }

      if (isAuthenticated) {
        final bundleRes = await _api.request('GET', '/sync/bundle', token: _token);
        if (!bundleRes.ok || bundleRes.data == null) {
          _lastSyncError = bundleRes.error ?? 'Failed syncing household bundle.';
          _isSyncing = false;
          notifyListeners();
          return (ok: false, error: _lastSyncError);
        }

        await _applySyncBundle(bundleRes.data!);
        _lastSyncedAt = DateTime.now();
        await _persistSession();
      }

      _isSyncing = false;
      notifyListeners();
      return (ok: true, error: null);
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return (ok: false, error: _lastSyncError);
    }
  }

  Future<({bool sent, bool networkError})> _dispatchMutation(
    SyncMutation m,
  ) async {
    if (m.type != 'submit_evaluation' && !isAuthenticated) {
      return (sent: false, networkError: false);
    }

    late final ApiResponse res;
    switch (m.type) {
      case 'upsert_kit':
        res = await _api.request('PUT', '/kit', token: _token, body: m.payload);
        break;
      case 'delete_kit':
        final id = (m.payload['id'] ?? '').toString();
        res = await _api.request('DELETE', '/kit/$id', token: _token);
        break;
      case 'save_plan':
        res = await _api.request('PUT', '/plan', token: _token, body: m.payload);
        break;
      case 'add_checkin':
        res = await _api.request('POST', '/checkins', token: _token, body: m.payload);
        break;
      case 'add_shelter':
        res = await _api.request('POST', '/shelters', token: _token, body: m.payload);
        break;
      case 'submit_evaluation':
        res = await _api.request(
          'POST',
          '/evaluations',
          token: _token,
          body: m.payload,
        );
        break;
      default:
        return (sent: true, networkError: false);
    }

    if (res.ok) return (sent: true, networkError: false);
    if (res.isNetworkError || res.statusCode >= 500) {
      return (sent: false, networkError: true);
    }
    return (sent: true, networkError: false);
  }

  Future<void> _applySyncBundle(Map<String, dynamic> bundle) async {
    final household = bundle['household'] as Map<String, dynamic>?;
    final rawItems = (bundle['kitItems'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawCheckins = (bundle['checkins'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawShelters = (bundle['shelters'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (household != null) {
      _householdName = household['name']?.toString() ?? _householdName;
      _inviteCode = household['inviteCode']?.toString() ?? _inviteCode;

      if (rawItems.isEmpty && _kitPayloadReader != null) {
        // First time syncing this empty cloud household: seed with local kit
        final localPayload = _kitPayloadReader!();
        await _api.request('PUT', '/kit', token: _token, body: localPayload);
      } else if (_kitBundleApplier != null) {
        final profile = household['profile'] is Map
            ? Map<String, dynamic>.from(household['profile'])
            : null;
        final alertDays = household['expiryAlertDays'] as int?;
        await _kitBundleApplier!(rawItems, profile, alertDays);
      }

      if (household['plan'] is Map &&
          (household['plan'] as Map).isNotEmpty &&
          _planApplier != null) {
        await _planApplier!(Map<String, dynamic>.from(household['plan']));
      }
    }

    if (_sheltersApplier != null && rawShelters.isNotEmpty) {
      await _sheltersApplier!(rawShelters);
    }
    if (_checkinsApplier != null && rawCheckins.isNotEmpty) {
      await _checkinsApplier!(rawCheckins);
    }
  }

  Future<Map<String, dynamic>?> fetchTelemetryProxy(
    double lat,
    double lng,
  ) async {
    if (!hasCloudEndpoint) return null;
    final res = await _api.request(
      'GET',
      '/telemetry',
      queryParameters: {
        'lat': lat.toStringAsFixed(4),
        'lng': lng.toStringAsFixed(4),
      },
    );
    if (res.ok && res.data != null) {
      return res.data;
    }
    return null;
  }

  Future<({bool ok, bool queuedOffline, String? error})> submitEvaluation({
    required String respondentLabel,
    required int functionalityScore,
    required int usabilityScore,
    required int reliabilityScore,
    required int effectivenessScore,
    required double readinessPercentage,
    required double rawCompletionPercentage,
    String comments = '',
  }) async {
    final payload = <String, dynamic>{
      'respondentLabel': respondentLabel.trim().isEmpty
          ? (_fullName ?? 'Anonymous Household')
          : respondentLabel.trim(),
      'platform': ApiConfig.platformLabel,
      'functionalityScore': functionalityScore,
      'usabilityScore': usabilityScore,
      'reliabilityScore': reliabilityScore,
      'effectivenessScore': effectivenessScore,
      'readinessPercentage': readinessPercentage,
      'rawCompletionPercentage': rawCompletionPercentage,
      'comments': comments.trim(),
    };

    if (!hasCloudEndpoint) {
      await _queue.enqueue('submit_evaluation', payload);
      notifyListeners();
      return (ok: true, queuedOffline: true, error: null);
    }

    final res = await _api.request(
      'POST',
      '/evaluations',
      token: _token,
      body: payload,
    );
    if (res.ok) {
      return (ok: true, queuedOffline: false, error: null);
    }

    if (res.isNetworkError || res.statusCode >= 500) {
      await _queue.enqueue('submit_evaluation', payload);
      notifyListeners();
      return (ok: true, queuedOffline: true, error: null);
    }

    return (ok: false, queuedOffline: false, error: res.error);
  }

  Future<({bool ok, Map<String, dynamic>? summary, String? error})>
      fetchEvaluationSummary({String? adminCode}) async {
    final res = await _api.request(
      'GET',
      '/evaluations/summary',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
    );
    if (res.ok && res.data != null) {
      return (ok: true, summary: res.data, error: null);
    }
    return (ok: false, summary: null, error: res.error);
  }

  Future<({bool ok, String? csv, String? error})> exportEvaluationsCsv({
    String? adminCode,
  }) async {
    final res = await _api.request(
      'GET',
      '/evaluations/export',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
    );
    if (res.ok && res.rawText != null) {
      return (ok: true, csv: res.rawText, error: null);
    }
    return (ok: false, csv: null, error: res.error);
  }

  Future<({bool ok, Map<String, dynamic>? data, String? error})>
      fetchAdminOverview({String? adminCode}) async {
    final res = await _api.request(
      'GET',
      '/admin/overview',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
    );
    if (res.ok && res.data != null) {
      return (ok: true, data: res.data, error: null);
    }
    return (ok: false, data: null, error: res.error ?? 'Admin access denied.');
  }

  Future<({bool ok, Map<String, dynamic>? shelter, String? error})>
      createOfficialShelter({
    required Map<String, dynamic> shelter,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'POST',
      '/admin/shelters',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
      body: shelter,
    );
    if (res.ok && res.data?['shelter'] is Map) {
      return (
        ok: true,
        shelter: Map<String, dynamic>.from(res.data!['shelter']),
        error: null,
      );
    }
    return (
      ok: false,
      shelter: null,
      error: res.error ?? 'Could not add shelter.',
    );
  }

  Future<({bool ok, Map<String, dynamic>? shelter, String? error})>
      updateOfficialShelter({
    required String id,
    bool? isOpen,
    int? capacityPeople,
    String? name,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? contactPerson,
    String? contactNumber,
    String? facilities,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'PATCH',
      '/shelters/${Uri.encodeComponent(id)}',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
      body: {
        if (isOpen != null) 'isOpen': isOpen,
        if (capacityPeople != null) 'capacityPeople': capacityPeople,
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (contactPerson != null) 'contactPerson': contactPerson,
        if (contactNumber != null) 'contactNumber': contactNumber,
        if (facilities != null) 'facilities': facilities,
      },
    );
    if (res.ok && res.data?['shelter'] is Map) {
      return (
        ok: true,
        shelter: Map<String, dynamic>.from(res.data!['shelter']),
        error: null,
      );
    }
    return (
      ok: false,
      shelter: null,
      error: res.error ?? 'Could not update shelter.',
    );
  }

  Future<({bool ok, Map<String, dynamic>? checkin, String? error})>
      acknowledgeCheckin({
    required String id,
    required bool acknowledged,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'PATCH',
      '/admin/checkins/${Uri.encodeComponent(id)}',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
      body: {'acknowledged': acknowledged},
    );
    if (res.ok && res.data?['checkin'] is Map) {
      return (
        ok: true,
        checkin: Map<String, dynamic>.from(res.data!['checkin']),
        error: null,
      );
    }
    return (
      ok: false,
      checkin: null,
      error: res.error ?? 'Could not update check-in status.',
    );
  }

  Future<List<Map<String, dynamic>>> fetchPublicAdvisories() async {
    if (!hasCloudEndpoint) return [];
    final res = await _api.request('GET', '/advisories');
    if (res.ok && res.data?['advisories'] is List) {
      return (res.data!['advisories'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<({bool ok, Map<String, dynamic>? advisory, String? error})>
      createAdvisory({
    required String title,
    required String message,
    required String severity,
    required String area,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'POST',
      '/admin/advisories',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
      body: {
        'title': title.trim(),
        'message': message.trim(),
        'severity': severity,
        'area': area.trim().isEmpty ? 'Metro Manila' : area.trim(),
      },
    );
    if (res.ok && res.data?['advisory'] is Map) {
      return (
        ok: true,
        advisory: Map<String, dynamic>.from(res.data!['advisory']),
        error: null,
      );
    }
    return (
      ok: false,
      advisory: null,
      error: res.error ?? 'Could not publish advisory.',
    );
  }

  Future<({bool ok, Map<String, dynamic>? advisory, String? error})>
      updateAdvisory({
    required String id,
    bool? isActive,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'PATCH',
      '/admin/advisories/${Uri.encodeComponent(id)}',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
      body: {
        if (isActive != null) 'isActive': isActive,
      },
    );
    if (res.ok && res.data?['advisory'] is Map) {
      return (
        ok: true,
        advisory: Map<String, dynamic>.from(res.data!['advisory']),
        error: null,
      );
    }
    return (
      ok: false,
      advisory: null,
      error: res.error ?? 'Could not update advisory.',
    );
  }

  Future<({bool ok, String? error})> deleteAdvisory({
    required String id,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'DELETE',
      '/admin/advisories/${Uri.encodeComponent(id)}',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
    );
    if (res.ok) return (ok: true, error: null);
    return (ok: false, error: res.error ?? 'Could not delete advisory.');
  }

  Future<({bool ok, String? error})> deleteOfficialShelter({
    required String id,
    String? adminCode,
  }) async {
    final res = await _api.request(
      'DELETE',
      '/admin/shelters/${Uri.encodeComponent(id)}',
      token: _token,
      headers: adminCode != null && adminCode.trim().isNotEmpty
          ? {'x-admin-code': adminCode.trim()}
          : null,
    );
    if (res.ok) return (ok: true, error: null);
    return (ok: false, error: res.error ?? 'Could not delete shelter.');
  }

  Future<({bool ok, String? error})> checkHealth() async {
    final res = await _api.request('GET', '/health');
    if (res.ok && res.data?['ok'] == true) {
      return (ok: true, error: null);
    }
    return (ok: false, error: res.error ?? 'Backend unavailable');
  }

  Future<void> _applyAuthPayload(Map<String, dynamic> data) async {
    _token = data['token']?.toString();
    final user = data['user'] as Map<String, dynamic>?;
    final hh = data['household'] as Map<String, dynamic>?;
    if (user != null) {
      _userId = user['id']?.toString();
      _email = user['email']?.toString();
      _fullName = user['fullName']?.toString();
      _role = (user['role'] ?? 'household').toString();
    }
    if (hh != null) {
      _householdId = hh['id']?.toString();
      _householdName = hh['name']?.toString();
      _inviteCode = hh['inviteCode']?.toString();
    }
    await _persistSession();
    notifyListeners();
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        json.encode({
          'token': _token,
          'userId': _userId,
          'email': _email,
          'fullName': _fullName,
          'role': _role,
          'householdId': _householdId,
          'householdName': _householdName,
          'inviteCode': _inviteCode,
          'lastSyncedAt': _lastSyncedAt?.toIso8601String(),
        }),
      );
    } catch (_) {}
  }
}
