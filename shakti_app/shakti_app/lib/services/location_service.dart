import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Location Service
/// Caches last known position so it works when GPS is slow or offline
class LocationService {
  static const _cacheKey = 'last_position';

  static Future<Position> getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Cache it
      await _cachePosition(position);
      return position;
    } catch (_) {
      // Return cached position if GPS fails
      return await _getCachedPosition();
    }
  }

  static Future<Position> getCurrentPositionCached() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return _getCachedPosition();
    }
  }

  static Future<void> _cachePosition(Position position) async {
    final box = Hive.box('location_cache');
    await box.put(_cacheKey, {
      'lat': position.latitude,
      'lng': position.longitude,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<Position> _getCachedPosition() async {
    final box = Hive.box('location_cache');
    final cached = box.get(_cacheKey);
    if (cached != null) {
      return Position(
        latitude: cached['lat'],
        longitude: cached['lng'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(cached['ts']),
        accuracy: 100,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
    // Fallback to Bengaluru city center
    return Position(
      latitude: 12.9716, longitude: 77.5946,
      timestamp: DateTime.now(),
      accuracy: 5000, altitude: 0, heading: 0,
      speed: 0, speedAccuracy: 0,
      altitudeAccuracy: 0, headingAccuracy: 0,
    );
  }

  // Stream for live location updates
  static Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
}
