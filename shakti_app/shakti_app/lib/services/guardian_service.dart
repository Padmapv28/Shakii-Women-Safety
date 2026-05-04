import 'dart:io';
import 'package:telephony/telephony.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/guardian.dart';
import 'offline_service.dart';

class GuardianService {
  static final _telephony = Telephony.instance;
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // ─── Get Guardians ────────────────────────────────────────────────────────

  static Future<List<Guardian>> getGuardians() async {
    final box = Hive.box('guardians');
    return box.values.map((v) => Guardian.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  static Future<void> addGuardian(Guardian guardian) async {
    final box = Hive.box('guardians');
    await box.put(guardian.id, guardian.toMap());
    // Sync to Firestore if online
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      await _db.collection('guardians').doc(guardian.id).set(guardian.toMap());
    }
  }

  // ─── SOS Alert ───────────────────────────────────────────────────────────

  static Future<void> sendSOSAlert({
    required Position position,
    required String message,
    required String alertId,
  }) async {
    final guardians = await getGuardians();
    final mapsLink =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final fullMessage = '$message\n📍 Location: $mapsLink';

    for (final g in guardians) {
      // 1. SMS — works offline via device SIM
      await _sendSMS(g.phone, fullMessage);

      // 2. Push notification — queued if offline
      await _sendPushNotification(
        token: g.fcmToken,
        title: '🆘 SOS Alert',
        body: message,
        data: {
          'type': 'sos',
          'alertId': alertId,
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
        },
      );
    }

    // 3. Firestore record
    await _writeAlert(alertId: alertId, position: position, type: 'sos');
  }

  // ─── User Safety Prompt (local notification) ──────────────────────────────

  static Future<void> sendUserSafetyPrompt({
    required int promptNumber,
    required String alertId,
  }) async {
    // This triggers a local notification via flutter_local_notifications
    // User must tap "I'm Safe" within 60s or escalation proceeds
    final channel = const MethodChannel('com.shakti/notifications');
    await channel.invokeMethod('showSafetyPrompt', {
      'promptNumber': promptNumber,
      'alertId': alertId,
      'message': promptNumber == 3
          ? '⚠️ Last chance: Are you okay? Guardians will be notified now.'
          : 'Are you safe? Tap to confirm. ($promptNumber/3)',
    });
  }

  // ─── Escalation Alert with Media ─────────────────────────────────────────

  static Future<void> sendEscalationAlert({
    required Position position,
    required String alertId,
    required String message,
    String? audioPath,
    String? imagePath,
  }) async {
    final guardians = await getGuardians();
    final mapsLink =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';

    // Upload media (queue offline)
    String? audioUrl, imageUrl;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      audioUrl = await _uploadFile(audioPath, 'audio/$alertId.m4a');
      imageUrl = await _uploadFile(imagePath, 'images/$alertId.jpg');
    } else {
      // Queue for later sync
      await OfflineService.queueMediaUpload(alertId, audioPath, imagePath);
    }

    final smsBody =
        '$message\n📍 $mapsLink\n'
        '🎙️ Audio: ${audioUrl ?? "(uploading soon)"}\n'
        '📷 Photo: ${imageUrl ?? "(uploading soon)"}';

    for (final g in guardians) {
      await _sendSMS(g.phone, smsBody);
      await _sendPushNotification(
        token: g.fcmToken,
        title: '🚨 ESCALATION ALERT',
        body: message,
        data: {
          'type': 'escalation',
          'alertId': alertId,
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
          'audioUrl': audioUrl ?? '',
          'imageUrl': imageUrl ?? '',
        },
      );
    }
  }

  // ─── Cancellation Notice ─────────────────────────────────────────────────

  static Future<void> sendCancellationNotice({
    required String message,
    String? imagePath,
  }) async {
    final guardians = await getGuardians();
    for (final g in guardians) {
      await _sendSMS(g.phone, message);
      await _sendPushNotification(
        token: g.fcmToken,
        title: 'Shakti Alert Update',
        body: message,
        data: {'type': 'cancellation'},
      );
    }
  }

  // ─── Low Battery Alert ────────────────────────────────────────────────────

  static Future<void> sendLowBatteryAlert({
    required Position position,
    required int batteryLevel,
  }) async {
    final guardians = await getGuardians();
    final mapsLink =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final msg =
        '🔋 Shakti: Battery at $batteryLevel%. '
        'Last known location: $mapsLink';

    for (final g in guardians) {
      await _sendSMS(g.phone, msg);
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  static Future<void> _sendSMS(String phone, String message) async {
    try {
      // Telephony uses Android SIM — works with NO internet
      await _telephony.sendSms(
        to: phone,
        message: message.length > 160 ? message.substring(0, 157) + '...' : message,
        isMultipart: message.length > 160,
        statusListener: (status) {},
      );
    } catch (e) {
      // Queue for retry
      await OfflineService.queueSMS(phone, message);
    }
  }

  static Future<void> _sendPushNotification({
    required String? token,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    if (token == null) return;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        await OfflineService.queuePush(token, title, body, data);
        return;
      }
      // Via your backend /api/notify endpoint
      // (FCM requires server-side send — backend handles this)
      await OfflineService.queuePush(token, title, body, data);
    } catch (_) {
      await OfflineService.queuePush(token, title, body, data);
    }
  }

  static Future<String?> _uploadFile(String? path, String storagePath) async {
    if (path == null) return null;
    try {
      final ref = _storage.ref(storagePath);
      await ref.putFile(File(path));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeAlert({
    required String alertId,
    required Position position,
    required String type,
  }) async {
    try {
      await _db.collection('alerts').doc(alertId).set({
        'type': type,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Will sync when online
    }
  }
}
