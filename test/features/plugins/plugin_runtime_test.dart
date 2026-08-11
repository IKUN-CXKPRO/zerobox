import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/plugins/runtime/plugin_runtime.dart';

void main() {
  test('interconnect send forwards the optional device id', () {
    expect(
      oronBoxPluginBootstrap,
      contains("host('interconnect.send', [packageName, data, deviceId])"),
    );
  });

  test('failed host futures are consumed and dispatch QuickJS once', () async {
    final unhandled = <Object>[];
    var dispatches = 0;

    await runZonedGuarded(() async {
      settlePluginHostCall(
        Future<Object?>.error(StateError('host failure')),
        () => dispatches++,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => unhandled.add(error));

    expect(unhandled, isEmpty);
    expect(dispatches, 1);
  });
}
