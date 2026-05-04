import { Router, Request, Response } from 'express';
import admin from 'firebase-admin';
import twilio from 'twilio';

const router = Router();
const db = admin.firestore();
const twilioClient = twilio(
  process.env.TWILIO_SID,
  process.env.TWILIO_TOKEN
);

// POST /api/sos/trigger
// Called when SMS via device SIM fails (internet fallback)
router.post('/trigger', async (req: Request, res: Response) => {
  const { userId, alertId, latitude, longitude, source, guardians } = req.body;

  try {
    // 1. Save alert
    await db.collection('alerts').doc(alertId).set({
      userId,
      latitude,
      longitude,
      source,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const mapsLink = `https://maps.google.com/?q=${latitude},${longitude}`;
    const message = `🆘 SOS Alert! ${userId} needs help.\n📍 ${mapsLink}`;

    // 2. Send SMS via Twilio (backup if device SIM unavailable)
    const smsPromises = (guardians as Array<{phone: string}>).map(g =>
      twilioClient.messages.create({
        body: message,
        from: process.env.TWILIO_FROM,
        to: g.phone,
      }).catch(err => console.error('SMS failed:', g.phone, err))
    );

    // 3. Send FCM push notifications
    const pushPromises = (guardians as Array<{fcmToken: string}>)
      .filter(g => g.fcmToken)
      .map(g =>
        admin.messaging().send({
          token: g.fcmToken,
          notification: { title: '🆘 SOS Alert', body: message },
          data: { alertId, lat: String(latitude), lng: String(longitude), type: 'sos' },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        }).catch(err => console.error('Push failed:', err))
      );

    await Promise.allSettled([...smsPromises, ...pushPromises]);

    res.json({ success: true, alertId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'SOS dispatch failed' });
  }
});

// POST /api/sos/escalate
// Called after 3 ignored prompts — sends media URLs to guardians
router.post('/escalate', async (req: Request, res: Response) => {
  const { alertId, userId, latitude, longitude, audioUrl, imageUrl, guardians } = req.body;

  try {
    await db.collection('alerts').doc(alertId).update({
      escalated: true,
      audioUrl,
      imageUrl,
      escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const mapsLink = `https://maps.google.com/?q=${latitude},${longitude}`;
    const message = `🚨 ESCALATION: ${userId} hasn't responded to 3 safety checks.\n` +
      `📍 ${mapsLink}\n🎙 Audio: ${audioUrl || 'N/A'}\n📷 Photo: ${imageUrl || 'N/A'}`;

    const promises = (guardians as Array<{phone: string, fcmToken?: string}>).map(async g => {
      await twilioClient.messages.create({
        body: message,
        from: process.env.TWILIO_FROM,
        to: g.phone,
      }).catch(() => {});

      if (g.fcmToken) {
        await admin.messaging().send({
          token: g.fcmToken,
          notification: { title: '🚨 ESCALATION ALERT', body: `${userId} needs urgent help` },
          data: { alertId, type: 'escalation', audioUrl: audioUrl || '', imageUrl: imageUrl || '' },
          android: { priority: 'high' },
        }).catch(() => {});
      }
    });

    await Promise.allSettled(promises);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Escalation failed' });
  }
});

// POST /api/sos/resolve
router.post('/resolve', async (req: Request, res: Response) => {
  const { alertId } = req.body;
  await db.collection('alerts').doc(alertId).update({
    status: 'resolved',
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  res.json({ success: true });
});

// GET /api/sos/history/:userId
router.get('/history/:userId', async (req: Request, res: Response) => {
  const { userId } = req.params;
  const alerts = await db.collection('alerts')
    .where('userId', '==', userId)
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get();
  res.json(alerts.docs.map(d => ({ id: d.id, ...d.data() })));
});

export { router as sosRouter };
