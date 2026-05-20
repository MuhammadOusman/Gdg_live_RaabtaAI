import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { handleMessage, confirmAndSave } from './orchestrator/index.js';
import './agents/janitor/cron.js';

const app = express();
app.use(cors({
    origin: 'http://localhost:5173'
}))
app.use(express.json());

app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'Raabta AI', ts: new Date() });
});

app.post('/api/message', async (req, res) => {
    try {
        const { raw_text, sender_agent_id, source } = req.body;
        if (!raw_text || !sender_agent_id) {
            return res.status(400).json({ error: 'raw_text and sender_agent_id required' });
        }
        // Pass source through correctly to handleMessage (defaults to 'whatsapp' in orchestrator)
        const result = await handleMessage(raw_text, sender_agent_id, source);
        res.json(result);
    } catch (err) {
        console.error('[App] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/confirm', async (req, res) => {
    try {
        const { parsed_data, sender_agent_id, session_id } = req.body
        const result = await confirmAndSave(parsed_data, sender_agent_id, session_id)
        if (result.status === 'conflict') {
            return res.json(result);
        }
        res.json({ status: 'listing_saved', listing: result, matches_count: result.matches_count || 0 })
    } catch (err) {
        console.error('[Confirm] Error:', err.message)
        res.status(500).json({ error: err.message })
    }
})

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

// ── Manual Janitor Trigger ─────────────────────────────
app.post('/api/janitor/run', async (req, res) => {
    try {
        const { runDailyReview, autoArchiveStale, refreshBlockStats } = await import('./agents/janitor/index.js');
        console.log('[API] Manually triggering Janitor routines...');
        const stats = await refreshBlockStats();
        const archived = await autoArchiveStale();
        res.json({ status: 'success', message: 'Janitor routines executed successfully', stats_updated_count: stats.length, archived_count: archived.length });
    } catch (err) {
        console.error('[API Janitor] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// ── Manual Recommender Trigger ─────────────────────────
app.post('/api/recommender/run', async (req, res) => {
    try {
        const { generateRecommendations } = await import('./agents/recommender/index.js');
        const { agent_id } = req.body;
        if (!agent_id) {
            return res.status(400).json({ error: 'agent_id required' });
        }
        console.log(`[API] Manually triggering Recommender for agent ${agent_id}...`);
        const result = await generateRecommendations(agent_id);
        res.json({ status: 'success', recommendations: result.recommendations });
    } catch (err) {
        console.error('[API Recommender] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`\n🚀 Raabta AI — port ${PORT}`);
    console.log(`📡 http://localhost:${PORT}/health\n`);
});