import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';

class OronBoxResourceCatalog implements CommunityResourceCatalog {
  OronBoxResourceCatalog({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  CommunitySourceId get sourceId => CommunitySourceId.oronBox;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(serverSort: true);

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/resources',
      queryParameters: {
        'limit': query.pageSize,
        'offset': query.page * query.pageSize,
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.type != null) 'type': _typeName(query.type!),
        if (query.selectedDevices.isNotEmpty)
          'devices': query.selectedDevices.join(','),
        'sort': query.sort.name,
      },
    );
    final root = _map(response.data);
    final items = (root['resources'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _summary(value.cast<String, Object?>()))
        .toList();
    return CommunityResourcePage(
      items: items,
      page: query.page,
      hasMore: items.length == query.pageSize,
      total: (root['total'] as num?)?.toInt(),
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _requireSource(ref);
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/resources/${Uri.encodeComponent(ref.id)}',
    );
    final json = _map(response.data);
    final summary = _summary(json);
    final media = (json['media'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .toList();
    final artifacts = (json['artifacts'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .toList();
    final previewImages = parseOronBoxPreviewImages(media, blobUri: _blobUri);
    final previews = previewImages.map((image) => image.url).toList();
    return CommunityResourceDetail(
      ref: summary.ref,
      name: summary.name,
      type: summary.type,
      paidType: summary.paidType,
      authors: summary.authors,
      supportedDevices: summary.supportedDevices,
      iconUrl: summary.iconUrl,
      coverUrl: summary.coverUrl,
      summary: summary.summary,
      updatedAt: summary.updatedAt,
      version: summary.version,
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: summary.summary,
      ),
      previews: previews,
      previewImages: previewImages,
      files: artifacts.map((item) {
        final digest =
            (item['sha256'] ?? item['blob_sha256'])?.toString() ?? '';
        return CommunityResourceFile(
          id: item['id']?.toString() ?? digest,
          fileName: item['original_name']?.toString() ?? 'resource',
          version: item['version']?.toString() ?? '',
          downloadUrl: _blobUri(digest),
          supportedDevices:
              (item['device_ids'] as List? ??
                      item['devices'] as List? ??
                      const [])
                  .map((value) => value.toString())
                  .toSet(),
        );
      }).toList(),
    );
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/devices',
    );
    return (_map(response.data)['devices'] as List? ?? const [])
        .whereType<Map>()
        .map((value) {
          final json = value.cast<String, Object?>();
          return CommunityResourceDevice(
            codename: json['codename']?.toString() ?? '',
            name: json['name']?.toString() ?? '',
            description: json['platform']?.toString() ?? '',
          );
        })
        .toList();
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    final url = request.file.downloadUrl;
    if (url == null) throw StateError('OronBox resource has no download URL');
    final fileName = _safeName(request.file.label);
    if (kIsWeb) {
      final bytes = await _downloadBytesWithFallback(url, request);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('OronBox resource download returned empty data');
      }
      return CommunityResourceDownloadResult(
        path: '/oronbox_downloads/$fileName',
        fileName: fileName,
        bytes: bytes,
      );
    }
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/oronbox_downloads/${request.resource.ref.id}',
    );
    await directory.create(recursive: true);
    final destination = '${directory.path}/$fileName';
    await _downloadFileWithFallback(url, destination, request);
    return CommunityResourceDownloadResult(
      path: destination,
      fileName: fileName,
    );
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async {
    final url = file.downloadUrl;
    if (url == null) return null;
    Response<Object?> response;
    try {
      response = await _dio.head<Object?>(_line(url, 'r2').toString());
    } on DioException {
      response = await _dio.head<Object?>(_line(url, 'local').toString());
    }
    return int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
  }

  Future<Uint8List?> _downloadBytesWithFallback(
    Uri url,
    CommunityDownloadRequest request,
  ) async {
    try {
      return (await _dio.get<Uint8List>(
        _line(url, 'r2').toString(),
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'r2'),
      )).data;
    } on DioException {
      return (await _dio.get<Uint8List>(
        _line(url, 'local').toString(),
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'local'),
      )).data;
    }
  }

  Future<void> _downloadFileWithFallback(
    Uri url,
    String destination,
    CommunityDownloadRequest request,
  ) async {
    try {
      await _dio.download(
        _line(url, 'r2').toString(),
        destination,
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'r2'),
      );
    } on DioException {
      await _dio.download(
        _line(url, 'local').toString(),
        destination,
        onReceiveProgress: (received, total) =>
            _reportProgress(request, received, total, 'local'),
      );
    }
  }

  Uri _line(Uri url, String line) =>
      url.replace(queryParameters: {...url.queryParameters, 'line': line});

  void _reportProgress(
    CommunityDownloadRequest request,
    int received,
    int total,
    String line,
  ) {
    if (total > 0) request.onProgress?.call(received / total, status: line);
  }

  CommunityResource _summary(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    final preview = json['preview_sha256']?.toString() ?? '';
    final icon = json['icon_sha256']?.toString() ?? '';
    final cover = json['cover_sha256']?.toString() ?? '';
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: id),
      name: json['name']?.toString() ?? '',
      type: _parseType(json['kind']?.toString()),
      paidType: CommunityPaidType.free,
      authors: [
        if (json['owner']?.toString().isNotEmpty == true)
          CommunityResourceAuthor(name: json['owner']!.toString()),
      ],
      supportedDevices: (json['devices'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet(),
      iconUrl: _blobUri(icon.isNotEmpty ? icon : preview),
      coverUrl: _blobUri(cover.isNotEmpty ? cover : preview),
      summary: json['summary']?.toString() ?? '',
      version: json['version']?.toString(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  Uri? _blobUri(String digest) => digest.length == 64
      ? Uri.parse('$oronBoxServerBaseUrl/api/blobs/$digest')
      : null;

  CommunityResourceType _parseType(String? value) => switch (value) {
    'zepp_app' => CommunityResourceType.miniprogram,
    'watchface' => CommunityResourceType.watchface,
    'firmware' => CommunityResourceType.firmware,
    _ => CommunityResourceType.quickApp,
  };

  String _typeName(CommunityResourceType type) => switch (type) {
    CommunityResourceType.quickApp => 'quickapp',
    CommunityResourceType.miniprogram => 'zepp_app',
    CommunityResourceType.watchface => 'watchface',
    CommunityResourceType.firmware => 'firmware',
    CommunityResourceType.fontpack => 'fontpack',
    CommunityResourceType.iconpack => 'iconpack',
  };

  Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw FormatException('OronBox server returned ${value.runtimeType}');

  String _safeName(String value) {
    final name = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return name.isEmpty || name == '.' || name == '..' ? 'resource' : name;
  }

  void _requireSource(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw ArgumentError.value(ref, 'ref', 'Wrong resource source');
    }
  }
}

List<CommunityResourceImage> parseOronBoxPreviewImages(
  List<Map<String, Object?>> media, {
  required Uri? Function(String digest) blobUri,
}) => media
    .where((item) => item['role'] == 'preview')
    .map((item) {
      final digest = (item['sha256'] ?? item['blob_sha256'])?.toString() ?? '';
      final url = blobUri(digest);
      if (url == null) return null;
      return CommunityResourceImage(
        url: url,
        width: (item['width'] as num?)?.toInt(),
        height: (item['height'] as num?)?.toInt(),
      );
    })
    .whereType<CommunityResourceImage>()
    .toList();
