import 'dart:typed_data';

class SegmentationResult {
  final Uint8List bytes;
  final bool hasTransparency;
  const SegmentationResult(this.bytes, this.hasTransparency);
}

class SegmentationService {
  static Future<SegmentationResult> removeBackground(Uint8List imageBytes) async {
    return SegmentationResult(imageBytes, false);
  }
}
