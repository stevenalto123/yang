import 'dart:io';
import 'package:flutter/services.dart';

const MethodChannel _nativeChannel =
    MethodChannel('com.eac.lifecheckpoint/native');

String getWebNotificationPermissionStatus() {
  if (!Platform.isAndroid) return 'unsupported';
  return 'android';
}

Future<bool> requestWebNotificationPermission() async {
  if (!Platform.isAndroid) return false;
  try {
    final granted = await _nativeChannel
        .invokeMethod<bool>('requestNotificationPermission');
    return granted ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> showWebNotification({
  required String title,
  required String body,
}) async {
  if (!Platform.isAndroid) return false;
  try {
    final sent = await _nativeChannel.invokeMethod<bool>(
      'showNotification',
      {'title': title, 'body': body},
    );
    return sent ?? false;
  } catch (_) {
    return false;
  }
}
