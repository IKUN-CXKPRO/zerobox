import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';

const creatorStateOrder = [
  'draft',
  'pending',
  'rejected',
  'failed',
  'approved',
  'published',
  'archived',
];

String creatorWorkspaceState(CreatorWorkspace workspace) {
  if (workspace.resource.state == 'archived') return 'archived';
  if (workspace.revisions.isEmpty) return 'draft';
  final review = workspace.review?['state']?.toString();
  if (review == 'pending') return 'pending';
  if (review == 'rejected') return 'rejected';
  if (workspace.publications.any(
    (publication) => publication['state'] == 'failed',
  )) {
    return 'failed';
  }
  if (workspace.publications.any(
    (publication) => publication['state'] == 'published',
  )) {
    return 'published';
  }
  return review == 'approved' ? 'approved' : 'published';
}

String creatorStateLabel(AppLocalizations l10n, String state) =>
    switch (state) {
      'draft' => l10n.drafts,
      'archived' => l10n.creatorArchived,
      'pending' || 'submitted' => l10n.pendingReview,
      'approved' => l10n.creatorStateApproved,
      'rejected' => l10n.creatorReviewRejected,
      'published' => l10n.published,
      'reviewing' => l10n.creatorStateExternalReview,
      'failed' => l10n.creatorStateFailed,
      'superseded' => l10n.creatorStateSuperseded,
      'cancelled' => l10n.creatorStateCancelled,
      _ => state,
    };

String creatorOperationLabel(
  AppLocalizations l10n,
  CreatorOperation? operation,
) => switch (operation) {
  CreatorOperation.refreshing => l10n.creatorOperationRefreshing,
  CreatorOperation.creating => l10n.creatorOperationCreating,
  CreatorOperation.saving => l10n.creatorOperationSaving,
  CreatorOperation.publishing => l10n.creatorOperationSubmitting,
  CreatorOperation.deleting => l10n.creatorOperationDeleting,
  CreatorOperation.authorizing => l10n.creatorOperationAuthorizing,
  null => l10n.creatorOperationWorking,
};

String creatorTargetLabel(AppLocalizations l10n, String target) =>
    switch (target) {
      'oronbox' => l10n.oronBox,
      'bandbbs' => l10n.bandbbs,
      'astrobox' => l10n.astroBox,
      _ => target,
    };

String creatorKindLabel(AppLocalizations l10n, CreatorResourceKind kind) =>
    kind == CreatorResourceKind.watchface ? l10n.watchface : l10n.quickApp;

String creatorWorkspaceTitle(CreatorWorkspace workspace) {
  final latest = workspace.latestRevision;
  if (latest != null && latest.name.isNotEmpty) return latest.name;
  return workspace.resource.slug;
}

String creatorReviewNote(CreatorWorkspace workspace) =>
    workspace.review?['note']?.toString().trim() ?? '';

CreatorMedia? creatorThumbnailMedia(CreatorWorkspace workspace) {
  CreatorMedia? preview;
  for (final media in workspace.media) {
    if (media.role == 'icon' && media.sha256.isNotEmpty) return media;
    if (media.role == 'preview' &&
        media.sha256.isNotEmpty &&
        (preview == null || media.position < preview.position)) {
      preview = media;
    }
  }
  return preview;
}

void showCreatorFailure(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context)!;
  final message = creatorFailureMessage(error);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(l10n.errorUnknownWithDetail(message))),
    );
}

String formatCreatorFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024.0;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

class CreatorBrandLogo extends StatelessWidget {
  const CreatorBrandLogo({
    super.key,
    required this.asset,
    required this.label,
    this.size = 24,
  });

  final String asset;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: label,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    );
  }
}

class CreatorStateBadge extends StatelessWidget {
  const CreatorStateBadge({super.key, required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (state) {
      'rejected' || 'failed' => (colors.errorContainer, colors.onErrorContainer),
      'pending' => (colors.tertiaryContainer, colors.onTertiaryContainer),
      'published' || 'approved' => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        creatorStateLabel(AppLocalizations.of(context)!, state),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

class CreatorSectionTitle extends StatelessWidget {
  const CreatorSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class CreatorBottomBar extends StatelessWidget {
  const CreatorBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: children),
        ),
      ),
    );
  }
}

class CreatorReviewFeedback extends StatelessWidget {
  const CreatorReviewFeedback({super.key, required this.review});

  final Map<String, Object?> review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final state = review['state']?.toString() ?? '';
    final note = review['note']?.toString().trim() ?? '';
    final rejected = state == 'rejected';
    return Card(
      color: rejected ? colors.errorContainer : colors.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rejected ? Icons.feedback_outlined : Icons.fact_check_outlined,
              color: rejected
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rejected
                        ? l10n.creatorReviewRejected
                        : l10n.creatorReviewState(
                            creatorStateLabel(l10n, state),
                          ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.reviewNote}: $note',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
