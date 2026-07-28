import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_music_upload_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;

class DeviceMusicUploadPage extends ConsumerStatefulWidget {
  const DeviceMusicUploadPage({super.key, this.xiaomi = false});

  final bool xiaomi;

  @override
  ConsumerState<DeviceMusicUploadPage> createState() =>
      _DeviceMusicUploadPageState();
}

class _DeviceMusicUploadPageState extends ConsumerState<DeviceMusicUploadPage> {
  Uint8List? _bytes;
  String? _fileName;
  final _title = TextEditingController();
  final _artist = TextEditingController();
  bool _artistInitialized = false;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_artistInitialized) return;
    _artistInitialized = true;
    _artist.text = AppLocalizations.of(context)!.deviceMusicUnknownArtist;
  }

  Future<void> _chooseFile() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      dialogTitle: l10n.deviceMusicChooseDialog,
      type: FileType.custom,
      allowedExtensions: const ['mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = l10n.deviceMusicReadFailed);
      return;
    }
    final maxBytes = widget.xiaomi
        ? 100 * 1024 * 1024
        : ZeppOsMusicUploadSystem.maxFileBytes;
    if (bytes.isEmpty || bytes.length > maxBytes) {
      setState(
        () => _error = l10n.deviceMusicSizeInvalid(maxBytes ~/ (1024 * 1024)),
      );
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
    final l10n = AppLocalizations.of(context)!;
    final bytes = _bytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null || _uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      if (widget.xiaomi) {
        await manager.uploadXiaomiMusic(
          bytes,
          title: _title.text,
          artist: _artist.text,
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        );
      } else {
        await manager.uploadZeppOsMusic(
          bytes,
          fileName: fileName,
          title: _title.text,
          artist: _artist.text,
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        );
      }
      if (!mounted) return;
      setState(() => _progress = 1);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deviceMusicTransferred)));
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          widget.xiaomi ? l10n.deviceMusicSync : l10n.deviceMusicUpload,
        ),
      ),
      body: PageContainer(
        child: ListView(
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.deviceMusicTransferTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.xiaomi
                        ? l10n.deviceMusicVelaDescription
                        : l10n.deviceMusicZeppDescription,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _chooseFile,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: Text(_fileName ?? l10n.deviceMusicChooseMp3),
                  ),
                  if (_bytes != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _title,
                      enabled: !_uploading,
                      decoration: InputDecoration(
                        labelText: l10n.deviceMusicSongTitle,
                        prefixIcon: const Icon(Icons.music_note),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _artist,
                      enabled: !_uploading,
                      decoration: InputDecoration(
                        labelText: l10n.deviceMusicArtist,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.deviceMusicFileSize(_formatBytes(_bytes!.length)),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (_uploading || _progress > 0) ...[
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text(
                      l10n.deviceMusicProgress(
                        (_progress * 100).toStringAsFixed(1),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: ready && _bytes != null && !_uploading
                        ? _upload
                        : null,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _uploading
                          ? l10n.deviceMusicTransferring
                          : l10n.deviceMusicSend,
                    ),
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
