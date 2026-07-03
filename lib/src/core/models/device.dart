import 'package:zerobox/src/core/models/bt_models.dart';

enum DevicePlatform { velaOS, zeppOS }

enum ConnectionStatus { disconnected, scanning, connecting, connected, ready, error }

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.modelId,
    required this.status,
    this.battery,
    this.firmwareVersion,
    this.address,
    this.authkey,
    this.connectType,
    this.codename,
  });

  final String id;
  final String name;
  final DevicePlatform platform;
  final String modelId;
  final ConnectionStatus status;
  final int? battery;
  final String? firmwareVersion;
  final String? address;
  final String? authkey;
  final String? connectType;
  final String? codename;

  bool get isConnected =>
      status == ConnectionStatus.connected || status == ConnectionStatus.ready;

  MiWearState toMiWearState() => MiWearState(
        name: name,
        addr: address ?? id,
        connectType: connectType ?? 'ble',
        authkey: authkey,
        codename: codename,
        disconnected: !isConnected,
      );
}

String devicePlatformLabel(DevicePlatform platform) {
  return switch (platform) {
    DevicePlatform.velaOS => 'VelaOS',
    DevicePlatform.zeppOS => 'ZeppOS',
  };
}

String connectionStatusLabel(ConnectionStatus status) {
  return switch (status) {
    ConnectionStatus.disconnected => 'Disconnected',
    ConnectionStatus.scanning => 'Scanning',
    ConnectionStatus.connecting => 'Connecting',
    ConnectionStatus.connected => 'Connected',
    ConnectionStatus.ready => 'Ready',
    ConnectionStatus.error => 'Error',
  };
}

final _deviceIllustrationMatchers = [
  (
    RegExp(r'Redmi Band \w', caseSensitive: false),
    'assets/images/devices/redmi-band.svg',
  ),
  (
    RegExp(r'Redmi Watch \w', caseSensitive: false),
    'assets/images/devices/redmi-watch.svg',
  ),
  (
    RegExp(r'Xiaomi Smart Band \w\w? Pro .{4}|小米手环\w\w? Pro',
        caseSensitive: false),
    'assets/images/devices/xiaomi-band-pro.svg',
  ),
  (
    RegExp(r'Xiaomi Smart Band \w\w? ?\S{4}?|小米手环\w\w?',
        caseSensitive: false),
    'assets/images/devices/xiaomi-band.svg',
  ),
  (
    RegExp(r'Xiaomi Watch S\w (eSIM )?\S{4}', caseSensitive: false),
    'assets/images/devices/xiaomi-watch.svg',
  ),
];

String _matchIllustrationAsset(String name) {
  for (final (regex, asset) in _deviceIllustrationMatchers) {
    if (regex.hasMatch(name)) return asset;
  }
  return 'assets/images/devices/xiaomi-watch.svg';
}

extension DeviceIllustration on Device {
  String? illustrationAsset() {
    return _matchIllustrationAsset(name);
  }
}

extension MiWearStateIllustration on MiWearState {
  String illustrationAsset() {
    return _matchIllustrationAsset(name);
  }
}

extension BTDeviceInfoIllustration on BTDeviceInfo {
  String illustrationAsset() {
    return _matchIllustrationAsset(name);
  }
}
