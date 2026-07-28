import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/layout/app_scaffold.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/widgets/dialog_helper.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/devices/pages/apps/device_apps_page.dart';
import 'package:oronbox/src/features/devices/pages/devices_page.dart';
import 'package:oronbox/src/features/devices/pages/firmware/device_firmware_page.dart';
import 'package:oronbox/src/features/devices/pages/info/device_info_page.dart';
import 'package:oronbox/src/features/devices/pages/install/install_local_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_more_features_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_xiao_ai_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_app_side_debug_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_app_settings_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_maps_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_music_upload_page.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_voice_memos_page.dart';
import 'package:oronbox/src/features/devices/pages/switch/device_switch_page.dart';
import 'package:oronbox/src/features/debug/pages/debug_window_app.dart';
import 'package:oronbox/src/features/oobe/oobe_state.dart';
import 'package:oronbox/src/features/oobe/pages/oobe_page.dart';
import 'package:oronbox/src/features/devices/pages/watchfaces/device_watchfaces_page.dart';
import 'package:oronbox/src/features/devices/providers/pending_shared_device_provider.dart';
import 'package:oronbox/src/features/devices/services/device_share_link.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_center_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_resource_page.dart';
import 'package:oronbox/src/features/resources/pages/huami_publisher_page.dart';
import 'package:oronbox/src/features/resources/pages/queue_page.dart';
import 'package:oronbox/src/features/resources/pages/resource_detail_page.dart';
import 'package:oronbox/src/features/resources/pages/resources_page.dart';
import 'package:oronbox/src/features/settings/pages/acknowledgements_page.dart';
import 'package:oronbox/src/features/settings/pages/about_software_page.dart';
import 'package:oronbox/src/features/settings/pages/settings_page.dart';
import 'package:oronbox/src/features/settings/pages/clean_mode_page.dart';
import 'package:oronbox/src/features/settings/pages/bandbbs_account_page.dart';
import 'package:oronbox/src/features/settings/pages/feedback_page.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_detail_page.dart';
import 'package:oronbox/src/features/plugins/pages/plugins_page.dart';
import 'package:oronbox/src/features/messages/pages/inbox_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/resources',
    observers: [OronBoxDialog.observer],
    redirect: (context, state) {
      final uri = state.uri;
      final onOobe = uri.path == '/oobe';
      if (!isOobeCompleted()) {
        // Until the agreements are accepted and the wizard is finished,
        // everything lands on the OOBE. OAuth callbacks are consumed by
        // DeviceDeepLinkHandler independently of the route.
        return onOobe ? null : '/oobe';
      }
      if (onOobe && uri.queryParameters['replay'] != '1') {
        return '/resources';
      }
      final clean = ref.read(appSettingsProvider).clean;
      if (uri.path == '/inbox' && !clean.inboxEnabled) {
        return clean.exploreEnabled ? '/resources' : '/devices';
      }
      if (uri.path.startsWith('/plugins') && !clean.pluginsEnabled) {
        return clean.exploreEnabled ? '/resources' : '/devices';
      }
      if (uri.path.startsWith('/resources')) {
        if (!clean.exploreEnabled) return '/devices';
        if (uri.path.startsWith('/resources/creator') &&
            !clean.creatorEnabled) {
          return '/resources';
        }
        if (uri.path.startsWith('/resources/detail') &&
            !clean.resourceLibraryEnabled) {
          return '/resources';
        }
      }
      final isDeviceShareLink =
          (uri.scheme == 'oronbox' && uri.host == 'open') ||
          ((uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host == 'oronbox.zxor.org' &&
              uri.path == '/open');
      if (!isDeviceShareLink) return null;

      final device = DeviceShareLink.parse(uri.toString());
      if (device != null) {
        ref.read(pendingSharedDeviceProvider.notifier).set(device);
        return '/devices/switch';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/home', redirect: (context, state) => '/resources'),
      GoRoute(path: '/oobe', builder: (context, state) => const OobePage()),
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugWindowPage(embedded: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resources',
                builder: (context, state) => const ResourcesPage(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    pageBuilder: (context, state) {
                      final resource = state.extra as CommunityResource?;
                      late final Widget child;
                      if (resource != null) {
                        child = ResourceDetailPage(
                          resource: resource,
                          targetCommentId:
                              state.uri.queryParameters['comment'] ?? '',
                        );
                      } else {
                        child = ResourceDetailPage(
                          targetCommentId:
                              state.uri.queryParameters['comment'] ?? '',
                          resource: CommunityResource(
                            ref: ResourceRef(
                              source:
                                  communitySourceIdByName(
                                    state.uri.queryParameters['source'] ?? '',
                                  ) ??
                                  ref.read(selectedCommunitySourceProvider),
                              id: state.pathParameters['id']!,
                            ),
                            name: '',
                            type: CommunityResourceType.quickApp,
                            paidType: CommunityPaidType.free,
                            authors: const [],
                            supportedDevices: const {},
                          ),
                        );
                      }
                      return CustomTransitionPage<void>(
                        key: state.pageKey,
                        transitionDuration: const Duration(milliseconds: 320),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 300,
                        ),
                        child: ScaffoldMessenger(child: child),
                        transitionsBuilder:
                            AppTheme.buildPlatformPageTransition,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'huami-publisher',
                    builder: (context, state) => HuamiPublisherPage(
                      publisherName: state.uri.queryParameters['name'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'creator',
                    builder: (context, state) => const CreatorCenterPage(),
                    routes: [
                      GoRoute(
                        path: 'resource',
                        builder: (context, state) =>
                            const CreatorResourcePage(),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const InboxPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/devices',
                builder: (context, state) => const DevicesPage(),
                routes: [
                  GoRoute(
                    path: 'switch',
                    builder: (context, state) => const DeviceSwitchPage(),
                  ),
                  GoRoute(
                    path: 'info',
                    builder: (context, state) => const DeviceInfoPage(),
                  ),
                  GoRoute(
                    path: 'firmware',
                    pageBuilder: (context, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      transitionDuration: const Duration(milliseconds: 320),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 300,
                      ),
                      child: const ScaffoldMessenger(
                        child: DeviceFirmwarePage(),
                      ),
                      transitionsBuilder: AppTheme.buildPlatformPageTransition,
                    ),
                  ),
                  GoRoute(
                    path: 'install/:type',
                    builder: (context, state) {
                      final typeName = state.pathParameters['type']!;
                      final type = InstallType.values.firstWhere(
                        (e) => e.name == typeName,
                        orElse: () => InstallType.app,
                      );
                      return InstallLocalPage(type: type);
                    },
                  ),
                  GoRoute(
                    path: 'apps',
                    builder: (context, state) => const DeviceAppsPage(),
                  ),
                  GoRoute(
                    path: 'watchfaces',
                    builder: (context, state) => const DeviceWatchfacesPage(),
                  ),
                  GoRoute(
                    path: 'velaos-music',
                    builder: (context, state) =>
                        const DeviceMusicUploadPage(xiaomi: true),
                  ),
                  GoRoute(
                    path: 'zeppos-more',
                    builder: (context, state) => const ZeppOsMoreFeaturesPage(),
                    routes: [
                      GoRoute(
                        path: 'xiao-ai',
                        builder: (context, state) => const ZeppOsXiaoAiPage(),
                      ),
                      GoRoute(
                        path: 'voice-memos',
                        builder: (context, state) =>
                            const ZeppOsVoiceMemosPage(),
                      ),
                      GoRoute(
                        path: 'music',
                        builder: (context, state) =>
                            const DeviceMusicUploadPage(),
                      ),
                      GoRoute(
                        path: 'app-side',
                        builder: (context, state) =>
                            const ZeppOsAppSideDebugPage(),
                      ),
                      GoRoute(
                        path: 'settings',
                        builder: (context, state) =>
                            const ZeppOsAppSettingsPage(),
                      ),
                      GoRoute(
                        path: 'maps',
                        builder: (context, state) => const ZeppOsMapsPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/queue',
                builder: (context, state) => const QueuePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plugins',
                builder: (context, state) => const PluginsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        PluginDetailPage(pluginId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  for (final category in SettingsCategory.values)
                    GoRoute(
                      path: category.name,
                      builder: (context, state) =>
                          SettingsPage(category: category),
                    ),
                  GoRoute(
                    path: 'clean-mode',
                    builder: (context, state) => const CleanModePage(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutSoftwarePage(),
                  ),
                  GoRoute(
                    path: 'logs',
                    builder: (context, state) => const RuntimeLogsPage(),
                  ),
                  GoRoute(
                    path: 'bandbbs',
                    builder: (context, state) => const BandBbsAccountPage(),
                  ),
                  GoRoute(
                    path: 'team',
                    redirect: (context, state) => '/settings/about',
                  ),
                  GoRoute(
                    path: 'acknowledgements',
                    builder: (context, state) => const AcknowledgementsPage(),
                  ),
                  GoRoute(
                    path: 'licenses',
                    builder: (context, state) =>
                        const LicensePage(applicationName: 'OronBox'),
                  ),
                  GoRoute(
                    path: 'feedback',
                    builder: (context, state) =>
                        FeedbackPage(target: state.extra as FeedbackTarget?),
                    routes: [
                      GoRoute(
                        path: 'ticket',
                        builder: (context, state) => FeedbackTicketPage(
                          ticket: state.extra! as FeedbackTicket,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
