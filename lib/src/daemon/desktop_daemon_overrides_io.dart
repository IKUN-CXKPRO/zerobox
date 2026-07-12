import 'dart:io';

import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/devices/controllers/remote_device_manager.dart';

dynamic desktopDaemonOverride() {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
    return null;
  }
  return deviceManagerProvider.overrideWith(RemoteDeviceManager.new);
}
