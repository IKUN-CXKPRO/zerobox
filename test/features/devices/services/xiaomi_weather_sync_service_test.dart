import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/components/info_system.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_weather_sync_service.dart';

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
          return handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
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
                  'sunrise': ['06:00', '06:01'],
                  'sunset': ['18:00', '18:01'],
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
}
