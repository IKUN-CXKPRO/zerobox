import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_two_factor_resolver.dart';

/// The accounts step of the OOBE: three sign-in blocks replicated from the
/// settings page (BandBBS, Xiaomi, Huami) with their own descriptions.
class OobeLoginBlocks extends ConsumerWidget {
  const OobeLoginBlocks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.oobeLoginTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SettingsSection(
                        tiles: [
                          _bandBbsTile(context, ref, l10n),
                          _xiaomiTile(context, ref, l10n),
                          _huamiTile(context, ref, l10n),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.oobeLoginLocalNote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _startBandBbsLogin(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    await ref.read(hostAccountsProvider.notifier).startBandBbsLogin();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsAccountBandBbsOpenedBrowser)),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizedErrorMessage(l10n, e))));
  }
}

SettingsTile _bandBbsTile(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  return SettingsTile.navigation(
    onPressed: (_) {
      final account = ref.read(hostAccountsProvider).bandbbs;
      if (!account.isSignedIn && !account.isBusy) {
        _startBandBbsLogin(context, ref);
      }
    },
    leading: const _BrandLogo(
      asset: 'assets/images/brands/bandbbs.svg',
      semanticsLabel: 'BandBBS',
    ),
    title: Text(l10n.settingsAccountBandBbsAccount),
    description: Consumer(
      builder: (context, ref, _) {
        final account = ref.watch(hostAccountsProvider).bandbbs;
        if (account.isBusy) {
          return Text(l10n.settingsAccountBandBbsSigningIn);
        }
        if (account.isSignedIn) {
          final username = account.username?.trim() ?? '';
          final userId = account.userId?.trim() ?? '';
          if (username.isNotEmpty && userId.isNotEmpty) {
            return Text('$username · $userId');
          }
          if (username.isNotEmpty) return Text(username);
          if (userId.isNotEmpty) return Text(userId);
          return Text(l10n.settingsConnected);
        }
        return Text(l10n.oobeLoginBandBbsDesc);
      },
    ),
    value: Consumer(
      builder: (context, ref, _) {
        final account = ref.watch(hostAccountsProvider).bandbbs;
        if (account.isBusy) {
          return const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Text(
          account.isSignedIn
              ? l10n.settingsConnected
              : l10n.settingsTapToSignIn,
        );
      },
    ),
  );
}

SettingsTile _xiaomiTile(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  return SettingsTile.navigation(
    onPressed: (_) => _showMiAccountLogin(context, ref),
    leading: const _MiLogo(),
    title: Text(l10n.settingsMiAccount),
    description: Consumer(
      builder: (context, ref, _) {
        final account = ref.watch(hostAccountsProvider).xiaomi;
        if (account.isBusy) {
          return Text(l10n.settingsHuamiAccountSigningIn);
        }
        if (account.isSignedIn) {
          return Text(
            account.username?.isNotEmpty == true
                ? account.username!
                : l10n.settingsConnected,
          );
        }
        return Text(l10n.oobeLoginXiaomiDesc);
      },
    ),
    value: Consumer(
      builder: (context, ref, _) {
        final account = ref.watch(hostAccountsProvider).xiaomi;
        if (account.isBusy) {
          return const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Text(
          account.isSignedIn
              ? l10n.settingsConnected
              : l10n.settingsTapToSignIn,
        );
      },
    ),
  );
}

SettingsTile _huamiTile(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  return SettingsTile.navigation(
    onPressed: (_) => _showHuamiAccountLogin(context, ref),
    leading: const _LeadingBox(child: Icon(Icons.functions)),
    title: Text(l10n.settingsHuamiAccount),
    description: Consumer(
      builder: (context, ref, _) {
        final account = ref.watch(hostAccountsProvider).amazfit;
        if (account.isBusy) {
          return Text(l10n.settingsHuamiAccountSigningIn);
        }
        if (account.isSignedIn) {
          return Text(
            account.username?.isNotEmpty == true
                ? account.username!
                : l10n.settingsConnected,
          );
        }
        return Text(l10n.oobeLoginHuamiDesc);
      },
    ),
    value: Consumer(
      builder: (context, ref, _) {
        final account = ref.watch(hostAccountsProvider).amazfit;
        if (account.isBusy) {
          return const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Text(
          account.isSignedIn
              ? l10n.settingsConnected
              : l10n.settingsTapToSignIn,
        );
      },
    ),
  );
}

Future<void> _showMiAccountLogin(BuildContext context, WidgetRef ref) async {
  final rootContext = context;
  final l10n = AppLocalizations.of(context)!;
  final accounts = ref.read(hostAccountsProvider.notifier);
  final credentials = await accounts.rememberedCredentials('xiaomi');
  var rememberCredentials = credentials['remember'] == true;
  var username = rememberCredentials
      ? credentials['username']?.toString() ?? ''
      : '';
  var password = rememberCredentials
      ? credentials['password']?.toString() ?? ''
      : '';
  var running = false;
  var obscurePassword = true;
  String? error;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final normalizedUsername = username.trim();
            if (normalizedUsername.isEmpty || password.isEmpty) {
              setState(() {
                error = l10n.settingsMiAccountMissingCredentials;
              });
              return;
            }
            setState(() {
              running = true;
              error = null;
            });
            try {
              final account = await ref
                  .read(hostAccountsProvider.notifier)
                  .loginXiaomi(
                    username: normalizedUsername,
                    password: password,
                  );
              await accounts.saveCredentials(
                provider: 'xiaomi',
                remember: rememberCredentials,
                username: normalizedUsername,
                password: password,
                userId: account.userId ?? '',
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.settingsMiAccountSyncedDevices(
                        account.syncedDevices,
                      ),
                    ),
                  ),
                );
              }
            } on HostTwoFactorRequired catch (e) {
              try {
                setState(() {
                  error = l10n.settingsMiAccountTwoFactorPrompt;
                });
                if (!rootContext.mounted) {
                  throw StateError(l10n.settingsMiAccountLoginWindowClosed);
                }
                final cookieHeader = await createMiAccountTwoFactorResolver()
                    .resolve(rootContext, Uri.parse(e.url));
                final account = await ref
                    .read(hostAccountsProvider.notifier)
                    .completeXiaomiTwoFactor(
                      challenge: e,
                      cookieHeader: cookieHeader,
                    );
                await accounts.saveCredentials(
                  provider: 'xiaomi',
                  remember: rememberCredentials,
                  username: normalizedUsername,
                  password: password,
                  userId: account.userId ?? '',
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.settingsMiAccountSyncedDevices(
                          account.syncedDevices,
                        ),
                      ),
                    ),
                  );
                }
              } catch (twoFactorError) {
                setState(() {
                  running = false;
                  error = localizedErrorMessage(l10n, twoFactorError);
                });
              }
            } catch (e) {
              setState(() {
                running = false;
                error = localizedErrorMessage(l10n, e);
              });
            }
          }

          return AlertDialog(
            title: Text(l10n.settingsMiAccountLoginTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: username,
                    onChanged: (value) => username = value,
                    enabled: !running,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.settingsMiAccountUsername,
                      prefixIcon: const Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: password,
                    onChanged: (value) => password = value,
                    enabled: !running,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.settingsMiAccountPassword,
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
                    onFieldSubmitted: (_) {
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
                    title: Text(l10n.settingsMiAccountRememberCredentials),
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
                child: Text(l10n.settingsCancel),
              ),
              FilledButton(
                onPressed: running ? null : submit,
                child: Text(l10n.settingsMiAccountLoginAndSync),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showHuamiAccountLogin(BuildContext context, WidgetRef ref) async {
  final rootContext = context;
  final l10n = AppLocalizations.of(context)!;
  final accounts = ref.read(hostAccountsProvider.notifier);
  final credentials = await accounts.rememberedCredentials('amazfit');
  final existing = ref.read(hostAccountsProvider).amazfit;
  var rememberCredentials = credentials['remember'] == true;
  var username = rememberCredentials
      ? credentials['username']?.toString() ?? existing.username ?? ''
      : existing.username ?? '';
  var password = rememberCredentials
      ? credentials['password']?.toString() ?? ''
      : '';
  var running = false;
  var obscurePassword = true;
  String? error;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final normalizedUsername = username.trim();
            if (normalizedUsername.isEmpty || password.isEmpty) {
              setState(() {
                error = l10n.settingsHuamiAccountMissingCredentials;
              });
              return;
            }
            setState(() {
              running = true;
              error = null;
            });
            try {
              await ref
                  .read(hostAccountsProvider.notifier)
                  .loginAmazfit(
                    username: normalizedUsername,
                    password: password,
                  );
              await accounts.saveCredentials(
                provider: 'amazfit',
                remember: rememberCredentials,
                username: normalizedUsername,
                password: password,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text(l10n.settingsHuamiAccountSignedIn)),
                );
              }
            } catch (e) {
              setState(() {
                running = false;
                error = localizedErrorMessage(l10n, e);
              });
            }
          }

          return AlertDialog(
            title: Text(l10n.settingsHuamiAccountLoginTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: username,
                    onChanged: (value) => username = value,
                    enabled: !running,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.settingsHuamiAccountUsername,
                      prefixIcon: const Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: password,
                    onChanged: (value) => password = value,
                    enabled: !running,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.settingsHuamiAccountPassword,
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
                    onFieldSubmitted: (_) {
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
                    title: Text(l10n.settingsHuamiAccountRememberCredentials),
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
                child: Text(l10n.settingsCancel),
              ),
              FilledButton(
                onPressed: running ? null : submit,
                child: Text(l10n.settingsHuamiAccountLoginAndSave),
              ),
            ],
          );
        },
      );
    },
  );
}

class _LeadingBox extends StatelessWidget {
  const _LeadingBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: 32, child: Center(child: child));
  }
}

class _MiLogo extends StatelessWidget {
  const _MiLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/brands/xiaomi.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
          semanticsLabel: 'Xiaomi',
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.asset, required this.semanticsLabel});

  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: 27,
          height: 27,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}
