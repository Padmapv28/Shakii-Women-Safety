import 'package:battery_plus/battery_plus.dart';
import 'guardian_service.dart';
import 'location_service.dart';

class BatteryService {
  static final _battery = Battery();
  static bool _alertSent = false;

  static Future<void> startMonitoring() async {
    _battery.onBatteryStateChanged.listen((_) async {
      await _check();
    });
    // Also poll on boot
    await _check();
  }

  // WorkManager background call
  static Future<void> backgroundCheck() async {
    await _check();
  }

  static Future<void> _check() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;

    // Only alert if on battery (not charging) and below 10%
    if (state != BatteryState.charging && level <= 10 && !_alertSent) {
      _alertSent = true;
      final position = await LocationService.getCurrentPositionCached();
      await GuardianService.sendLowBatteryAlert(
        position: position,
        batteryLevel: level,
      );
    }

    // Reset if charged above 20%
    if (level > 20) _alertSent = false;
  }
}
