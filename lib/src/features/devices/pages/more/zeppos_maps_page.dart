import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_map_upload_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/pages/more/zeppos_map_preview.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;
import 'package:segmented_list/segmented_list.dart';

class ZeppOsMapsPage extends ConsumerStatefulWidget {
  const ZeppOsMapsPage({super.key});

  @override
  ConsumerState<ZeppOsMapsPage> createState() => _ZeppOsMapsPageState();
}

class _ZeppOsMapsPageState extends ConsumerState<ZeppOsMapsPage> {
  bool _uploading = false;
  double _progress = 0;
  String _operationStatus = '';

  Future<void> _upload() async {
    if (_uploading) return;
    final selection = await FilePicker.pickFiles(
      dialogTitle: '选择 Zepp OS 地图包',
      type: FileType.custom,
      allowedExtensions: const ['zip', 'img'],
      withData: true,
    );
    if (!mounted || selection == null || selection.files.isEmpty) return;
    final file = selection.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showError('无法读取地图包');
      return;
    }
    late final ZeppOsPreparedMap prepared;
    try {
      prepared = ZeppOsMapPackage.prepare(bytes, fileName: file.name);
    } catch (error) {
      await _showMapAnalysisError(error.toString());
      return;
    }
    final package = prepared.package;
    final previewTiles = package.tiles
        .map((tile) => (x: tile.x, y: tile.y, url: tile.openStreetMapUrl))
        .toList();
    if (!mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.map_outlined),
            title: const Text('传输离线地图'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (package.isGarminImg) ...[
                      Text(
                        '${file.name}\n'
                        '已识别为佳明单 IMG 地图：${package.garminImgName}',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '该地图没有 Zepp OS 的 11/x/y 瓦片目录，'
                        '将保留原始 IMG 内容并作为单文件地图包传输，因此不提供覆盖范围预览。',
                      ),
                    ] else ...[
                      Text(
                        '${file.name} · ${package.tiles.length} 个瓦片\n'
                        '预览显示地图包的覆盖范围，不代表手表上的 Garmin IMG 渲染样式。',
                      ),
                      const SizedBox(height: 16),
                      ZeppOsMapPreview(tiles: previewTiles, maxWidth: 420),
                    ],
                    const SizedBox(height: 12),
                    const Text('开始后还需要在手表上接受安装，传输期间请保持手表靠近电脑。'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始传输'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() {
      _uploading = true;
      _progress = 0;
      _operationStatus = '正在通过蓝牙传输';
    });
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .uploadZeppOsMap(
            prepared.bytes,
            fileName: prepared.fileName,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress.clamp(0, 1));
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('离线地图传输完成')));
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMapAnalysisError(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline),
        title: const Text('地图无法安全转换'),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceManagerProvider);
    final ready = deviceState.protocolState == proto.ProtocolState.ready;
    final usingBtbr = deviceState.currentDevice?.connectType == 'spp';
    return Scaffold(
      appBar: const SysAppBar(secondary: true, title: Text('离线地图')),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
        ),
        child: ListView(
          children: [
            SegmentedSection(
              title: const Text('地图'),
              margin: EdgeInsetsDirectional.zero,
              tiles: [
                SegmentedTile.navigation(
                  leading: _uploading
                      ? SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            value: _progress == 0 ? null : _progress,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  title: const Text('传输地图'),
                  description: Text(
                    _uploading
                        ? '$_operationStatus ${(_progress * 100).round()}%'
                        : '选择 ZIP 或 Garmin IMG 地图并发送到手表',
                  ),
                  enabled: ready && !_uploading,
                  onPressed: (_) => _upload(),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        usingBtbr
                            ? '当前使用 BT Classic 大文件通道。地图传输开始后，'
                                  '请同时在手表上确认安装。'
                            : 'BLE LE 仅支持不超过 2 MB 的地图包；更大的地图请先'
                                  '切换到 BT Classic。传输开始后请在手表上确认安装。',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
