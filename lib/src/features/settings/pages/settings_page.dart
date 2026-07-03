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
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/features/accounts/services/mi_account_service.dart';
import 'package:zerobox/src/features/accounts/services/mi_account_two_factor_resolver.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _keyMiAccountRemember = 'mi_account.remember_credentials';
  static const _keyMiAccountUsername = 'mi_account.username';
  static const _keyMiAccountPassword = 'mi_account.password';

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
                onPressed: (_) => _showMiAccountLogin(context, ref),
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('小米账号'),
                description: const Text('登录并同步已绑定设备 authkey'),
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
                onPressed: (_) =>
                    _launchUrl(context, 'https://zerobox.zxor.org'),
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
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
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

  Future<void> _showMiAccountLogin(BuildContext context, WidgetRef ref) async {
    final rootContext = context;
    final prefs = SharedPrefsService.instance;
    var rememberCredentials = prefs.getBool(_keyMiAccountRemember) ?? false;
    final usernameController = TextEditingController(
      text: rememberCredentials ? prefs.getString(_keyMiAccountUsername) : null,
    );
    final passwordController = TextEditingController(
      text: rememberCredentials ? prefs.getString(_keyMiAccountPassword) : null,
    );
    var running = false;
    var obscurePassword = true;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final username = usernameController.text.trim();
              final password = passwordController.text;
              if (username.isEmpty || password.isEmpty) {
                setState(() {
                  error = '请输入小米账号和密码';
                });
                return;
              }
              setState(() {
                running = true;
                error = null;
              });
              final accountService = ref.read(miAccountServiceProvider);
              try {
                final token = await accountService.login(
                  username: username,
                  password: password,
                );
                final devices = await accountService.fetchBoundDevices(
                  token: token,
                );
                final imported = await ref
                    .read(deviceManagerProvider.notifier)
                    .importMiCloudDevices(devices);
                await _persistMiAccountCredentials(
                  remember: rememberCredentials,
                  username: username,
                  password: password,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text('已同步 $imported 台小米设备')),
                  );
                }
              } on MiAccountTwoFactorRequired catch (e) {
                try {
                  setState(() {
                    error = '请在弹出的验证页面完成小米账号二次验证';
                  });
                  if (!rootContext.mounted) {
                    throw StateError('登录窗口已关闭');
                  }
                  final cookieHeader = await createMiAccountTwoFactorResolver()
                      .resolve(rootContext, Uri.parse(e.url));
                  final token = await accountService.completeTwoFactorLogin(
                    challenge: e,
                    cookieHeader: cookieHeader,
                  );
                  final devices = await accountService.fetchBoundDevices(
                    token: token,
                  );
                  final imported = await ref
                      .read(deviceManagerProvider.notifier)
                      .importMiCloudDevices(devices);
                  await _persistMiAccountCredentials(
                    remember: rememberCredentials,
                    username: username,
                    password: password,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (rootContext.mounted) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(content: Text('已同步 $imported 台小米设备')),
                    );
                  }
                } catch (twoFactorError) {
                  setState(() {
                    running = false;
                    error = twoFactorError.toString();
                  });
                }
              } catch (e) {
                setState(() {
                  running = false;
                  error = e.toString();
                });
              }
            }

            return AlertDialog(
              title: const Text('小米账号登录'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      enabled: !running,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      enabled: !running,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: running
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!running) submit();
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: rememberCredentials,
                      onChanged: running
                          ? null
                          : (value) {
                              setState(() {
                                rememberCredentials = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('记住账号密码'),
                      dense: true,
                    ),
                    if (running) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: running
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: running ? null : submit,
                  child: const Text('登录并同步'),
                ),
              ],
            );
          },
        );
      },
    );

    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _persistMiAccountCredentials({
    required bool remember,
    required String username,
    required String password,
  }) async {
    final prefs = SharedPrefsService.instance;
    await prefs.setBool(_keyMiAccountRemember, remember);
    if (!remember) {
      await prefs.remove(_keyMiAccountUsername);
      await prefs.remove(_keyMiAccountPassword);
      return;
    }
    await prefs.setString(_keyMiAccountUsername, username);
    await prefs.setString(_keyMiAccountPassword, password);
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
