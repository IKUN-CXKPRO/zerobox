import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/network/http_observability_interceptor.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

class OronBoxCreatorApi {
  OronBoxCreatorApi({required this.auth, Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: oronBoxServerBaseUrl)) {
    installHttpObservability(_dio);
  }

  final BandBbsAuthNotifier auth;
  final Dio _dio;
  static final _log = getLogger('CreatorApi');

  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    String stage = 'request',
  }) async {
    final response = await _requestResponse(
      method,
      path,
      data: data,
      query: query,
      stage: stage,
    );
    return response.data;
  }

  Future<Response<Object?>> _requestResponse(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    required String stage,
  }) async {
    final session = await _requireSession(stage);
    final response = await _send(
      () => _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      ),
      stage: stage,
    );
    return response;
  }

  Future<OronBoxSession> _requireSession(String stage) async {
    OronBoxSession? session;
    try {
      session = await auth.sessionIfNeeded();
    } on DioException catch (error) {
      throw CreatorApiException.fromDio(error, stage: '$stage.auth');
    }
    if (session == null) {
      throw CreatorApiException(
        code: 'auth_required',
        message: 'BandBBS account is not signed in',
        details: {'stage': '$stage.auth'},
      );
    }
    return session;
  }

  Future<Object?> publish({
    required String resourceId,
    required Uint8List bundle,
    void Function(double progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    logDiagnostic(
      _log,
      Level.INFO,
      'Creator publish started',
      fields: {'resource': resourceId, 'bytes': bundle.length},
    );
    try {
      final session = await _requireSession('publish');
      final response = await _send(
        () => _dio.post<Object?>(
          '/api/creator/resources/$resourceId/publish',
          data: Stream.fromIterable([bundle]),
          options: Options(
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              Headers.contentLengthHeader: bundle.length,
              Headers.contentTypeHeader: 'application/zip',
            },
          ),
          onSendProgress: (sent, total) {
            if (total > 0) onProgress?.call(sent / total);
          },
        ),
        stage: 'publish',
      );
      stopwatch.stop();
      logDiagnostic(
        _log,
        Level.INFO,
        'Creator publish completed',
        fields: {
          'resource': resourceId,
          'bytes': bundle.length,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      return response.data;
    } catch (error, stackTrace) {
      stopwatch.stop();
      final failure = error is CreatorApiException
          ? error
          : CreatorApiException(
              code: 'publish_failed',
              message: _friendlyMessage(error),
              details: const {'stage': 'publish'},
            );
      logDiagnostic(
        _log,
        Level.WARNING,
        'Creator publish failed',
        fields: {
          'resource': resourceId,
          'bytes': bundle.length,
          'durationMs': stopwatch.elapsedMilliseconds,
          'code': failure.code,
          ...failure.details,
        },
        error: failure.message,
        stackTrace: error is CreatorApiException ? null : stackTrace,
      );
      throw failure;
    }
  }

  Future<Uint8List> downloadBlob(String resourceId, String digest) async {
    final session = await _requireSession('blob');
    final response = await _send(
      () => _dio.get<List<int>>(
        '/api/creator/resources/$resourceId/blobs/$digest',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      ),
      stage: 'blob',
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<Response<T>> _send<T>(
    Future<Response<T>> Function() operation, {
    required String stage,
  }) async {
    try {
      return await operation();
    } on DioException catch (error) {
      throw CreatorApiException.fromDio(error, stage: stage);
    }
  }

  static String _friendlyMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }
}

class CreatorApiException implements Exception {
  const CreatorApiException({
    required this.code,
    required this.message,
    required this.details,
  });

  factory CreatorApiException.fromDio(
    DioException error, {
    required String stage,
  }) {
    final status = error.response?.statusCode;
    final summary = safeHttpErrorSummary(error.response?.data);
    final serverMessage = summary['serverMessage']?.toString();
    final serverCode = summary['serverCode']?.toString();
    final message = serverMessage?.isNotEmpty == true
        ? serverMessage!
        : switch ((status, error.type)) {
            (413, _) => 'The selected file is too large',
            (400, _) => 'The server rejected the selected file',
            (_, DioExceptionType.connectionTimeout) ||
            (_, DioExceptionType.sendTimeout) ||
            (
              _,
              DioExceptionType.receiveTimeout,
            ) => 'The server did not respond in time',
            (_, DioExceptionType.connectionError) =>
              'Unable to connect to the OronBox server',
            _ =>
              status == null
                  ? 'The request to the OronBox server failed'
                  : 'The OronBox server returned HTTP $status',
          };
    return CreatorApiException(
      code: serverCode ?? (status == null ? 'network_error' : 'http_$status'),
      message: message,
      details: {
        'stage': stage,
        'endpoint': safeHttpEndpoint(error.requestOptions.uri),
        if (status != null) 'status': status,
        'errorType': error.type.name,
        if (httpRequestId(error.response) case final requestId?)
          'requestId': requestId,
      },
    );
  }

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => message;
}

