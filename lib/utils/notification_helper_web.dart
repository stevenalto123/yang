import 'dart:js_interop';
import 'package:web/web.dart' as web;

String getWebNotificationPermissionStatus() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<bool> requestWebNotificationPermission() async {
  try {
    final current = web.Notification.permission;
    if (current == 'granted') return true;
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> showWebNotification({
  required String title,
  required String body,
}) async {
  try {
    if (web.Notification.permission != 'granted') {
      final granted = await requestWebNotificationPermission();
      if (!granted) return false;
    }
    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: 'icons/Icon-192.png',
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
