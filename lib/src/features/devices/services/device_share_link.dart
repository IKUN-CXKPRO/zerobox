import 'package:zerobox/src/core/models/bt_models.dart';

class DeviceShareLink {
  const DeviceShareLink._();

  static Uri build(MiWearState device) {
    return Uri(
      scheme: 'zerobox',
      host: 'open',
      queryParameters: {
        'source': 'deviceQr',
        'name': device.name,
        'mac': device.addr.replaceAll(':', ''),
        if (device.authkey case final authkey? when authkey.isNotEmpty)
          'authkey': authkey,
      },
    );
  }

  static Uri buildAstroBoxCompatible(MiWearState device) {
    return Uri(
      scheme: 'https',
      host: 'astrobox.online',
      path: '/open',
      queryParameters: {
        'source': 'deviceQr',
        'name': device.name,
        'mac': device.addr.replaceAll(':', ''),
        if (device.authkey case final authkey? when authkey.isNotEmpty)
          'authkey': authkey,
      },
    );
  }

  static MiWearState? parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;

    final isZeroBox = uri.scheme == 'zerobox' && uri.host == 'open';
    final isZeroBoxWeb =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'zerobox.zxor.org' &&
        uri.path == '/open';
    final isAstroBox =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'astrobox.online' &&
        uri.path == '/open';
    if (!isZeroBox && !isZeroBoxWeb && !isAstroBox) return null;

    if (uri.queryParameters['source'] != 'deviceQr') return null;
    final name = uri.queryParameters['name'];
    final mac = uri.queryParameters['mac'];
    if (name == null || name.isEmpty || mac == null || mac.isEmpty) {
      return null;
    }

    final addr = _formatMac(mac);
    if (addr == null) return null;

    return MiWearState(
      name: name,
      addr: addr,
      connectType: 'spp',
      authkey: uri.queryParameters['authkey'] ?? '',
      disconnected: true,
    );
  }

  static String? _formatMac(String value) {
    final compact = value.replaceAll(':', '').toUpperCase();
    final valid = RegExp(r'^[0-9A-F]{12}$').hasMatch(compact);
    if (!valid) return null;
    return List.generate(
      6,
      (index) => compact.substring(index * 2, index * 2 + 2),
    ).join(':');
  }
}
