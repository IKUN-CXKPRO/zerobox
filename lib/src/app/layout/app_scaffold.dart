import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/messages/widgets/announcement_gate.dart';

final _queueDoneAtProvider = NotifierProvider<_QueueDoneNotifier, DateTime?>(
  _QueueDoneNotifier.new,
);

class _QueueDoneNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void mark() => state = DateTime.now();
  void clear() => state = null;
}

final _queueDoneVersionProvider = NotifierProvider<_QueueVersionNotifier, int>(
  _QueueVersionNotifier.new,
);

class _QueueVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  int next() {
    state = state + 1;
    return state;
  }
}

bool _hasPending(List<ResourceTask> dl, List<InstallTask> il) =>
    dl.any((t) => t.status != ResourceTaskStatus.completed) ||
    il.any((t) => t.status != ResourceTaskStatus.completed);

class _QueueState {
  const _QueueState({
    this.active = 0,
    this.pending = 0,
    this.total = 0,
    this.progress = 0,
    this.installing = false,
    this.hasError = false,
  });
  final int active;
  final int pending;
  final int total;
  final double progress;
  final bool installing;
  final bool hasError;
}

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(downloadQueueProvider, (prev, _) {
      if (prev == null) return;
      final il = ref.read(installQueueProvider).tasks;
      if (_hasPending(prev, il) &&
          !_hasPending(ref.read(downloadQueueProvider), il)) {
        _markDone(ref);
      }
    });
    ref.listen(installQueueProvider, (prev, _) {
      if (prev == null) return;
      final dl = ref.read(downloadQueueProvider);
      if (_hasPending(dl, prev.tasks) &&
          !_hasPending(dl, ref.read(installQueueProvider).tasks)) {
        _markDone(ref);
      }
    });

    final doneAt = ref.watch(_queueDoneAtProvider);
    final width = MediaQuery.sizeOf(context).width;
    final l10n = AppLocalizations.of(context)!;
    final queue = _queueCounts(ref);

    final showExplore = ref.watch(
      appSettingsProvider.select((state) => state.clean.exploreEnabled),
    );
    final showPlugins = ref.watch(
      appSettingsProvider.select((state) => state.clean.pluginsEnabled),
    );
    final branchIndices = [if (showExplore) 0, 1, 2, if (showPlugins) 3, 4];
    if (!branchIndices.contains(navigationShell.currentIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigationShell.goBranch(branchIndices.first);
      });
    }
    final railPosition = ref.watch(
      appSettingsProvider.select((state) => state.wideNavigationRailPosition),
    );

    if (useWideLayout(width)) {
      return _buildSideMenu(
        context,
        l10n,
        queue,
        doneAt,
        railPosition,
        branchIndices,
      );
    }
    const primaryPaths = {
      '/resources',
      '/devices',
      '/queue',
      '/plugins',
      '/settings',
    };
    return _buildBottomMenu(
      context,
      l10n,
      queue,
      doneAt,
      branchIndices,
      showNavigation: primaryPaths.contains(GoRouterState.of(context).uri.path),
    );
  }

  static void _markDone(WidgetRef ref) {
    final version = ref.read(_queueDoneVersionProvider.notifier).next();
    ref.read(_queueDoneAtProvider.notifier).mark();
    Timer(const Duration(seconds: 2), () {
      if (ref.read(_queueDoneVersionProvider) == version) {
        ref.read(_queueDoneAtProvider.notifier).clear();
      }
    });
  }

  Widget _buildBottomMenu(
    BuildContext context,
    AppLocalizations l10n,
    _QueueState queue,
    DateTime? doneAt,
    List<int> branchIndices, {
    required bool showNavigation,
  }) {
    final navigationBar = NavigationBar(
      destinations: branchIndices
          .map(
            (index) => _bottomDestination(context, l10n, queue, doneAt, index),
          )
          .toList(growable: false),
      selectedIndex: branchIndices
          .indexOf(navigationShell.currentIndex)
          .clamp(0, branchIndices.length - 1),
      onDestinationSelected: (index) {
        final branch = branchIndices[index];
        if (branch != navigationShell.currentIndex) {
          navigationShell.goBranch(branch);
        }
      },
    );
    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: AnnouncementGate(child: navigationShell),
      ),
      bottomNavigationBar: showNavigation ? navigationBar : null,
    );
  }

  Widget _buildSideMenu(
    BuildContext context,
    AppLocalizations l10n,
    _QueueState queue,
    DateTime? doneAt,
    WideNavigationRailPosition railPosition,
    List<int> branchIndices,
  ) {
    final destinations = branchIndices
        .map((index) => _railDestination(context, l10n, queue, doneAt, index))
        .toList(growable: false);
    final selectedIndex = branchIndices.indexOf(navigationShell.currentIndex);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          SizedBox(
            width: 80,
            child: _WideNavigationRail(
              position: railPosition,
              destinations: destinations,
              selectedIndex: selectedIndex < 0 ? null : selectedIndex,
              onDestinationSelected: (index) {
                final branch = branchIndices[index];
                if (branch != navigationShell.currentIndex) {
                  navigationShell.goBranch(branch);
                }
              },
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
                child: AnnouncementGate(child: navigationShell),
              ),
            ),
          ),
        ],
      ),
    );
  }

  NavigationDestination _bottomDestination(
    BuildContext context,
    AppLocalizations l10n,
    _QueueState queue,
    DateTime? doneAt,
    int branch,
  ) => switch (branch) {
    0 => NavigationDestination(
      selectedIcon: const Icon(Icons.apps),
      icon: const Icon(Icons.apps_outlined),
      label: l10n.exploreTab,
    ),
    1 => NavigationDestination(
      selectedIcon: const Icon(Icons.watch),
      icon: const Icon(Icons.watch_outlined),
      label: l10n.devicesTab,
    ),
    2 => _queueDestination(context, queue, doneAt, l10n.settingsQueue),
    3 => NavigationDestination(
      selectedIcon: const Icon(Icons.extension),
      icon: const Icon(Icons.extension_outlined),
      label: l10n.pluginsTab,
    ),
    _ => NavigationDestination(
      selectedIcon: const Icon(Icons.settings),
      icon: const Icon(Icons.settings_outlined),
      label: l10n.settingsTab,
    ),
  };

  NavigationRailDestination _railDestination(
    BuildContext context,
    AppLocalizations l10n,
    _QueueState queue,
    DateTime? doneAt,
    int branch,
  ) => switch (branch) {
    0 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.apps),
      icon: const Icon(Icons.apps_outlined),
      label: Text(l10n.exploreTab),
    ),
    1 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.watch),
      icon: const Icon(Icons.watch_outlined),
      label: Text(l10n.devicesTab),
    ),
    2 => () {
      final icon = _queueIcon(context, queue, doneAt);
      return NavigationRailDestination(
        selectedIcon: icon,
        icon: icon,
        label: Text(l10n.settingsQueue),
      );
    }(),
    3 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.extension),
      icon: const Icon(Icons.extension_outlined),
      label: Text(l10n.pluginsTab),
    ),
    _ => NavigationRailDestination(
      selectedIcon: const Icon(Icons.settings),
      icon: const Icon(Icons.settings_outlined),
      label: Text(l10n.settingsTab),
    ),
  };

  NavigationDestination _queueDestination(
    BuildContext context,
    _QueueState queue,
    DateTime? doneAt,
    String label,
  ) {
    final icon = _queueIcon(context, queue, doneAt);
    return NavigationDestination(selectedIcon: icon, icon: icon, label: label);
  }

  Widget _queueIcon(BuildContext context, _QueueState queue, DateTime? doneAt) {
    if (queue.total == 0) {
      if (doneAt != null) {
        return Icon(Icons.check, color: Theme.of(context).colorScheme.primary);
      }
      return const Icon(Icons.format_list_bulleted);
    }
    if (queue.active == 0 && queue.hasError) {
      return Icon(
        Icons.priority_high,
        color: Theme.of(context).colorScheme.error,
      );
    }
    if (queue.active == 0) return const Icon(Icons.format_list_bulleted);
    final scheme = Theme.of(context).colorScheme;
    final color = queue.installing ? scheme.primary : scheme.secondary;
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: queue.progress),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v > 0 ? v : null,
              strokeWidth: 2.5,
              color: color,
            ),
          ),
          Text(
            '${queue.total}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  _QueueState _queueCounts(WidgetRef ref) {
    final dl = ref.watch(downloadQueueProvider);
    final il = ref.watch(installQueueProvider).tasks;
    var active = 0, pending = 0, total = 0;
    var installing = false, hasError = false;
    double progress = 0;
    bool hasActive = false;
    for (final t in dl) {
      if (t.status == ResourceTaskStatus.completed) continue;
      total++;
      if (t.status == ResourceTaskStatus.failed) hasError = true;
      if (t.status == ResourceTaskStatus.downloading ||
          t.status == ResourceTaskStatus.installing) {
        active++;
        if (!hasActive) {
          progress = t.progress;
          hasActive = true;
        }
      } else if (t.status == ResourceTaskStatus.pending) {
        pending++;
      }
    }
    for (final t in il) {
      if (t.status == ResourceTaskStatus.completed) continue;
      total++;
      if (t.status == ResourceTaskStatus.failed) hasError = true;
      if (t.status == ResourceTaskStatus.downloading ||
          t.status == ResourceTaskStatus.installing) {
        active++;
        installing = true;
        if (!hasActive) {
          progress = t.progress;
          hasActive = true;
        }
      } else if (t.status == ResourceTaskStatus.pending) {
        pending++;
      }
    }
    return _QueueState(
      active: active,
      pending: pending,
      total: total,
      progress: progress,
      installing: installing,
      hasError: hasError,
    );
  }
}

class _WideNavigationRail extends StatelessWidget {
  const _WideNavigationRail({
    required this.position,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final WideNavigationRailPosition position;
  final List<NavigationRailDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainer;
    if (position != WideNavigationRailPosition.split) {
      return NavigationRail(
        backgroundColor: color,
        groupAlignment: switch (position) {
          WideNavigationRailPosition.center => 0,
          _ => 1,
        },
        labelType: NavigationRailLabelType.selected,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      );
    }
    final primaryCount = destinations.length - 1;
    return Material(
      color: color,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: NavigationRail(
                backgroundColor: color,
                groupAlignment: 0,
                labelType: NavigationRailLabelType.selected,
                destinations: destinations
                    .take(primaryCount)
                    .toList(growable: false),
                selectedIndex:
                    selectedIndex != null && selectedIndex! < primaryCount
                    ? selectedIndex
                    : null,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 96,
                child: NavigationRail(
                  backgroundColor: color,
                  groupAlignment: 0,
                  labelType: NavigationRailLabelType.selected,
                  destinations: [destinations.last],
                  selectedIndex: selectedIndex == primaryCount ? 0 : null,
                  onDestinationSelected: (_) =>
                      onDestinationSelected(primaryCount),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
