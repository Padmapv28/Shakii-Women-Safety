import { Router, Request, Response } from 'express';
import admin from 'firebase-admin';

const router = Router();
const db = admin.firestore();

// GET /api/zones/nearby?lat=&lng=&radiusKm=
router.get('/nearby', async (req: Request, res: Response) => {
  const { lat, lng, radiusKm = '5' } = req.query;
  if (!lat || !lng) return res.status(400).json({ error: 'lat/lng required' });

  // Firestore doesn't support geo queries natively — use GeoFirestore or bounding box
  // Simple bounding box approximation (1 degree ≈ 111km)
  const radius = parseFloat(radiusKm as string) / 111;
  const latN = parseFloat(lat as string) + radius;
  const latS = parseFloat(lat as string) - radius;

  const snapshot = await db.collection('zones')
    .where('latitude', '>=', latS)
    .where('latitude', '<=', latN)
    .limit(50)
    .get();

  res.json(snapshot.docs.map(d => ({ id: d.id, ...d.data() })));
});

// POST /api/zones/report — User reports a location as safe/unsafe
router.post('/report', async (req: Request, res: Response) => {
  const { latitude, longitude, isSafe, issueType, userId } = req.body;

  const zoneRef = db.collection('zone_reports').doc();
  await zoneRef.set({
    latitude,
    longitude,
    isSafe,
    issueType: issueType || 'unspecified',
    reportedBy: userId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    verified: false,
  });

  // Aggregate: if 3+ users report same area → promote to zones collection
  await _aggregateReports(latitude, longitude, isSafe);

  res.json({ success: true, id: zoneRef.id });
});

async function _aggregateReports(lat: number, lng: number, isSafe: boolean) {
  const delta = 0.002; // ~200m
  const reports = await db.collection('zone_reports')
    .where('latitude', '>=', lat - delta)
    .where('latitude', '<=', lat + delta)
    .get();

  const nearby = reports.docs.filter(d => {
    const data = d.data();
    return Math.abs(data.longitude - lng) < delta && data.isSafe === isSafe;
  });

  if (nearby.length >= 3) {
    // Promote to verified zones
    await db.collection('zones').add({
      latitude: lat,
      longitude: lng,
      isSafe,
      reportCount: nearby.length,
      crowdSourced: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

export { router as zonesRouter };
