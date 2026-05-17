import { Router } from 'express';
import supabase from '../services/supabaseClient.js';
import { requireAuth as authMiddleware } from '../middleware/auth.js';

const router = Router();

router.get('/markers', authMiddleware, async (req, res) => {
    try {
        const { data: agent } = await supabase
            .from('agents')
            .select('work_areas')
            .eq('id', req.agent.agent_id)
            .single();

        const workAreas = agent?.work_areas || [];

        let query = supabase
            .from('listings')
            .select('id, block_id, geo_point, size, unit, demand_price, is_hot_property, features, created_at')
            .eq('is_public', true)
            .eq('status', 'active');

        if (workAreas.length > 0) {
            const filters = workAreas.map(area => `block_id.ilike.%${area}%`).join(',');
            query = query.or(filters);
        }

        const { data: listings, error } = await query;
        if (error) throw error;

        const now = new Date();
        const markers = (listings || [])
            .filter(l => l.geo_point)
            .map(l => {
                const coords = parseGeoPoint(l.geo_point);
                const hoursAgo = (now - new Date(l.created_at)) / (1000 * 60 * 60);
                return {
                    id: l.id,
                    lat: coords.lat,
                    lng: coords.lng,
                    block_id: l.block_id,
                    size: l.size,
                    unit: l.unit,
                    price: l.demand_price,
                    is_hot: l.is_hot_property,
                    is_new: hoursAgo <= 24,
                    features: l.features || [],
                    marker_type: l.is_hot_property ? 'hot' : hoursAgo <= 24 ? 'new' : 'standard',
                };
            });

        res.json({ markers, total: markers.length, work_areas: workAreas });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/trends', authMiddleware, async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('block_market_stats')
            .select('*');

        if (error) throw error;

        const trends = (data || []).map(block => ({
            ...block,
            heat_level: getHeatLevel(block.demand_ratio),
            circle_radius: Math.min(500 + (block.demand * 100), 2000),
        }));

        res.json(trends);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/ghost-markers', authMiddleware, async (req, res) => {
    try {
        const { data: agent } = await supabase
            .from('agents')
            .select('work_areas')
            .eq('id', req.agent.agent_id)
            .single();

        const workAreas = agent?.work_areas || [];

        const { data: requests, error } = await supabase
            .from('requests')
            .select('target_blocks')
            .eq('status', 'searching')
            .order('created_at', { ascending: false })
            .limit(50);

        if (error) throw error;

        const blockDemand = {};
        for (const req of (requests || [])) {
            for (const block of (req.target_blocks || [])) {
                if (workAreas.length > 0) {
                    const inArea = workAreas.some(area =>
                        block.toLowerCase().includes(area.toLowerCase())
                    );
                    if (!inArea) continue;
                }
                blockDemand[block] = (blockDemand[block] || 0) + 1;
            }
        }

        const ghostMarkers = Object.entries(blockDemand).map(([block_id, demand_count]) => ({
            block_id,
            demand_count,
            opacity: Math.min(0.3 + (demand_count * 0.1), 0.8),
        }));

        res.json(ghostMarkers);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get('/pulse', async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('block_market_stats')
            .select('block_id, supply, demand, demand_ratio')
            .order('demand_ratio', { ascending: false })
            .limit(10);

        if (error) throw error;

        res.json({
            trending_blocks: data || [],
            generated_at: new Date().toISOString(),
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

function parseGeoPoint(geoPoint) {
    try {
        if (typeof geoPoint === 'string') geoPoint = JSON.parse(geoPoint);
        if (geoPoint?.coordinates) {
            return { lng: geoPoint.coordinates[0], lat: geoPoint.coordinates[1] };
        }
    } catch {}
    return { lat: null, lng: null };
}

function getHeatLevel(ratio) {
    if (!ratio) return 'low';
    if (ratio > 2.0) return 'high';
    if (ratio > 1.0) return 'medium';
    return 'low';
}

export default router;
