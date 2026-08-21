import 'package:dio/dio.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';

class XiaomiWeatherSyncService {
  XiaomiWeatherSyncService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<XiaomiWeatherData> fetch(String city) async {
    final query = city.trim();
    if (query.isEmpty) throw const FormatException('请输入城市');

    final locationResponse = await _dio.get<Map<String, dynamic>>(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': query,
        'count': 1,
        'language': 'zh',
        'format': 'json',
      },
    );
    final results = locationResponse.data?['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw StateError('找不到该城市');
    }
    final location = (results.first as Map).cast<String, Object?>();
    final latitude = (location['latitude'] as num?)?.toDouble();
    final longitude = (location['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw StateError('城市坐标无效');
    }

    final forecastResponse = await _dio.get<Map<String, dynamic>>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'weather_code',
          'wind_speed_10m',
          'wind_direction_10m',
          'uv_index',
          'surface_pressure',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_min',
          'temperature_2m_max',
          'sunrise',
          'sunset',
        ].join(','),
        'hourly': [
          'temperature_2m',
          'weather_code',
          'wind_speed_10m',
          'wind_direction_10m',
        ].join(','),
        'forecast_days': 7,
        'timezone': 'auto',
      },
    );
    final data = forecastResponse.data;
    if (data == null) throw StateError('天气服务没有返回数据');
    final current = _map(data['current']);
    final daily = _map(data['daily']);
    final hourly = _map(data['hourly']);

    final dailyCodes = _nullableNumbers(daily['weather_code']);
    final minimums = _nullableNumbers(daily['temperature_2m_min']);
    final maximums = _nullableNumbers(daily['temperature_2m_max']);
    final dates = _strings(daily['time']);
    final sunrises = _strings(daily['sunrise']);
    final sunsets = _strings(daily['sunset']);
    final dailyItems = <XiaomiWeatherDay>[];
    for (var i = 0; i < dates.length; i++) {
      final code = _numberAt(dailyCodes, i);
      final minimum = _numberAt(minimums, i);
      final maximum = _numberAt(maximums, i);
      if (code == null || minimum == null || maximum == null) continue;
      dailyItems.add(
        XiaomiWeatherDay(
          conditionCode: _condition(code),
          minimumTemperature: minimum.round(),
          maximumTemperature: maximum.round(),
          date: _value(dates, i),
          sunrise: _value(sunrises, i),
          sunset: _value(sunsets, i),
        ),
      );
    }

    final hourlyCodes = _nullableNumbers(hourly['weather_code']);
    final hourlyTemperatures = _nullableNumbers(hourly['temperature_2m']);
    final hourlySpeeds = _nullableNumbers(hourly['wind_speed_10m']);
    final hourlyDirections = _nullableNumbers(hourly['wind_direction_10m']);
    final hourlyTimes = _strings(hourly['time']);
    final hourlyItems = <XiaomiWeatherHour>[];
    final hourlyStart = _firstFutureHourIndex(
      hourlyTimes,
      current['time']?.toString() ?? '',
    );
    for (
      var offset = 0;
      hourlyStart + offset < hourlyTimes.length && hourlyItems.length < 24;
      offset++
    ) {
      final i = hourlyStart + offset;
      final code = _numberAt(hourlyCodes, i);
      final temperature = _numberAt(hourlyTemperatures, i);
      final speed = _numberAt(hourlySpeeds, i);
      final direction = _numberAt(hourlyDirections, i);
      if (code == null ||
          temperature == null ||
          speed == null ||
          direction == null) {
        continue;
      }
      hourlyItems.add(
        XiaomiWeatherHour(
          conditionCode: _condition(code),
          temperature: temperature.round(),
          windSpeedBeaufort: _beaufort(speed),
          windDirection: direction.round(),
          time: hourlyTimes[i],
        ),
      );
    }

    return XiaomiWeatherData(
      locationKey:
          'open-meteo:${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}',
      cityName: location['name']?.toString() ?? query,
      locationName: location['name']?.toString() ?? query,
      publishedAt:
          current['time']?.toString() ?? DateTime.now().toIso8601String(),
      conditionCode: _condition(_number(current['weather_code'])),
      temperature: _number(current['temperature_2m']).round(),
      humidity: _number(current['relative_humidity_2m']).round(),
      windSpeedBeaufort: _beaufort(_number(current['wind_speed_10m'])),
      windDirection: _number(current['wind_direction_10m']).round(),
      uvIndex: _number(current['uv_index']).round(),
      aqi: 0,
      pressureHpa: _number(current['surface_pressure']),
      daily: dailyItems,
      hourly: hourlyItems,
    );
  }

  Map<String, Object?> _map(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const {};

  List<double?> _nullableNumbers(Object? value) => value is List
      ? value
            .map((item) => item is num ? item.toDouble() : null)
            .toList(growable: false)
      : const [];

  List<String> _strings(Object? value) => value is List
      ? value.map((item) => item?.toString() ?? '').toList()
      : const [];

  double _number(Object? value) => value is num ? value.toDouble() : 0;

  double? _numberAt(List<double?> values, int index) =>
      index < values.length ? values[index] : null;

  String _value(List<String> values, int index) =>
      index < values.length ? values[index] : '';

  int _firstFutureHourIndex(List<String> values, String currentTime) {
    if (values.isEmpty || currentTime.isEmpty) return 0;
    for (var i = 0; i < values.length; i++) {
      if (values[i].compareTo(currentTime) >= 0) return i;
    }
    return values.length;
  }

  int _beaufort(double speedKmh) {
    if (speedKmh < 1) return 0;
    if (speedKmh < 6) return 1;
    if (speedKmh < 12) return 2;
    if (speedKmh < 20) return 3;
    if (speedKmh < 29) return 4;
    if (speedKmh < 39) return 5;
    if (speedKmh < 50) return 6;
    if (speedKmh < 62) return 7;
    if (speedKmh < 75) return 8;
    if (speedKmh < 89) return 9;
    if (speedKmh < 103) return 10;
    if (speedKmh < 118) return 11;
    return 12;
  }

  int _condition(double code) => switch (code.round()) {
    0 => 0,
    1 || 2 => 1,
    3 => 2,
    45 || 48 => 18,
    51 || 53 || 55 || 61 => 7,
    56 || 57 || 66 || 67 => 19,
    63 => 8,
    65 => 9,
    71 || 77 || 85 => 14,
    73 => 15,
    75 || 86 => 16,
    80 || 81 => 3,
    82 => 11,
    95 => 4,
    96 || 99 => 5,
    _ => 0,
  };
}
