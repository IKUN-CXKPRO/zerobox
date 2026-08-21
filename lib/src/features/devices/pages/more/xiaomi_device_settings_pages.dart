import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

class XiaomiAppLayoutPage extends ConsumerStatefulWidget {
  const XiaomiAppLayoutPage({super.key});

  @override
  ConsumerState<XiaomiAppLayoutPage> createState() =>
      _XiaomiAppLayoutPageState();
}

class _XiaomiAppLayoutPageState extends ConsumerState<XiaomiAppLayoutPage> {
  pb_system.AppLayout? _layout;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final value = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiAppLayout();
      if (!mounted) return;
      setState(() {
        _layout = value;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setLayout(pb_system.AppLayout_Layout value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(deviceManagerProvider.notifier).setXiaomiAppLayout(value);
      if (mounted) {
        setState(() {
          _layout = pb_system.AppLayout(
            layout: value,
            supportLayouts: _layout?.supportLayouts,
          );
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final supported = _supportedLayouts(layout?.supportLayouts ?? 0);
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: const Text('应用布局设置')),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
        sections: [
          if (_loading)
            const CustomSegmentedSection(
              child: SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            SegmentedSection(
              tiles: [
                SegmentedTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('无法读取应用布局'),
                  description: Text(_error!),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            )
          else
            CustomSegmentedSection(
              child: RadioGroup<pb_system.AppLayout_Layout>(
                groupValue: layout?.layout,
                onChanged: (value) {
                  if (!_saving && value != null) _setLayout(value);
                },
                child: SegmentedSection(
                  tiles: [
                    for (final value in supported)
                      SegmentedTile(
                        leading: Icon(_layoutIcon(value)),
                        title: Text(_layoutName(value)),
                        trailing: Radio<pb_system.AppLayout_Layout>(
                          value: value,
                        ),
                        enabled: !_saving,
                        onPressed: (_) => _setLayout(value),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<pb_system.AppLayout_Layout> _supportedLayouts(int mask) {
    final values = [
      pb_system.AppLayout_Layout.LIST,
      pb_system.AppLayout_Layout.GRID,
      pb_system.AppLayout_Layout.GRID_TEXT,
    ];
    final supported = values
        .where((value) => mask == 0 || (mask & value.value) != 0)
        .toList(growable: false);
    return supported.isEmpty ? [values.first] : supported;
  }

  String _layoutName(pb_system.AppLayout_Layout value) => switch (value) {
    pb_system.AppLayout_Layout.LIST => '列表',
    pb_system.AppLayout_Layout.GRID => '网格',
    pb_system.AppLayout_Layout.GRID_TEXT => '带文字网格',
    _ => value.name,
  };

  IconData _layoutIcon(pb_system.AppLayout_Layout value) => switch (value) {
    pb_system.AppLayout_Layout.LIST => Icons.view_list_outlined,
    pb_system.AppLayout_Layout.GRID => Icons.grid_view_outlined,
    pb_system.AppLayout_Layout.GRID_TEXT => Icons.view_module_outlined,
    _ => Icons.dashboard_outlined,
  };
}
