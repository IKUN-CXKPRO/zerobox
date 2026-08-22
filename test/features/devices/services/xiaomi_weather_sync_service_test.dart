import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/components/info_system.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_weather_sync_service.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear_common.pb.dart'
    as pb_common;

void main() {
  test('keeps weather arrays aligned when Open-Meteo returns nulls', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('geocoding-api')) {
            return handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'results': [
                    {'name': 'Test City', 'latitude': 1.0, 'longitude': 2.0},
                  ],
                },
              ),
            );
          }
          if (options.path.contains('air-quality-api')) {
            return handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'current': {'time': '2026-08-21T10:00', 'us_aqi': 84},
                },
              ),
            );
          }
          return handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'utc_offset_seconds': 8 * 60 * 60,
                'current': {
                  'time': '2026-08-21T10:00',
                  'temperature_2m': 20,
                  'relative_humidity_2m': 50,
                  'weather_code': 0,
                  'wind_speed_10m': 5,
                  'wind_direction_10m': 90,
                  'uv_index': 1,
                  'surface_pressure': 1000,
                },
                'daily': {
                  'time': ['2026-08-21', '2026-08-22'],
                  'weather_code': [0, 3],
                  'temperature_2m_min': [10, null],
                  'temperature_2m_max': [20, 30],
                  'sunrise': ['2026-08-21T06:00', '2026-08-22T06:01'],
                  'sunset': ['2026-08-21T18:00', '2026-08-22T18:01'],
                },
                'hourly': {
                  'time': [
                    '2026-08-21T10:00',
                    '2026-08-21T11:00',
                    '2026-08-21T12:00',
                  ],
                  'weather_code': [0, null, 3],
                  'temperature_2m': [20, 99, 22],
                  'wind_speed_10m': [5, 6, 7],
                  'wind_direction_10m': [90, 100, 110],
                },
              },
            ),
          );
        },
      ),
    );

    final weather = await XiaomiWeatherSyncService(dio: dio).fetch('Test');

    expect(weather.daily, hasLength(1));
    expect(weather.daily.single.date, '2026-08-21');
    expect(weather.daily.single.sunrise, '2026-08-21T06:00:00+08:00');
    expect(weather.publishedAt, '2026-08-21T10:00:00+08:00');
    expect(weather.aqi, 84);
    expect(weather.locationKey, startsWith('accu:'));
    expect(weather.hourly.map((item) => item.time), [
      '2026-08-21T10:00',
      '2026-08-21T12:00',
    ]);
    expect(weather.hourly.last.temperature, 22);
    expect(weather.hourly.last.windDirection, 110);
  });

  test('encodes Xiaomi daily temperature range as maximum then minimum', () {
    final range = xiaomiDailyTemperatureRange(
      const XiaomiWeatherDay(
        conditionCode: 0,
        minimumTemperature: 12,
        maximumTemperature: 25,
      ),
    );

    expect(range.from, 25);
    expect(range.to, 12);
  });

  test(
    'encodes current and hourly values with Gadgetbridge field semantics',
    () {
      const weather = XiaomiWeatherData(
        locationKey: 'open-meteo:30.8160:108.3741',
        cityName: '万州',
        locationName: '万州',
        publishedAt: '2026-08-22T08:30:00+08:00',
        conditionCode: 0,
        temperature: 28,
        humidity: 80,
        windSpeedBeaufort: 2,
        windDirection: 52,
        uvIndex: 2,
        aqi: 84,
        pressureHpa: 970,
        daily: [],
        hourly: [],
      );
      final id = buildXiaomiWeatherId(weather);
      final latest = buildXiaomiWeatherLatest(weather, id);
      final hourly = buildXiaomiHourlyWeatherEntry(
        const XiaomiWeatherHour(
          conditionCode: 1,
          temperature: 29,
          windSpeedBeaufort: 2,
          windDirection: 55,
        ),
      );

      expect(id.pubTime, '2026-08-22T08:30:00+08:00');
      expect(latest.temperature.key, '℃');
      expect(latest.temperature.value, 28);
      expect(latest.aqi.value, 84);
      expect(latest.windInfo.key, '52');
      expect(latest.windInfo.value, 2);
      expect(hourly.temperature.from, 0);
      expect(hourly.temperature.to, 29);
      expect(hourly.windInfo.key, '55');
      expect(hourly.windInfo.value, 2);
    },
  );

  test('encodes weather values as protobuf sint32 ZigZag integers', () {
    final one = pb_common.KeyValue(key: 'x', value: 1).writeToBuffer();
    final temperature = pb_common.KeyValue(key: 'x', value: 28).writeToBuffer();

    expect(one, [0x0a, 0x01, 0x78, 0x10, 0x02]);
    expect(temperature, [0x0a, 0x01, 0x78, 0x10, 0x38]);
  });
}
