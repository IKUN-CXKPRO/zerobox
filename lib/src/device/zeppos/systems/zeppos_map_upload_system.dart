import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsMapUploadSystem extends System {
  static const mapsEndpoint = 0x0046;
  static const httpEndpoint = 0x0001;
  static const fileTransferEndpoint = 0x000d;
  static const _firmwareService = '00001530-0000-3512-2118-0009af100700';
  static const _v3Send = BleRequiredCharacteristic(
    serviceUuid: _firmwareService,
    characteristicUuid: '00000023-0000-3512-2118-0009af100700',
    label: 'Zepp OS file transfer v3 send',
  );

  bool _mapsEncrypted = false;
  bool _httpEncrypted = false;
  bool _fileTransferEncrypted = false;
  int? _fileTransferVersion;
  int _chunkSize = 0;
  bool _uploading = false;
  StreamSubscription<Uint8List>? _ackSubscription;
  Completer<void>? _capabilities;
  Completer<void>? _mapStart;
  Completer<_RawDownloadRequest>? _rawRequest;
  Completer<int>? _fileRequest;
  Completer<int>? _chunkAck;

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  int? get _maxWriteLength {
    final transport = entity.transport;
    return transport is CharacteristicTransport
        ? transport.maxWriteLength
        : null;
  }

  Future<void> upload(
    Uint8List bytes, {
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (_uploading) throw StateError('地图传输正在进行中');
    _uploading = true;
    try {
      final package = ZeppOsMapPackage.validate(bytes, fileName: fileName);
      await _initialize();

      final mapStart = Completer<void>();
      final rawRequest = Completer<_RawDownloadRequest>();
      _mapStart = mapStart;
      _rawRequest = rawRequest;
      final fakeUrl =
          'https://gadgetbridge.freeyourgadget.nodomain/map/0.zip'
          '?type=1&zipsize=${bytes.length}';

      try {
        await _component.sendToEndpoint(
          mapsEndpoint,
          _mapStartRequest(package.uncompressedSize, fakeUrl),
          encrypted: _mapsEncrypted,
          maxWriteLength: _maxWriteLength,
        );
        _log.info(
          'map upload requested: file=$fileName, compressed=${bytes.length}, '
          'uncompressed=${package.uncompressedSize}',
        );

        // Some firmware starts the HTTP request before sending the maps ACK.
        // Treat either event as acceptance, while still surfacing an explicit
        // rejection when it arrives first.
        await Future.any<void>([
          mapStart.future,
          rawRequest.future.then((_) {}),
        ]).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException(
            '等待手表确认地图安装超时',
            const Duration(seconds: 60),
          ),
        );
        final request = await rawRequest.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw TimeoutException('手表未请求地图文件', const Duration(seconds: 20)),
        );
        if (request.url != fakeUrl) {
          throw StateError('手表请求了未知地图地址：${request.url}');
        }

        await _sendFile(request.requestId, bytes, onProgress: onProgress);
      } finally {
        if (identical(_mapStart, mapStart)) _mapStart = null;
        if (identical(_rawRequest, rawRequest)) _rawRequest = null;
      }
    } finally {
      _uploading = false;
    }
  }

  Future<void> _initialize() async {
    final transport = entity.transport;
    if (transport is! CharacteristicTransport) {
      throw UnsupportedError('地图传输需要 Zepp OS 特征通道');
    }
    final servicesSystem = entity.system<ZeppOsServicesSystem>();
    if (servicesSystem == null) {
      throw StateError('Zepp OS 服务列表系统未初始化');
    }
    final services = await servicesSystem.fetchSupportedServices();
    for (final endpoint in const [
      mapsEndpoint,
      httpEndpoint,
      fileTransferEndpoint,
    ]) {
      if (!services.containsKey(endpoint)) {
        throw UnsupportedError(
          '手表未提供地图传输服务 0x${endpoint.toRadixString(16).padLeft(4, '0')}',
        );
      }
    }
    _mapsEncrypted = services[mapsEndpoint] ?? false;
    _httpEncrypted = services[httpEndpoint] ?? false;
    _fileTransferEncrypted = services[fileTransferEndpoint] ?? false;

    if (_fileTransferVersion == null) {
      final capabilities = Completer<void>();
      _capabilities = capabilities;
      try {
        await _component.sendToEndpoint(
          fileTransferEndpoint,
          Uint8List.fromList(const [0x01]),
          encrypted: _fileTransferEncrypted,
          maxWriteLength: _maxWriteLength,
        );
        await capabilities.future.timeout(const Duration(seconds: 8));
      } finally {
        if (identical(_capabilities, capabilities)) _capabilities = null;
      }
    }
    if (_fileTransferVersion != 3) {
      throw UnsupportedError(
        '地图上传当前需要 Zepp OS V3 文件传输，手表返回 '
        'V${_fileTransferVersion ?? '未知'}',
      );
    }
    _ackSubscription ??= await transport.subscribeToCharacteristic(
      _v3Send,
      _handleV3Ack,
    );
  }

  Future<void> _sendFile(
    int requestId,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    final fileRequest = Completer<int>();
    _fileRequest = fileRequest;
    try {
      await _component.sendToEndpoint(
        fileTransferEndpoint,
        _fileRequestPayload(requestId, bytes),
        encrypted: _fileTransferEncrypted,
        maxWriteLength: _maxWriteLength,
      );
      await _component.sendToEndpoint(
        httpEndpoint,
        _rawDownloadStart(requestId, bytes.length),
        encrypted: _httpEncrypted,
        maxWriteLength: _maxWriteLength,
      );
      final existingProgress = await fileRequest.future.timeout(
        const Duration(seconds: 15),
      );
      if (existingProgress < 0 || existingProgress > bytes.length) {
        throw StateError('手表返回了无效的地图传输进度：$existingProgress');
      }

      var offset = existingProgress;
      var index = offset ~/ _chunkSize;
      onProgress?.call(bytes.isEmpty ? 1 : offset / bytes.length);
      while (offset < bytes.length) {
        final length = (bytes.length - offset).clamp(0, _chunkSize);
        final last = offset + length == bytes.length;
        final packet = Uint8List(5 + length);
        packet[0] = 0x12;
        packet[1] = (offset == 0 ? 1 : 0) | (last ? 2 : 0);
        packet[2] = index & 0xff;
        ByteData.sublistView(packet).setUint16(3, length, Endian.little);
        packet.setRange(5, packet.length, bytes, offset);

        final ack = Completer<int>();
        _chunkAck = ack;
        try {
          await _writeV3Packet(packet);
          final acknowledged = await ack.future.timeout(
            const Duration(seconds: 20),
          );
          if (acknowledged != (index & 0xff)) {
            throw StateError('地图分块确认序号不匹配：$acknowledged/${index & 0xff}');
          }
        } finally {
          if (identical(_chunkAck, ack)) _chunkAck = null;
        }
        offset += length;
        index += 1;
        onProgress?.call(offset / bytes.length);
      }

      await _component.sendToEndpoint(
        httpEndpoint,
        _rawDownloadFinish(requestId),
        encrypted: _httpEncrypted,
        maxWriteLength: _maxWriteLength,
      );
      _log.info('map upload completed: ${bytes.length} bytes');
    } finally {
      if (identical(_fileRequest, fileRequest)) _fileRequest = null;
    }
  }

  Future<void> _writeV3Packet(Uint8List packet) async {
    final transport = entity.transport as CharacteristicTransport;
    final writeLength = _maxWriteLength ?? packet.length;
    if (writeLength <= 0) {
      throw StateError('BLE 最大写入长度无效：$writeLength');
    }
    for (var offset = 0; offset < packet.length; offset += writeLength) {
      final end = (offset + writeLength).clamp(0, packet.length);
      await transport.sendToCharacteristic(
        Uint8List.sublistView(packet, offset, end),
        _v3Send,
        withResponse: false,
      );
    }
  }

  void handlePayload(int endpoint, Uint8List payload) {
    if (payload.isEmpty) return;
    if (endpoint == mapsEndpoint) {
      if (payload.length >= 2 && payload[0] == 0x06) {
        final pending = _mapStart;
        if (pending == null || pending.isCompleted) return;
        if (payload[1] == 1) {
          pending.complete();
        } else {
          pending.completeError(StateError('手表拒绝了地图安装：${payload[1]}'));
        }
      }
      return;
    }
    if (endpoint == httpEndpoint) {
      if (payload.length >= 4 && payload[0] == 0x03) {
        final zero = payload.indexOf(0, 2);
        if (zero < 0) return;
        final pending = _rawRequest;
        if (pending != null && !pending.isCompleted) {
          pending.complete(
            _RawDownloadRequest(
              payload[1],
              utf8.decode(payload.sublist(2, zero)),
            ),
          );
        }
      }
      return;
    }
    if (endpoint != fileTransferEndpoint) return;
    if (payload[0] == 0x02 && payload.length >= 4) {
      _fileTransferVersion = payload[1];
      _chunkSize = ByteData.sublistView(payload).getUint16(2, Endian.little);
      final pending = _capabilities;
      if (_chunkSize <= 0) {
        pending?.completeError(StateError('手表返回了无效的文件分块大小：$_chunkSize'));
      } else if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
      return;
    }
    if (payload[0] == 0x04 && payload.length >= 7) {
      final pending = _fileRequest;
      if (pending == null || pending.isCompleted) return;
      if (payload[2] != 0) {
        pending.completeError(StateError('手表拒绝接收地图文件：${payload[2]}'));
      } else {
        pending.complete(
          ByteData.sublistView(payload).getUint32(3, Endian.little),
        );
      }
    }
  }

  void _handleV3Ack(Uint8List payload) {
    if (payload.length < 3 || payload[0] != 0x13) return;
    final pending = _chunkAck;
    if (pending == null || pending.isCompleted) return;
    if (payload[1] == 0) {
      pending.complete(payload[2]);
    } else {
      pending.completeError(StateError('地图分块写入失败：${payload[1]}'));
    }
  }

  static Uint8List _mapStartRequest(int uncompressedSize, String url) {
    final urlBytes = utf8.encode(url);
    final bytes = Uint8List(1 + 4 + 2 + urlBytes.length + 2);
    bytes[0] = 0x05;
    final view = ByteData.sublistView(bytes);
    view.setUint32(1, uncompressedSize, Endian.little);
    view.setUint16(5, 1, Endian.little);
    bytes.setRange(7, 7 + urlBytes.length, urlBytes);
    bytes[7 + urlBytes.length] = 0;
    bytes.last = 1;
    return bytes;
  }

  static Uint8List _fileRequestPayload(int requestId, Uint8List bytes) {
    final url = utf8.encode('httpproxy://download?sessionid=$requestId');
    final name = utf8.encode('0.zip');
    final payload = Uint8List(2 + url.length + 1 + name.length + 1 + 10);
    var offset = 0;
    payload[offset++] = 0x03;
    payload[offset++] = requestId;
    payload.setRange(offset, offset + url.length, url);
    offset += url.length;
    payload[offset++] = 0;
    payload.setRange(offset, offset + name.length, name);
    offset += name.length;
    payload[offset++] = 0;
    final view = ByteData.sublistView(payload);
    view.setUint32(offset, bytes.length, Endian.little);
    view.setUint32(offset + 4, _crc32(bytes), Endian.little);
    payload[offset + 8] = 0;
    payload[offset + 9] = 0;
    return payload;
  }

  static Uint8List _rawDownloadStart(int requestId, int length) {
    final payload = Uint8List(10)
      ..[0] = 0x04
      ..[1] = requestId;
    ByteData.sublistView(payload).setUint32(2, length, Endian.little);
    return payload;
  }

  static Uint8List _rawDownloadFinish(int requestId) {
    final payload = Uint8List.fromList([0x05, requestId, 1, 0, 0]);
    ByteData.sublistView(payload).setUint16(3, 200, Endian.little);
    return payload;
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  @override
  void onData(Uint8List data) {}

  @override
  Future<void> dispose() async {
    await _ackSubscription?.cancel();
    _ackSubscription = null;
  }
}

