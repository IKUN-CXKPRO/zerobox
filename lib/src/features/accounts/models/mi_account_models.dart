class MiAccountToken {
  const MiAccountToken({
    required this.userId,
    required this.deviceId,
    required this.ssecurity,
    required this.serviceToken,
    required this.cUserId,
    required this.passToken,
    required this.psecurity,
  });

  final String userId;
  final String deviceId;
  final String ssecurity;
  final String serviceToken;
  final String cUserId;
  final String passToken;
  final String psecurity;
}

class MiCloudDevice {
  const MiCloudDevice({
    required this.name,
    required this.model,
    required this.mac,
    required this.authKey,
    required this.firmwareVersion,
    required this.serialNumber,
  });

  final String name;
  final String model;
  final String mac;
  final String authKey;
  final String firmwareVersion;
  final String serialNumber;

  bool get hasAuthKey => mac.trim().isNotEmpty && authKey.trim().isNotEmpty;

  factory MiCloudDevice.fromJson(Map<String, dynamic> json) {
    final detail =
        (json['detail'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return MiCloudDevice(
      name: json['name']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      mac: detail['mac']?.toString() ?? '',
      authKey: detail['encrypt_key']?.toString() ?? '',
      firmwareVersion: detail['fw_ver']?.toString() ?? '',
      serialNumber: detail['sn']?.toString() ?? '',
    );
  }
}

class MiAccountTwoFactorRequired implements Exception {
  MiAccountTwoFactorRequired({required this.url, required this.deviceId});

  final String url;
  final String deviceId;

  @override
  String toString() => 'Xiaomi account requires two-factor verification: $url';
}
