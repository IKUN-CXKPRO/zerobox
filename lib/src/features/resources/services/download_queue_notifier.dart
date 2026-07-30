import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/daemon/daemon_task_models.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/community_resource_codec.dart';
import 'package:oronbox/src/features/resources/services/daemon_task_feed.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

export 'package:oronbox/src/features/resources/services/resource_install_service.dart'
    show ResourceTaskStatus;

class ResourceTask {
  const ResourceTask({
    required this.id,
    required this.resource,
    required this.file,
    required this.codename,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String id;
  final CommunityResourceDetail resource;
  final CommunityResourceFile file;
  final String codename;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;

  String get title => resource.name;
  String get subtitle => '${resource.authorName} · $codename';
}

class DownloadQueueNotifier extends Notifier<List<ResourceTask>> {
  DaemonTaskFeed<ResourceTask>? _feed;
  CancelToken? _cancelToken;
  final Set<String> _enqueuing = {};

  @override
  List<ResourceTask> build() {
    if (kIsWeb) return const [];
    final host = ref.watch(applicationHostProvider);
    _feed = DaemonTaskFeed(
      host: host,
      method: 'resource.download',
      decode: _fromView,
      taskId: (task) => task.id,
      onChanged: (tasks) => state = tasks,
    );
    ref.onDispose(() => unawaited(_feed?.dispose()));
    scheduleMicrotask(() => _feed?.start());
    return const [];
  }

  ResourceTask? get runningTask => state
      .where(
        (task) =>
            task.status == ResourceTaskStatus.downloading ||
            task.status == ResourceTaskStatus.installing,
      )
      .firstOrNull;

  bool enqueue({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String codename,
  }) {
    final key = '${resource.ref.key}:${file.id}:$codename';
    if (_enqueuing.contains(key)) return false;
    if (state.any(
      (task) =>
          task.resource.ref == resource.ref &&
          task.file.id == file.id &&
          task.codename == codename &&
          task.status != ResourceTaskStatus.completed,
    )) {
      return false;
    }
    _enqueuing.add(key);
    unawaited(
      _enqueue(
        resource,
        file,
        codename,
      ).whenComplete(() => _enqueuing.remove(key)),
    );
    return true;
  }

  Future<void> _enqueue(
    CommunityResourceDetail resource,
    CommunityResourceFile file,
    String codename,
  ) async {
    if (kIsWeb) {
      final task = ResourceTask(
        id: '${resource.ref.key}:${file.id}:$codename',
        resource: resource,
        file: file,
        codename: codename,
      );
      state = [...state, task];
      _startNextWeb();
      return;
    }
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'task.enqueue',
            params: {
              'command': OronBoxCommand(
                method: 'resource.download',
                params: {
                  'ref': resource.ref.key,
                  'file': file.id,
                  'targetDevice': codename,
                  'title': resource.name,
                  'resource': communityResourceDetailToJson(resource),
                  'queueInstall': true,
                  'autoClean': true,
                },
              ).toJson(),
            },
          ),
        );
    if (!result.ok) throw StateError(result.error!.message);
    await _feed?.refresh();
  }

  void _startNextWeb() {
    if (runningTask != null) return;
    final next = state
        .where((task) => task.status == ResourceTaskStatus.pending)
        .firstOrNull;
    if (next != null) unawaited(_runWeb(next));
  }

  Future<void> _runWeb(ResourceTask task) async {
    _cancelToken = CancelToken();
    _updateWeb(task.id, ResourceTaskStatus.downloading, 0, null);
    try {
      final downloaded = await ResourceInstallService().downloadResource(
        resource: task.resource,
        file: task.file,
        catalog: ref.read(
          localCommunityCatalogProviderForSource(task.resource.ref.source),
        ),
        targetDevice: task.codename,
        onUpdate: (status, progress, error) =>
            _updateWeb(task.id, status, progress, error),
      );
      if (downloaded == null || !state.any((entry) => entry.id == task.id)) {
        return;
      }
      ref
          .read(installQueueProvider.notifier)
          .enqueueResource(
            resource: task.resource,
            file: task.file,
            codename: task.codename,
            filePath: downloaded.path,
            bytes: downloaded.bytes,
          );
      state = state.where((entry) => entry.id != task.id).toList();
    } finally {
      _cancelToken = null;
      _startNextWeb();
    }
  }

  void _updateWeb(
    String id,
    ResourceTaskStatus status,
    double progress,
    String? error,
  ) {
    state = [
      for (final task in state)
        if (task.id == id)
          ResourceTask(
            id: task.id,
            resource: task.resource,
            file: task.file,
            codename: task.codename,
            status: status,
            progress: progress,
            error: error,
          )
        else
          task,
    ];
  }

  void remove(String id) => unawaited(_remove(id));

  Future<void> _remove(String id) async {
    final task = state.where((task) => task.id == id).firstOrNull;
    if (task == null) return;
    if (kIsWeb) {
      if (task == runningTask) _cancelToken?.cancel('Removed from queue');
      state = state.where((entry) => entry.id != id).toList();
      _startNextWeb();
      return;
    }
    await _feed?.remove(
      id,
      terminal:
          task.status == ResourceTaskStatus.completed ||
          task.status == ResourceTaskStatus.failed,
    );
  }

  void clearTerminal() {
    if (kIsWeb) {
      state = state
          .where(
            (task) =>
                task.status != ResourceTaskStatus.completed &&
                task.status != ResourceTaskStatus.failed,
          )
          .toList();
      return;
    }
    for (final task in state.where(
      (task) =>
          task.status == ResourceTaskStatus.completed ||
          task.status == ResourceTaskStatus.failed,
    )) {
      unawaited(_remove(task.id));
    }
  }

  void retry(String id) {
    if (kIsWeb) {
      state = [
        for (final task in state)
          if (task.id == id)
            ResourceTask(
              id: task.id,
              resource: task.resource,
              file: task.file,
              codename: task.codename,
            )
          else
            task,
      ];
      _startNextWeb();
      return;
    }
    unawaited(_feed?.retry(id));
  }

  ResourceTask? _fromView(DaemonTaskView view) {
    final resourceJson = view.params['resource'];
    if (resourceJson is! Map) return null;
    final resource = communityResourceDetailFromJson(
      resourceJson.cast<String, Object?>(),
    );
    final fileId = view.params['file']?.toString();
    final file = resource.files.where((file) => file.id == fileId).firstOrNull;
    if (file == null) return null;
    return ResourceTask(
      id: view.id,
      resource: resource,
      file: file,
      codename: view.params['targetDevice']?.toString() ?? '',
      status: resourceTaskStatusFromDaemon(
        view.status,
        activity: ResourceTaskActivity.download,
      ),
      progress: view.progress,
      error: view.error,
    );
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<ResourceTask>>(
      DownloadQueueNotifier.new,
    );