class ZeppOsMapPackage {
  const ZeppOsMapPackage({
    required this.uncompressedSize,
    required this.tiles,
    required this.kind,
    this.garminImgName,
    this.garminAnalysis,
  });

  final int uncompressedSize;
  final List<ZeppOsMapTile> tiles;
  final ZeppOsMapPackageKind kind;
  final String? garminImgName;
  final GarminImgAnalysis? garminAnalysis;

  bool get isGarminImg => kind == ZeppOsMapPackageKind.garminImg;

  static GarminImgInput readGarminInput(
    Uint8List bytes, {
    required String fileName,
  }) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.img')) {
      return GarminImgInput(
        bytes: bytes,
        fileName: fileName,
        analysis: GarminImgAnalysis.analyze(bytes, fileName: fileName),
      );
    }
    if (!lowerName.endsWith('.zip')) {
      throw FormatException('$fileName 不是支持的 ZIP 或 Garmin IMG 地图');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FormatException('$fileName 不是有效的 ZIP 地图包：$error');
    }
    final files = archive.files.where((entry) => entry.isFile).toList();
    if (files.length != 1 ||
        !files.single.name.toLowerCase().endsWith('.img')) {
      throw FormatException('$fileName 不是仅包含一个 IMG 的佳明地图包');
    }
    final entry = files.single;
    final imgBytes = Uint8List.fromList(entry.content as List<int>);
    return GarminImgInput(
      bytes: imgBytes,
      fileName: entry.name,
      analysis: GarminImgAnalysis.analyze(
        imgBytes,
        fileName: entry.name,
      ),
    );
  }

  static ZeppOsPreparedMap prepare(
    Uint8List bytes, {
    required String fileName,
  }) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.zip')) {
      final package = validate(bytes, fileName: fileName);
      if (package.isGarminImg) {
        final archive = ZipDecoder().decodeBytes(bytes, verify: true);
        final entry = archive.files.singleWhere(
          (candidate) =>
              candidate.isFile &&
              candidate.name.toLowerCase().endsWith('.img'),
        );
        return _prepareGarminImg(
          Uint8List.fromList(entry.content as List<int>),
          fileName: entry.name,
        );
      }
      return ZeppOsPreparedMap(
        bytes: bytes,
        fileName: fileName,
        package: package,
      );
    }
    if (!lowerName.endsWith('.img')) {
      throw FormatException('$fileName 不是支持的 ZIP 或 Garmin IMG 地图');
    }
    _validateImg(bytes, fileName);
    if (bytes.length > 100 * 1024 * 1024) {
      throw FormatException('地图文件大小无效：${bytes.length} 字节');
    }
    return _prepareGarminImg(bytes, fileName: fileName);
  }

  static ZeppOsPreparedMap _prepareGarminImg(
    Uint8List bytes, {
    required String fileName,
  }) {
    final analysis = GarminImgAnalysis.analyze(bytes, fileName: fileName);
    if (!analysis.canConvertDirectly || analysis.maps.length != 1) {
      throw FormatException(analysis.conversionMessage);
    }
    final tile = analysis.maps.single.zoom11Tile!;
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          '11/${tile.x}/${tile.y}.img',
          bytes.length,
          bytes,
        ),
      );
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final outputName = '${_baseNameWithoutExtension(fileName)}-zeppos.zip';
    return ZeppOsPreparedMap(
      bytes: zipBytes,
      fileName: outputName,
      package: validate(zipBytes, fileName: outputName),
    );
  }

  static String _baseNameWithoutExtension(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    final baseName = normalized.substring(normalized.lastIndexOf('/') + 1);
    final dot = baseName.lastIndexOf('.');
    return dot > 0 ? baseName.substring(0, dot) : baseName;
  }

  static ZeppOsMapPackage validate(
    Uint8List bytes, {
    required String fileName,
  }) {
    if (bytes.isEmpty || bytes.length > 100 * 1024 * 1024) {
      throw FormatException('地图包大小无效：${bytes.length} 字节');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FormatException('$fileName 不是有效的 ZIP 地图包：$error');
    }
    final pathPattern = RegExp(r'^11/([0-9]+)/([0-9]+)\.img$');
    final files = archive.files.where((entry) => entry.isFile).toList();
    if (files.length == 1 &&
        files.single.name.toLowerCase().endsWith('.img') &&
        pathPattern.firstMatch(files.single.name) == null) {
      final entry = files.single;
      final content = Uint8List.fromList(entry.content as List<int>);
      _validateImg(content, entry.name);
      if (entry.size <= 0 || entry.size > 0xffffffff) {
        throw FormatException('Garmin IMG 大小无效：${entry.size} 字节');
      }
      return ZeppOsMapPackage(
        uncompressedSize: entry.size,
        tiles: const [],
        kind: ZeppOsMapPackageKind.garminImg,
        garminImgName: entry.name,
        garminAnalysis: GarminImgAnalysis.analyze(
          content,
          fileName: entry.name,
        ),
      );
    }
    var total = 0;
    var count = 0;
    final tiles = <ZeppOsMapTile>[];
    for (final entry in files) {
      final match = pathPattern.firstMatch(entry.name);
      if (match == null ||
          int.parse(match.group(1)!) > 2048 ||
          int.parse(match.group(2)!) > 2048) {
        throw FormatException('地图包包含无效文件：${entry.name}');
      }
      final content = Uint8List.fromList(entry.content as List<int>);
      _validateImg(content, entry.name);
      total += entry.size;
      count += 1;
      tiles.add(
        ZeppOsMapTile(
          x: int.parse(match.group(1)!),
          y: int.parse(match.group(2)!),
        ),
      );
    }
    if (count == 0 || total <= 0 || total > 0xffffffff) {
      throw const FormatException('地图包中没有有效的地图切片');
    }
    tiles.sort((a, b) {
      final row = a.y.compareTo(b.y);
      return row != 0 ? row : a.x.compareTo(b.x);
    });
    return ZeppOsMapPackage(
      uncompressedSize: total,
      tiles: tiles,
      kind: ZeppOsMapPackageKind.zeppTiles,
    );
  }

  static void _validateImg(Uint8List bytes, String fileName) {
    if (bytes.length < 512 ||
        utf8.decode(bytes.sublist(0x10, 0x17), allowMalformed: true) !=
            'DSKIMG\u0000') {
      throw FormatException('$fileName 不是有效的 Garmin IMG 地图');
    }
  }

}

