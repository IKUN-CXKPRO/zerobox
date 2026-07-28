import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/messages/widgets/announcement_gate.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final l10n = AppLocalizations.of(context)!;
    final badgeCount = _queueBadgeCount(ref);
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
        badgeCount,
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
      badgeCount,
      branchIndices,
      showNavigation: primaryPaths.contains(GoRouterState.of(context).uri.path),
    );
  }

  Widget _buildBottomMenu(
    BuildContext context,
    AppLocalizations l10n,
    int badgeCount,
    List<int> branchIndices, {
    required bool showNavigation,
  }) {
    final navigationBar = NavigationBar(
      destinations: branchIndices
          .map((index) => _bottomDestination(l10n, badgeCount, index))
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
    int badgeCount,
    WideNavigationRailPosition railPosition,
    List<int> branchIndices,
  ) {
    final destinations = branchIndices
        .map((index) => _railDestination(l10n, badgeCount, index))
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
    AppLocalizations l10n,
    int badgeCount,
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
    2 => NavigationDestination(
      selectedIcon: const Icon(Icons.format_list_bulleted),
      icon: badgeCount > 0
          ? Badge(
              label: Text('$badgeCount'),
              child: const Icon(Icons.format_list_bulleted),
            )
          : const Icon(Icons.format_list_bulleted),
      label: l10n.settingsQueue,
    ),
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
    AppLocalizations l10n,
    int badgeCount,
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
    2 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.format_list_bulleted),
      icon: badgeCount > 0
          ? Badge(
              label: Text('$badgeCount'),
              child: const Icon(Icons.format_list_bulleted),
            )
          : const Icon(Icons.format_list_bulleted),
      label: Text(l10n.settingsQueue),
    ),
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

  int _queueBadgeCount(WidgetRef ref) {
    final downloadCount = ref.watch(
      downloadQueueProvider.select(
        (tasks) =>
            tasks.where((t) => t.status != ResourceTaskStatus.completed).length,
      ),
    );
    final installCount = ref.watch(
      installQueueProvider.select(
        (state) => state.tasks
            .where((t) => t.status != ResourceTaskStatus.completed)
            .length,
      ),
    );
    return downloadCount + installCount;
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
