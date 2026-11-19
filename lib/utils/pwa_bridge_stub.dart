bool isDeviceOnline() => true;

void Function() listenConnectivity(void Function(bool isOnline) onChanged) {
  return () {};
}

bool canTriggerNativePwaInstall() => false;

bool isRunningAsInstalledPwa() => true;

bool isIosBrowser() => false;

Future<bool> triggerNativePwaInstall() async => false;

bool startEmergencyWhistle() => false;

void stopEmergencyWhistle() {}