class GarminImgAnalysis {
  const GarminImgAnalysis({
    required this.fileName,
    required this.maps,
    required this.extensions,
    required this.hasTyp,
    required this.hasDem,
    required this.hasRouting,
    required this.isNt,
    required this.isLocked,
  });

  final String fileName;
  final List<GarminImgMapInfo> maps;
  final Set<String> extensions;
  final bool hasTyp;
  final bool hasDem;
  final bool hasRouting;
  final bool isNt;
  final bool isLocked;

  bool get isCombined => maps.length > 1;
  bool get canConvertDirectly =>
      maps.isNotEmpty &&
      !isNt &&
      !isLocked &&
      maps.every((map) => map.zoom11Tile != null);

  String get conversionMessage {
    final features = <String>[
      if (hasTyp) 'TYP',
      if (hasDem) 'DEM',
      if (hasRouting) '路由',
      if (isNt) 'NT/GMP',
      if (isLocked) '锁定',
    ].join('、');
    final prefix =
        '已分析 Garmin IMG：${maps.length} 张内部地图'
        '${features.isEmpty ? '' : '，包含 $features'}。';
    if (isLocked) return '$prefix 地图已锁定，不能转换或发送。';
    if (isNt) return '$prefix 当前不支持 NT/GMP 地图，不能转换或发送。';
    final unsafe = maps.where((map) => map.zoom11Tile == null).toList();
    if (unsafe.isNotEmpty) {
      final details = unsafe
          .map(
            (map) =>
                '${map.mapId} 覆盖约 '
                '${map.zoom11Width}×${map.zoom11Height} 个 zoom 11 格子',
          )
          .join('；');
      return '$prefix $details，边界不符合 11/x/y 网格，'
          '必须从原始地图数据重新切图，不能只拆包改名。';
    }
    return '$prefix 所有内部地图边界均符合 zoom 11 网格，可以转换。';
  }

