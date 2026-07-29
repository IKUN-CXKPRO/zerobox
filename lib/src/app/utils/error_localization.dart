import 'package:flutter/services.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

String localizedErrorMessage(AppLocalizations l10n, Object? error) {
  final raw = _flattenError(error);
  final normalized = raw.toLowerCase();
  final code = _errorCode(error, normalized);

  switch (code) {
    case 'invalid_refresh_token':
    case 'session_expired':
    case 'http_401':
      return l10n.errorOronBoxSessionExpired;
    case 'auth_required':
    case 'unauthenticated':
      return l10n.settingsBandBbsAccountRequired;
    case 'forbidden':
    case 'banned':
    case 'creator_frozen':
    case 'bandbbs_scope_forbidden':
    case 'http_403':
      return l10n.errorPermissionDenied;
    case 'not_found':
    case 'resource_not_found':
    case 'collection_not_found':
    case 'comment_not_found':
    case 'feedback_not_found':
    case 'document_not_found':
    case 'blob_not_found':
    case 'http_404':
      return l10n.errorContentNotFound;
    case 'conflict':
    case 'already_exists':
    case 'http_409':
      return l10n.errorRequestConflict;
    case 'rate_limited':
    case 'comment_rate_limited':
    case 'quota_exceeded':
    case 'http_429':
      return l10n.errorRateLimited;
    case 'payload_too_large':
    case 'file_too_large':
    case 'http_413':
      return l10n.errorFileTooLarge;
    case 'invalid_argument':
    case 'invalid_request':
    case 'creator_invalid':
    case 'validation':
    case 'usage':
    case 'http_400':
    case 'http_422':
      return l10n.errorInvalidRequest;
    case 'network_error':
    case 'connection_error':
    case 'host_unavailable':
    case 'daemon_disconnected':
      return l10n.errorNetworkUnavailable;
    case 'service_unavailable':
    case 'moderation_unavailable':
    case 'r2_unavailable':
    case 'http_500':
    case 'http_502':
    case 'http_503':
    case 'http_504':
      return l10n.errorServiceUnavailable;
    case 'cancelled':
      return l10n.errorOperationCancelled;
  }

  if (code == 'unauthorized' &&
      (normalized.contains('expired') ||
          normalized.contains('invalid') ||
          normalized.contains('token'))) {
    return l10n.errorOronBoxSessionExpired;
  }

  if (raw == DeviceManager.errorBluetoothUnavailable ||
      normalized.contains('bluetooth is not available') ||
      normalized.contains('bluetooth not available') ||
      normalized.contains('availabilitystate.unsupported')) {
    return l10n.errorBluetoothUnavailable;
  }

  if (normalized.contains('web serial api is not available')) {
    return l10n.errorWebSerialUnavailable;
  }

  if (normalized.contains('no rfcomm channel available')) {
    return l10n.errorUnknownWithDetail(_trimPlatformNoise(raw));
  }

  if (normalized.contains('certificate_verify_failed') ||
      normalized.contains('self signed certificate') ||
      normalized.contains('handshakeexception') ||
      normalized.contains('certificate verify failed')) {
    return l10n.errorCertificateVerificationFailed;
  }

  if (normalized.contains('ble connect failed: timeout') ||
      normalized.contains('ble connect failed: service discovery timed out') ||
      normalized.contains('ble notification subscription timed out')) {
    // All connection-failure causes (timeout or refused) share one message:
    // permissions, radio off, device occupied, or wrong device mode.
    return l10n.errorBluetoothConnectFailed;
  }

  // The BLE and SPP drivers normalize native failures into these stable
  // shapes at the Dart boundary; match the shape, not native wording.
  if (normalized.contains('ble connect failed') ||
      normalized.contains('spp connect failed') ||
      normalized.contains('ble device was not discovered') ||
      normalized.contains('unknown deviceid')) {
    return l10n.errorBluetoothConnectFailed;
  }

  if (normalized.contains('ble write timed out')) {
    return l10n.errorBluetoothDisconnected;
  }

  if (normalized.contains('bluetooth permission is required')) {
    return l10n.errorBluetoothUnavailable;
  }

  if (normalized.contains('timeout') ||
      normalized.contains('timed out') ||
      normalized.contains('future not completed') ||
      normalized.contains('操作超时')) {
    // Preserve the connection stage carried by the error instead of reducing
    // every failure to the same unactionable timeout message.
    final detail = _trimPlatformNoise(raw);
    return detail.isEmpty
        ? l10n.errorOperationTimeout
        : l10n.errorUnknownWithDetail(detail);
  }

  if (normalized.contains('device not ready')) {
    return l10n.errorDeviceNotReady;
  }

  if (normalized.contains('unsupported or unrecognized file type') ||
      normalized.contains('unsupported file type') ||
      normalized.contains('unsupported file')) {
    return l10n.errorUnsupportedFileType;
  }

  if (normalized.contains('required ble characteristics not found') ||
      normalized.contains('characteristic') &&
          normalized.contains('not found')) {
    final detail = _trimPlatformNoise(raw);
    return normalized.contains('discovered:')
        ? l10n.errorUnknownWithDetail(detail)
        : l10n.errorBleCharacteristicsMissing;
  }

  if (normalized.contains('send_failed') ||
      normalized.contains('disconnected') ||
      normalized.contains('not connected') ||
      normalized.contains('传输端点尚未连接') ||
      normalized.contains('socket is not connected')) {
    return l10n.errorBluetoothDisconnected;
  }

  if (normalized.contains('connect_failed') ||
      normalized.contains('connect failed on channel') ||
      normalized.contains('universalble.connect failed') ||
      normalized.contains('连接被拒绝') ||
      normalized.contains('设备或资源忙') ||
      normalized.contains('无法分配内存')) {
    return l10n.errorBluetoothConnectFailed;
  }

  if (normalized.contains('username or password is incorrect')) {
    return l10n.errorAccountPasswordIncorrect;
  }

  if (normalized.contains('bandbbs account is not signed in')) {
    return l10n.settingsBandBbsAccountRequired;
  }

  if (normalized.contains('huami account is not signed in')) {
    return l10n.settingsHuamiAccountRequired;
  }

  if (normalized.contains('2fa') ||
      normalized.contains('two-factor') ||
      normalized.contains('did not return account cookies')) {
    return l10n.errorAccountTwoFactorIncomplete;
  }

  if (raw.trim().isEmpty) {
    return l10n.error;
  }

  return l10n.errorUnknownWithDetail(_trimPlatformNoise(raw));
}

