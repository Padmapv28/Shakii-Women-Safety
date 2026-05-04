import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:record/record.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../models/guardian.dart';
import '../models/alert.dart';
import 'guardian_service.dart';
import 'location_service.dart';
import 'offline_service.dart';
import 'face_verify_service.dart';
import '../utils/constants.dart';

enum SOSState { idle, triggered, escalating, resolved, cancelled }

class SOSService {
  static SOSState _state = SOSState.idle;
  static int _alertPromptCount = 0;
  static Timer? _escalationTimer;
  static Timer? _countdownTimer;
  static int _powerButtonPressCount = 0;
  static DateTime? _lastPowerPress;

  // ─── Background Service Init ──────────────────────────────────────────────

  static Future<void> initBackgroundService(ServiceInstance service) async {
    // Listen for SOS trigger from UI
    service.on('sos_trigger').listen((_) => triggerSOS());
    service.on('sos_cancel').listen((_) async {
      await _cancelWithVerification();
    });

    // Power button listener (3 rapid presses → SOS)
    _listenPowerButton();
  }

  // ─── Power Button Detection ───────────────────────────────────────────────

  static void _listenPowerButton() {
    // Uses volume key as proxy (power button events need accessibility service)
    // On Android, register an AccessibilityService to catch power button events
    // This implementation uses a broadcast receiver via platform channel
    const channel = EventChannel('com.shakti/power_button');
    channel.receiveBroadcastStream().listen((_) {
      final now = DateTime.now();
      if (_lastPowerPress != null &&
          now.difference(_lastPowerPress!).inSeconds < 2) {
        _powerButtonPressCount++;
      } else {
        _powerButtonPressCount = 1;
      }
      _lastPowerPress = now;

      if (_powerButtonPressCount >= 3) {
        _powerButtonPressCount = 0;
        triggerSOS(source: 'power_button');
      }
    });
  }

  // ─── Trigger SOS ─────────────────────────────────────────────────────────

  static Future<void> triggerSOS({String source = 'manual'}) async {
    if (_state == SOSState.triggered || _state == SOSState.escalating) return;

    _state = SOSState.triggered;
    _alertPromptCount = 0;

    // Get location immediately (cached if offline)
    final position = await LocationService.getCurrentPosition();

    // Persist alert locally first (offline-safe)
    final alert = Alert(
      id: _uuid(),
      timestamp: DateTime.now(),
      source: source,
      latitude: position.latitude,
      longitude: position.longitude,
      status: AlertStatus.active,
    );
    await OfflineService.saveAlert(alert);

    // Send to guardians
    await GuardianService.sendSOSAlert(
      position: position,
      message: '🆘 SOS from Shakti! ${_userName()} needs help.',
      alertId: alert.id,
    );

    // Start 3-prompt escalation loop
    _startEscalationLoop(alert);
  }

  // ─── 3-Prompt Escalation Loop ─────────────────────────────────────────────

  static void _startEscalationLoop(Alert alert) {
    _alertPromptCount = 0;
    _sendUserPrompt(alert);
  }

  static void _sendUserPrompt(Alert alert) {
    _alertPromptCount++;

    // Send local notification to user asking "Are you safe?"
    GuardianService.sendUserSafetyPrompt(
      promptNumber: _alertPromptCount,
      alertId: alert.id,
    );

    // Wait 60 seconds for response
    _escalationTimer?.cancel();
    _escalationTimer = Timer(const Duration(seconds: 60), () {
      if (_state == SOSState.triggered) {
        if (_alertPromptCount < 3) {
          _sendUserPrompt(alert); // Send next prompt
        } else {
          // 3 prompts ignored → escalate to guardian with media
          _escalateWithMedia(alert);
        }
      }
    });
  }

  // ─── Escalation with Media ────────────────────────────────────────────────

  static Future<void> _escalateWithMedia(Alert alert) async {
    _state = SOSState.escalating;

    final position = await LocationService.getCurrentPosition();

    // Capture 5-second audio
    final audioPath = await _captureAudio(seconds: 5);

    // Capture front camera snapshot
    final imagePath = await _captureFrontCamera();

    // Send everything to guardians
    await GuardianService.sendEscalationAlert(
      position: position,
      alertId: alert.id,
      audioPath: audioPath,
      imagePath: imagePath,
      message:
          '🚨 ESCALATION: ${_userName()} has not responded to 3 safety checks. '
          'Live location, audio and photo attached.',
    );
  }

  // ─── Cancel with Face Verification ───────────────────────────────────────

  static Future<void> _cancelWithVerification() async {
    // Capture front camera for identity verification
    final imagePath = await _captureFrontCamera();
    final isVerified = await FaceVerifyService.verify(imagePath);

    if (isVerified) {
      _state = SOSState.resolved;
      _escalationTimer?.cancel();
      await OfflineService.resolveAlert();
      await GuardianService.sendCancellationNotice(
        message: '✅ ${_userName()} has cancelled the alert and is safe.',
      );
    } else {
      // Face not recognised → still escalate
      await GuardianService.sendCancellationNotice(
        message:
            '⚠️ Alert cancellation attempted but face not verified. '
            'Please check on ${_userName()}.',
        imagePath: imagePath,
      );
    }
  }

  // ─── Media Capture Helpers ────────────────────────────────────────────────

  static Future<String?> _captureAudio({required int seconds}) async {
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) return null;
      final path = await _tempPath('audio_${_timestamp()}.m4a');
      await recorder.start(const RecordConfig(), path: path);
      await Future.delayed(Duration(seconds: seconds));
      await recorder.stop();
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _captureFrontCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(front, ResolutionPreset.medium);
      await controller.initialize();
      final file = await controller.takePicture();
      await controller.dispose();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ─── Auto-Call Guardian ───────────────────────────────────────────────────

  static Future<void> autoCallGuardian() async {
    final guardians = await GuardianService.getGuardians();
    if (guardians.isEmpty) return;
    final primary = guardians.first;
    // Uses flutter_phone_direct_caller — no user interaction needed
    await const MethodChannel('com.shakti/call')
        .invokeMethod('call', {'number': primary.phone});
  }

  // ─── Utility ─────────────────────────────────────────────────────────────

  static SOSState get state => _state;

  static String _uuid() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-');

  static String _userName() => 'User'; // Pull from Hive preferences

  static Future<String> _tempPath(String name) async {
    final dir = Directory.systemTemp;
    return '${dir.path}/$name';
  }

  static void reset() {
    _state = SOSState.idle;
    _alertPromptCount = 0;
    _escalationTimer?.cancel();
    _countdownTimer?.cancel();
  }
}
