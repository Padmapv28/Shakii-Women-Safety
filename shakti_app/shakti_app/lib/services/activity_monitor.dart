import 'dart:math';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/activity_pattern.dart';
import '../models/alert.dart';
import 'guardian_service.dart';
import 'location_service.dart';
import 'offline_service.dart';

/// AI Activity Monitor
/// Builds a daily routine baseline from location + movement history.
/// Detects anomalies (no movement when expected, unexpected location).
/// Runs every 15 minutes via WorkManager — fully offline.
class ActivityMonitor {
  static const _boxName = 'activity_patterns';
  static const _historyBox = 'location_history';

  // ─── Background Monitoring ────────────────────────────────────────────────

  static Future<void> startBackgroundMonitoring(ServiceInstance service) async {
    // Configure background geolocation (works in background/killed state)
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      _recordLocation(location.coords.latitude, location.coords.longitude);
    });

    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_MEDIUM,
      distanceFilter: 50.0,       // Record every 50m movement
      stopTimeout: 5,
      enableHeadless: true,        // Works when app is killed
      persistMode: bg.Config.PERSIST_MODE_ALL,
      maxDaysToPersist: 14,
      stopOnTerminate: false,
      startOnBoot: true,
    ));

    await bg.BackgroundGeolocation.start();
  }

  // WorkManager callback (every 15 min)
  static Future<void> backgroundCheck() async {
    await Hive.initFlutter();
    final position = await LocationService.getCurrentPositionCached();
    await _recordLocation(position.latitude, position.longitude);
    await _runAnomalyDetection();
  }

  // ─── Record Location ──────────────────────────────────────────────────────

  static Future<void> _recordLocation(double lat, double lng) async {
    final box = await Hive.openBox(_historyBox);
    final hour = DateTime.now().hour;
    final dayOfWeek = DateTime.now().weekday;
    final key = '$dayOfWeek-$hour'; // e.g. "2-14" = Tuesday 2pm

    // Append to hourly slot
    final existing = List<Map>.from(box.get(key, defaultValue: []));
    existing.add({
      'lat': lat,
      'lng': lng,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep last 8 weeks of data per slot
    if (existing.length > 56) existing.removeAt(0);
    await box.put(key, existing);

    // Also store as "last known location" for low-battery alerts
    await box.put('last_known', {'lat': lat, 'lng': lng, 'ts': DateTime.now().millisecondsSinceEpoch});
  }

  // ─── Anomaly Detection ────────────────────────────────────────────────────

  static Future<void> _runAnomalyDetection() async {
    final pattern = await _getExpectedPattern();
    if (pattern == null) return; // Not enough history yet (<1 week)

    final current = await LocationService.getCurrentPositionCached();
    final anomalyScore = _computeAnomalyScore(current, pattern);

    if (anomalyScore > kAnomalyThreshold) {
      await _handleAnomaly(score: anomalyScore, pattern: pattern);
    }
  }

  static Future<ActivityPattern?> _getExpectedPattern() async {
    final box = await Hive.openBox(_historyBox);
    final hour = DateTime.now().hour;
    final dayOfWeek = DateTime.now().weekday;
    final key = '$dayOfWeek-$hour';

    final history = List<Map>.from(box.get(key, defaultValue: []));
    if (history.length < 5) return null; // Need at least 5 data points

    // Compute centroid (average position) + standard deviation (spread)
    double sumLat = 0, sumLng = 0;
    for (final h in history) {
      sumLat += (h['lat'] as num).toDouble();
      sumLng += (h['lng'] as num).toDouble();
    }
    final avgLat = sumLat / history.length;
    final avgLng = sumLng / history.length;

    // Std dev in meters (approx)
    double variance = 0;
    for (final h in history) {
      final dist = Geolocator.distanceBetween(
        avgLat, avgLng,
        (h['lat'] as num).toDouble(),
        (h['lng'] as num).toDouble(),
      );
      variance += dist * dist;
    }
    final stdDev = sqrt(variance / history.length);

    return ActivityPattern(
      expectedLat: avgLat,
      expectedLng: avgLng,
      radiusMeters: max(200, stdDev * 2), // 2σ boundary
      dataPoints: history.length,
    );
  }

  /// Returns 0.0 (normal) to 1.0 (very anomalous)
  static double _computeAnomalyScore(
    Position current,
    ActivityPattern pattern,
  ) {
    final distance = Geolocator.distanceBetween(
      pattern.expectedLat,
      pattern.expectedLng,
      current.latitude,
      current.longitude,
    );

    if (distance <= pattern.radiusMeters) return 0.0;

    // Score grows logarithmically with distance beyond expected radius
    final excess = distance - pattern.radiusMeters;
    final score = min(1.0, log(excess / 100 + 1) / log(50));
    return score;
  }

  // ─── Handle Anomaly ───────────────────────────────────────────────────────

  static int _ignoredPrompts = 0;
  static DateTime? _firstAnomalyTime;

  static Future<void> _handleAnomaly({
    required double score,
    required ActivityPattern pattern,
  }) async {
    _firstAnomalyTime ??= DateTime.now();

    if (_ignoredPrompts < 3) {
      _ignoredPrompts++;

      // Notify user (local notification)
      final channel = const MethodChannel('com.shakti/notifications');
      await channel.invokeMethod('showAnomalyPrompt', {
        'promptNumber': _ignoredPrompts,
        'message': 'Shakti: You seem to be in an unusual location. Are you safe?',
      });

      // Schedule next check in 5 min
      return;
    }

    // 3 ignored → notify guardian
    final position = await LocationService.getCurrentPositionCached();
    await GuardianService.sendEscalationAlert(
      position: position,
      alertId: 'anomaly_${DateTime.now().millisecondsSinceEpoch}',
      message:
          '⚠️ Shakti AI detected unusual activity for User. '
          'They have not responded to 3 safety checks.',
    );
    _ignoredPrompts = 0;
    _firstAnomalyTime = null;
  }

  static void resetAnomalyState() {
    _ignoredPrompts = 0;
    _firstAnomalyTime = null;
  }
}

const double kAnomalyThreshold = 0.6;
