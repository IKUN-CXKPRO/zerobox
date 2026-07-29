import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

final oronBoxCoinServiceProvider = Provider<OronBoxCoinService>(
  (ref) => OronBoxCoinService(ref.watch(bandBbsAuthProvider.notifier)),
);

class CoinAccount {
  const CoinAccount({required this.balanceUnits, this.frozenReason = ''});

  factory CoinAccount.fromJson(Map<String, Object?> json) => CoinAccount(
    balanceUnits: (json['balance_units'] as num?)?.toInt() ?? 0,
    frozenReason: json['voting_frozen_reason']?.toString() ?? '',
  );

  final int balanceUnits;
  final String frozenReason;

  String get displayBalance {
    final whole = balanceUnits ~/ 10;
    final decimal = balanceUnits.remainder(10);
    return decimal == 0 ? '$whole' : '$whole.$decimal';
  }
}

class CoinCheckinResult {
  const CoinCheckinResult({required this.reward, required this.account});

  final int reward;
  final CoinAccount account;
}

class OronBoxCoinService {
  OronBoxCoinService(this._auth)
    : _dio = Dio(BaseOptions(baseUrl: oronBoxServerBaseUrl));

  final BandBbsAuthNotifier _auth;
  final Dio _dio;

  Future<Options> _options() async {
    final session = await _auth.sessionIfNeeded();
    if (session == null) throw StateError('BandBBS account is not signed in');
    return Options(headers: {'Authorization': 'Bearer ${session.accessToken}'});
  }

  Future<CoinAccount> account() async {
    final response = await _dio.get<Object?>(
      '/api/coins',
      options: await _options(),
    );
    return CoinAccount.fromJson(_map(response.data));
  }

  Future<CoinCheckinResult> checkin() async {
    final response = await _dio.post<Object?>(
      '/api/coins/checkin',
      options: await _options(),
    );
    final json = _map(response.data);
    return CoinCheckinResult(
      reward: (json['reward_coins'] as num?)?.toInt() ?? 0,
      account: CoinAccount.fromJson(_map(json['account'])),
    );
  }

  Future<void> coin(String resourceId, int coins) async {
    await _dio.post<Object?>(
      '/api/resources/${Uri.encodeComponent(resourceId)}/coins',
      data: {'coins': coins},
      options: await _options(),
    );
  }

  Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw FormatException('OronBox server returned ${value.runtimeType}');
}
