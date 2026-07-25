import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/window/secondary_window_host.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_detail_page.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_host_request_handler.dart';

class PluginWindowApp extends StatelessWidget {
  const PluginWindowApp({super.key, required this.pluginId});
  final String pluginId;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OronBox Plugin',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SecondaryWindowHost(
      role: 'plugin.$pluginId',
      child: PluginHostRequestHandler(
        child: PluginDetailPage(pluginId: pluginId, allowDetach: false),
      ),
    ),
  );
}
