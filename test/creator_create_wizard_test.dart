import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_create_wizard.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  testWidgets('import selection step renders appbar and body', (tester) async {
    tester.view.physicalSize = const Size(752, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [applicationHostProvider.overrideWithValue(_WizardHost())],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreatorCreateWizard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    debugPrint(
      'FORM TEXTS: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Import existing resources from other platforms'),
    );
    await tester.pump();
    expect(find.text('Import existing resources'), findsOneWidget);
    await tester.tap(find.text('Continue import'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CreatorBottomBar)).height, lessThan(100));
    expect(find.text('BandBBS Community'), findsOneWidget);
    expect(find.text('Select resources'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}

class _WizardHost implements OronBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(
    OronBoxCommand command,
  ) async => switch (command.method) {
    'creator.list' => const CommandResult.success({'resources': <Object?>[]}),
    'creator.collections.list' => const CommandResult.success({
      'collections': <Object?>[],
    }),
    'creator.devices' => const CommandResult.success({'devices': <Object?>[]}),
    'creator.grants' => const CommandResult.success(<String, Object?>{}),
    'account.list' => const CommandResult.success(<String, Object?>{
      'accounts': <Object?>[],
    }),
    _ => CommandResult.failure(CommandError('unexpected', command.method)),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
