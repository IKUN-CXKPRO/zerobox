import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/providers/ble_service_provider.dart';
import 'package:zerobox/src/core/services/ble_service_manager.dart';
import 'package:zerobox/src/core/services/classic_spp_service.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/device/core/ble_transport.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/runtime.dart';
import 'package:zerobox/src/device/core/spp_transport.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/xiaomi/components/auth_system.dart';
import 'package:zerobox/src/device/xiaomi/components/info_system.dart';
import 'package:zerobox/src/device/xiaomi/components/install_system.dart';
import 'package:zerobox/src/device/xiaomi/components/xiaomi_device_component.dart';
import 'package:zerobox/src/device/xiaomi/xiaomi_device_factory.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart'
    hide ChargeStatus, BatteryInfo, DeviceInfo;
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_thirdparty_app.pb.dart'
    as pb_thirdparty;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;

class DeviceManagerState {
  const DeviceManagerState({
    this.currentDevice,
    this.pairedDevices = const [],
    this.scannedDevices = const [],
    this.scanning = false,
    this.connecting = false,
    this.connectStatus = 0,
    this.protocolState = ProtocolState.disconnected,
    this.battery,
    this.systemInfo,
    this.apps = const [],
    this.watchfaces = const [],
    this.error,
  });

  final MiWearState? currentDevice;
  final List<MiWearState> pairedDevices;
  final List<BTDeviceInfo> scannedDevices;
  final bool scanning;
  final bool connecting;
  final int connectStatus;
  final ProtocolState protocolState;
  final BatteryStatus? battery;
  final SystemInfo? systemInfo;
  final List<AppInfo> apps;
  final List<WatchfaceInfo> watchfaces;
  final String? error;

