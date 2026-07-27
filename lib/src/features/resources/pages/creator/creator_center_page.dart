import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_resource_list.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';

class CreatorCenterPage extends ConsumerWidget {
  const CreatorCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creatorWorkspaceProvider);
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    final bandBbs = ref.watch(hostAccountsProvider).bandbbs;
    final l10n = AppLocalizations.of(context)!;
    ref.listen(
      hostAccountsProvider.select(
        (value) => (value.bandbbs.isSignedIn, value.revision),
      ),
      (previous, current) {
        if (previous != current && current.$1) {
          unawaited(controller.refresh());
        }
      },
    );
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.creatorCenter),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () => unawaited(controller.refresh()),
          ),
        ],
      ),
      body: !bandBbs.isSignedIn
          ? _CreatorLoginGate(
              busy: bandBbs.isBusy,
              onLogin: ref
                  .read(hostAccountsProvider.notifier)
                  .startBandBbsLogin,
            )
          : state.governance != null
          ? _CreatorGovernanceGate(code: state.governance!)
          : _CreatorTermsGate(
              loading: state.loading,
              onCreate: () => _create(context, controller),
              child: PageContainer(
                maxWidth: 1000,
                padding: const EdgeInsets.symmetric(
                  horizontal: StyleConstants.pagePadding,
                ),
                child: CreatorResourceList(
                  state: state,
                  controller: controller,
                  onCreate: () => _create(context, controller),
                  onOpen: (workspace) {
                    controller.select(workspace);
                    context.push('/resources/creator/resource');
                  },
                ),
              ),
            ),
    );
  }

  Future<void> _create(
    BuildContext context,
    CreatorWorkspaceController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    var kind = CreatorResourceKind.quickApp;
    final name = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.creatorNewResource),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<CreatorResourceKind>(
                segments: [
                  ButtonSegment(
                    value: CreatorResourceKind.quickApp,
                    label: Text(l10n.quickApp),
                    icon: const Icon(Icons.apps_outlined),
                  ),
                  ButtonSegment(
                    value: CreatorResourceKind.watchface,
                    label: Text(l10n.watchface),
                    icon: const Icon(Icons.watch_outlined),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setState(() => kind = value.single),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: true,
                maxLength: 120,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.creatorResourceName,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) Navigator.pop(context, true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: Text(l10n.creatorNewResource),
            ),
          ],
        ),
      ),
    );
    final resourceName = name.text.trim();
    name.dispose();
    if (accepted == true) {
      const rulesSeenKey = 'creator.reviewRules.seen';
      final rulesSeen =
          SharedPrefsService.instance.getBool(rulesSeenKey) ?? false;
      if (!rulesSeen) {
        if (!context.mounted) return;
        final rulesAccepted = await showDialog<bool>(
          context: context,
          builder: (context) => const _ReviewRulesDialog(),
        );
        if (rulesAccepted != true) return;
        await SharedPrefsService.instance.setBool(rulesSeenKey, true);
      }
      try {
        final slug = 'resource-${DateTime.now().microsecondsSinceEpoch}';
        await controller.create(slug, resourceName, kind);
      } catch (error) {
        if (context.mounted) showCreatorFailure(context, error);
      }
    }
  }
}

class _CreatorGovernanceGate extends StatelessWidget {
  const _CreatorGovernanceGate({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final banned = code == 'banned';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: colors.surfaceContainerHigh,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  banned ? Icons.block : Icons.lock_outline,
                  size: 56,
                  color: colors.error,
                ),
                const SizedBox(height: 20),
                Text(
                  banned ? l10n.creatorBannedTitle : l10n.creatorFrozenTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  banned
                      ? l10n.creatorBannedDescription
                      : l10n.creatorFrozenDescription,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorLoginGate extends StatelessWidget {
  const _CreatorLoginGate({required this.busy, required this.onLogin});

  final bool busy;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: colors.surfaceContainerHigh,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 56,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.creatorLoginRequiredTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.creatorLoginRequiredDescription,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : onLogin,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(l10n.creatorLoginAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorTermsGate extends ConsumerStatefulWidget {
  const _CreatorTermsGate({
    required this.child,
    required this.loading,
    required this.onCreate,
  });

  final Widget child;
  final bool loading;
  final VoidCallback onCreate;

  @override
  ConsumerState<_CreatorTermsGate> createState() => _CreatorTermsGateState();
}

class _CreatorTermsGateState extends ConsumerState<_CreatorTermsGate> {
  static const keyAccepted = 'creator.terms.accepted';
  bool _accepted = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _accepted = SharedPrefsService.instance.getBool(keyAccepted) ?? false;
  }

  Future<void> _continue() async {
    await SharedPrefsService.instance.setBool(keyAccepted, true);
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_accepted) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'creator-new-resource',
              onPressed: widget.loading ? null : widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.creatorNewResource),
            ),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'zh';
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FutureBuilder<String>(
                            future: loadLegalDocument(
                              ref,
                              'resource-publishing',
                              language,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return Markdown(
                                data: snapshot.data!,
                                selectable: true,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  16,
                                ),
                                styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                    .copyWith(
                                      p: theme.textTheme.bodyMedium?.copyWith(
                                        height: 1.5,
                                      ),
                                      pPadding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      h1: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      h1Padding: const EdgeInsets.only(
                                        top: 16,
                                        bottom: 8,
                                      ),
                                      h2: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      h2Padding: const EdgeInsets.only(
                                        top: 12,
                                        bottom: 6,
                                      ),
                                    ),
                                onTapLink: (_, href, _) {
                                  final uri = Uri.tryParse(href ?? '');
                                  if (uri != null && uri.hasScheme) {
                                    launchUrl(uri);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        CreatorBottomBar(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _checked = !_checked),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checked,
                      onChanged: (value) =>
                          setState(() => _checked = value == true),
                    ),
                    Flexible(child: Text(l10n.creatorTermsAccept)),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: _checked ? _continue : null,
              child: Text(l10n.creatorTermsContinue),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRulesDialog extends ConsumerWidget {
  const _ReviewRulesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'zh';
    return Dialog.fullscreen(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FutureBuilder<String>(
                        future: loadLegalDocument(
                          ref,
                          'review-rules',
                          language,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return Markdown(
                            data: snapshot.data!,
                            selectable: true,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(
                                  p: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                                  pPadding: const EdgeInsets.only(bottom: 12),
                                  h1: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  h1Padding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 8,
                                  ),
                                  h2: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  h2Padding: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 6,
                                  ),
                                ),
                            onTapLink: (_, href, _) {
                              final uri = Uri.tryParse(href ?? '');
                              if (uri != null && uri.hasScheme) {
                                launchUrl(uri);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          CreatorBottomBar(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.creatorRulesAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
