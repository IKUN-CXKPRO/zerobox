import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:oronbox/src/features/devices/utils/device_address.dart';

typedef DeviceConnectionEndpoint = ({String addr, String name});

/// Resolves the physical endpoint used to connect a device card.
///
/// A saved device owns an exact address/transport pair. Scanned endpoints are
/// only consulted when the user explicitly switches a Zepp OS device to its
/// other transport.
DeviceConnectionEndpoint? resolveDeviceConnectionEndpoint({
  required MiWearState device,
  required bool saved,
  required String connectType,
  required List<BTDeviceInfo> scannedDevices,
}) {
  final normalizedType = connectType.toLowerCase();
  if (device.connectType.toLowerCase() == normalizedType) {
    return (addr: device.addr, name: device.name);
  }

  final sourceIdentity = zeppOsDeviceForBluetoothName(device.name);
  if (sourceIdentity == null) {
    final profile = DeviceRegistry.resolveIdentity(
      name: device.name,
      codename: device.codename,
    );
    if (profile.id == DeviceRegistry.unknown.id) return null;
    for (final endpoint in scannedDevices) {
      if (deviceAddressEquals(endpoint.addr, device.addr)) {
        return (addr: formatDeviceAddress(endpoint.addr), name: endpoint.name);
      }
    }
    return null;
  }
  for (final endpoint in scannedDevices) {
    if (endpoint.connectType.toLowerCase() != normalizedType) continue;
    final candidateIdentity = zeppOsDeviceForBluetoothName(endpoint.name);
    if (candidateIdentity?.id == sourceIdentity.id) {
      return (addr: endpoint.addr, name: endpoint.name);
    }
  }

  if (saved &&
      normalizedType == ConnectType.spp.name &&
      sourceIdentity.connectionCapability != ZeppOsConnectionCapability.ble) {
    return (addr: device.addr, name: device.name);
  }
  return null;
}
