import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

class CreatorResourceList extends StatefulWidget {
  const CreatorResourceList({
    super.key,
    required this.state,
    required this.controller,
    required this.onCreate,
  });

  final CreatorWorkspaceState state;
  final CreatorWorkspaceController controller;
  final VoidCallback onCreate;

  @override
  State<CreatorResourceList> createState() => _CreatorResourceListState();
}

class _CreatorResourceListState extends State<CreatorResourceList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    if (state.loading && state.resources.isEmpty) {
      return Center(child: Text(creatorOperationLabel(l10n, state.operation)));
    }
    if (state.resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(l10n.creatorNoResources),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.loading ? null : widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.creatorNewResource),
            ),
          ],
        ),
      );
    }
    final presentStates = creatorStateOrder
        .where(
          (value) => state.resources.any(
            (workspace) => creatorWorkspaceState(workspace) == value,
          ),
        )
        .toList();
    if (!presentStates.contains(_filter)) _filter = 'all';
    final visible = _filter == 'all'
        ? state.resources
        : state.resources
              .where((workspace) => creatorWorkspaceState(workspace) == _filter)
              .toList();
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                _filterChip(l10n.all, 'all'),
                for (final value in presentStates)
                  _filterChip(creatorStateLabel(l10n, value), value),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final workspace in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CreatorResourceCard(
                workspace: workspace,
                controller: widget.controller,
                selected: workspace.resource.id == state.selected?.resource.id,
                onTap: () => widget.controller.select(workspace),
                onAction: (action) => _runAction(workspace, action),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  Future<void> _runAction(
    CreatorWorkspace workspace,
    CreatorResourceAction action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    controller.select(workspace);
    try {
      switch (action) {
        case CreatorResourceAction.delete:
          final accepted = await _confirm(
            title: l10n.creatorDeleteResource,
            message: workspace.revisions.isEmpty
                ? l10n.creatorDeleteConfirm
                : l10n.creatorDeletePublishedConfirm,
          );
          if (accepted) await controller.deleteResource();
        case CreatorResourceAction.archive:
          final accepted = await _confirm(
            title: l10n.creatorArchiveAction,
            message: l10n.creatorArchiveConfirm,
          );
          if (accepted) await controller.archive(true);
        case CreatorResourceAction.restore:
          await controller.archive(false);
      }
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(title),
          ),
        ],
      ),
    );
    return accepted == true;
  }
}

enum CreatorResourceAction { archive, restore, delete }

class CreatorResourceThumbnail extends StatefulWidget {
  const CreatorResourceThumbnail({
    super.key,
    required this.workspace,
    required this.controller,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceController controller;

  @override
  State<CreatorResourceThumbnail> createState() =>
      _CreatorResourceThumbnailState();
}

class _CreatorResourceThumbnailState extends State<CreatorResourceThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final media = creatorThumbnailMedia(widget.workspace);
    if (media == null) return;
    try {
      final bytes = await widget.controller.blob(
        widget.workspace.resource.id,
        media.sha256,
      );
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = _bytes;
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : Icon(
              widget.workspace.resource.kind == CreatorResourceKind.watchface
                  ? Icons.watch_outlined
                  : Icons.apps_outlined,
              color: colors.onSurfaceVariant,
            ),
    );
  }
}

class CreatorResourceCard extends StatelessWidget {
  const CreatorResourceCard({
    super.key,
    required this.workspace,
    required this.controller,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceController controller;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<CreatorResourceAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final state = creatorWorkspaceState(workspace);
    final isDraft = workspace.revisions.isEmpty;
    final isArchived = workspace.resource.state == 'archived';
    final subtitle = workspace.latestRevision?.summary ?? '';
    final note = state == 'rejected' ? creatorReviewNote(workspace) : '';
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? colors.secondaryContainer : null,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorResourceThumbnail(
                workspace: workspace,
                controller: controller,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            creatorWorkspaceTitle(workspace),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CreatorStateBadge(state: state),
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          creatorKindLabel(l10n, workspace.resource.kind),
                          if (workspace.artifacts.isNotEmpty)
                            l10n.creatorArtifactCount(
                              workspace.artifacts.length,
                            ),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${l10n.reviewNote}: $note',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<CreatorResourceAction>(
                tooltip: '',
                onSelected: onAction,
                itemBuilder: (_) => [
                  if (!isDraft && isArchived)
                    PopupMenuItem(
                      value: CreatorResourceAction.restore,
                      child: Text(l10n.creatorRestoreAction),
                    ),
                  if (!isDraft && !isArchived)
                    PopupMenuItem(
                      value: CreatorResourceAction.archive,
                      child: Text(l10n.creatorArchiveAction),
                    ),
                  PopupMenuItem(
                    value: CreatorResourceAction.delete,
                    child: Text(l10n.creatorDeleteResource),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
