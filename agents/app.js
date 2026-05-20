import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { handleMessage, confirmAndSave } from './orchestrator/index.js';

// Only import cron scheduler when running locally (not on Vercel serverless)
if (!process.env.VERCEL) {
    import('./agents/janitor/cron.js').catch(() => {});
}

const app = express();
app.use(cors());
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

// ── Janitor Trigger (Supports GET for Cron, POST for manual) ────────
const handleJanitorRun = async (req, res) => {
    try {
        const { autoArchiveStale, refreshBlockStats } = await import('./agents/janitor/index.js');
        console.log('[API] Triggering Janitor routines...');
        const stats = await refreshBlockStats();
        const archived = await autoArchiveStale();
        res.json({
            status: 'success',
            message: 'Janitor routines executed successfully',
            stats_updated_count: stats.length,
            archived_count: archived.length
        });
    } catch (err) {
        console.error('[API Janitor] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
};
app.get('/api/janitor/run', handleJanitorRun);
app.post('/api/janitor/run', handleJanitorRun);

// ── Recommender Trigger (Supports GET for Cron, POST for manual) ───
const handleRecommenderRun = async (req, res) => {
    try {
        const { generateRecommendations } = await import('./agents/recommender/index.js');
        const agent_id = req.query.agent_id || req.body?.agent_id;

        if (agent_id) {
            console.log(`[API] Triggering Recommender for single agent ${agent_id}...`);
            const result = await generateRecommendations(agent_id);
            return res.json({ status: 'success', recommendations: result.recommendations });
        }

        // If no agent_id is provided, run for all agents with active listings (Cron mode)
        console.log('[API] Triggering Recommender for all active agents (Cron Mode)...');
        const { default: supabase } = await import('./services/supabaseClient.js');
        const { data: listings, error } = await supabase
            .from('listings')
            .select('owner_agent_id')
            .eq('status', 'active');

        if (error) throw error;

        const agentIds = [...new Set((listings || []).map(l => l.owner_agent_id).filter(Boolean))];
        console.log(`[API Cron] Found ${agentIds.length} unique agent(s) to generate recommendations for`);

        const processed = [];
        for (const id of agentIds) {
            try {
                await generateRecommendations(id);
                processed.push({ agent_id: id, status: 'success' });
            } catch (innerErr) {
                console.error(`[API Cron] Recommender failed for agent ${id}:`, innerErr.message);
                processed.push({ agent_id: id, status: 'failed', error: innerErr.message });
            }
        }

        res.json({
            status: 'success',
            message: 'Recommender cron completed',
            processed_count: processed.length,
            details: processed
        });
    } catch (err) {
        console.error('[API Recommender] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
};
app.get('/api/recommender/run', handleRecommenderRun);
app.post('/api/recommender/run', handleRecommenderRun);

// Only start listening when running locally (Vercel handles this automatically)
if (!process.env.VERCEL) {
    const PORT = process.env.PORT || 8080;
    app.listen(PORT, () => {
        console.log(`\n🚀 Raabta AI — port ${PORT}`);
        console.log(`📡 http://localhost:${PORT}/health\n`);
    });
}

export default app;