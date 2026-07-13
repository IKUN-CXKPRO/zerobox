import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

class ZeppOsMoreFeaturesPage extends ConsumerStatefulWidget {
  const ZeppOsMoreFeaturesPage({super.key});

  @override
  ConsumerState<ZeppOsMoreFeaturesPage> createState() =>
      _ZeppOsMoreFeaturesPageState();
}

class _ZeppOsMoreFeaturesPageState
    extends ConsumerState<ZeppOsMoreFeaturesPage> {
  bool _finding = false;
  bool _busy = false;

  Future<void> _setFinding(bool finding) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setFindingZeppOsDevice(finding);
      if (mounted) setState(() => _finding = finding);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.zeppOsMoreFeatures)),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
          vertical: 16,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vibration,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.zeppOsFindDevice,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.zeppOsFindDeviceDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _finding
                          ? OutlinedButton.icon(
                              onPressed: ready && !_busy
                                  ? () => _setFinding(false)
                                  : null,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.stop_circle_outlined),
                              label: Text(l10n.zeppOsFindDeviceStop),
                            )
                          : FilledButton.icon(
                              onPressed: ready && !_busy
                                  ? () => _setFinding(true)
                                  : null,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.notifications_active),
                              label: Text(l10n.zeppOsFindDeviceStart),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