  static GarminImgAnalysis analyze(
    Uint8List bytes, {
    required String fileName,
  }) {
    if (bytes.length < 0x400 ||
        utf8.decode(bytes.sublist(0x10, 0x17), allowMalformed: true) !=
            'DSKIMG\u0000') {
      throw FormatException('$fileName 不是有效的 Garmin IMG 地图');
    }
    final blockShift = bytes[0x61] + bytes[0x62];
    if (blockShift < 9 || blockShift > 24) {
      throw FormatException('$fileName 的 Garmin IMG 块大小无效');
    }
    final blockSize = 1 << blockShift;
    var directorySize = math.min(bytes.length, 1024 * 1024);
    final entries = <String, _GarminFatFile>{};
    for (var offset = 0x200;
        offset + 512 <= directorySize;
        offset += 512) {
      final entry = Uint8List.sublistView(bytes, offset, offset + 512);
      if (entry[0] != 1) continue;
      final name = ascii
          .decode(entry.sublist(1, 9), allowInvalid: true)
          .trimRight();
      final extension = ascii
          .decode(entry.sublist(9, 12), allowInvalid: true)
          .trimRight()
          .toUpperCase();
      final view = ByteData.sublistView(entry);
      final size = view.getUint32(12, Endian.little);
      final part = view.getUint16(16, Endian.little);
      final blocks = <int>[];
      for (var blockOffset = 0x20; blockOffset < 512; blockOffset += 2) {
        final block = view.getUint16(blockOffset, Endian.little);
        if (block == 0xffff) break;
        blocks.add(block);
      }
      if (name.isEmpty && extension.isEmpty && size >= 0x400) {
        directorySize = math.min(bytes.length, size);
        continue;
      }
      if (name.isEmpty || extension.isEmpty) continue;
      final key = '$name.$extension';
      final file = entries.putIfAbsent(
        key,
        () => _GarminFatFile(name: name, extension: extension, size: size),
      );
      file.parts.add((part: part, blocks: blocks));
    }
    if (entries.isEmpty) {
      throw FormatException('$fileName 没有可读取的 Garmin FAT 目录');
    }

    final extensions = entries.values
        .map((entry) => entry.extension)
        .toSet();
    final maps = <GarminImgMapInfo>[];
    var locked = false;
    for (final entry in entries.values.where(
      (entry) => entry.extension == 'TRE',
    )) {
      final tre = entry.read(bytes, blockSize);
      if (tre.length < 0x21) {
        throw FormatException('${entry.name}.TRE 内容不完整');
      }
      locked = locked || (tre[0x0d] & 0x80) != 0;
      maps.add(
        GarminImgMapInfo.fromTre(
          mapId: entry.name,
          north: _garminDegrees(_signed24(tre, 0x15)),
          east: _garminDegrees(_signed24(tre, 0x18)),
          south: _garminDegrees(_signed24(tre, 0x1b)),
          west: _garminDegrees(_signed24(tre, 0x1e)),
        ),
      );
    }
    maps.sort((a, b) => a.mapId.compareTo(b.mapId));
    return GarminImgAnalysis(
      fileName: fileName,
      maps: maps,
      extensions: extensions,
      hasTyp: extensions.contains('TYP'),
      hasDem: extensions.contains('DEM'),
      hasRouting:
          extensions.contains('NET') || extensions.contains('NOD'),
      isNt: extensions.contains('GMP'),
      isLocked: locked,
    );
  }

