import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { handleMessage } from './orchestrator/index.js';
import './agents/janitor/cron.js';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'Raabta AI', ts: new Date() });
});

app.post('/api/message', async (req, res) => {
    try {
        const { raw_text, sender_agent_id } = req.body;
        if (!raw_text || !sender_agent_id) {
            return res.status(400).json({ error: 'raw_text and sender_agent_id required' });
        }
        const result = await handleMessage(raw_text, sender_agent_id);
        res.json(result);
    } catch (err) {
        console.error('[App] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/listings', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');
        const { agent_id } = req.query;
        let query = supabase.from('listings').select('*').eq('status', 'active');
        if (agent_id) query = query.eq('owner_agent_id', agent_id);
        const { data, error } = await query;
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`\n🚀 Raabta AI — port ${PORT}`);
    console.log(`📡 http://localhost:${PORT}/health\n`);
});