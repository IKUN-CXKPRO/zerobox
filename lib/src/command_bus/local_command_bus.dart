import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/huami_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/mi_account_service.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';

class LocalCommandBus implements ZeroBoxCommandBus {
  LocalCommandBus(this.container) {
    _deviceManagerSubscription = container.listen<DeviceManagerState>(
      deviceManagerProvider,
      (_, state) => _events.add(
        CommandEvent('device.state', data: {'state': _deviceStateJson(state)}),
      ),
      fireImmediately: true,
    );
    _logSubscription = zeroBoxLogStream.listen(
      (line) => _events.add(CommandEvent('log', data: {'message': line})),
    );
  }

  final ProviderContainer container;
  final _events = StreamController<CommandEvent>.broadcast();
  late final ProviderSubscription<DeviceManagerState>
  _deviceManagerSubscription;
  late final StreamSubscription<String> _logSubscription;
  bool _activeCommandCancelled = false;
  Future<void> _commandTail = Future<void>.value();

  DeviceManager get _manager => container.read(deviceManagerProvider.notifier);
  DeviceManagerState get _state => container.read(deviceManagerProvider);

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    final previous = _commandTail;
    final turn = Completer<void>();
    _commandTail = turn.future;
    await previous;
    try {
      return await _execute(command);
    } finally {
      turn.complete();
    }
  }

  Future<CommandResult> _execute(ZeroBoxCommand command) async {
    _activeCommandCancelled = false;
    try {
      final result = await _dispatch(command);
      return CommandResult.success(result);
    } on CommandFailure catch (error) {
      return CommandResult.failure(
        CommandError(error.code, error.message, details: error.details),
      );
    } catch (error, stackTrace) {
      return CommandResult.failure(
        CommandError('internal', error.toString(), details: '$stackTrace'),
      );
    }
  }

  Future<void> cancelActiveOperation() async {
    _activeCommandCancelled = true;
    if (_state.connecting || _state.protocolState == ProtocolState.ready) {
      await _manager.disconnect();
    }
  }

  void _throwIfCancelled() {
    if (_activeCommandCancelled) {
      throw const CommandFailure('cancelled', 'Operation was cancelled');
    }
  }

  Future<Object?> _dispatch(ZeroBoxCommand command) => switch (command.method) {
    'status' => Future.value(_status()),
    'device.snapshot' => Future.value(_deviceStateJson(_state)),
    'device.paired' => Future.value(
      _state.pairedDevices.map(_deviceJson).toList(growable: false),
    ),
    'device.status' => Future.value(_status()),
    'device.connect' => _connect(command.params['device']?.toString()),
    'device.disconnect' => _disconnect(),
    'device.scan' => _scan(command.params),
    'device.scan.start' => _scanStart(command.params),
    'device.scan.stop' => _scanStop(),
    'device.info' => _deviceInfo(),
    'device.refresh.battery' => _refreshBattery(),
    'device.refresh.system' => _refreshSystem(),
    'device.refresh.storage' => _refreshStorage(),
    'device.zeppos.find' => _setFindingZeppOsDevice(
      command.params['finding'] == true,
    ),
    'device.remove' => _removeDevice(command.params['device']?.toString()),
    'device.import' => _importDevice(command.params),
    'app.list' => _listApps(),
    'app.uninstall' => _uninstallApp(command.params['package']?.toString()),
    'app.launch' => _launchApp(command.params['package']?.toString()),
    'watchface.list' => _listWatchfaces(),
    'watchface.remove' => _removeWatchface(command.params['id']?.toString()),
    'watchface.set' => _setWatchface(command.params['id']?.toString()),
    'settings.list' => Future.value(_settingsList()),
    'settings.get' => Future.value(
      _settingsGet(command.params['key']?.toString()),
    ),
    'settings.set' => _settingsSet(command.params),
    'resource.sources' => Future.value(
      CommunitySourceId.values
          .map(
            (source) => {'id': source.storageKey, 'name': source.displayName},
          )
          .toList(growable: false),
    ),
    'resource.list' || 'resource.search' => _resourceList(command.params),
    'resource.info' => _resourceInfo(command.params),
    'resource.download' => _resourceDownload(command.params, install: false),
    'resource.install' => _resourceDownload(command.params, install: true),
    'account.list' => Future.value(_accountList()),
    'account.status' => Future.value(
      _freshAccountStatus(command.params['provider']?.toString()),
    ),
    'account.login' => _accountLogin(command.params),
    'account.logout' => _accountLogout(command.params['provider']?.toString()),
    'logs.recent' => Future.value(recentZeroBoxLogs),
    'install.local' => _installLocal(command.params),
    _ => throw CommandFailure(
      'unknown_command',
      'Unknown command: ${command.method}',
    ),
  };

  Map<String, Object?> _status() {
    final current = _state.currentDevice;
    return {
      'connected': _state.protocolState == ProtocolState.ready,
      'protocolState': _state.protocolState.name,
      if (current != null) 'device': _deviceJson(current),
      if (_state.battery != null) 'battery': _state.battery!.capacity,
      if (_state.error != null) 'error': _state.error,
    };
  }

  Map<String, Object?> _deviceStateJson(DeviceManagerState state) => {
    if (state.currentDevice != null)
      'currentDevice': state.currentDevice!.toJson(),
    'pairedDevices': state.pairedDevices.map((item) => item.toJson()).toList(),
    'scannedDevices': state.scannedDevices
        .map((item) => item.toJson())
        .toList(),
    'scanning': state.scanning,
    'connecting': state.connecting,
    'connectStatus': state.connectStatus,
    'protocolState': state.protocolState.name,
    if (state.battery != null) 'battery': state.battery!.toJson(),
    if (state.systemInfo != null) 'systemInfo': state.systemInfo!.toJson(),
    'apps': state.apps.map((item) => item.toJson()).toList(),
    'watchfaces': state.watchfaces.map((item) => item.toJson()).toList(),
    if (state.error != null) 'error': state.error,
  };

  Future<Object?> _connect(String? requestedAddress) async {
    final paired = _state.pairedDevices;
    if (paired.isEmpty) {
      throw const CommandFailure('no_device', 'No paired devices found');
    }
    final target = requestedAddress == null || requestedAddress.isEmpty
        ? paired.first
        : paired.where((device) => device.addr == requestedAddress).firstOrNull;
    if (target == null) {
      throw CommandFailure(
        'no_device',
        'Paired device not found: $requestedAddress',
      );
    }
    if (_state.protocolState == ProtocolState.ready &&
        _state.currentDevice?.addr == target.addr) {
      return _deviceJson(target);
    }
    final authKey = target.authkey ?? '';
    if (authKey.isEmpty) {
      throw CommandFailure(
        'connection',
        'Device has no authentication key: ${target.addr}',
      );
    }
    _events.add(CommandEvent('connecting', data: _deviceJson(target)));
    await _manager.connect(
      target.addr,
      target.name,
      authKey,
      connectType: target.connectType,
    );
    if (_state.protocolState != ProtocolState.ready) {
      final reason = _state.error;
      throw CommandFailure(
        'connection',
        reason == null || reason.isEmpty
            ? 'Device did not become ready: ${target.addr}'
            : 'Failed to connect ${target.addr}: $reason',
      );
    }
    _events.add(CommandEvent('connected', data: _deviceJson(target)));
    return _deviceJson(_state.currentDevice ?? target);
  }

  Future<Object?> _disconnect() async {
    await _manager.disconnect();
    _events.add(const CommandEvent('disconnected'));
    return const {'disconnected': true};
  }

  Future<Object?> _scan(Map<String, Object?> params) async {
    final seconds = int.tryParse(params['timeout']?.toString() ?? '') ?? 10;
    final connectType = switch (params['connectType']?.toString()) {
      'spp' => ConnectType.spp,
      _ => ConnectType.ble,
    };
    await _manager.startBluetoothScan(connectType: connectType);
    await Future<void>.delayed(Duration(seconds: seconds.clamp(1, 15)));
    await _manager.stopBluetoothScan();
    return _state.scannedDevices
        .map(
          (device) => {
            'name': device.name,
            'address': device.addr,
            'connectType': device.connectType,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _scanStart(Map<String, Object?> params) async {
    final connectType = switch (params['connectType']?.toString()) {
      'spp' => ConnectType.spp,
      _ => ConnectType.ble,
    };
    await _manager.startBluetoothScan(connectType: connectType);
    return {'scanning': _state.scanning};
  }

  Future<Object?> _scanStop() async {
    await _manager.stopBluetoothScan();
    return _deviceStateJson(_state);
  }

  Future<Object?> _removeDevice(String? address) async {
    if (address == null || address.isEmpty) {
      throw const CommandFailure('usage', 'Missing device address');
    }
    await _manager.removeDevice(address);
    return _deviceStateJson(_state);
  }

  Future<Object?> _importDevice(Map<String, Object?> params) async {
    final raw = params['device'];
    if (raw is! Map) {
      throw const CommandFailure('usage', 'Missing device payload');
    }
    await _manager.importSharedDevice(
      MiWearState.fromJson(raw.cast<String, dynamic>()),
    );
    return _deviceStateJson(_state);
  }

  Future<Object?> _deviceInfo() async {
    await _ensureConnected(null);
    await _manager.refreshBattery();
    await _manager.fetchSystemInfo();
    await _manager.fetchStorageInfo();
    final device = _state.currentDevice;
    final info = _state.systemInfo;
    final battery = _state.battery;
    return {
      if (device != null)
        'device': {
          'name': device.name,
          'address': device.addr,
          if (device.authkey != null) 'authKey': device.authkey,
          'connectionType': device.connectType,
          if (device.codename != null) 'codename': device.codename,
        },
      if (info != null)
        'system': {
          'model': info.model,
          'imei': info.imei,
          'firmwareVersion': info.firmwareVersion,
          'serialNumber': info.serialNumber,
          if (info.storageInfo != null)
            'storage': {
              'used': info.storageInfo!.used,
              'total': info.storageInfo!.total,
              'free': info.storageInfo!.total - info.storageInfo!.used,
            },
        },
      if (battery != null)
        'status': {
          'battery': battery.capacity,
          'chargeStatus': battery.chargeStatus.name,
          if (battery.chargeInfo != null)
            'chargeInfo': {
              'state': battery.chargeInfo!.state,
              if (battery.chargeInfo!.timestamp != null)
                'timestamp': battery.chargeInfo!.timestamp,
            },
        },
    };
  }

  Future<Object?> _refreshBattery() async {
    await _ensureConnected(null);
    await _manager.refreshBattery();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshSystem() async {
    await _ensureConnected(null);
    await _manager.fetchSystemInfo();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshStorage() async {
    await _ensureConnected(null);
    await _manager.fetchStorageInfo();
    return _deviceStateJson(_state);
  }

  Future<Object?> _setFindingZeppOsDevice(bool finding) async {
    await _ensureConnected(null);
    await _manager.setFindingZeppOsDevice(finding);
    return {'finding': finding};
  }

  Future<Object?> _listApps() async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    return _state.apps
        .map(
          (app) => {
            'packageName': app.packageName,
            'name': app.appName,
            'versionCode': app.versionCode,
            'canRemove': app.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _listWatchfaces() async {
    await _ensureConnected(null);
    await _manager.fetchWatchfaces();
    return _state.watchfaces
        .map(
          (face) => {
            'id': face.id,
            'name': face.name,
            'current': face.isCurrent,
            'canRemove': face.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _uninstallApp(String? packageName) async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    final app = _state.apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw CommandFailure('not_found', 'App not found: $packageName');
    }
    await _manager.uninstallApp(app);
    for (var attempt = 0; attempt < 10; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _manager.fetchApps();
      if (_state.apps.every(
        (candidate) => candidate.packageName != packageName,
      )) {
        return {'removed': packageName};
      }
    }
    throw CommandFailure(
      'operation_failed',
      'App is still installed after removal request: $packageName',
    );
  }

  Future<Object?> _launchApp(String? packageName) async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    final app = _state.apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw CommandFailure('not_found', 'App not found: $packageName');
    }
    await _manager.openApp(app);
    return {'launched': packageName};
  }

  Future<Object?> _removeWatchface(String? id) async {
    final face = await _watchface(id);
    await _manager.uninstallWatchface(face);
    return {'removed': id};
  }

  Future<Object?> _setWatchface(String? id) async {
    final face = await _watchface(id);
    await _manager.setWatchface(face);
    return {'current': id};
  }

  Future<WatchfaceInfo> _watchface(String? id) async {
    await _ensureConnected(null);
    await _manager.fetchWatchfaces();
    final face = _state.watchfaces
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (face == null) {
      throw CommandFailure('not_found', 'Watchface not found: $id');
    }
    return face;
  }

  static const _settingKeys = <String>{
    'auto_reconnect',
    'auto_install',
    'community_source',
    'desktop.exit_behavior',
  };

  Map<String, Object?> _settingsList() => {
    for (final key in _settingKeys) key: _readSetting(key),
  };

  Object? _settingsGet(String? key) {
    _validateSettingKey(key);
    return {'key': key, 'value': _readSetting(key!)};
  }

  Future<Object?> _settingsSet(Map<String, Object?> params) async {
    final key = params['key']?.toString();
    _validateSettingKey(key);
    final raw = params['value'];
    final prefs = SharedPrefsService.instance;
    if (raw == null) {
      await prefs.remove(key!);
    } else if (raw is bool) {
      await prefs.setBool(key!, raw);
    } else if (raw is int) {
      await prefs.setInt(key!, raw);
    } else {
      await prefs.setString(key!, raw.toString());
    }
    return {'key': key, 'value': _readSetting(key)};
  }

  void _validateSettingKey(String? key) {
    if (key == null || !_settingKeys.contains(key)) {
      throw CommandFailure('usage', 'Unsupported setting key: $key');
    }
  }

  Object? _readSetting(String key) {
    final prefs = SharedPrefsService.instance;
    return switch (key) {
      'auto_reconnect' || 'auto_install' => prefs.getBool(key),
      'desktop.exit_behavior' => prefs.getInt(key),
      'community_source' => prefs.getString(key),
      _ => null,
    };
  }

  Future<Object?> _installLocal(Map<String, Object?> params) async {
    final path = params['path']?.toString() ?? '';
    final typeName = params['type']?.toString() ?? '';
    if (path.isEmpty) {
      throw const CommandFailure('usage', 'Missing resource path');
    }
    final type = switch (typeName) {
      'quickapp' || 'app' => LocalDeviceInstallType.app,
      'watchface' => LocalDeviceInstallType.watchface,
      'firmware' => LocalDeviceInstallType.firmware,
      _ => throw CommandFailure('usage', 'Unsupported install type: $typeName'),
    };
    final file = File(path);
    if (!await file.exists()) {
      throw CommandFailure('file', 'File not found: $path');
    }
    try {
      final bytes = await file.readAsBytes();
      _throwIfCancelled();
      await _ensureConnected(params['device']?.toString());
      _throwIfCancelled();
      final service = container.read(resourceInstallServiceProvider);
      await service.installLocalPayload(
        type: type,
        fileName: file.uri.pathSegments.last,
        bytes: bytes,
        deviceManager: _manager,
        onProgress: (progress) => _events.add(
          CommandEvent('progress', data: {'progress': progress, 'path': path}),
        ),
      );
      _events.add(CommandEvent('completed', data: {'path': path}));
      return {'installed': true, 'path': path, 'type': typeName};
    } finally {
      if (params['deleteAfter'] == true && await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Object?> _resourceList(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final source = _source(params['source']?.toString());
    final catalog = container.read(communityCatalogProviderForSource(source));
    final type = _resourceType(params['type']?.toString(), required: false);
    final page = await catalog.getPage(
      CommunityResourceQuery(
        page: int.tryParse(params['page']?.toString() ?? '') ?? 0,
        pageSize: int.tryParse(params['pageSize']?.toString() ?? '') ?? 30,
        query: params['query']?.toString() ?? '',
        type: type,
        selectedDevices: {
          if (params['device']?.toString().isNotEmpty == true)
            params['device'].toString(),
        },
      ),
    );
    return {
      'page': page.page,
      'hasMore': page.hasMore,
      if (page.total != null) 'total': page.total,
      'items': page.items.map(_resourceJson).toList(growable: false),
    };
  }

  Future<Object?> _resourceInfo(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final ref = _resourceRef(params);
    final catalog = container.read(
      communityCatalogProviderForSource(ref.source),
    );
    final detail = await catalog.getDetail(ref);
    _throwIfCancelled();
    return _resourceDetailJson(detail);
  }

  Future<Object?> _resourceDownload(
    Map<String, Object?> params, {
    required bool install,
  }) async {
    _reloadPersistedAccounts();
    final ref = _resourceRef(params);
    final catalog = container.read(
      communityCatalogProviderForSource(ref.source),
    );
    final detail = await catalog.getDetail(ref);
    if (detail.files.isEmpty) {
      throw CommandFailure(
        'not_found',
        'Resource has no downloadable files: ${ref.key}',
      );
    }
    final requestedFile = params['file']?.toString();
    final file = requestedFile == null
        ? detail.files.first
        : detail.files
              .where((candidate) => candidate.id == requestedFile)
              .firstOrNull;
    if (file == null) {
      throw CommandFailure(
        'not_found',
        'Resource file not found: $requestedFile',
      );
    }
    final service = container.read(resourceInstallServiceProvider);
    final downloaded = await service.downloadResource(
      resource: detail,
      file: file,
      catalog: catalog,
      targetDevice: params['targetDevice']?.toString(),
      onUpdate: (status, progress, error) => _events.add(
        CommandEvent(
          status.name,
          data: {'progress': progress, if (error != null) 'error': error},
        ),
      ),
    );
    _throwIfCancelled();
    if (downloaded == null) {
      throw const CommandFailure('download', 'Resource download failed');
    }
    if (install) {
      await _ensureConnected(params['device']?.toString());
      _throwIfCancelled();
      await service.installLocalPayload(
        type: switch (detail.type) {
          CommunityResourceType.quickApp => LocalDeviceInstallType.app,
          CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
          CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
          _ => throw CommandFailure(
            'validation',
            'Resource type cannot be installed: ${detail.type.name}',
          ),
        },
        fileName: downloaded.fileName,
        bytes: downloaded.bytes ?? await File(downloaded.path).readAsBytes(),
        deviceManager: _manager,
        onProgress: (progress) =>
            _events.add(CommandEvent('progress', data: {'progress': progress})),
      );
    }
    return {
      'path': downloaded.path,
      'fileName': downloaded.fileName,
      'installed': install,
    };
  }

  CommunitySourceId _source(String? value) {
    final normalized = value ?? 'astrobox-repo';
    if (normalized == 'amazfit' || normalized == 'huami') {
      return CommunitySourceId.huamiAppStore;
    }
    final source = communitySourceIdByName(normalized);
    if (source == null) {
      throw CommandFailure('usage', 'Unknown resource source: $normalized');
    }
    return source;
  }

  CommunityResourceType? _resourceType(
    String? value, {
    required bool required,
  }) {
    if (value == null || value.isEmpty) {
      if (required) {
        throw const CommandFailure('usage', 'Missing resource type');
      }
      return null;
    }
    return switch (value) {
      'quickapp' || 'miniprogram' => CommunityResourceType.quickApp,
      'watchface' => CommunityResourceType.watchface,
      'firmware' => CommunityResourceType.firmware,
      'fontpack' => CommunityResourceType.fontpack,
      'iconpack' => CommunityResourceType.iconpack,
      _ => throw CommandFailure('usage', 'Unknown resource type: $value'),
    };
  }

  ResourceRef _resourceRef(Map<String, Object?> params) {
    final raw = params['ref']?.toString() ?? '';
    final separator = raw.indexOf(':');
    if (separator <= 0 || separator == raw.length - 1) {
      throw CommandFailure('usage', 'Resource ref must be <source>:<id>: $raw');
    }
    return ResourceRef(
      source: _source(raw.substring(0, separator)),
      id: raw.substring(separator + 1),
    );
  }

  Map<String, Object?> _resourceJson(CommunityResource resource) => {
    'ref': resource.ref.key,
    'name': resource.name,
    'type': resource.type.name,
    'paidType': resource.paidType.name,
    'authors': resource.authors.map((author) => author.name).toList(),
    'devices': resource.supportedDevices.toList(),
    if (resource.tags.isNotEmpty) 'tags': resource.tags,
    if (resource.summary.isNotEmpty) 'summary': resource.summary,
    if (resource.version != null) 'version': resource.version,
  };

  Map<String, Object?> _resourceDetailJson(CommunityResourceDetail detail) => {
    ..._resourceJson(detail),
    'content': detail.content.value,
    'canDownload': detail.canDownload,
    'files': detail.files
        .map(
          (file) => {
            'id': file.id,
            'fileName': file.fileName,
            'version': file.version,
            if (file.size != null) 'size': file.size,
          },
        )
        .toList(growable: false),
  };

  List<Map<String, Object?>> _accountList() {
    _reloadPersistedAccounts();
    return [
      _accountStatus('xiaomi'),
      _accountStatus('amazfit'),
      _accountStatus('bandbbs'),
    ];
  }

  void _reloadPersistedAccounts() {
    container.invalidate(huamiAuthProvider);
    container.invalidate(bandBbsAuthProvider);
  }

  Map<String, Object?> _freshAccountStatus(String? provider) {
    _reloadPersistedAccounts();
    return _accountStatus(provider);
  }

  Map<String, Object?> _accountStatus(String? provider) {
    return switch (provider) {
      'xiaomi' => {
        'provider': 'xiaomi',
        'signedIn': _state.pairedDevices.isNotEmpty,
        'syncedDevices': _state.pairedDevices.length,
      },
      'amazfit' || 'huami' => () {
        final account = container.read(huamiAuthProvider);
        return {
          'provider': 'amazfit',
          'signedIn': account.isSignedIn,
          if (account.username != null) 'username': account.username,
        };
      }(),
      'bandbbs' => () {
        final account = container.read(bandBbsAuthProvider);
        return {
          'provider': 'bandbbs',
          'signedIn': account.isSignedIn,
          if (account.username != null) 'username': account.username,
          if (account.userId != null) 'userId': account.userId,
        };
      }(),
      _ => throw CommandFailure('usage', 'Unknown account provider: $provider'),
    };
  }

  Future<Object?> _accountLogin(Map<String, Object?> params) async {
    final provider = params['provider']?.toString();
    final username = params['username']?.toString() ?? '';
    final password = params['password']?.toString() ?? '';
    switch (provider) {
      case 'amazfit':
      case 'huami':
        if (username.isEmpty || password.isEmpty) {
          throw const CommandFailure(
            'usage',
            'Amazfit username and password are required',
          );
        }
        await container
            .read(huamiAuthProvider.notifier)
            .login(username: username, password: password);
        return _accountStatus('amazfit');
      case 'xiaomi':
        if (username.isEmpty || password.isEmpty) {
          throw const CommandFailure(
            'usage',
            'Xiaomi username and password are required',
          );
        }
        final service = container.read(miAccountServiceProvider);
        final token = await service.login(
          username: username,
          password: password,
        );
        final devices = await service.fetchBoundDevices(token: token);
        final imported = await _manager.importMiCloudDevices(devices);
        return {
          'provider': 'xiaomi',
          'signedIn': true,
          'importedDevices': imported,
        };
      case 'bandbbs':
        await container.read(bandBbsAuthProvider.notifier).startLogin();
        return const {'provider': 'bandbbs', 'authorizationStarted': true};
      default:
        throw CommandFailure('usage', 'Unknown account provider: $provider');
    }
  }

  Future<Object?> _accountLogout(String? provider) async {
    switch (provider) {
      case 'amazfit':
      case 'huami':
        await container.read(huamiAuthProvider.notifier).signOut();
        return {'provider': 'amazfit', 'signedIn': false};
      case 'bandbbs':
        await container.read(bandBbsAuthProvider.notifier).signOut();
        return {'provider': 'bandbbs', 'signedIn': false};
      case 'xiaomi':
        throw const CommandFailure(
          'unsupported',
          'Xiaomi credentials are not persisted as a login session',
        );
      default:
        throw CommandFailure('usage', 'Unknown account provider: $provider');
    }
  }

  Future<void> _ensureConnected(String? address) async {
    if (_state.protocolState == ProtocolState.ready &&
        (address == null || _state.currentDevice?.addr == address)) {
      return;
    }
    await _connect(address);
  }

  Map<String, Object?> _deviceJson(MiWearState device) => {
    'name': device.name,
    'address': device.addr,
    'connectType': device.connectType,
    if (device.codename != null) 'codename': device.codename,
    'disconnected': device.disconnected,
  };

  @override
  Future<void> close() async {
    _deviceManagerSubscription.close();
    await _logSubscription.cancel();
    await _events.close();
  }
}

class CommandFailure implements Exception {
  const CommandFailure(this.code, this.message, {this.details});
  final String code;
  final String message;
  final Object? details;
}
