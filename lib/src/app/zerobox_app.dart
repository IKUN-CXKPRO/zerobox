import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/router/app_router.dart';
import 'package:zerobox/src/app/theme/app_theme.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/core/providers/theme_locale_providers.dart';
import 'package:zerobox/src/features/devices/widgets/device_deep_link_handler.dart';

class ZeroBoxApp extends ConsumerWidget {
  const ZeroBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    final localeSettings = ref.watch(localeSettingsProvider);

    return MaterialApp.router(
      title: 'ZeroBox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: themeSettings.isOledDark ? AppTheme.oledDark : AppTheme.dark,
      themeMode: themeSettings.materialThemeMode,
      locale: localeSettings.materialLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) =>
          DeviceDeepLinkHandler(child: child ?? const SizedBox.shrink()),
    );
  }
}
