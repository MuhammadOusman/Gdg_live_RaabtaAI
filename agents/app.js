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

// ── Analytics Endpoints (Intel Page Compatibility) ─────────────────────────
app.get('/api/analytics/dashboard', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');

        const { data: blockStats } = await supabase
            .from('block_market_stats')
            .select('*');

        const { data: closedListings } = await supabase
            .from('listings')
            .select('created_at, updated_at')
            .in('status', ['sold', 'archived'])
            .limit(100);

        const avgDays = calcAvgVelocity(closedListings || []);

        const { count: hotCount } = await supabase
            .from('listings')
            .select('*', { count: 'exact', head: true })
            .eq('is_hot_property', true)
            .eq('status', 'active');

        const { data: topAgents } = await supabase
            .from('agents')
            .select('id, name, agency_name, public_listings_count')
            .order('public_listings_count', { ascending: false })
            .limit(10);

        res.json({
            block_stats: blockStats || [],
            avg_velocity_days: avgDays,
            hot_properties_count: hotCount || 0,
            top_agents: topAgents || [],
            generated_at: new Date().toISOString(),
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/analytics/demand-vs-supply', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');

        const { data: listings, error: lErr } = await supabase
            .from('listings')
            .select('block_id')
            .eq('is_public', true)
            .eq('status', 'active');

        const { data: requests, error: rErr } = await supabase
            .from('requests')
            .select('target_blocks')
            .eq('status', 'searching');

        if (lErr || rErr) {
            return res.status(400).json({ error: lErr?.message || rErr?.message });
        }

        const supplyMap = {};
        for (const l of listings || []) {
            supplyMap[l.block_id] = (supplyMap[l.block_id] || 0) + 1;
        }

        const demandMap = {};
        for (const r of requests || []) {
            for (const b of (r.target_blocks || [])) {
                demandMap[b] = (demandMap[b] || 0) + 1;
            }
        }

        const allBlocks = new Set([...Object.keys(supplyMap), ...Object.keys(demandMap)]);
        const result = [...allBlocks].sort().map((b) => {
            const supply = supplyMap[b] || 0;
            const demand = demandMap[b] || 0;
            return {
                block_id: b,
                supply,
                demand,
                demand_supply_ratio: supply > 0 ? Math.round((demand / supply) * 100) / 100 : null,
            };
        });

        res.json(result.sort((a, b) => (b.demand_supply_ratio || 0) - (a.demand_supply_ratio || 0)));
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/analytics/price-stats', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');
        const { data, error } = await supabase
            .from('listings')
            .select('block_id, unit, demand_price')
            .eq('is_public', true)
            .eq('status', 'active');

        if (error) return res.status(400).json({ error: error.message });

        const groups = {};
        for (const row of data || []) {
            const key = `${row.block_id}__${row.unit}`;
            if (!groups[key]) groups[key] = { block_id: row.block_id, unit: row.unit, prices: [] };
            groups[key].prices.push(row.demand_price);
        }

        const stats = Object.values(groups).map(({ block_id, unit, prices }) => {
            const sorted = [...prices].sort((a, b) => a - b);
            const n = sorted.length;
            const median = n % 2 === 1
                ? sorted[Math.floor(n / 2)]
                : Math.floor((sorted[n / 2 - 1] + sorted[n / 2]) / 2);
            return {
                block_id,
                unit,
                count: n,
                min_price: sorted[0],
                max_price: sorted[n - 1],
                avg_price: Math.round(prices.reduce((s, p) => s + p, 0) / n),
                median_price: median,
            };
        });

        res.json(stats.sort((a, b) => a.block_id.localeCompare(b.block_id)));
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/analytics/velocity', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');
        const days = Number(req.query.days || 30);
        const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

        const { data, error } = await supabase
            .from('listings')
            .select('block_id, status, updated_at')
            .in('status', ['sold', 'under_offer'])
            .gte('updated_at', cutoff);

        if (error) return res.status(400).json({ error: error.message });

        const velocityMap = {};
        for (const row of data || []) {
            if (!velocityMap[row.block_id]) velocityMap[row.block_id] = { sold: 0, under_offer: 0 };
            velocityMap[row.block_id][row.status] = (velocityMap[row.block_id][row.status] || 0) + 1;
        }

        const result = Object.entries(velocityMap).map(([b, v]) => ({
            block_id: b,
            [`sold_last_${days}_days`]: v.sold,
            [`under_offer_last_${days}_days`]: v.under_offer,
            total_activity: v.sold + v.under_offer,
        }));

        res.json(result.sort((a, b) => b.total_activity - a.total_activity));
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/analytics/corner-premium', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');
        const { data, error } = await supabase
            .from('listings')
            .select('block_id, features, demand_price')
            .eq('is_public', true)
            .eq('status', 'active');

        if (error) return res.status(400).json({ error: error.message });

        const groups = {};
        for (const row of data || []) {
            const b = row.block_id;
            if (!groups[b]) groups[b] = { corner: [], non_corner: [] };
            const features = (row.features || []).map((f) => String(f).toLowerCase());
            const isCorner = features.includes('corner');
            groups[b][isCorner ? 'corner' : 'non_corner'].push(row.demand_price);
        }

        const avg = (arr) => arr.length ? Math.round(arr.reduce((s, p) => s + p, 0) / arr.length) : null;
        const result = Object.entries(groups).map(([b, { corner, non_corner }]) => {
            const cornerAvg = avg(corner);
            const nonCornerAvg = avg(non_corner);
            const premiumPct = cornerAvg && nonCornerAvg
                ? Math.round(((cornerAvg - nonCornerAvg) / nonCornerAvg) * 1000) / 10
                : null;
            return {
                block_id: b,
                corner_avg_price: cornerAvg,
                non_corner_avg_price: nonCornerAvg,
                corner_premium_pct: premiumPct,
                corner_count: corner.length,
                non_corner_count: non_corner.length,
            };
        });

        res.json(result.sort((a, b) => (b.corner_premium_pct || 0) - (a.corner_premium_pct || 0)));
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/analytics/leaderboard', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');
        const limit = Number(req.query.limit || 10);
        const { data, error } = await supabase
            .from('agents')
            .select('id, name, agency_name, public_listings_count, is_verified, work_areas')
            .order('public_listings_count', { ascending: false })
            .limit(limit);

        if (error) return res.status(400).json({ error: error.message });
        res.json((data || []).map((agent, idx) => ({ rank: idx + 1, ...agent })));
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/analytics/recommendations', async (req, res) => {
    try {
        const { default: supabase } = await import('./services/supabaseClient.js');
        const agent_id = req.query.agent_id;
        const limit = Number(req.query.limit || 20);
        if (!agent_id) return res.status(400).json({ error: 'agent_id required' });

        const { data, error } = await supabase
            .from('notifications')
            .select('id, agent_id, type, message, is_read, created_at')
            .eq('agent_id', String(agent_id))
            .eq('type', 'recommendation')
            .order('created_at', { ascending: false })
            .limit(limit);

        if (error) return res.status(400).json({ error: error.message });
        res.json(data || []);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Only start listening when running locally (Vercel handles this automatically)
if (!process.env.VERCEL) {
    const PORT = process.env.PORT || 8080;
    app.listen(PORT, () => {
        console.log(`\n🚀 Raabta AI — port ${PORT}`);
        console.log(`📡 http://localhost:${PORT}/health\n`);
    });
}

export default app;

function calcAvgVelocity(listings) {
    if (!listings || listings.length === 0) return null;
    const days = listings
        .filter((l) => l.created_at && l.updated_at)
        .map((l) => (new Date(l.updated_at) - new Date(l.created_at)) / (1000 * 60 * 60 * 24));
    if (!days.length) return null;
    return Math.round(days.reduce((a, b) => a + b, 0) / days.length);
}
