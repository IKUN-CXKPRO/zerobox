import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_editor_page.dart';
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
    if (!bandBbs.isSignedIn) {
      return _CreatorLoginGate(
        busy: bandBbs.isBusy,
        onLogin: ref.read(hostAccountsProvider.notifier).startBandBbsLogin,
      );
    }
    return _CreatorTermsGate(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = useWideLayout(constraints.maxWidth);
          final listPane = Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.myResources,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: state.loading
                        ? null
                        : () => _create(context, controller),
                    icon: const Icon(Icons.add),
                    tooltip: l10n.creatorNewResource,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: CreatorResourceList(
                  state: state,
                  controller: controller,
                  onCreate: () => _create(context, controller),
                ),
              ),
              const SizedBox(height: 12),
              _CreatorAuthorizationStatus(
                grants: state.grants,
                busy:
                    bandBbs.isBusy ||
                    state.operation == CreatorOperation.authorizing,
                onBandBbsAuthorize: () => _authorizeBandBbs(context, ref),
                onGitHubAuthorize: () => _authorizeGitHub(context, controller),
              ),
              const SizedBox(height: 12),
            ],
          );
          final selected = state.selected;
          if (!wide && selected == null) {
            return PageContainer(
              maxWidth: 1000,
              padding: const EdgeInsets.symmetric(
                horizontal: StyleConstants.pagePadding,
              ),
              child: listPane,
            );
          }
          if (!wide) {
            return _CreatorWorkspaceView(
              workspace: selected!,
              state: state,
              controller: controller,
              showBack: true,
            );
          }
          return PageContainer(
            maxWidth: 1400,
            padding: const EdgeInsets.symmetric(
              horizontal: StyleConstants.pagePadding,
            ),
            child: Row(
              children: [
                SizedBox(width: 360, child: listPane),
                const SizedBox(width: 24),
                Expanded(
                  child: selected == null
                      ? _CreatorSelectionPlaceholder(
                          text: l10n.creatorSelectHint,
                        )
                      : _CreatorWorkspaceView(
                          workspace: selected,
                          state: state,
                          controller: controller,
                          showBack: false,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _authorizeGitHub(
    BuildContext context,
    CreatorWorkspaceController controller,
  ) async {
    try {
      final started = await controller.startGitHubAuthorization();
      final flowId = started['flow_id']?.toString() ?? '';
      final uri = Uri.tryParse(started['authorization_url']?.toString() ?? '');
      if (flowId.isEmpty || uri == null || !await launchUrl(uri)) {
        controller.finishAuthorization();
        return;
      }
      for (var attempt = 0; attempt < 60 && context.mounted; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (await controller.pollGitHubAuthorization(flowId)) return;
      }
      controller.finishAuthorization();
    } catch (error) {
      controller.finishAuthorization();
      if (context.mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _authorizeBandBbs(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(hostAccountsProvider.notifier)
          .startBandBbsPublishingAuthorization();
    } catch (error) {
      if (context.mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _create(
    BuildContext context,
    CreatorWorkspaceController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    var kind = CreatorResourceKind.quickApp;
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.creatorNewResource),
            ),
          ],
        ),
      ),
    );
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
        await controller.create(slug, kind);
      } catch (error) {
        if (context.mounted) showCreatorFailure(context, error);
      }
    }
  }
}

class _CreatorWorkspaceView extends ConsumerWidget {
  const _CreatorWorkspaceView({
    required this.workspace,
    required this.state,
    required this.controller,
    required this.showBack,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceState state;
  final CreatorWorkspaceController controller;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            children: [
              if (showBack) ...[
                IconButton(
                  onPressed: () => controller.select(null),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  creatorWorkspaceTitle(workspace),
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              CreatorStateBadge(state: creatorWorkspaceState(workspace)),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CreatorEditorView(
                key: ValueKey(
                  '${workspace.resource.id}:${workspace.latestRevision?.id ?? 'new'}',
                ),
                workspace: workspace,
                state: state,
                controller: controller,
                ref: ref,
              ),
            ),
          ),
        ),
      ],
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

class _CreatorSelectionPlaceholder extends StatelessWidget {
  const _CreatorSelectionPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_note_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _CreatorAuthorizationStatus extends StatelessWidget {
  const _CreatorAuthorizationStatus({
    required this.grants,
    required this.busy,
    required this.onBandBbsAuthorize,
    required this.onGitHubAuthorize,
  });

  final Map<String, Object?> grants;
  final bool busy;
  final Future<void> Function() onBandBbsAuthorize;
  final Future<void> Function() onGitHubAuthorize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final bandBbsReady = grants['bandbbs_publish'] == true;
    final githubLogin = grants['github_login']?.toString() ?? '';
    return Card(
      color: colors.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const CreatorBrandLogo(
              asset: 'assets/images/brands/bandbbs.svg',
              label: 'BandBBS',
            ),
            title: const Text('BandBBS'),
            subtitle: Text(
              bandBbsReady
                  ? l10n.creatorBandBbsWriteReady
                  : l10n.creatorBandBbsWriteMissing,
            ),
            trailing: bandBbsReady
                ? Icon(Icons.check_circle_outline, color: colors.primary)
                : FilledButton.tonal(
                    onPressed: busy ? null : onBandBbsAuthorize,
                    child: Text(l10n.creatorAuthorize),
                  ),
          ),
          ListTile(
            leading: const CreatorBrandLogo(
              asset: 'assets/images/brands/github.svg',
              label: 'GitHub',
            ),
            title: const Text('GitHub'),
            subtitle: Text(
              githubLogin.isEmpty
                  ? l10n.creatorGitHubOwnPublishMissing
                  : l10n.creatorGitHubOwnPublishReady(githubLogin),
            ),
            trailing: githubLogin.isNotEmpty
                ? Icon(Icons.check_circle_outline, color: colors.primary)
                : FilledButton.tonal(
                    onPressed: busy ? null : onGitHubAuthorize,
                    child: Text(l10n.creatorConnect),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CreatorTermsGate extends ConsumerStatefulWidget {
  const _CreatorTermsGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_CreatorTermsGate> createState() => _CreatorTermsGateState();
}

class _CreatorTermsGateState extends ConsumerState<_CreatorTermsGate> {
  static const _keyAccepted = 'creator.terms.accepted';
  bool _accepted = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _accepted = SharedPrefsService.instance.getBool(_keyAccepted) ?? false;
  }

  Future<void> _continue() async {
    await SharedPrefsService.instance.setBool(_keyAccepted, true);
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    final l10n = AppLocalizations.of(context)!;
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
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