  static int _signed24(Uint8List bytes, int offset) {
    var value =
        bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
    if ((value & 0x800000) != 0) value -= 0x1000000;
    return value;
  }

  static double _garminDegrees(int value) => value * 180 / (1 << 23);
}

class GarminImgInput {
  const GarminImgInput({
    required this.bytes,
    required this.fileName,
    required this.analysis,
  });

  final Uint8List bytes;
  final String fileName;
  final GarminImgAnalysis analysis;
}

class GarminImgMapInfo {
  const GarminImgMapInfo({
    required this.mapId,
    required this.north,
    required this.east,
    required this.south,
    required this.west,
    required this.zoom11Width,
    required this.zoom11Height,
    required this.zoom11Tile,
  });

  final String mapId;
  final double north;
  final double east;
  final double south;
  final double west;
  final int zoom11Width;
  final int zoom11Height;
  final ZeppOsMapTile? zoom11Tile;

  factory GarminImgMapInfo.fromTre({
    required String mapId,
    required double north,
    required double east,
    required double south,
    required double west,
  }) {
    const count = 1 << 11;
    final westEdge = (west + 180) / 360 * count;
    final eastEdge = (east + 180) / 360 * count;
    final northEdge = _latitudeToTileY(north, count);
    final southEdge = _latitudeToTileY(south, count);
    final roundedWest = westEdge.round();
    final roundedEast = eastEdge.round();
    final roundedNorth = northEdge.round();
    final roundedSouth = southEdge.round();
    const tolerance = .01;
    final aligned =
        (westEdge - roundedWest).abs() <= tolerance &&
        (eastEdge - roundedEast).abs() <= tolerance &&
        (northEdge - roundedNorth).abs() <= tolerance &&
        (southEdge - roundedSouth).abs() <= tolerance &&
        roundedEast == roundedWest + 1 &&
        roundedSouth == roundedNorth + 1;
    return GarminImgMapInfo(
      mapId: mapId,
      north: north,
      east: east,
      south: south,
      west: west,
      zoom11Width: math.max(1, eastEdge.ceil() - westEdge.floor()),
      zoom11Height: math.max(1, southEdge.ceil() - northEdge.floor()),
      zoom11Tile: aligned
          ? ZeppOsMapTile(x: roundedWest, y: roundedNorth)
          : null,
    );
  }

