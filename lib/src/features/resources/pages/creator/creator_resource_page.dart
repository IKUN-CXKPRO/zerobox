import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_editor_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

class CreatorResourcePage extends ConsumerWidget {
  const CreatorResourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(creatorWorkspaceProvider);
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    final workspace = state.selected;
    if (workspace == null) {
      return Scaffold(
        appBar: SysAppBar(secondary: true, title: Text(l10n.creatorCenter)),
        body: Center(child: Text(l10n.creatorSelectHint)),
      );
    }
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          creatorWorkspaceTitle(workspace),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: CreatorStateBadge(state: creatorWorkspaceState(workspace)),
            ),
          ),
        ],
      ),
      body: CreatorEditorView(
        key: ValueKey(
          '${workspace.resource.id}:${workspace.latestRevision?.id ?? 'new'}',
        ),
        workspace: workspace,
        state: state,
        controller: controller,
        ref: ref,
      ),
    );
  }
}
