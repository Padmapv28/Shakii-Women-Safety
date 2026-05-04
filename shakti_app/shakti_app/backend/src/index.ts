import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import admin from 'firebase-admin';
import { sosRouter } from './routes/sos';
import { zonesRouter } from './routes/zones';
import { guardianRouter } from './routes/guardian';
import { chatbotRouter } from './routes/chatbot';
import { activityRouter } from './routes/activity';

// Firebase Admin init
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
});

const app = express();
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));

// Routes
app.use('/api/sos', sosRouter);
app.use('/api/zones', zonesRouter);
app.use('/api/guardians', guardianRouter);
app.use('/api/chatbot', chatbotRouter);
app.use('/api/activity', activityRouter);
app.get('/health', (_, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Shakti backend on :${PORT}`));
export default app;
