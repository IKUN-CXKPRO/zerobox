import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/core/network/github_release.dart';
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

    final products = _resolveProducts(query);
    if (products.isEmpty) return const [];
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
    final releasesByProduct = <String, List<FirmwareRelease>>{};
    for (final raw in response.data ?? const []) {
      if (raw is! Map) continue;
      final release = GitHubRelease.fromJson(raw.cast<String, Object?>());
      final name = release.name;
      final parts = name.split(RegExp(r'\s+'));
      final product = parts.first.toLowerCase();
      if (parts.length < 2 || !products.contains(product)) continue;
      final version = _normalizeVersion(parts[1]);
      if (version.isEmpty) continue;

      final assets = release.assets
          .where((asset) => asset.name.endsWith('.bin'))
          .toList(growable: false);
      final asset = _selectFullAsset(assets);
      if (asset == null) continue;
      final downloadUrl = Uri.tryParse(asset.downloadUrl);
      if (downloadUrl == null) continue;
      releasesByProduct
          .putIfAbsent(product, () => [])
          .add(
            FirmwareRelease(
              version: version,
              downloadUrl: downloadUrl,
              fileName: asset.name,
              releaseNotes: release.body,
              size: asset.size,
              sha256: asset.digest?.replaceFirst('sha256:', ''),
            ),
          );
    }
    for (final product in products) {
      final releases = releasesByProduct[product];
      if (releases == null || releases.isEmpty) continue;
      releases.sort((a, b) => _compareVersions(b.version, a.version));
      return releases;
    }
    return const [];
  }

  List<String> _resolveProducts(FirmwareCatalogQuery query) {
    final model = query.model.trim().toLowerCase();
    if (model.contains('.watch.')) return [model];
    final codename = query.codename?.trim().toLowerCase();
    if (codename == null || codename.isEmpty) return const [];
    if (codename.contains('.watch.')) return [codename];
    final identity = xiaomiWearableIdentityForCodename(codename);
    return (identity?.aliases ?? const <String>[])
        .map((alias) => alias.trim().toLowerCase())
        .where((alias) => alias.contains('.watch.'))
        .toSet()
        .toList(growable: false);
  }

  GitHubReleaseAsset? _selectFullAsset(List<GitHubReleaseAsset> assets) {
    for (final asset in assets) {
      if (asset.name.toLowerCase().contains('_full_')) {
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
