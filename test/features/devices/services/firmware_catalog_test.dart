import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/features/devices/services/firmware_catalog.dart';

void main() {
  test(
    'falls back from the n67 codename to the available n67cn release',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<List<dynamic>>(
              requestOptions: options,
              data: [
                _release(product: 'miwear.watch.n67cn', version: 'v3.1.175'),
                _release(product: 'miwear.watch.n67cn', version: 'v3.1.171'),
              ],
            ),
          ),
        ),
      );

      final releases = await DeviceFirmwareCatalog(dio).findUpdates(
        const FirmwareCatalogQuery(
          kind: DeviceKind.xiaomi,
          codename: 'n67',
          model: 'Xiaomi Smart Band 9 Pro',
          currentVersion: '3.1.162',
        ),
      );

      expect(releases.map((release) => release.version), [
        '3.1.175',
        '3.1.171',
      ]);
      expect(
        releases.first.fileName,
        'miwear.watch.n67cn_v3.1.175_full_test.bin',
      );
    },
  );

  test(
    'keeps an exact firmware product isolated from regional aliases',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<List<dynamic>>(
              requestOptions: options,
              data: [
                _release(product: 'miwear.watch.n67cn', version: 'v3.1.175'),
                _release(product: 'miwear.watch.n67gl', version: 'v2.0.1'),
              ],
            ),
          ),
        ),
      );

      final releases = await DeviceFirmwareCatalog(dio).findUpdates(
        const FirmwareCatalogQuery(
          kind: DeviceKind.xiaomi,
          codename: 'n67',
          model: 'miwear.watch.n67gl',
          currentVersion: '2.0.0',
        ),
      );

      expect(releases.single.version, '2.0.1');
      expect(releases.single.fileName, contains('n67gl'));
    },
  );
}

Map<String, dynamic> _release({
  required String product,
  required String version,
}) {
  return {
    'name': '$product $version',
    'body': 'Release notes',
    'assets': [
      {
        'name': '${product}_${version}_full_test.bin',
        'browser_download_url': 'https://example.com/$product/$version.bin',
        'size': 1024,
        'digest': 'sha256:test',
      },
    ],
  };
}
