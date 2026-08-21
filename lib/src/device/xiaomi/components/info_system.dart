import 'dart:async';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/models/bt_models.dart' as models;
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_clock.pb.dart'
    as pb_clock;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_common.pb.dart'
    as pb_common;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_weather.pb.dart'
    as pb_weather;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_lpa.pb.dart'
    as pb_lpa;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;
import 'package:oronbox/src/protocols/xiaomi/commands/xiaomi_request_pool.dart';

class XiaomiInfoSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiInfoSystem');

  Future<models.BatteryStatus> fetchBatteryInfo() async {
    final response = await component.requestPool
        .request<pb_system.DeviceStatus>(
          packet: buildSystemPacket(
            pb_system.System_SystemID.GET_DEVICE_STATUS,
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.system &&
              p.id == pb_system.System_SystemID.GET_DEVICE_STATUS.value,
          responseMapper: (p) => p.system.deviceStatus,
        );
    final status = _batteryStatus(response.battery);
    _emitBattery(status);
    return status;
  }

  models.BatteryStatus _batteryStatus(pb_system.DeviceStatus_Battery battery) {
    return models.BatteryStatus(
      capacity: battery.capacity,
      chargeStatus: _mapChargeStatus(battery.chargeStatus),
      chargeInfo: battery.hasChargeInfo()
          ? models.ChargeInfo(
              state: battery.chargeInfo.state.toInt(),
              timestamp: battery.chargeInfo.hasTimestamp()
                  ? battery.chargeInfo.timestamp.toInt()
                  : null,
            )
          : null,
    );
  }

  void _emitBattery(models.BatteryStatus status) {
    entity.emit(BatteryUpdated(deviceId: entity.id, battery: status));
  }

  Future<models.SystemInfo> fetchDeviceInfo() async {
    _log.fine('[${entity.id}] fetching device info');
    final response = await component.requestPool.request<pb_system.DeviceInfo>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_DEVICE_INFO),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_DEVICE_INFO.value,
      responseMapper: (p) => p.system.deviceInfo,
    );
    final info = models.SystemInfo(
      serialNumber: response.serialNumber,
      firmwareVersion: response.firmwareVersion,
      imei: response.imei,
      model: response.model,
    );
    _log.fine(
      '[${entity.id}] device info: model=${info.model}, fw=${info.firmwareVersion}, serial=${info.serialNumber}, imei=${info.imei}',
    );
    entity.emit(DeviceInfoUpdated(deviceId: entity.id, info: info));
    return info;
  }

  Future<String?> fetchEuiccImei() async {
    _log.fine('[${entity.id}] fetching eUICC info');
    final response = await component.requestPool.request<pb_lpa.EuiccInfo>(
      packet: pb.WearPacket(
        type: pb.WearPacket_Type.LPA,
        id: pb_lpa.Lpa_LpaID.GET_EUICC_INFO.value,
        lpa: pb_lpa.Lpa(),
      ),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.lpa &&
          p.id == pb_lpa.Lpa_LpaID.GET_EUICC_INFO.value &&
          p.lpa.hasEuiccInfo(),
      responseMapper: (p) => p.lpa.euiccInfo,
      timeout: const Duration(seconds: 3),
    );
    final imei = response.hasImei() ? response.imei.trim() : '';
    final eidLength = response.hasEid() ? response.eid.length : 0;
    _log.fine(
      '[${entity.id}] eUICC info: imei_present=${imei.isNotEmpty}, eid_bytes=$eidLength',
    );
    return imei.isEmpty ? null : imei;
  }

  Future<models.StorageInfo> fetchStorageInfo() async {
    _log.fine('[${entity.id}] fetching storage info');
    final response = await component.requestPool.request<pb_system.StorageInfo>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_STORAGE_INFO),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_STORAGE_INFO.value,
      responseMapper: (p) => p.system.storageInfo,
    );
    final info = models.StorageInfo(
      used: response.used.toInt(),
      total: response.total.toInt(),
    );
    _log.fine(
      '[${entity.id}] storage info: used=${info.used}, total=${info.total}',
    );
    entity.emit(StorageInfoUpdated(deviceId: entity.id, info: info));
    return info;
  }

  Future<List<models.AppInfo>> fetchInstalledApps() async {
    _log.fine('[${entity.id}] fetching installed apps');
    final response = await component.requestPool.request<pb_system.App_List>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_ORDERED_APP_LIST),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_ORDERED_APP_LIST.value,
      responseMapper: (p) => p.system.appList,
    );
    final apps = response.list
        .map((app) => models.AppInfo(packageName: app.id, appName: app.name))
        .toList();
    _log.fine('[${entity.id}] installed apps: ${apps.length}');
    entity.emit(AppListUpdated(deviceId: entity.id, apps: apps));
    return apps;
  }

  Future<void> setOrderedApps(List<models.AppInfo> apps) async {
    await component.sendPbPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.SET_ORDERED_APP_LIST.value,
        system: pb_system.System(
          appList: pb_system.App_List(
            list: apps
                .map(
                  (app) =>
                      pb_system.App(id: app.packageName, name: app.appName),
                )
                .toList(growable: false),
          ),
        ),
      ),
      waitForAck: true,
    );
    entity.emit(AppListUpdated(deviceId: entity.id, apps: apps));
  }

  Future<List<XiaomiAlarm>> fetchAlarms() async {
    final response = await component.requestPool
        .request<pb_clock.ClockInfo_List>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.CLOCK,
            id: pb_clock.Clock_ClockID.GET_CLOCK_LIST.value,
            clock: pb_clock.Clock(),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.clock &&
              p.id == pb_clock.Clock_ClockID.GET_CLOCK_LIST.value &&
              p.clock.hasClockInfoList(),
          responseMapper: (p) => p.clock.clockInfoList,
        );
    return response.list.map(XiaomiAlarm.fromProto).toList(growable: false);
  }

  Future<void> addAlarm(XiaomiAlarm alarm) async {
    await _sendClockCommand(
      pb_clock.Clock_ClockID.ADD_CLOCK,
      clockInfo: alarm.toProto(),
    );
  }

  Future<void> updateAlarm(XiaomiAlarm alarm) async {
    await _sendClockCommand(
      pb_clock.Clock_ClockID.UPDATE_CLOCK,
      clockInfo: alarm.toProto(),
    );
  }

  Future<void> removeAlarm(int id) async {
    await _sendClockCommand(pb_clock.Clock_ClockID.REMOVE_CLOCK, idValue: id);
  }

  Future<void> setAlarmEnabled(int id, bool enabled) async {
    await _sendClockCommand(
      pb_clock.Clock_ClockID.ENABLE_OR_DISABLE_CLOCK,
      idValue: id,
      enable: enabled,
    );
  }

  Future<void> _sendClockCommand(
    pb_clock.Clock_ClockID id, {
    pb_clock.ClockInfo? clockInfo,
    int? idValue,
    bool? enable,
  }) async {
    await component.sendPbPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.CLOCK,
        id: id.value,
        clock: pb_clock.Clock(
          clockInfo: clockInfo,
          id: idValue,
          enable: enable,
        ),
      ),
      waitForAck: true,
    );
  }

  Future<void> sendWeather(XiaomiWeatherData weather) async {
    final id = pb_weather.WeatherId(
      pubTime: weather.publishedAt,
      cityName: weather.cityName,
      locationName: weather.locationName,
      locationKey: weather.locationKey,
      isCurrentLocation: true,
    );
    final latest = pb_weather.WeatherLatest(
      id: id,
      weather: weather.conditionCode,
      temperature: _weatherValue('℃', weather.temperature),
      humidity: _weatherValue('%', weather.humidity),
      windInfo: _weatherValue(
        weather.windDirection.toString(),
        weather.windSpeedBeaufort,
      ),
      uvindex: _weatherValue('', weather.uvIndex),
      aqi: _weatherValue('Unknown', weather.aqi),
      alertsList: pb_weather.Alerts_List(),
      pressure: weather.pressureHpa * 100,
    );

    final cityKey = pb_weather.CityKey(
      locationKey: weather.locationKey,
      cityName: weather.cityName,
    );
    await _sendWeatherPacket(
      pb_weather.Weather_WeatherID.ADD_CITY_KEY,
      weather: pb_weather.Weather(cityKey: cityKey),
    );
    await _sendWeatherPacket(
      pb_weather.Weather_WeatherID.UPDATE_CITY_KEYS,
      weather: pb_weather.Weather(
        cityKeyList: pb_weather.CityKey_List(list: [cityKey]),
      ),
    );
    await _sendWeatherPacket(
      pb_weather.Weather_WeatherID.SET_CONFIG,
      weather: pb_weather.Weather(
        weatherConfig: pb_weather.WeatherConfig(
          temperatureUnit: pb_common.TemperatureUnit.CENTIGRADE,
        ),
      ),
    );
    await _sendWeatherPacket(
      pb_weather.Weather_WeatherID.LATEST_WEATHER,
      weather: pb_weather.Weather(latest: latest),
    );
    await _sendWeatherPacket(
      pb_weather.Weather_WeatherID.DAILY_FORECAST,
      weather: pb_weather.Weather(
        forecast: pb_weather.WeatherForecast(
          id: id,
          dataList: pb_weather.WeatherForecast_Data_List(
            list: weather.daily
                .map(
                  (day) => pb_weather.WeatherForecast_Data(
                    aqi: _weatherValue('Unknown', 0),
                    weather: pb_common.RangeValue(
                      from: day.conditionCode,
                      to: day.conditionCode,
                    ),
                    temperature: xiaomiDailyTemperatureRange(day),
                    temperatureUnit: '℃',
                    sunRiseSet: pb_weather.SunRiseSet(
                      sunRise: day.sunrise,
                      sunSet: day.sunset,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (weather.hourly.isNotEmpty) {
      await _sendWeatherPacket(
        pb_weather.Weather_WeatherID.HOURLY_FORECAST,
        weather: pb_weather.Weather(
          forecast: pb_weather.WeatherForecast(
            id: id,
            dataList: pb_weather.WeatherForecast_Data_List(
              list: weather.hourly
                  .map(
                    (hour) => pb_weather.WeatherForecast_Data(
                      aqi: _weatherValue('Unknown', 0),
                      weather: pb_common.RangeValue(
                        from: 0,
                        to: hour.conditionCode,
                      ),
                      temperature: pb_common.RangeValue(
                        from: 0,
                        to: hour.temperature,
                      ),
                      temperatureUnit: '℃',
                      windInfo: _weatherValue(
                        hour.windDirection.toString(),
                        hour.windSpeedBeaufort,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      );
    }
  }

  pb_common.KeyValue _weatherValue(String key, int value) =>
      pb_common.KeyValue(key: key, value: value);

  Future<void> _sendWeatherPacket(
    pb_weather.Weather_WeatherID id, {
    required pb_weather.Weather weather,
  }) async {
    await component.sendPbPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.WEATHER,
        id: id.value,
        weather: weather,
      ),
      waitForAck: true,
    );
  }

  Future<pb_system.AppLayout> fetchAppLayout() async {
    final response = await component.requestPool.request<pb_system.AppLayout>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_APP_LAYOUT),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_APP_LAYOUT.value,
      responseMapper: (p) => p.system.appLayout,
    );
    return response;
  }

  Future<void> setAppLayout(pb_system.AppLayout_Layout layout) async {
    await component.sendPbPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.SET_APP_LAYOUT.value,
        system: pb_system.System(
          appLayout: pb_system.AppLayout(layout: layout),
        ),
      ),
      waitForAck: true,
    );
  }

  Future<List<models.WatchfaceInfo>> fetchInstalledWatchfaces() async {
    _log.fine('[${entity.id}] fetching installed watchfaces');
    final response = await component.requestPool
        .request<pb_watchface.WatchFaceItem_List>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.WATCH_FACE,
            id: pb_watchface.WatchFace_WatchFaceID.GET_INSTALLED_LIST.value,
            watchFace: pb_watchface.WatchFace(),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.watchFace &&
              p.id ==
                  pb_watchface.WatchFace_WatchFaceID.GET_INSTALLED_LIST.value &&
              p.watchFace.hasWatchFaceList(),
          responseMapper: (p) => p.watchFace.watchFaceList,
        );
    final watchfaces = response.list
        .map(
          (item) => models.WatchfaceInfo(
            id: item.id,
            name: item.name,
            isCurrent: item.isCurrent,
            canRemove: item.canRemove,
            versionCode: item.versionCode.toInt(),
            canEdit: item.canEdit,
            backgroundColor: item.backgroundColor,
            backgroundImage: item.backgroundImage,
            style: item.style,
            backgroundImageList: item.backgroundImageList.toList(),
          ),
        )
        .toList();
    _log.fine('[${entity.id}] installed watchfaces: ${watchfaces.length}');
    entity.emit(
      WatchfaceListUpdated(deviceId: entity.id, watchfaces: watchfaces),
    );
    return watchfaces;
  }

  models.ChargeStatus _mapChargeStatus(
    pb_system.DeviceStatus_Battery_ChargeStatus status,
  ) {
    return switch (status) {
      pb_system.DeviceStatus_Battery_ChargeStatus.CHARGING =>
        models.ChargeStatus.charging,
      pb_system.DeviceStatus_Battery_ChargeStatus.NOT_CHARGING =>
        models.ChargeStatus.notCharging,
      pb_system.DeviceStatus_Battery_ChargeStatus.FULL =>
        models.ChargeStatus.full,
      _ => models.ChargeStatus.unknown,
    };
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() != pb.WearPacket_Payload.system ||
        packet.system.whichPayload() !=
            pb_system.System_Payload.batteryStatus) {
      return;
    }
    _emitBattery(_batteryStatus(packet.system.batteryStatus));
  }
}

pb_common.RangeValue xiaomiDailyTemperatureRange(XiaomiWeatherDay day) =>
    pb_common.RangeValue(
      from: day.maximumTemperature,
      to: day.minimumTemperature,
    );
