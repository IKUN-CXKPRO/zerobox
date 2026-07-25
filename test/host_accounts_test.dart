import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

void main() {
  test('account state and mutations use the host interface', () async {
    final host = _AccountHost();
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    await container.read(hostAccountsProvider.notifier).refresh();
    await container
        .read(hostAccountsProvider.notifier)
        .loginAmazfit(username: 'user@example.com', password: 'secret');
    await container
        .read(hostAccountsProvider.notifier)
        .saveCredentials(
          provider: 'amazfit',
          remember: true,
          username: 'user@example.com',
          password: 'secret',
        );
    final credentials = await container
        .read(hostAccountsProvider.notifier)
        .rememberedCredentials('amazfit');

    final state = container.read(hostAccountsProvider);
    expect(state.amazfit.signedIn, true);
    expect(state.amazfit.username, 'user@example.com');
    expect(credentials['password'], 'secret');
    expect(
      host.methods.where((method) => method == 'account.list'),
      isNotEmpty,
    );
    expect(
      host.methods,
      containsAll([
        'account.login',
        'account.credentials.set',
        'account.credentials.get',
      ]),
    );
  });

  test(
    'BandBBS callback state is not overwritten by a stale account list',
    () async {
      final host = _OAuthCallbackHost();
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      await container.read(hostAccountsProvider.notifier).refresh();
      expect(container.read(hostAccountsProvider).bandbbs.signedIn, false);

      await container
          .read(hostAccountsProvider.notifier)
          .handleBandBbsCallback(
            Uri.parse('oronbox://oauth/bandbbs?ticket=one-time'),
          );
      host.completeStaleRefresh();
      await Future<void>.delayed(Duration.zero);

      final account = container.read(hostAccountsProvider).bandbbs;
      expect(account.signedIn, true);
      expect(account.username, 'OrPudding');
      expect(account.userId, '191699');
    },
  );

  test('BandBBS publishing authorization runs through the host', () async {
    final host = _AccountHost();
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    await container
        .read(hostAccountsProvider.notifier)
        .startBandBbsPublishingAuthorization();

    expect(host.methods, contains('account.bandbbs.publish'));
    expect(container.read(hostAccountsProvider).bandbbs.isBusy, false);
  });
}

class _AccountHost implements OronBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    if (command.method == 'account.list') {
      return const CommandResult.success([
        {'provider': 'xiaomi', 'signedIn': false},
        {'provider': 'amazfit', 'signedIn': false},
        {'provider': 'bandbbs', 'signedIn': false},
      ]);
    }
    if (command.method == 'account.credentials.get') {
      return const CommandResult.success({
        'provider': 'amazfit',
        'remember': true,
        'username': 'user@example.com',
        'password': 'secret',
      });
    }
    if (command.method == 'account.credentials.set') {
      return CommandResult.success(command.params);
    }
    return CommandResult.success({
      'provider': 'amazfit',
      'signedIn': true,
      'username': command.params['username'],
    });
  }

  @override
  Future<void> close() => _events.close();
}

class _OAuthCallbackHost implements OronBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();
  Completer<CommandResult>? _staleRefresh;
  var _callbackStarted = false;

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'account.list') {
      if (_callbackStarted) {
        return (_staleRefresh ??= Completer<CommandResult>()).future;
      }
      return const CommandResult.success([
        {'provider': 'bandbbs', 'signedIn': false},
      ]);
    }
    if (command.method == 'account.bandbbs.callback') {
      _callbackStarted = true;
      const account = {
        'provider': 'bandbbs',
        'signedIn': true,
        'username': 'OrPudding',
        'userId': '191699',
      };
      _events.add(
        const CommandEvent(
          'account.state',
          data: {
            'state': [account],
          },
        ),
      );
      return const CommandResult.success(account);
    }
    throw StateError('Unexpected command ${command.method}');
  }

  void completeStaleRefresh() {
    _staleRefresh?.complete(
      const CommandResult.success([
        {'provider': 'bandbbs', 'signedIn': false},
      ]),
    );
  }

  @override
  Future<void> close() => _events.close();
}
