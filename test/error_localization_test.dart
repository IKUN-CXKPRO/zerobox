import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations_en.dart';
import 'package:oronbox/src/app/generated/app_localizations_zh.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();

  group('localizedErrorMessage', () {
    test('maps every connection failure shape to one unified message', () {
      const shapes = [
        // BLE link-establishment timeout (daemon wrapper included).
        'Bad state: connection: Failed to connect '
            '66F65DDF-EA1A-DE29-7CBC-509EB8DE2E2D: TimeoutException after '
            '0:00:12.000000: BLE connect failed: timeout (Xiaomi Smart Band 7); '
            'the device may be occupied by another host or tool, or out of range',
        // BLE post-connect stage timeouts.
        'TimeoutException after 0:00:10.000000: '
            'BLE connect failed: service discovery timed out',
        'TimeoutException after 0:00:08.000000: '
            'BLE notification subscription timed out for 00000002-0000-3512-2118-0009af100700',
        // BLE native failure, normalized at the driver boundary.
        'Bad state: BLE connect failed: connect_failed: gatt 133',
        // SPP native failures, normalized at the driver boundary.
        'Bad state: SPP connect failed: CONNECT_FAILED: '
            'connect failed: channel 5: -536870186, channel 1: -536870186',
        'Bad state: SPP connect failed: CONNECT_FAILED: '
            'read failed, socket might closed or timeout',
      ];

      for (final raw in shapes) {
        expect(
          localizedErrorMessage(en, raw),
          en.errorBluetoothConnectFailed,
          reason: raw,
        );
        expect(
          localizedErrorMessage(zh, raw),
          zh.errorBluetoothConnectFailed,
          reason: raw,
        );
      }
    });

    test('maps BLE write timeout to the disconnected message', () {
      const raw =
          'TimeoutException after 0:00:05.000000: '
          'BLE write timed out for 00000001-0000-3512-2118-0009af100700';

      expect(localizedErrorMessage(en, raw), en.errorBluetoothDisconnected);
    });

    test('maps missing bluetooth permission to the unavailable message', () {
      const raw =
          'PlatformException(MISSING_PERMISSION, '
          'Bluetooth permission is required, null, null)';

      expect(localizedErrorMessage(en, raw), en.errorBluetoothUnavailable);
    });

    test('does not swallow generic timeouts', () {
      const raw = 'TimeoutException after 0:00:05.000000: Future not completed';

      expect(
        localizedErrorMessage(en, raw),
        isNot(en.errorBluetoothConnectFailed),
      );
    });

    test('maps expired OronBox sessions to a sign-in prompt', () {
      const shapes = [
        'invalid_refresh_token: refresh token is invalid or expired',
        'OronBox session expired',
        'unauthorized: OronBox access token is invalid or expired',
      ];

      for (final raw in shapes) {
        expect(
          localizedErrorMessage(en, raw),
          en.errorOronBoxSessionExpired,
          reason: raw,
        );
        expect(
          localizedErrorMessage(zh, raw),
          zh.errorOronBoxSessionExpired,
          reason: raw,
        );
      }
    });

    test(
      'maps common structured service failures without exposing internals',
      () {
        final cases = <String, String>{
          'forbidden': en.errorPermissionDenied,
          'resource_not_found': en.errorContentNotFound,
          'conflict': en.errorRequestConflict,
          'coin_balance_insufficient': en.errorCoinBalanceInsufficient,
          'coin_resource_limit': en.errorCoinResourceLimit,
          'coin_own_resource': en.errorCoinOwnResource,
          'coin_voting_frozen': en.errorCoinVotingFrozen,
          'coin_account_too_new': en.errorCoinAccountTooNew,
          'coin_vote_failed': en.errorCoinOperationFailed,
          'coin_status_failed': en.errorCoinStatusUnavailable,
          'coin_account_failed': en.errorServiceUnavailable,
          'rate_limited': en.errorRateLimited,
          'http_413': en.errorFileTooLarge,
          'invalid_request': en.errorInvalidRequest,
          'network_error': en.errorNetworkUnavailable,
          'http_503': en.errorServiceUnavailable,
          'cancelled': en.errorOperationCancelled,
        };

        for (final entry in cases.entries) {
          expect(
            localizedErrorMessage(
              en,
              _TestCodedError(entry.key, 'sensitive backend detail'),
            ),
            entry.value,
            reason: entry.key,
          );
        }
      },
    );

    test('localizes the complete coded-error catalog safely', () {
      for (final code in oronBoxKnownErrorCodes) {
        final message = localizedErrorMessage(
          en,
          _TestCodedError(code, 'sensitive backend detail'),
        );
        expect(
          message,
          isNot(contains('sensitive backend detail')),
          reason: code,
        );
      }

      expect(
        localizedErrorMessage(
          en,
          const _TestCodedError('new_server_code', 'sensitive backend detail'),
        ),
        en.errorUnknown,
      );
      expect(
        localizedErrorMessage(en, StateError('new_server_code: secret detail')),
        en.errorUnknown,
      );
      expect(
        localizedErrorMessage(en, StateError('invalid_request: secret detail')),
        en.errorInvalidRequest,
      );
    });

    test('localizes raw Dio transport and response failures safely', () {
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/resources'),
            type: DioExceptionType.connectionError,
          ),
        ),
        en.errorNetworkUnavailable,
      );
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/resources'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/api/resources'),
              statusCode: 429,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        en.errorRateLimited,
      );
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/resources'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/api/resources'),
              statusCode: 400,
              data: {'code': 'coin_balance_insufficient'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        en.errorCoinBalanceInsufficient,
      );
      expect(
        localizedErrorMessage(
          en,
          DioException(
            requestOptions: RequestOptions(path: '/api/resources'),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/api/resources'),
              statusCode: 400,
              data: {'code': 'future_server_code', 'detail': 'secret'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        en.errorUnknown,
      );
    });

    test(
      'unified guidance covers permission, nearby, not in use, mode, retry',
      () {
        for (final message in [
          zh.errorBluetoothConnectFailed,
          en.errorBluetoothConnectFailed,
        ]) {
          expect(message.length, greaterThan(40));
        }
        expect(zh.errorBluetoothConnectFailed, contains('蓝牙权限'));
        expect(zh.errorBluetoothConnectFailed, contains('附近'));
        expect(zh.errorBluetoothConnectFailed, contains('占用'));
        expect(zh.errorBluetoothConnectFailed, contains('连接新手机'));
        expect(zh.errorBluetoothConnectFailed, contains('重试'));
        expect(en.errorBluetoothConnectFailed, contains('permission'));
        expect(en.errorBluetoothConnectFailed, contains('nearby'));
        expect(en.errorBluetoothConnectFailed, contains('not in use'));
        expect(en.errorBluetoothConnectFailed, contains('Connect new phone'));
        expect(en.errorBluetoothConnectFailed, contains('try again'));
      },
    );
  });
}

class _TestCodedError implements CodedError {
  const _TestCodedError(this.code, this.message);

  @override
  final String code;
  @override
  final String message;
  @override
  Object? get details => null;

  @override
  String toString() => message;
}
