import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/domain/device_connection_endpoint.dart';

void main() {
  test('saved Zepp OS device keeps its stored endpoint when reconnecting', () {
    final endpoint = resolveDeviceConnectionEndpoint(
      device: const MiWearState(
        name: 'Active 2 (Round)',
        addr: '11:22:33:44:55:66',
        connectType: 'spp',
      ),
      saved: true,
      connectType: 'spp',
      scannedDevices: const [
        BTDeviceInfo(
          name: 'Active 2 (Round)',
          addr: 'AA:BB:CC:DD:EE:FF',
          connectType: 'ble',
        ),
      ],
    );

    expect(endpoint?.addr, '11:22:33:44:55:66');
    expect(endpoint?.name, 'Active 2 (Round)');
  });
}
