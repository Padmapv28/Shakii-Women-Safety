import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/home_screen.dart';
import 'services/sos_service.dart';
import 'services/activity_monitor.dart';
import 'services/battery_service.dart';
import 'services/offline_service.dart';
import 'utils/theme.dart';
import 'utils/constants.dart';

// Background task dispatcher (runs even when app is killed)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case kActivityCheckTask:
        await ActivityMonitor.backgroundCheck();
        break;
      case kBatteryCheckTask:
        await BatteryService.backgroundCheck();
        break;
      case kLocationSyncTask:
        await OfflineService.syncPendingAlerts();
        break;
    }
    return Future.value(true);
  });
}

// Background service (persistent foreground service)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await SOSService.initBackgroundService(service);
  await ActivityMonitor.startBackgroundMonitoring(service);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp();

  // Offline storage
  await Hive.initFlutter();
  await OfflineService.initialize();

  // Background tasks (activity + battery monitoring)
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    kActivityCheckTask,
    kActivityCheckTask,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.not_required), // Works offline
  );
  await Workmanager().registerPeriodicTask(
    kBatteryCheckTask,
    kBatteryCheckTask,
    frequency: const Duration(minutes: 5),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.not_required),
  );

  // Persistent foreground service for SOS listening
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'shakti_safety',
      initialNotificationTitle: 'Shakti Safety Active',
      initialNotificationContent: 'Monitoring for your safety',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onStart,
    ),
  );

  runApp(const ProviderScope(child: ShaktiApp()));
}

class ShaktiApp extends StatelessWidget {
  const ShaktiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shakti',
      debugShowCheckedModeBanner: false,
      theme: ShaktiTheme.light,
      darkTheme: ShaktiTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