  static double _latitudeToTileY(double latitude, int count) {
    final radians = latitude * math.pi / 180;
    final tangent = math.tan(radians);
    final inverseHyperbolicSine = math.log(
      tangent + math.sqrt(tangent * tangent + 1),
    );
    return (1 - inverseHyperbolicSine / math.pi) / 2 * count;
  }
}

class _GarminFatFile {
  _GarminFatFile({
    required this.name,
    required this.extension,
    required this.size,
  });

  final String name;
  final String extension;
  final int size;
  final List<({int part, List<int> blocks})> parts = [];

  Uint8List read(Uint8List image, int blockSize) {
    final output = BytesBuilder(copy: false);
    parts.sort((a, b) => a.part.compareTo(b.part));
    for (final part in parts) {
      for (final block in part.blocks) {
        final start = block * blockSize;
        if (start < 0 || start + blockSize > image.length) {
          throw FormatException('$name.$extension 引用了无效数据块 $block');
        }
        output.add(Uint8List.sublistView(image, start, start + blockSize));
      }
    }
    final bytes = output.takeBytes();
    if (size > bytes.length) {
      throw FormatException('$name.$extension 的 FAT 长度无效');
    }
    return Uint8List.sublistView(bytes, 0, size);
  }
}

enum ZeppOsMapPackageKind { zeppTiles, garminImg }

class ZeppOsPreparedMap {
  const ZeppOsPreparedMap({
    required this.bytes,
    required this.fileName,
    required this.package,
  });

  final Uint8List bytes;
  final String fileName;
  final ZeppOsMapPackage package;
}

class ZeppOsMapTile {
  const ZeppOsMapTile({required this.x, required this.y});

  final int x;
  final int y;

  String get openStreetMapUrl => 'https://tile.openstreetmap.org/11/$x/$y.png';
}

class _RawDownloadRequest {
  const _RawDownloadRequest(this.requestId, this.url);
  final int requestId;
  final String url;
}

final Logger _log = getLogger('ZeppOsMapUploadSystem');
