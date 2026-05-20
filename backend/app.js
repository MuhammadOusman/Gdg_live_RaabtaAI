import express from 'express';
import cors from 'cors';
import 'dotenv/config';

import authRoutes from './routes/auth.js';
import agentRoutes from './routes/agents.js';
import listingRoutes from './routes/listings.js';
import requestRoutes from './routes/requests.js';
import notificationRoutes from './routes/notifications.js';
import analyticsRoutes from './routes/analytics.js';
import mapRoutes from './routes/map.js';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: '*' }));
app.use(express.json());

app.get('/health', (req, res) => res.json({
    status: 'ok',
    service: 'Raabta AI Backend',
    ts: new Date()
}));

app.use('/api/auth', authRoutes);
app.use('/api/agents', agentRoutes);
app.use('/api/listings', listingRoutes);
app.use('/api/requests', requestRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/map', mapRoutes);

// Export for Vercel serverless — only listen locally
if (process.env.VERCEL !== '1') {
    app.listen(PORT, () => {
        console.log(`\n🚀 Raabta AI Backend — port ${PORT}`);
        console.log(`🔗 http://localhost:${PORT}/health\n`);
    });
}

export default app;

