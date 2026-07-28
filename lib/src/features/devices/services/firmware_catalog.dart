import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';

class FirmwareCatalogQuery {
  const FirmwareCatalogQuery({
    required this.kind,
    required this.codename,
    required this.model,
    required this.currentVersion,
  });

  final DeviceKind kind;
  final String? codename;
  final String model;
  final String currentVersion;
}

class FirmwareRelease {
  const FirmwareRelease({
    required this.version,
    required this.downloadUrl,
    required this.fileName,
    this.releaseNotes,
    this.size,
    this.sha256,
  });

  final String version;
  final Uri downloadUrl;
  final String fileName;
  final String? releaseNotes;
  final int? size;
  final String? sha256;
}

abstract interface class FirmwareCatalog {
  Future<List<FirmwareRelease>> findUpdates(FirmwareCatalogQuery query);
}

class FirmwareCatalogUnavailable implements Exception {
  const FirmwareCatalogUnavailable();
}

class DeviceFirmwareCatalog implements FirmwareCatalog {
  DeviceFirmwareCatalog(this._dio);

  static const _releasesUrl =
      'https://api.github.com/repos/AstralSightStudios/'
      'MiWearFirmwareArchives/releases';

  final Dio _dio;

  @override
  Future<List<FirmwareRelease>> findUpdates(FirmwareCatalogQuery query) async {
    if (query.kind == DeviceKind.zepp) {
      // TODO(collaborator): Provide a ZeppOS firmware catalog implementation.
      throw const FirmwareCatalogUnavailable();
    }

    final product = _resolveProduct(query);
    if (product == null) return const [];
    final response = await _dio.get<List<dynamic>>(
      _releasesUrl,
      queryParameters: const {'per_page': 100},
      options: Options(
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ),
    );
    final releases = <FirmwareRelease>[];
    for (final raw in response.data ?? const []) {
      if (raw is! Map) continue;
      final release = raw.cast<String, dynamic>();
      final name = release['name']?.toString().trim() ?? '';
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length < 2 || parts.first.toLowerCase() != product) continue;
      final version = _normalizeVersion(parts[1]);
      if (version.isEmpty) continue;

      final assets = (release['assets'] as List? ?? const [])
          .whereType<Map>()
          .map((asset) => asset.cast<String, dynamic>())
          .where((asset) => asset['name']?.toString().endsWith('.bin') ?? false)
          .toList(growable: false);
      final asset = _selectFullAsset(assets);
      if (asset == null) continue;
      final downloadUrl = Uri.tryParse(
        asset['browser_download_url']?.toString() ?? '',
      );
      if (downloadUrl == null) continue;
      releases.add(
        FirmwareRelease(
          version: version,
          downloadUrl: downloadUrl,
          fileName: asset['name'].toString(),
          releaseNotes: release['body']?.toString(),
          size: (asset['size'] as num?)?.toInt(),
          sha256: asset['digest']?.toString().replaceFirst('sha256:', ''),
        ),
      );
    }
    releases.sort((a, b) => _compareVersions(b.version, a.version));
    return releases;
  }

  String? _resolveProduct(FirmwareCatalogQuery query) {
    final model = query.model.trim().toLowerCase();
    if (model.contains('.watch.')) return model;
    final codename = query.codename?.trim().toLowerCase();
    if (codename == null || codename.isEmpty) return null;
    if (codename.contains('.watch.')) return codename;
    final identity = xiaomiWearableIdentityForCodename(codename);
    for (final alias in identity?.aliases ?? const <String>[]) {
      final normalized = alias.toLowerCase();
      if (normalized.contains('.watch.') && normalized.endsWith('.$codename')) {
        return normalized;
      }
    }
    return null;
  }

  Map<String, dynamic>? _selectFullAsset(List<Map<String, dynamic>> assets) {
    for (final asset in assets) {
      if (asset['name'].toString().toLowerCase().contains('_full_')) {
        return asset;
      }
    }
    return null;
  }

  String _normalizeVersion(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^v'), '')
      .split(RegExp(r'[^0-9.]'))
      .first;

  int _compareVersions(String left, String right) {
    final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final result = (index < a.length ? a[index] : 0).compareTo(
        index < b.length ? b[index] : 0,
      );
      if (result != 0) return result;
    }
    return 0;
  }
}

final firmwareCatalogProvider = Provider<FirmwareCatalog>(
  (ref) => DeviceFirmwareCatalog(ref.watch(appDioProvider)),
);

Future<XFile> downloadFirmwareRelease(
  Dio dio,
  FirmwareRelease release, {
  void Function(double progress)? onProgress,
}) async {
  final root = await getTemporaryDirectory();
  final safeName = release.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final path = '${root.path}/$safeName';
  await dio.download(
    release.downloadUrl.toString(),
    path,
    deleteOnError: true,
    onReceiveProgress: (received, total) {
      if (total > 0) onProgress?.call(received / total);
    },
  );
  return XFile(path, name: release.fileName);
}
