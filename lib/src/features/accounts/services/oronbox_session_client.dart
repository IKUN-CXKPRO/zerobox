import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final oronBoxSessionAccessProvider = Provider<OronBoxSessionAccess>(
  (ref) => HostOronBoxSessionAccess(ref.watch(applicationHostProvider)),
);

class HostOronBoxSessionAccess implements OronBoxSessionAccess {
  const HostOronBoxSessionAccess(this._host);

  final OronBoxCommandBus _host;

  @override
  Future<OronBoxSession?> sessionIfNeeded() async {
    final result = await _host.execute(
      const OronBoxCommand(method: 'account.session'),
    );
    if (!result.ok) throw HostSessionCommandException(result.error!);
    final value = result.value;
    return value is Map
        ? OronBoxSession.fromJson(value.cast<String, Object?>())
        : null;
  }

  @override
  Future<void> expireSession() async {
    final result = await _host.execute(
      const OronBoxCommand(method: 'account.session.expire'),
    );
    if (!result.ok) throw HostSessionCommandException(result.error!);
  }
}

class HostSessionCommandException implements CodedError {
  const HostSessionCommandException(this.error);

  final CommandError error;

  @override
  String get code => error.code;
  @override
  String get message => error.message;
  @override
  Object? get details => error.details;

  @override
  String toString() => message;
}

class OronBoxAuthRequiredException implements CodedError {
  const OronBoxAuthRequiredException();

  @override
  String get code => 'auth_required';

  @override
  String get message => 'BandBBS account is not signed in';

  @override
  Object? get details => null;

  @override
  String toString() => message;
}

class OronBoxSessionClient {
  const OronBoxSessionClient(this._sessions);

  final OronBoxSessionAccess _sessions;

  Future<Response<T>> send<T>(
    Future<Response<T>> Function(Options authorization) operation,
  ) async {
    final session = await _sessions.sessionIfNeeded();
    if (session == null) throw const OronBoxAuthRequiredException();
    try {
      return await operation(
        Options(headers: {'Authorization': 'Bearer ${session.accessToken}'}),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      try {
        await _sessions.expireSession();
      } catch (_) {
        // The authenticated request already proved the session invalid.
        // Failure to notify the host must not hide the user-facing expiry.
      }
      throw const BandBbsSessionExpiredException();
    }
  }
}
