import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/domain/device_connection_endpoint.dart';

void main() {
  test('a newly scanned Xiaomi BLE endpoint can use its SPP transport', () {
    const scanned = BTDeviceInfo(
      name: 'Xiaomi Smart Band 9 Pro',
      addr: 'D4:17:61:14:18:6E',
      connectType: 'ble',
    );

    final endpoint = resolveDeviceConnectionEndpoint(
      device: const MiWearState(
        name: 'Xiaomi Smart Band 9 Pro',
        addr: 'D4:17:61:14:18:6E',
        connectType: 'ble',
        codename: 'n67',
      ),
      saved: false,
      connectType: 'spp',
      scannedDevices: const [scanned],
    );

    expect(endpoint, isNotNull);
    expect(endpoint!.addr, 'D4:17:61:14:18:6E');
  });
}
