import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';

final appDioProvider = Provider<Dio>((ref) {
  return createAppHttpTransport(
    githubCdn: () => ref.read(appSettingsProvider).cdn,
  );
});
