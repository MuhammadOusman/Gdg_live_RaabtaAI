import express from 'express';
import supabase from '../services/supabaseClient.js';

const router = express.Router();

// GET /api/analytics/dashboard
router.get('/dashboard', async (req, res) => {
    try {
        const { block_id } = req.query;

        let statsQuery = supabase.from('block_market_stats').select('*');
        if (block_id) statsQuery = statsQuery.eq('block_id', block_id);
        const { data: blockStats } = await statsQuery;

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

        const featurePremium = await calcFeaturePremium();

        res.json({
            block_stats: blockStats || [],
            avg_velocity_days: avgDays,
            hot_properties_count: hotCount || 0,
            top_agents: topAgents || [],
            feature_premium: featurePremium,
            generated_at: new Date().toISOString(),
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/analytics/demand-vs-supply
router.get('/demand-vs-supply', async (req, res) => {
    const { block_id } = req.query;

    let listingsQuery = supabase
        .from('listings')
        .select('block_id')
        .eq('is_public', true)
        .eq('status', 'available');

    const { data: listings, error: lErr } = block_id
        ? await listingsQuery.eq('block_id', block_id)
        : await listingsQuery;

    const { data: requests, error: rErr } = await supabase
        .from('requests')
        .select('target_blocks')
        .eq('status', 'active');

    if (lErr || rErr) return res.status(400).json({ error: lErr?.message || rErr?.message });

    const supplyMap = {};
    for (const l of listings) {
        supplyMap[l.block_id] = (supplyMap[l.block_id] || 0) + 1;
    }

    const demandMap = {};
    for (const r of requests) {
        for (const b of (r.target_blocks || [])) {
            demandMap[b] = (demandMap[b] || 0) + 1;
        }
    }

    const allBlocks = new Set([...Object.keys(supplyMap), ...Object.keys(demandMap)]);
    if (block_id) allBlocks.clear(), allBlocks.add(block_id);

    const result = [...allBlocks].sort().map(b => {
        const supply = supplyMap[b] || 0;
        const demand = demandMap[b] || 0;
        return {
            block_id: b,
            supply,
            demand,
            demand_supply_ratio: supply > 0 ? Math.round((demand / supply) * 100) / 100 : null,
        };
    });

    return res.json(result.sort((a, b) => (b.demand_supply_ratio || 0) - (a.demand_supply_ratio || 0)));
});

// GET /api/analytics/price-stats
router.get('/price-stats', async (req, res) => {
    const { block_id, unit } = req.query;

    let query = supabase
        .from('listings')
        .select('block_id, unit, demand_price')
        .eq('is_public', true)
        .eq('status', 'available');

    if (block_id) query = query.eq('block_id', block_id);
    if (unit)     query = query.eq('unit', unit);

    const { data, error } = await query;
    if (error) return res.status(400).json({ error: error.message });

    const groups = {};
    for (const row of data) {
        const key = `${row.block_id}__${row.unit}`;
        if (!groups[key]) groups[key] = { block_id: row.block_id, unit: row.unit, prices: [] };
        groups[key].prices.push(row.demand_price);
    }

    const stats = Object.values(groups).map(({ block_id, unit, prices }) => {
        const sorted = [...prices].sort((a, b) => a - b);
        const n = sorted.length;
        const median = n % 2 === 1 ? sorted[Math.floor(n / 2)] : Math.floor((sorted[n / 2 - 1] + sorted[n / 2]) / 2);
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

    return res.json(stats.sort((a, b) => a.block_id.localeCompare(b.block_id)));
});

// GET /api/analytics/velocity
router.get('/velocity', async (req, res) => {
    const { block_id, days = 30 } = req.query;
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

    let query = supabase
        .from('listings')
        .select('block_id, status, updated_at')
        .in('status', ['sold', 'under_offer'])
        .gte('updated_at', cutoff);

    if (block_id) query = query.eq('block_id', block_id);

    const { data, error } = await query;
    if (error) return res.status(400).json({ error: error.message });

    const velocityMap = {};
    for (const row of data) {
        if (!velocityMap[row.block_id]) velocityMap[row.block_id] = { sold: 0, under_offer: 0 };
        velocityMap[row.block_id][row.status]++;
    }

    const result = Object.entries(velocityMap).map(([b, v]) => ({
        block_id: b,
        [`sold_last_${days}_days`]: v.sold,
        [`under_offer_last_${days}_days`]: v.under_offer,
        total_activity: v.sold + v.under_offer,
    }));

    return res.json(result.sort((a, b) => b.total_activity - a.total_activity));
});

// GET /api/analytics/corner-premium
router.get('/corner-premium', async (req, res) => {
    const { block_id } = req.query;

    let query = supabase
        .from('listings')
        .select('block_id, features, demand_price')
        .eq('is_public', true)
        .eq('status', 'available');

    if (block_id) query = query.eq('block_id', block_id);

    const { data, error } = await query;
    if (error) return res.status(400).json({ error: error.message });

    const groups = {};
    for (const row of data) {
        const b = row.block_id;
        if (!groups[b]) groups[b] = { corner: [], non_corner: [] };
        const isCorner = (row.features || []).includes('corner');
        groups[b][isCorner ? 'corner' : 'non_corner'].push(row.demand_price);
    }

    const avg = arr => arr.length ? Math.round(arr.reduce((s, p) => s + p, 0) / arr.length) : null;

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

    return res.json(result.sort((a, b) => (b.corner_premium_pct || 0) - (a.corner_premium_pct || 0)));
});

// GET /api/analytics/leaderboard
router.get('/leaderboard', async (req, res) => {
    const { limit = 10 } = req.query;

    const { data, error } = await supabase
        .from('agents')
        .select('id, name, agency_name, public_listings_count, is_verified, work_areas')
        .order('public_listings_count', { ascending: false })
        .limit(Number(limit));

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data.map((agent, idx) => ({ rank: idx + 1, ...agent })));
});

// Helper functions
function calcAvgVelocity(listings) {
    if (!listings.length) return null;
    const days = listings.map(l => {
        const diff = new Date(l.updated_at) - new Date(l.created_at);
        return diff / (1000 * 60 * 60 * 24);
    });
    return Math.round(days.reduce((a, b) => a + b, 0) / days.length);
}

async function calcFeaturePremium() {
    const { data: all } = await supabase
        .from('listings')
        .select('features, demand_price')
        .eq('is_public', true)
        .eq('status', 'active');

    if (!all?.length) return [];

    const withCorner = all.filter(l => l.features?.includes('Corner'));
    const withoutCorner = all.filter(l => !l.features?.includes('Corner'));

    if (!withCorner.length || !withoutCorner.length) return [];

    const avgWith = withCorner.reduce((s, l) => s + l.demand_price, 0) / withCorner.length;
    const avgWithout = withoutCorner.reduce((s, l) => s + l.demand_price, 0) / withoutCorner.length;
    const premium = Math.round(((avgWith - avgWithout) / avgWithout) * 100);

    return [{ feature: 'Corner', premium_percent: premium }];
}

export default router;