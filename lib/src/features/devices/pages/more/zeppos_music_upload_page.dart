import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_music_upload_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;

class ZeppOsMusicUploadPage extends ConsumerStatefulWidget {
  const ZeppOsMusicUploadPage({super.key});

  @override
  ConsumerState<ZeppOsMusicUploadPage> createState() =>
      _ZeppOsMusicUploadPageState();
}

class _ZeppOsMusicUploadPageState
    extends ConsumerState<ZeppOsMusicUploadPage> {
  Uint8List? _bytes;
  String? _fileName;
  final _title = TextEditingController();
  final _artist = TextEditingController(text: '未知歌手');
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  Future<void> _chooseFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择要传到手表的 MP3',
      type: FileType.custom,
      allowedExtensions: const ['mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = '无法读取所选 MP3');
      return;
    }
    if (bytes.isEmpty || bytes.length > ZeppOsMusicUploadSystem.maxFileBytes) {
      setState(() => _error = 'MP3 大小必须在 1 字节至 50 MB 之间');
      return;
    }
    final base = file.name.toLowerCase().endsWith('.mp3')
        ? file.name.substring(0, file.name.length - 4)
        : file.name;
    setState(() {
      _bytes = bytes;
      _fileName = file.name;
      _title.text = base;
      _progress = 0;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final bytes = _bytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null || _uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .uploadZeppOsMusic(
            bytes,
            fileName: fileName,
            title: _title.text,
            artist: _artist.text,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            },
          );
      if (!mounted) return;
      setState(() => _progress = 1);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('音乐已传到手表')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        ref.watch(deviceManagerProvider).protocolState ==
        proto.ProtocolState.ready;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const SysAppBar(secondary: true, title: Text('音乐上传')),
      body: PageContainer(
        child: ListView(
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '传输 MP3 到手表',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持最大 50 MB 的 MP3。BT Classic 连接具有更高吞吐量，'
                    '适合音乐等大文件；BLE 也能使用，但耗时会明显增加。',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _chooseFile,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: Text(_fileName ?? '选择 MP3'),
                  ),
                  if (_bytes != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _title,
                      enabled: !_uploading,
                      decoration: const InputDecoration(
                        labelText: '歌名',
                        prefixIcon: Icon(Icons.music_note),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _artist,
                      enabled: !_uploading,
                      decoration: const InputDecoration(
                        labelText: '歌手',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '文件大小：${_formatBytes(_bytes!.length)}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (_uploading || _progress > 0) ...[
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text('已传输 ${(_progress * 100).toStringAsFixed(1)}%'),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        ready && _bytes != null && !_uploading ? _upload : null,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_uploading ? '正在传输' : '发送到手表'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
