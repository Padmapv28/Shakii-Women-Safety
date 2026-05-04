import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Face Verification Service
/// Uses Google ML Kit Face Detection (fully on-device, works offline)
/// On first setup: stores face template hash
/// On cancel: compares live capture to stored template
class FaceVerifyService {
  static final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  // ─── Enroll Face (during onboarding) ─────────────────────────────────────

  static Future<bool> enrollFace(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) return false;

      final face = faces.first;

      // Store bounding box and key measurements as template
      final template = {
        'boundingWidth': face.boundingBox.width,
        'boundingHeight': face.boundingBox.height,
        'leftEyeOpen': face.leftEyeOpenProbability,
        'rightEyeOpen': face.rightEyeOpenProbability,
        'smileProbability': face.smilingProbability,
        'headEulerY': face.headEulerAngleY,
        'headEulerZ': face.headEulerAngleZ,
      };

      final box = Hive.box('preferences');
      await box.put('face_template', template);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Verify Face ──────────────────────────────────────────────────────────

  static Future<bool> verify(String? imagePath) async {
    if (imagePath == null) return false;

    try {
      final box = Hive.box('preferences');
      final template = box.get('face_template');
      if (template == null) return true; // Not enrolled → allow cancel

      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return false;

      final face = faces.first;

      // Simple similarity check on face proportions
      final storedWidth = (template['boundingWidth'] as num).toDouble();
      final storedHeight = (template['boundingHeight'] as num).toDouble();
      final ratio = storedWidth / storedHeight;
      final liveRatio = face.boundingBox.width / face.boundingBox.height;

      final ratioMatch = (ratio - liveRatio).abs() < 0.3;
      final eyeMatch =
          (face.leftEyeOpenProbability ?? 0) > 0.5 &&
          (face.rightEyeOpenProbability ?? 0) > 0.5;

      // Note: For production, use a proper face embedding model
      // (e.g., MobileFaceNet via TFLite) for real cosine similarity matching
      return ratioMatch && eyeMatch;
    } catch (_) {
      return false;
    }
  }

  static void dispose() {
    _detector.close();
  }
}
