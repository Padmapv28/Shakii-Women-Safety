// ─── Guardian ────────────────────────────────────────────────────────────────

class Guardian {
  final String id;
  final String name;
  final String phone;
  final bool isPrimary;
  final String? fcmToken;

  Guardian({
    required this.id,
    required this.name,
    required this.phone,
    this.isPrimary = false,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'isPrimary': isPrimary,
        'fcmToken': fcmToken,
      };

  factory Guardian.fromMap(Map<String, dynamic> m) => Guardian(
        id: m['id'],
        name: m['name'],
        phone: m['phone'],
        isPrimary: m['isPrimary'] ?? false,
        fcmToken: m['fcmToken'],
      );
}

// ─── SafeZone ────────────────────────────────────────────────────────────────

class SafeZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isSafe;
  final String issueType;
  final String riskLevel;
  final int reportCount;

  SafeZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isSafe,
    required this.issueType,
    required this.riskLevel,
    required this.reportCount,
  });

  factory SafeZone.fromMap(Map<String, dynamic> m) => SafeZone(
        id: m['id'],
        name: m['name'],
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        radiusMeters: (m['radiusMeters'] as num).toDouble(),
        isSafe: m['isSafe'] as bool,
        issueType: m['issueType'] ?? '',
        riskLevel: m['riskLevel'] ?? 'medium',
        reportCount: m['reportCount'] ?? 1,
      );
}

// ─── Alert ───────────────────────────────────────────────────────────────────

enum AlertStatus { active, resolved, cancelled }

class Alert {
  final String id;
  final DateTime timestamp;
  final String source;
  final double latitude;
  final double longitude;
  final AlertStatus status;

  Alert({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': timestamp.millisecondsSinceEpoch,
        'source': source,
        'latitude': latitude,
        'longitude': longitude,
        'status': status.name,
      };
}

// ─── ActivityPattern ──────────────────────────────────────────────────────────

class ActivityPattern {
  final double expectedLat;
  final double expectedLng;
  final double radiusMeters;
  final int dataPoints;

  ActivityPattern({
    required this.expectedLat,
    required this.expectedLng,
    required this.radiusMeters,
    required this.dataPoints,
  });
}
