import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import twilio from 'twilio';

admin.initializeApp();
const db = admin.firestore();

// ─── Scheduled Activity Check (every 15 min) ─────────────────────────────────
export const activityCheck = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    // Find users who haven't pinged in >30 min during their active hours
    const threshold = new Date(Date.now() - 30 * 60 * 1000);
    const users = await db.collection('users')
      .where('lastSeen', '<', threshold)
      .where('monitoringActive', '==', true)
      .get();

    for (const user of users.docs) {
      const data = user.data();
      const hour = new Date().getHours();

      // Only check during user's typical active hours (7am-11pm)
      if (hour < 7 || hour > 23) continue;

      // Increment no-response counter
      const count = (data.noResponseCount || 0) + 1;
      await user.ref.update({ noResponseCount: count });

      if (count >= 3) {
        // Escalate
        await _escalateToGuardian(user.id, data);
        await user.ref.update({ noResponseCount: 0 });
      }
    }
  });

// ─── Sync Pending Offline Alerts ─────────────────────────────────────────────
export const syncPendingAlerts = functions.firestore
  .document('pending_alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const alert = snap.data();
    if (!alert) return;

    // Re-process alert that was queued offline
    await _notifyGuardians(alert.userId, alert);
    await snap.ref.delete(); // Remove from queue
  });

// ─── SOS Trigger via FCM Data Message ────────────────────────────────────────
export const onSOSTrigger = functions.firestore
  .document('alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const alert = snap.data();
    if (!alert || alert.type !== 'sos') return;

    // Push to guardians via FCM (backup if app is offline)
    const guardians = await db.collection('guardians')
      .where('userId', '==', alert.userId)
      .get();

    const tokens = guardians.docs
      .map(d => d.data().fcmToken)
      .filter(Boolean);

    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: '🆘 SOS Alert',
          body: `${alert.userName} needs help! Tap for location.`,
        },
        data: {
          type: 'sos',
          alertId: context.params.alertId,
          lat: String(alert.latitude),
          lng: String(alert.longitude),
        },
        android: { priority: 'high' },
      });
    }
  });

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function _escalateToGuardian(userId: string, userData: any) {
  const guardians = await db.collection('guardians')
    .where('userId', '==', userId)
    .get();

  const mapsLink = userData.lastLat
    ? `https://maps.google.com/?q=${userData.lastLat},${userData.lastLng}`
    : 'Location unavailable';

  const message = `⚠️ Shakti AI: ${userData.name} has not checked in for 45+ minutes. ` +
    `Last location: ${mapsLink}`;

  const client = twilio(process.env.TWILIO_SID, process.env.TWILIO_TOKEN);

  for (const g of guardians.docs) {
    const gData = g.data();
    await client.messages.create({
      body: message,
      from: process.env.TWILIO_FROM!,
      to: gData.phone,
    }).catch(() => {});
  }
}

async function _notifyGuardians(userId: string, alert: any) {
  // (Same as above — used for offline-queued alerts)
  await _escalateToGuardian(userId, alert);
}
