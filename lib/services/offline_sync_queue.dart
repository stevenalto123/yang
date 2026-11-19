import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncMutation {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final String createdAt;

  const SyncMutation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt,
      };

  factory SyncMutation.fromMap(Map<String, dynamic> map) {
    return SyncMutation(
      id: (map['id'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: (map['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }
}

class OfflineSyncQueue {
  static const String _storageKey = 'lifecheckpoint_sync_queue_v1';
  List<SyncMutation> _items = [];

  List<SyncMutation> get items => List.unmodifiable(_items);
  int get length => _items.length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List<dynamic>;
        _items = decoded
            .map((e) => SyncMutation.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    if (type == 'upsert_kit' || type == 'save_plan') {
      _items.removeWhere((m) => m.type == type);
    }
    _items.add(
      SyncMutation(
        id: '${type}_${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        payload: payload,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await _save();
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((m) => m.id == id);
    await _save();
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        json.encode(_items.map((e) => e.toMap()).toList()),
      );
    } catch (_) {}
  }
}
