import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('__lcCanInstall')
external bool _jsCanInstall();

@JS('__lcIsInstalled')
external bool _jsIsInstalled();

@JS('__lcIsIos')
external bool _jsIsIos();

@JS('__lcTriggerInstall')
external JSPromise<JSBoolean> _jsTriggerInstall();

@JS('__lcStartWhistle')
external bool _jsStartWhistle();

@JS('__lcStopWhistle')
external void _jsStopWhistle();

bool isDeviceOnline() {
  try {
    return web.window.navigator.onLine;
  } catch (_) {
    return true;
  }
}

void Function() listenConnectivity(void Function(bool isOnline) onChanged) {
  try {
    final onOnline = ((web.Event _) => onChanged(true)).toJS;
    final onOffline = ((web.Event _) => onChanged(false)).toJS;
    web.window.addEventListener('online', onOnline);
    web.window.addEventListener('offline', onOffline);
    return () {
      web.window.removeEventListener('online', onOnline);
      web.window.removeEventListener('offline', onOffline);
    };
  } catch (_) {
    return () {};
  }
}

bool canTriggerNativePwaInstall() {
  try {
    return _jsCanInstall();
  } catch (_) {
    return false;
  }
}

bool isRunningAsInstalledPwa() {
  try {
    return _jsIsInstalled();
  } catch (_) {
    return false;
  }
}

bool isIosBrowser() {
  try {
    return _jsIsIos();
  } catch (_) {
    return false;
  }
}

Future<bool> triggerNativePwaInstall() async {
  try {
    final res = await _jsTriggerInstall().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}

bool startEmergencyWhistle() {
  try {
    return _jsStartWhistle();
  } catch (_) {
    return false;
  }
}

void stopEmergencyWhistle() {
  try {
    _jsStopWhistle();
  } catch (_) {}
}