  DeviceManagerState copyWith({
    MiWearState? currentDevice,
    List<MiWearState>? pairedDevices,
    List<BTDeviceInfo>? scannedDevices,
    bool? scanning,
    bool? connecting,
    int? connectStatus,
    ProtocolState? protocolState,
    BatteryStatus? battery,
    SystemInfo? systemInfo,
    List<AppInfo>? apps,
    List<WatchfaceInfo>? watchfaces,
    String? error,
    bool clearCurrentDevice = false,
    bool clearBattery = false,
    bool clearSystemInfo = false,
    bool clearError = false,
  }) {
    return DeviceManagerState(
      currentDevice: clearCurrentDevice
          ? null
          : (currentDevice ?? this.currentDevice),
      pairedDevices: pairedDevices ?? this.pairedDevices,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      scanning: scanning ?? this.scanning,
      connecting: connecting ?? this.connecting,
      connectStatus: connectStatus ?? this.connectStatus,
      protocolState: protocolState ?? this.protocolState,
      battery: clearBattery ? null : (battery ?? this.battery),
      systemInfo: clearSystemInfo ? null : (systemInfo ?? this.systemInfo),
      apps: apps ?? this.apps,
      watchfaces: watchfaces ?? this.watchfaces,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeviceManager extends Notifier<DeviceManagerState> {
  @override
  DeviceManagerState build() {
    final ble = ref.watch(bleServiceManagerProvider);
    final spp = ref.watch(classicSppServiceProvider);

    _ble = ble;
    _spp = spp;
    _runtime = DeviceRuntime();
    _eventSubscription = _runtime.eventStream.listen(_onDeviceEvent);

    ref.onDispose(() {
      _log.info('DeviceManager disposed');
      _scanTimer?.cancel();
      _ble.stopScan();
      _eventSubscription?.cancel();
      _cleanupConnection();
      _runtime.dispose();
    });

    _log.info('DeviceManager created');
    final initialState = _loadStateSync();

    if (initialState.pairedDevices.isNotEmpty &&
        _shouldAutoReconnect() &&
        !kIsWeb) {
      final last = initialState.pairedDevices.first;
      final authKey = last.authkey;
      if (authKey != null && authKey.isNotEmpty) {
        _log.info(
          'auto reconnect enabled, attempting reconnect to ${last.addr}',
        );
        Future.microtask(() {
          connect(
            last.addr,
            last.name,
            authKey,
            connectType: last.connectType,
          ).catchError((Object e, StackTrace st) {
            _log.warning('auto reconnect to ${last.addr} failed', e, st);
            return;
          });
        });
      } else {
        _log.warning('auto reconnect skipped: no auth key for ${last.addr}');
      }
    }

    return initialState;
  }

  static final _log = getLogger('DeviceManager');
  late BleServiceManager _ble;
  late ClassicSppService _spp;
  late DeviceRuntime _runtime;
  StreamSubscription<DeviceEvent>? _eventSubscription;
  Timer? _scanTimer;
  BleConnection? _bleConnection;
  ClassicSppConnection? _sppConnection;
  DeviceEntity? _currentEntity;

  static const String _keyPairedDevices = 'paired_devices';
  static const String _keyAutoReconnect = 'auto_reconnect';

  DeviceManagerState _loadStateSync() {
    final prefs = SharedPrefsService.instance;
    final saved = prefs.getStringList(_keyPairedDevices) ?? [];
    final paired = saved
        .map((e) {
          try {
            return MiWearState.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (e, st) {
            _log.warning('failed to parse paired device', e, st);
            return null;
          }
        })
        .whereType<MiWearState>()
        .toList();

    _log.info('loaded ${paired.length} paired devices');
    return DeviceManagerState(
      pairedDevices: paired,
      currentDevice: null,
      protocolState: ProtocolState.disconnected,
    );
  }

  bool _shouldAutoReconnect() {
    try {
      return SharedPrefsService.instance.getBool(_keyAutoReconnect) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _savePairedDevices() async {
    final jsonList = state.pairedDevices
        .map((d) => jsonEncode(d.toJson()))
        .toList();
    await SharedPrefsService.instance.setStringList(
      _keyPairedDevices,
      jsonList,
    );
  }

  Future<void> startBleScan() async {
    if (state.scanning) return;
    state = state.copyWith(
      scanning: true,
      scannedDevices: const [],
      clearError: true,
    );

    final available = await _ble.isAvailable();
    if (!available) {
      _log.warning('bluetooth not available');
      state = state.copyWith(
        scanning: false,
        error: 'Bluetooth is not available',
      );
      return;
    }

    try {
      await _ble.requestPermissions();
      await _ble.startScan(timeout: const Duration(seconds: 15));

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), () {
        stopBleScan();
      });
    } catch (e, st) {
      _log.severe('start scan failed', e, st);
      state = state.copyWith(scanning: false, error: e.toString());
    }
  }

  Future<void> stopBleScan() async {
    _log.info('stopping scan');
    _scanTimer?.cancel();
    await _ble.stopScan();
    state = state.copyWith(scanning: false);
  }

  void onScannedDevice(ScannedBTDevice device) {
    final exists = state.scannedDevices.any((d) => d.addr == device.addr);
    if (exists) return;

    final savedAddrs = state.pairedDevices.map((d) => d.addr).toSet();
    if (savedAddrs.contains(device.addr)) return;

    state = state.copyWith(
      scannedDevices: [
        ...state.scannedDevices,
        BTDeviceInfo(
          name: device.name,
          addr: device.addr,
          connectType: _preferredConnectTypeFor(device),
        ),
      ],
    );
  }

  Future<ClassicSppConnection> _connectSppWithRetry(
    String addr,
    String name,
  ) async {
    const maxAttempts = 3;
    const timeout = Duration(seconds: 10);
    Exception? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      _log.info('SPP connect attempt $attempt/$maxAttempts to $addr');
      try {
        final connection = await _spp.connect(addr, name).timeout(timeout);
        _log.info('SPP connected on attempt $attempt');
        return connection;
      } on TimeoutException catch (e) {
        lastError = e;
        _log.warning('SPP connect attempt $attempt timed out');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        _log.warning('SPP connect attempt $attempt failed: $e');
      }

      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    throw lastError ??
        Exception('SPP connect failed after $maxAttempts attempts');
  }

  String _preferredConnectTypeFor(ScannedBTDevice device) {
    final name = device.name.toLowerCase();
    if (name.contains('xiaomi') ||
        name.contains('redmi') ||
        name.contains('mi ') ||
        name.startsWith('mi')) {
      return ConnectType.spp.name;
    }
    return device.connectType.name;
  }

  Future<void> connect(
    String addr,
    String name,
    String authKey, {
    DeviceKind kind = DeviceKind.xiaomi,
    String connectType = 'ble',
  }) async {
    final effectiveConnectType = kIsWeb ? ConnectType.spp.name : connectType;
    _log.info('connecting to $name @ $addr via $effectiveConnectType');
    state = state.copyWith(
      connecting: true,
      connectStatus: 1,
      protocolState: ProtocolState.connecting,
      clearError: true,
    );
    try {
      await stopBleScan();
      await _cleanupConnection();

      final Transport transport;
      if (effectiveConnectType.toLowerCase() == ConnectType.spp.name) {
        _sppConnection = await _connectSppWithRetry(addr, name);
        final sppTransport = SppTransport.xiaomi(_sppConnection!);
        await sppTransport.start();
        transport = sppTransport;
      } else {
        _bleConnection = await _ble.connect(addr, name);
        final bleTransport = BleTransport.xiaomi(_bleConnection!);
        await bleTransport.start();
        transport = bleTransport;
      }

      final entity = _runtime.spawnDevice(
        id: addr,
        kind: deviceKindString(kind),
        transport: transport,
        factory: XiaomiDeviceFactory(),
      );
      _currentEntity = entity;

      final component = entity.get<XiaomiDeviceComponent>()!;
      await component
          .startSession(
            spp: effectiveConnectType.toLowerCase() == ConnectType.spp.name,
          )
          .timeout(const Duration(seconds: 10));

      final authSystem = entity.system<XiaomiAuthSystem>()!;
      _log.info('starting authentication');
      await authSystem
          .authenticate(authKey)
          .timeout(const Duration(seconds: 10));
      _log.info('authentication succeeded');

      final connected = MiWearState(
        name: name,
        addr: addr,
        connectType: effectiveConnectType,
        authkey: authKey,
        disconnected: false,
      );
      final existingIndex = state.pairedDevices.indexWhere(
        (d) => d.addr == addr,
      );
      final updatedPaired = List<MiWearState>.from(state.pairedDevices);
      if (existingIndex >= 0) {
        updatedPaired[existingIndex] = connected;
      } else {
        updatedPaired.add(connected);
      }

      state = state.copyWith(
        currentDevice: connected,
        pairedDevices: updatedPaired,
        connecting: false,
        connectStatus: 2,
        protocolState: ProtocolState.ready,
      );
      await _savePairedDevices();
      unawaited(_loadInitialDeviceData(entity));
    } catch (e, st) {
      _log.severe('connect to $addr failed', e, st);
      state = state.copyWith(
        connecting: false,
        connectStatus: 3,
        protocolState: ProtocolState.error,
        error: e.toString(),
      );
      await _cleanupConnection();
    }
  }

  Future<void> _loadInitialDeviceData(DeviceEntity entity) async {
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) return;
    try {
      await infoSystem.fetchBatteryInfo();
    } catch (e, st) {
      _log.warning('initial battery fetch failed', e, st);
    }
    try {
      await infoSystem.fetchDeviceInfo();
    } catch (e, st) {
      _log.warning('initial device info fetch failed', e, st);
    }
  }

  void _onDeviceEvent(DeviceEvent event) {
    if (event.deviceId != state.currentDevice?.addr) return;

    switch (event) {
      case DeviceAuthenticated _:
        _log.info('event: authenticated');
        state = state.copyWith(protocolState: ProtocolState.ready);
      case AuthFailed(:final error):
        _log.warning('event: auth failed: $error');
        state = state.copyWith(
          protocolState: ProtocolState.error,
          error: error,
        );
      case TransportDisconnected _:
        _log.warning('event: transport disconnected');
        _onDisconnected();
      case BatteryUpdated(:final battery):
        _log.info('event: battery ${battery.capacity}%');
        state = state.copyWith(battery: battery);
      case DeviceInfoUpdated(:final info):
        _log.info('event: device info ${info.model}');
        state = state.copyWith(systemInfo: info);
        final current = state.currentDevice;
        if (current != null &&
            info.model.isNotEmpty &&
            current.name != info.model) {
          final renamed = current.copyWith(name: info.model);
          final updatedPaired = state.pairedDevices.map((d) {
            return d.addr == current.addr ? renamed : d;
          }).toList();
          state = state.copyWith(
            currentDevice: renamed,
            pairedDevices: updatedPaired,
          );
          _savePairedDevices();
        }
      case AppListUpdated(:final apps):
        _log.info('event: app list ${apps.length}');
        state = state.copyWith(apps: apps);
      case WatchfaceListUpdated(:final watchfaces):
        _log.info('event: watchface list ${watchfaces.length}');
        state = state.copyWith(watchfaces: watchfaces);
      case InstallProgress _:
        // Progress is consumed via callback in install UI.
        break;
      case InstallCompleted _:
        _log.info('event: install completed');
      case InstallFailed(:final error):
        _log.warning('event: install failed: $error');
        state = state.copyWith(error: error);
      case DeviceError(:final error):
        _log.warning('event: device error: $error');
        state = state.copyWith(error: error);
      default:
        break;
    }
  }

  void _onDisconnected() {
    final current = state.currentDevice;
    if (current == null) return;
    final disconnected = current.copyWith(disconnected: true);
    final updatedPaired = state.pairedDevices.map((d) {
      return d.addr == current.addr ? disconnected : d;
    }).toList();
    state = state.copyWith(
      currentDevice: disconnected,
      pairedDevices: updatedPaired,
      connectStatus: 0,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearSystemInfo: true,
    );
    _savePairedDevices();
    _cleanupConnection();
  }

  Future<void> disconnect() async {
    final current = state.currentDevice;
    if (current == null) return;
    final disconnected = current.copyWith(disconnected: true);
    final updatedPaired = state.pairedDevices.map((d) {
      return d.addr == current.addr ? disconnected : d;
    }).toList();
    await _cleanupConnection();
    state = state.copyWith(
      currentDevice: disconnected,
      pairedDevices: updatedPaired,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearSystemInfo: true,
      clearError: true,
    );
    await _savePairedDevices();
  }

  Future<void> _cleanupConnection() async {
    final ble = _bleConnection;
    final spp = _sppConnection;
    final entity = _currentEntity;
    _bleConnection = null;
    _sppConnection = null;
    _currentEntity = null;

    if (entity != null) {
      _log.info('cleaning up connection to ${entity.id}');
      _runtime.removeDevice(entity.id);
    }

    final futures = <Future<void>>[];
    if (ble != null) {
      futures.add(
        ble.dispose().catchError((Object e, StackTrace st) {
          _log.warning('BLE dispose failed', e, st);
        }),
      );
    }
    if (spp != null) {
      futures.add(
        spp.dispose().catchError((Object e, StackTrace st) {
          _log.warning('SPP dispose failed', e, st);
        }),
      );
    }
    await Future.wait(futures);
  }

  Future<void> removeDevice(String addr) async {
    final updatedPaired = state.pairedDevices
        .where((d) => d.addr != addr)
        .toList();
    final removedCurrent = state.currentDevice?.addr == addr;
    if (removedCurrent) {
      await _cleanupConnection();
    }
    state = state.copyWith(
      pairedDevices: updatedPaired,
      currentDevice: removedCurrent ? null : state.currentDevice,
      protocolState: removedCurrent
          ? ProtocolState.disconnected
          : state.protocolState,
      clearBattery: removedCurrent,
      clearSystemInfo: removedCurrent,
      clearError: true,
    );
    await _savePairedDevices();
  }

  Future<void> refreshBattery() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchBatteryInfo();
  }

  Future<void> fetchSystemInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchDeviceInfo();
  }

  Future<void> fetchApps() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchInstalledApps();
  }

