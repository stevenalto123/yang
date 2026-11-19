import 'dart:io';
import 'package:flutter/services.dart';

const MethodChannel _nativeChannel =
    MethodChannel('com.eac.lifecheckpoint/native');

Future<({double lat, double lng, double? accuracy})?> getCurrentGpsPosition() async {
  if (!Platform.isAndroid) return null;
  try {
    final result = await _nativeChannel
        .invokeMapMethod<String, dynamic>('getCurrentPosition')
        .timeout(const Duration(seconds: 9));
    if (result == null) return null;
    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    final acc = (result['accuracy'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng, accuracy: acc);
  } catch (_) {
    return null;
  }
}
