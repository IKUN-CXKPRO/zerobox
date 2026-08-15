import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/widgets/xiaomi_fitness_logo.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart';

class XiaomiHealthPage extends ConsumerStatefulWidget {
  const XiaomiHealthPage({super.key});

  @override
  ConsumerState<XiaomiHealthPage> createState() => _XiaomiHealthPageState();
}

class _XiaomiHealthPageState extends ConsumerState<XiaomiHealthPage> {
  XiaomiHealthData? _data;
  String? _error;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiHealthData();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = _healthErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(deviceManagerProvider.notifier)
          .syncXiaomiHealth();
      if (!mounted) return;
      setState(() => _data = result.data);
      if (result.warning?.isNotEmpty == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.deviceHealthPartialSync,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = _healthErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    final ready =
        ref.watch(deviceManagerProvider).protocolState == ProtocolState.ready;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceHealthTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && data == null
            ? ListView(
                children: [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _load),
                  _SyncCard(
                    data: data,
                    syncing: _syncing,
                    enabled: ready,
                    onSync: _sync,
                  ),
                  const SizedBox(height: 12),
                  _DailyCard(summary: data?.latestDay),
                  const SizedBox(height: 12),
                  _SleepCard(summary: data?.latestSleep),
                ],
              ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.data,
    required this.syncing,
    required this.enabled,
    required this.onSync,
  });

  final XiaomiHealthData? data;
  final bool syncing;
  final bool enabled;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lastSynced = data?.lastSyncedAt;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const XiaomiFitnessLogo(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.deviceHealthSyncCardTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lastSynced == null
                  ? l10n.deviceHealthNeverSynced
                  : l10n.deviceHealthLastSynced(_formatDateTime(lastSynced)),
            ),
            if (!enabled) ...[
              const SizedBox(height: 4),
              Text(l10n.deviceHealthConnectFirst),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: !enabled || syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                syncing ? l10n.deviceHealthSyncing : l10n.deviceHealthSync,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.summary});

  final HealthDailySummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deviceHealthToday,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (summary == null)
              Text(l10n.deviceHealthNoData)
            else
              Wrap(
                spacing: 24,
                runSpacing: 18,
                children: [
                  _Metric(
                    label: l10n.deviceHealthSteps,
                    value: '${summary!.steps}',
                  ),
                  _Metric(
                    label: l10n.deviceHealthDistance,
                    value: _distance(summary!.distanceMeters),
                  ),
                  _Metric(
                    label: l10n.deviceHealthCalories,
                    value: '${summary!.calories} kcal',
                  ),
                  _Metric(
                    label: l10n.deviceHealthHeartRate,
                    value: summary!.heartRate > 0
                        ? '${summary!.heartRate} bpm'
                        : '—',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.summary});

  final HealthSleepSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deviceHealthSleep,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (summary == null)
              Text(l10n.deviceHealthNoData)
            else ...[
              Text(
                _duration(summary!.durationSeconds),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatTime(summary!.startedAt)} – ${_formatTime(summary!.endedAt)}',
              ),
              if (summary!.averageHeartRate != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.deviceHealthAverageHeartRate(summary!.averageHeartRate!),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card.filled(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
      title: Text(AppLocalizations.of(context)!.deviceHealthLoadFailed),
      subtitle: Text(message),
      trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
    ),
  );
}

String _formatDateTime(DateTime value) =>
    '${value.month}/${value.day} ${_formatTime(value)}';
String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _distance(int meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '$meters m';
String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}m';

String _healthErrorMessage(AppLocalizations l10n, Object error) {
  if (error is UnsupportedError) return l10n.errorUnknown;
  return localizedErrorMessage(l10n, error);
}