  Future<void> fetchWatchfaces() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    final watchfaces = await infoSystem.fetchInstalledWatchfaces();
    state = state.copyWith(watchfaces: watchfaces);
  }

  Future<void> uninstallApp(AppInfo app) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('uninstalling app ${app.packageName}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.THIRDPARTY_APP,
      id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.REMOVE_APP.value,
      thirdpartyApp: pb_thirdparty.ThirdpartyApp(
        basicInfo: pb_thirdparty.BasicInfo(packageName: app.packageName),
      ),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      apps: state.apps.where((a) => a.packageName != app.packageName).toList(),
    );
  }

  Future<void> uninstallWatchface(WatchfaceInfo watchface) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('uninstalling watchface ${watchface.id}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.WATCH_FACE,
      id: pb_watchface.WatchFace_WatchFaceID.REMOVE_WATCH_FACE.value,
      watchFace: pb_watchface.WatchFace(id: watchface.id),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      watchfaces: state.watchfaces.where((w) => w.id != watchface.id).toList(),
    );
  }

  Future<void> setWatchface(WatchfaceInfo watchface) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('setting watchface ${watchface.id}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.WATCH_FACE,
      id: pb_watchface.WatchFace_WatchFaceID.SET_WATCH_FACE.value,
      watchFace: pb_watchface.WatchFace(id: watchface.id),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      watchfaces: state.watchfaces.map((w) {
        return w.id == watchface.id
            ? w.copyWith(isCurrent: true)
            : w.copyWith(isCurrent: false);
      }).toList(),
    );
  }

  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('installing app $packageName (${packageBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installApp(
      packageBytes,
      packageName: packageName,
      onProgress: onProgress,
    );
  }

  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info(
      'installing watchface $watchfaceId (${watchfaceBytes.length} bytes)',
    );
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installWatchface(
      watchfaceBytes,
      watchfaceId: watchfaceId,
      onProgress: onProgress,
    );
  }

  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('installing firmware (${firmwareBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installFirmware(firmwareBytes, onProgress: onProgress);
  }

  Future<void> importSharedDevice(MiWearState device) async {
    final normalized = device.copyWith(
      connectType: device.connectType.toLowerCase().isEmpty
          ? ConnectType.spp.name
          : device.connectType.toLowerCase(),
      disconnected: true,
    );
    final updatedPaired = List<MiWearState>.from(state.pairedDevices);
    final existingIndex = updatedPaired.indexWhere(
      (d) => d.addr == normalized.addr,
    );
    if (existingIndex >= 0) {
      updatedPaired[existingIndex] = normalized;
    } else {
      updatedPaired.add(normalized);
    }
    state = state.copyWith(
      currentDevice:
          state.currentDevice == null ||
              state.currentDevice?.addr == normalized.addr
          ? normalized
          : state.currentDevice,
      pairedDevices: updatedPaired,
      clearError: true,
    );
    await _savePairedDevices();
  }

  Future<int> importMiCloudDevices(List<MiCloudDevice> devices) async {
    final importable = devices.where((device) => device.hasAuthKey).toList();
    if (importable.isEmpty) return 0;

    final updatedPaired = List<MiWearState>.from(state.pairedDevices);
    for (final device in importable) {
      final imported = MiWearState(
        name: device.name.trim().isNotEmpty ? device.name.trim() : device.model,
        addr: device.mac.trim(),
        connectType: ConnectType.spp.name,
        authkey: device.authKey.trim(),
        codename: device.model.trim().isEmpty ? null : device.model.trim(),
        disconnected: true,
      );
      final existingIndex = updatedPaired.indexWhere(
        (d) => d.addr == imported.addr,
      );
      if (existingIndex >= 0) {
        updatedPaired[existingIndex] = imported;
      } else {
        updatedPaired.add(imported);
      }
    }

    final current = state.currentDevice;
    state = state.copyWith(
      currentDevice: current == null
          ? updatedPaired.firstWhere(
              (d) => d.addr == importable.first.mac.trim(),
            )
          : updatedPaired.firstWhere(
              (d) => d.addr == current.addr,
              orElse: () => current,
            ),
      pairedDevices: updatedPaired,
      clearError: true,
    );
    await _savePairedDevices();
    return importable.length;
  }
}

final deviceManagerProvider =
    NotifierProvider<DeviceManager, DeviceManagerState>(
      DeviceManager.new,
      isAutoDispose: true,
    );
