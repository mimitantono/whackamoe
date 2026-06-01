import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SegmentationResult {
  final Uint8List bytes;
  final bool hasTransparency;
  const SegmentationResult(this.bytes, this.hasTransparency);
}

class SegmentationService {
  static Future<SegmentationResult> removeBackground(Uint8List imageBytes) async {
    if (kIsWeb) return SegmentationResult(imageBytes, false);
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return SegmentationResult(imageBytes, false);
      final resized = decoded.width > 512
          ? img.copyResize(decoded, width: 512)
          : decoded;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/seg_input.jpg');
      await file.writeAsBytes(img.encodeJpg(resized, quality: 90));

      final segmenter = SubjectSegmenter(
        options: SubjectSegmenterOptions(
          enableForegroundBitmap: false,
          enableForegroundConfidenceMask: true,
          enableMultipleSubjects: SubjectResultOptions(
            enableConfidenceMask: false,
            enableSubjectBitmap: false,
          ),
        ),
      );
      final result = await segmenter.processImage(InputImage.fromFile(file));
      await segmenter.close();

      final mask = result.foregroundConfidenceMask;
      if (mask == null || mask.length != resized.width * resized.height) {
        return SegmentationResult(imageBytes, false);
      }

      final output = img.Image(
        width: resized.width,
        height: resized.height,
        numChannels: 4,
      );
      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          final alpha = (mask[y * resized.width + x] * 255).round().clamp(0, 255);
          output.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), alpha);
        }
      }
      return SegmentationResult(Uint8List.fromList(img.encodePng(output)), true);
    } catch (_) {
      return SegmentationResult(imageBytes, false);
    }
  }
}
