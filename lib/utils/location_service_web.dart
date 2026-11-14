import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<({double lat, double lng, double? accuracy})?> getCurrentGpsPosition() {
  final completer =
      Completer<({double lat, double lng, double? accuracy})?>();

  try {
    final geolocation = web.window.navigator.geolocation;

    void onSuccess(web.GeolocationPosition pos) {
      if (!completer.isCompleted) {
        completer.complete((
          lat: pos.coords.latitude.toDouble(),
          lng: pos.coords.longitude.toDouble(),
          accuracy: pos.coords.accuracy.toDouble(),
        ));
      }
    }

    void onError(web.GeolocationPositionError err) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    geolocation.getCurrentPosition(
      onSuccess.toJS,
      onError.toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 8000,
        maximumAge: 60000,
      ),
    );
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  return completer.future.timeout(
    const Duration(seconds: 9),
    onTimeout: () => null,
  );
}
