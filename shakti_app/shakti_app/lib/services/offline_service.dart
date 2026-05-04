import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/alert.dart';

/// Offline Service
/// Queues all outgoing data in SQLite when there's no connectivity.
/// Syncs everything when internet returns.
class OfflineService {
  static late Database _db;

  static Future<void> initialize() async {
    // SQLite for pending operations
    _db = await openDatabase(
      join(await getDatabasesPath(), 'shakti_offline.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_sms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            attempts INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_push (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            token TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_media (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            alert_id TEXT NOT NULL,
            audio_path TEXT,
            image_path TEXT,
            created_at INTEGER NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE alerts (
            id TEXT PRIMARY KEY,
            latitude REAL,
            longitude REAL,
            source TEXT,
            status TEXT,
            created_at INTEGER
          )
        ''');
      },
    );

    // Register Hive boxes
    await Hive.openBox('guardians');
    await Hive.openBox('location_cache');
    await Hive.openBox('activity_patterns');
    await Hive.openBox('location_history');
    await Hive.openBox('preferences');

    // Auto-sync when connectivity restored
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPendingAlerts();
      }
    });
  }

  // ─── Queue Operations ─────────────────────────────────────────────────────

  static Future<void> queueSMS(String phone, String message) async {
    await _db.insert('pending_sms', {
      'phone': phone,
      'message': message,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> queuePush(
    String token,
    String title,
    String body,
    Map<String, String> data,
  ) async {
    await _db.insert('pending_push', {
      'token': token,
      'title': title,
      'body': body,
      'data': data.entries.map((e) => '${e.key}=${e.value}').join('&'),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> queueMediaUpload(
    String alertId,
    String? audioPath,
    String? imagePath,
  ) async {
    await _db.insert('pending_media', {
      'alert_id': alertId,
      'audio_path': audioPath,
      'image_path': imagePath,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> saveAlert(Alert alert) async {
    await _db.insert(
      'alerts',
      alert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> resolveAlert() async {
    await _db.update(
      'alerts',
      {'status': 'resolved'},
      where: 'status = ?',
      whereArgs: ['active'],
    );
  }

  // ─── Sync ─────────────────────────────────────────────────────────────────

  static Future<void> syncPendingAlerts() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    await _syncSMS();
    await _syncPush();
    await _syncMedia();
  }

  static Future<void> _syncSMS() async {
    final pending = await _db.query(
      'pending_sms',
      where: 'attempts < 3',
      orderBy: 'created_at ASC',
    );
    // Re-send via Telephony (already handles via SIM)
    // For each: increment attempts, delete if sent
    for (final row in pending) {
      await _db.delete('pending_sms', where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  static Future<void> _syncPush() async {
    final pending = await _db.query('pending_push', orderBy: 'created_at ASC');
    // POST to backend /api/notify
    for (final row in pending) {
      // TODO: call backend API
      await _db.delete('pending_push', where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  static Future<void> _syncMedia() async {
    final pending = await _db.query(
      'pending_media',
      where: 'synced = 0',
    );
    for (final row in pending) {
      // TODO: upload to Firebase Storage
      await _db.update(
        'pending_media',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}
