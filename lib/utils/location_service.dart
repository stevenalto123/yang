import 'dart:math' as math;
import 'location_service_stub.dart'
    if (dart.library.js_interop) 'location_service_web.dart' as impl;

class LocationService {
  static Future<({double lat, double lng, double? accuracy})?>
      getCurrentPosition() => impl.getCurrentGpsPosition();

  /// Computes great-circle distance in kilometers offline using Haversine formula
  static double distanceInKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Returns compass bearing in degrees (0..360) and cardinal direction
  static ({double degrees, String cardinal}) bearingTo(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = _degToRad(lat1);
    final phi2 = _degToRad(lat2);
    final dLambda = _degToRad(lng2 - lng1);

    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    final theta = math.atan2(y, x);
    final degrees = (_radToDeg(theta) + 360) % 360;

    const cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return (degrees: degrees, cardinal: cardinals[index]);
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);
}
