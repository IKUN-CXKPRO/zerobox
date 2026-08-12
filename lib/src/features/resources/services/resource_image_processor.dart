import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:oronbox/src/core/wasm/wasm_webp_encoder.dart';

/// The canonical dimensions used by creator media.
const creatorIconMaxDimension = 256;
const creatorMediaMaxDimension = 1500;

/// Decodes, bounds, and encodes a creator image as WebP.
///
/// Keeping this in one place is important: imported media and images selected
/// in the creator editor must have the same dimensions and encoding rules.
Future<ProcessedResourceImage?> processResourceImage(
  Uint8List raw, {
  int maxDimension = creatorMediaMaxDimension,
  double quality = 75,
}) async {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  var processed = decoded;
  if (decoded.width > maxDimension || decoded.height > maxDimension) {
    final width = decoded.width >= decoded.height
        ? maxDimension
        : (decoded.width * maxDimension / decoded.height).round();
    final height = decoded.width >= decoded.height
        ? (decoded.height * maxDimension / decoded.width).round()
        : maxDimension;
    processed = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
  }
  // RGB sources have no alpha byte. Normalize to RGBA before passing the
  // pixels to libwebp so every platform uses the same input layout.
  processed = processed.convert(numChannels: 4);
  final encoder = await WasmWebpEncoder.instance();
  final webp = encoder.encode(
    processed.getBytes(),
    processed.width,
    processed.height,
    quality: quality,
  );
  if (webp == null || webp.isEmpty) return null;
  return ProcessedResourceImage(
    bytes: webp,
    width: processed.width,
    height: processed.height,
  );
}

final class ProcessedResourceImage {
  const ProcessedResourceImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}
