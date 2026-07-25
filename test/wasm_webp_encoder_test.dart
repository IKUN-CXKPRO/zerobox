import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasm_run_flutter/wasm_run_flutter.dart';
import 'package:oronbox/src/core/wasm/wasm_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('libwebp wasm encodes RGBA into a valid WebP payload', () async {
    final bytes = await File('assets/wasm/webp_encoder.wasm').readAsBytes();
    final scope = WasmRuntime.shared.openScope('test.webp-encoder');
    addTearDown(scope.dispose);
    final instance = await scope.instantiate(
      bytes,
      configure: (builder) => builder.addImport(
        'wasi_snapshot_preview1',
        'proc_exit',
        WasmFunction.voidReturn(
          (int code) => throw StateError('libwebp exited with code $code'),
          params: const [ValueTy.i32],
        ),
      ),
    );
    final memory = instance.memory('memory');

    const width = 8, height = 8;
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 200;
      rgba[i + 1] = 80;
      rgba[i + 2] = 40;
      rgba[i + 3] = 255;
    }
    int intResult(List<Object?> results) => (results.first as num).toInt();

    final input = intResult(instance.call('zb_alloc', [rgba.length]));
    expect(input, isNonZero);
    memory.view.setAll(input, rgba);
    final size = intResult(
      instance.call('zb_webp_encode', [input, width, height, 75.0]),
    );
    expect(size, greaterThan(0));
    final output = intResult(instance.call('zb_webp_output'));
    final webp = memory.view.sublist(output, output + size);
    // RIFF....WEBP container magic
    expect(String.fromCharCodes(webp.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(webp.sublist(8, 12)), 'WEBP');
  });
}
