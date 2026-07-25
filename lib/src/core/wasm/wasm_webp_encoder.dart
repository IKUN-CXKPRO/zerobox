import 'dart:typed_data';

import 'package:wasm_run_flutter/wasm_run_flutter.dart';
import 'package:oronbox/src/core/wasm/wasm_runtime.dart';

/// libwebp compiled to a freestanding WASM module (zig, see tool/webp_encoder/).
/// Encode failures return null so callers can fall back to PNG.
final class WasmWebpEncoder {
  WasmWebpEncoder._(this._instance, this._memory);

  static const _assetPath = 'assets/wasm/webp_encoder.wasm';
  static Future<WasmWebpEncoder>? _shared;

  final ScopedWasmInstance _instance;
  final WasmMemory _memory;

  static Future<WasmWebpEncoder> instance() => _shared ??= _create();

  static Future<WasmWebpEncoder> _create() async {
    final scope = WasmRuntime.shared.openScope('system.webp-encoder');
    try {
      final instance = await scope.instantiateAsset(
        _assetPath,
        configure: (builder) => builder.addImport(
          'wasi_snapshot_preview1',
          'proc_exit',
          WasmFunction.voidReturn(
            (int code) => throw StateError('libwebp exited with code $code'),
            params: const [ValueTy.i32],
          ),
        ),
      );
      return WasmWebpEncoder._(instance, instance.memory('memory'));
    } catch (_) {
      scope.dispose();
      rethrow;
    }
  }

  Uint8List? encode(
    Uint8List rgba,
    int width,
    int height, {
    double quality = 75,
  }) {
    final input = _intResult(_instance.call('zb_alloc', [rgba.length]));
    if (input == 0) return null;
    _memory.view.setAll(input, rgba);
    final size = _intResult(
      _instance.call('zb_webp_encode', [input, width, height, quality]),
    );
    _instance.call('zb_free', [input]);
    if (size <= 0) return null;
    final output = _intResult(_instance.call('zb_webp_output'));
    final bytes = Uint8List.fromList(
      _memory.view.sublist(output, output + size),
    );
    _instance.call('zb_free', [output]);
    return bytes;
  }

  static int _intResult(List<Object?> results) {
    final value = results.firstOrNull;
    return value is num ? value.toInt() : 0;
  }
}
