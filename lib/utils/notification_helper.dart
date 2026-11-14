import 'notification_helper_stub.dart'
    if (dart.library.js_interop) 'notification_helper_web.dart' as impl;

class NotificationHelper {
  static String getPermissionStatus() => impl.getWebNotificationPermissionStatus();

  static Future<bool> requestPermission() => impl.requestWebNotificationPermission();

  static Future<bool> showAlert({
    required String title,
    required String body,
  }) =>
      impl.showWebNotification(title: title, body: body);
}
