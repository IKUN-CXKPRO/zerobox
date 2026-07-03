import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/core/providers/theme_locale_providers.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.settingsTab)),
      body: SettingsList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
          vertical: StyleConstants.pagePadding,
        ),
        sections: [
          _buildSection(
            context,
            title: l10n.settingsAccount,
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => _showNotImplemented(context),
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(l10n.settingsGuest),
                description: Text(l10n.settingsTapToSignIn),
              ),
              SettingsTile.navigation(
                onPressed: (_) => _showNotImplemented(context),
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.settingsAccountLoginBBS),
                description: Text(l10n.settingsNotConnected),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsGeneral,
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => _showLanguageSelector(context, ref),
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.settingsGeneralLanguage),
                description: Text(l10n.settingsGeneralLanguageDesc),
                value: Consumer(
                  builder: (context, ref, _) {
                    final locale = ref.watch(localeSettingsProvider).locale;
                    return Text(_localeLabel(l10n, locale));
                  },
                ),
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setAutoReconnect(value ?? false);
                },
                initialValue: ref.watch(appSettingsProvider).autoReconnect,
                leading: const Icon(Icons.bluetooth_connected_outlined),
                title: Text(l10n.settingsAutoReconnectTitle),
                description: Text(l10n.settingsAutoReconnectDesc),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsSource,
            tiles: [
              SettingsTile.navigation(
                onPressed: (context) => _showCdnMenu(context, ref),
                leading: const Icon(Icons.cloud_outlined),
                title: Text(l10n.settingsSourceOfficialCdn),
                description: Text(l10n.settingsSourceOfficialCdnDesc),
                value: Consumer(
                  builder: (context, ref, _) {
                    final cdn = ref.watch(appSettingsProvider).cdn;
                    return Text(cdn.displayName);
                  },
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsInstall,
            tiles: [
              SettingsTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setAutoInstall(value ?? true);
                },
                initialValue: ref.watch(appSettingsProvider).autoInstall,
                leading: const Icon(Icons.task_alt_outlined),
                title: Text(l10n.settingsQueueAutoInstall),
                description: Text(l10n.settingsQueueAutoInstallDesc),
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setDisableAutoClean(value ?? false);
                },
                initialValue: ref.watch(appSettingsProvider).disableAutoClean,
                leading: const Icon(Icons.playlist_add_check_outlined),
                title: Text(l10n.settingsQueueDontClear),
                description: Text(l10n.settingsQueueDontClearDesc),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsAbout,
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => context.push('/settings/team'),
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.developmentTeam),
              ),
              SettingsTile.navigation(
                onPressed: (_) => _showLicensePage(context),
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.openSourceLicenses),
              ),
              SettingsTile.navigation(
                onPressed: (_) => context.push('/settings/acknowledgements'),
                leading: const Icon(Icons.favorite_outline),
                title: Text(l10n.acknowledgements),
              ),
              SettingsTile.navigation(
                onPressed: (_) => _launchUrl(context, 'https://zerobox.zxor.org'),
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.settingsAboutWebsite),
                description: Text(l10n.settingsAboutWebsiteDesc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SettingsSection _buildSection(
    BuildContext context, {
    required String title,
    required List<AbstractSettingsTile> tiles,
  }) {
    return SettingsSection(title: Text(title), tiles: tiles);
  }

  String _localeLabel(AppLocalizations l10n, AppLocale locale) {
    return switch (locale) {
      AppLocale.en => 'English',
      AppLocale.zh => '中文',
      _ => l10n.settingsSystem,
    };
  }

  Future<void> _showCdnMenu(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).cdn;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(tileContext).overlay?.context.findRenderObject()
        as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final selected = await showMenu<AstroBoxCdn>(
      context: tileContext,
      position: RelativeRect.fromRect(
        Rect.fromPoints(tileTopLeft, tileBottomRight),
        Offset.zero & overlay.size,
      ),
      initialValue: current,
      items: AstroBoxCdn.values.map((cdn) {
        return PopupMenuItem<AstroBoxCdn>(
          value: cdn,
          child: Text(cdn.displayName),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(appSettingsProvider.notifier).setCdn(selected);
      ref.invalidate(astroBoxIndexProvider);
      ref.invalidate(astroBoxDeviceMapProvider);
    }
  }

  Future<void> _showLanguageSelector(BuildContext context, WidgetRef ref) async {
    final current = ref.read(localeSettingsProvider).locale;
    final selected = await showModalBottomSheet<AppLocale>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.settingsGeneralLanguage,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ...AppLocale.values.map((locale) {
                final label = _localeLabel(l10n, locale);
                return ListTile(
                  leading: Icon(
                    Icons.language_outlined,
                    color: locale == current
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(label),
                  trailing: locale == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(locale),
                );
              }),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != current) {
      await ref.read(localeSettingsProvider.notifier).setLocale(selected);
    }
  }

  void _showNotImplemented(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Not implemented yet')),
    );
  }

  void _showLicensePage(BuildContext context) {
    showLicensePage(context: context);
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

