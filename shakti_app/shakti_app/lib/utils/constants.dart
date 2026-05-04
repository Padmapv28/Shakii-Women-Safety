// Background task names
const String kActivityCheckTask = 'shakti_activity_check';
const String kBatteryCheckTask = 'shakti_battery_check';
const String kLocationSyncTask = 'shakti_location_sync';

// API base URL
const String kApiBaseUrl = 'https://your-backend.com';

// SOS countdown seconds
const int kSOSCountdownSeconds = 5;

// Battery alert threshold
const int kBatteryAlertThreshold = 10;

// Anomaly detection threshold (0.0 - 1.0)
const double kAnomalyThreshold = 0.6;

// Escalation prompts before notifying guardian
const int kMaxEscalationPrompts = 3;

// Indian emergency numbers
const Map<String, String> kEmergencyNumbers = {
  'Police': '100',
  'Women Helpline': '1091',
  'National Emergency': '112',
  'Bengaluru Police': '080-22942222',
  'Cyber Crime': '1930',
  'Ambulance': '108',
};
