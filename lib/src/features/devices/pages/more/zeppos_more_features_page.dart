import 'dart:async';

import 'package:segmented_list/segmented_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/protocols/common/device_protocol.dart' as proto;

class ZeppOsMoreFeaturesPage extends ConsumerStatefulWidget {
  const ZeppOsMoreFeaturesPage({super.key});

  @override
  ConsumerState<ZeppOsMoreFeaturesPage> createState() =>
      _ZeppOsMoreFeaturesPageState();
}

class _ZeppOsMoreFeaturesPageState
    extends ConsumerState<ZeppOsMoreFeaturesPage> {
  static const _mirrorIntervalPreferenceKey = 'zeppos.mirror.frame_interval_ms';

  bool _finding = false;
  bool _busy = false;
  bool _messagesExpanded = true;
  bool _mirrorSettingsExpanded = false;
  int _mirrorIntervalMs = 10;
  late final TextEditingController _mirrorIntervalController;
  late final FocusNode _mirrorIntervalFocusNode;

  @override
  void initState() {
    super.initState();
    _mirrorIntervalMs =
        (SharedPrefsService.instance.getInt(_mirrorIntervalPreferenceKey) ?? 10)
            .clamp(10, 250)
            .toInt();
    _mirrorIntervalController = TextEditingController(
      text: '$_mirrorIntervalMs',
    );
    _mirrorIntervalFocusNode = FocusNode()
      ..addListener(_handleMirrorIntervalFocus);
  }

  @override
  void dispose() {
    _mirrorIntervalFocusNode
      ..removeListener(_handleMirrorIntervalFocus)
      ..dispose();
    _mirrorIntervalController.dispose();
    super.dispose();
  }

  Future<void> _showMirror() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatchMirrorSheet(frameIntervalMs: _mirrorIntervalMs),
    );
  }

  void _setMirrorInterval(int interval) {
    setState(() => _mirrorIntervalMs = interval);
    unawaited(
      SharedPrefsService.instance.setInt(
        _mirrorIntervalPreferenceKey,
        interval,
      ),
    );
  }

  void _handleMirrorIntervalFocus() {
    if (!_mirrorIntervalFocusNode.hasFocus) {
      _commitMirrorInterval();
    }
  }

  void _commitMirrorInterval() {
    final parsed = int.tryParse(_mirrorIntervalController.text);
    final interval = (parsed ?? _mirrorIntervalMs).clamp(10, 250).toInt();
    _mirrorIntervalController
      ..text = '$interval'
      ..selection = TextSelection.collapsed(offset: '$interval'.length);
    if (interval != _mirrorIntervalMs) {
      _setMirrorInterval(interval);
    }
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
      appBar: SysAppBar(secondary: true, title: Text(l10n.zeppOsMoreFeatures)),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
        ),
        child: ListView(
          children: [
            SegmentedSection(
              title: const Text('功能'),
              margin: EdgeInsetsDirectional.zero,
              tiles: [
                SegmentedTile.navigation(
                  leading: const Icon(Icons.record_voice_over),
                  title: const Text('小爱同学'),
                  description: const Text('捕获 Opus 帧并实时解码播放'),
                  enabled: ready,
                  onPressed: (_) =>
                      context.push('/devices/zeppos-more/xiao-ai'),
                ),
                SegmentedTile.navigation(
                  leading: const Icon(Icons.mic_none),
                  title: const Text('录音同步'),
                  description: const Text('从手表同步并导出录音'),
                  enabled: ready,
                  onPressed: (_) =>
                      context.push('/devices/zeppos-more/voice-memos'),
                ),
                SegmentedTile.navigation(
                  leading: const Icon(Icons.library_music_outlined),
                  title: const Text('音乐上传'),
                  description: const Text('通过 BT Classic 高速传输 MP3 到手表'),
                  enabled: ready,
                  onPressed: (_) => context.push('/devices/zeppos-more/music'),
                ),
                SegmentedTile.navigation(
                  leading: const Icon(Icons.tune),
                  title: const Text('应用设置'),
                  description: const Text('打开已缓存的 Zepp OS 应用设置页'),
                  onPressed: (_) =>
                      context.push('/devices/zeppos-more/settings'),
                ),
                SegmentedTile.navigation(
                  leading: const Icon(Icons.code),
                  title: const Text('App-side 调试'),
                  description: const Text('按 appId 调试 QuickJS 与 PeerSocket 消息'),
                  enabled: ready,
                  onPressed: (_) =>
                      context.push('/devices/zeppos-more/app-side'),
                ),
                SegmentedTile.navigation(
                  leading: const Icon(Icons.watch_outlined),
                  title: const Text('屏幕镜像'),
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('在手机上查看手表画面'),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.topCenter,
                        child: !_mirrorSettingsExpanded
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    const Text('画面间隔'),
                                    const Spacer(),
                                    SizedBox(
                                      width: 112,
                                      child: TextField(
                                        controller: _mirrorIntervalController,
                                        focusNode: _mirrorIntervalFocusNode,
                                        enabled: ready,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        textAlign: TextAlign.end,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          TextInputFormatter.withFunction((
                                            oldValue,
                                            newValue,
                                          ) {
                                            if (newValue.text.isEmpty) {
                                              return newValue;
                                            }
                                            final value = int.tryParse(
                                              newValue.text,
                                            );
                                            return value != null && value <= 250
                                                ? newValue
                                                : oldValue;
                                          }),
                                        ],
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          suffixText: 'ms',
                                          helperText: '10–250',
                                        ),
                                        onChanged: (text) {
                                          final value = int.tryParse(text);
                                          if (value != null &&
                                              value >= 10 &&
                                              value <= 250) {
                                            _setMirrorInterval(value);
                                          }
                                        },
                                        onEditingComplete: () {
                                          _commitMirrorInterval();
                                          _mirrorIntervalFocusNode.unfocus();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: _mirrorSettingsExpanded ? '收起设置' : '展开设置',
                    onPressed: () => setState(
                      () => _mirrorSettingsExpanded = !_mirrorSettingsExpanded,
                    ),
                    icon: AnimatedRotation(
                      turns: _mirrorSettingsExpanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
                  enabled: ready,
                  onPressed: (_) => _showMirror(),
                ),
                SegmentedTile.navigation(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('离线地图'),
                  description: const Text('传输已有地图包到手表'),
                  onPressed: (_) => context.push('/devices/zeppos-more/maps'),
                ),
              ],
            ),
            SegmentedSection(
              title: const Text('设备'),
              margin: EdgeInsetsDirectional.zero,
              tiles: [
                SegmentedTile.switchTile(
                  leading: _busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.vibration),
                  title: Text(l10n.zeppOsFindDevice),
                  description: Text(l10n.zeppOsFindDeviceDescription),
                  initialValue: _finding,
                  enabled: ready && !_busy,
                  onToggle: (value) => _setFinding(value ?? false),
                ),
              ],
            ),
            SectionCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(
                            () => _messagesExpanded = !_messagesExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bluetooth_searching,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '实时 Zepp OS 消息',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                Icon(
                                  _messagesExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: state.zeppOsMessages.isEmpty
                            ? null
                            : () => ref
                                  .read(deviceManagerProvider.notifier)
                                  .clearZeppOsMessages(),
                        tooltip: '清空消息',
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _messagesExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    secondChild: const SizedBox.shrink(),
                    firstChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          '显示现有分包层已经解码的设备上行 endpoint 消息，最多保留最近 200 条。',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        _ZeppOsMessageList(messages: state.zeppOsMessages),
                      ],
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

class _WatchMirrorSheet extends ConsumerStatefulWidget {
  const _WatchMirrorSheet({required this.frameIntervalMs});

  final int frameIntervalMs;

  @override
  ConsumerState<_WatchMirrorSheet> createState() => _WatchMirrorSheetState();
}

class _WatchMirrorSheetState extends ConsumerState<_WatchMirrorSheet> {
  Uint8List? _frame;
  Object? _error;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _loop();
  }

  Future<void> _loop() async {
    while (mounted && _active) {
      try {
        final frame = await ref
            .read(deviceManagerProvider.notifier)
            .requestZeppOsScreenshot();
        if (!mounted || !_active) return;
        setState(() {
          _frame = frame;
          _error = null;
        });
        await Future<void>.delayed(
          Duration(milliseconds: widget.frameIntervalMs),
        );
      } catch (error) {
        if (!mounted || !_active) return;
        setState(() => _error = error);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '屏幕镜像',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _WatchMirror(frame: _frame, error: _error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchMirror extends StatelessWidget {
  const _WatchMirror({required this.frame, required this.error});

  final Uint8List? frame;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final android = Theme.of(context).platform == TargetPlatform.android;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: android ? 28 : 0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: android ? 220 : 320),
          child: AspectRatio(
            aspectRatio: 1,
            child: Semantics(
              label: 'Zepp OS 手表屏幕镜像',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (frame == null)
                    Positioned.fill(
                      child: SvgPicture.asset(
                        'assets/images/devices/xiaomi-watch.svg',
                        colorFilter: ColorFilter.mode(
                          colors.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  if (frame == null)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        color: colors.primary,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  if (frame != null)
                    Positioned.fill(
                      child: Align(
                        child: FractionallySizedBox(
                          widthFactor: 13 / 16,
                          heightFactor: 13 / 16,
                          child: ClipOval(
                            child: ColoredBox(
                              color: Colors.black,
                              child: Image.memory(
                                frame!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, error, _) => _MirrorStatus(
                                  icon: Icons.broken_image_outlined,
                                  text: '画面格式无法显示\n$error',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (frame != null)
                    Positioned.fill(
                      child: SvgPicture.asset(
                        'assets/images/devices/xiaomi-watch-mirror-shell.svg',
                        colorFilter: ColorFilter.mode(
                          colors.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MirrorStatus extends StatelessWidget {
  const _MirrorStatus({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 36),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

class _ZeppOsMessageList extends StatelessWidget {
  const _ZeppOsMessageList({required this.messages});

  final List<ZeppOsMessageRecord> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('暂无设备消息'),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: ListView.separated(
        shrinkWrap: true,
        reverse: true,
        itemCount: messages.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, reverseIndex) {
          final message = messages[messages.length - 1 - reverseIndex];
          final endpoint = message.endpoint
              .toRadixString(16)
              .padLeft(4, '0')
              .toUpperCase();
          final hex = message.payload
              .map(
                (byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase(),
              )
              .join(' ');
          final text = message.payload
              .map(
                (byte) =>
                    byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.',
              )
              .join();
          final isoTime = message.timestamp.toLocal().toIso8601String();
          final time = isoTime.length >= 23
              ? isoTime.substring(11, 23)
              : isoTime;
          final copyText =
              '$time EP 0x$endpoint (${message.payload.length} bytes)\n'
              '$hex\n$text';
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '$time  ·  0x$endpoint  ·  ${message.payload.length} bytes',
            ),
            subtitle: SelectableText('$hex\n$text', maxLines: 4),
            trailing: IconButton(
              tooltip: '复制消息',
              onPressed: () => Clipboard.setData(ClipboardData(text: copyText)),
              icon: const Icon(Icons.copy_outlined),
            ),
          );
        },
      ),
    );
  }
}