String _errorCode(Object? error, String normalized) {
  if (error is CodedError) return error.code.trim().toLowerCase();
  if (normalized.contains('oronbox session expired')) return 'session_expired';
  const knownCodes = <String>{
    'invalid_refresh_token',
    'session_expired',
    'auth_required',
    'unauthenticated',
    'unauthorized',
    'forbidden',
    'banned',
    'creator_frozen',
    'bandbbs_scope_forbidden',
    'not_found',
    'resource_not_found',
    'collection_not_found',
    'comment_not_found',
    'feedback_not_found',
    'document_not_found',
    'blob_not_found',
    'conflict',
    'already_exists',
    'rate_limited',
    'comment_rate_limited',
    'quota_exceeded',
    'payload_too_large',
    'file_too_large',
    'invalid_argument',
    'invalid_request',
    'creator_invalid',
    'validation',
    'usage',
    'network_error',
    'connection_error',
    'host_unavailable',
    'daemon_disconnected',
    'service_unavailable',
    'moderation_unavailable',
    'r2_unavailable',
    'cancelled',
  };
  for (final code in knownCodes) {
    if (normalized == code ||
        normalized.startsWith('$code:') ||
        normalized.contains('"code":"$code"') ||
        normalized.contains('"code": "$code"')) {
      return code;
    }
  }
  final http = RegExp(
    r'\bhttp[_ ](400|401|403|404|409|413|422|429|500|502|503|504)\b',
  ).firstMatch(normalized);
  return http == null ? '' : 'http_${http.group(1)}';
}

String _flattenError(Object? error) {
  if (error == null) {
    return '';
  }
  if (error is PlatformException) {
    return [
      error.code,
      if (error.message != null) error.message!,
      if (error.details != null) error.details.toString(),
    ].join(' ');
  }
  return error.toString();
}

String _trimPlatformNoise(String raw) {
  var text = raw.trim();
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  if (text.startsWith('Bad state: ')) {
    text = text.substring('Bad state: '.length);
  }
  return text;
}
