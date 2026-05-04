import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'sos_service.dart';

/// Voice Activation Service
/// Listens continuously for trigger phrases like "help me", "Shakti help"
/// Uses on-device model — works FULLY OFFLINE
class VoiceService {
  static final _speech = SpeechToText();
  static bool _isListening = false;
  static bool _initialized = false;

  // Phrases that trigger SOS
  static const _triggerPhrases = [
    'help me',
    'shakti help',
    'emergency',
    'मुझे मदद चाहिए',    // Hindi: "I need help"
    'help',
    'save me',
    'bachao',              // Hindi: "save me"
  ];

  // ─── Init ─────────────────────────────────────────────────────────────────

  static Future<bool> initialize() async {
    _initialized = await _speech.initialize(
      onError: (error) => _restartListening(),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          // Restart loop
          Future.delayed(const Duration(milliseconds: 500), _startListening);
        }
      },
    );
    return _initialized;
  }

  // ─── Start Listening ──────────────────────────────────────────────────────

  static Future<void> startContinuousListening() async {
    if (!_initialized) await initialize();
    await _startListening();
  }

  static Future<void> _startListening() async {
    if (_isListening || !_initialized) return;
    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        final transcript = result.recognizedWords.toLowerCase();
        _checkTrigger(transcript);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_IN',     // Indian English
      listenMode: ListenMode.dictation,
      cancelOnError: false,
    );
  }

  static Future<void> _restartListening() async {
    _isListening = false;
    await Future.delayed(const Duration(seconds: 2));
    await _startListening();
  }

  // ─── Trigger Check ────────────────────────────────────────────────────────

  static void _checkTrigger(String transcript) {
    for (final phrase in _triggerPhrases) {
      if (transcript.contains(phrase)) {
        _onTriggerDetected(phrase, transcript);
        return;
      }
    }
  }

  static void _onTriggerDetected(String phrase, String transcript) {
    _speech.stop();
    _isListening = false;

    // Trigger SOS
    SOSService.triggerSOS(source: 'voice_command');

    // Restart listening after 30 seconds
    Future.delayed(const Duration(seconds: 30), startContinuousListening);
  }

  static void stopListening() {
    _speech.stop();
    _isListening = false;
  }

  static bool get isListening => _isListening;
}
