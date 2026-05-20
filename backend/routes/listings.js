import express from 'express';
import jwt from 'jsonwebtoken';
import 'dotenv/config';
import supabase from '../services/supabaseClient.js';
import { requireAuth } from '../middleware/auth.js';

const JWT_SECRET = process.env.JWT_SECRET;
const router = express.Router();

router.post('/', requireAuth, async (req, res) => {
    const { lat, lng, ...rest } = req.body;
    const listing = { ...rest, owner_agent_id: req.agentId };

    if (lat && lng) {
        listing.geo_point = `POINT(${lng} ${lat})`;
    }

    const { data, error } = await supabase
        .from('listings')
        .insert(listing)
        .select()
        .single();

    if (error) return res.status(400).json({ error: error.message });

    if (listing.is_public) {
        const { data: agent } = await supabase
            .from('agents')
            .select('public_listings_count')
            .eq('id', req.agentId)
            .single();

        await supabase
            .from('agents')
            .update({ public_listings_count: (agent?.public_listings_count || 0) + 1 })
            .eq('id', req.agentId);
    }

    return res.status(201).json(data);
});

router.get('/', async (req, res) => {
    const { block_id, status, min_size, max_size, min_price, max_price, is_hot, unit, limit = 50, offset = 0, is_public } = req.query;

    let query = supabase
        .from('listings')
        .select('id, owner_agent_id, block_id, sub_location_raw, size, unit, features, demand_price, status, is_hot_property, created_at, updated_at, geo_point, notes, agents(name, agency_name, is_verified)');

    if (is_public === 'false') {
        const authHeader = req.headers['authorization'];
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Authentication required' });
        }
        let agentId;
        try {
            const payload = jwt.verify(authHeader.split(' ')[1], JWT_SECRET);
            agentId = payload.agent_id || payload.sub;
        } catch {
            return res.status(401).json({ error: 'Invalid or expired token' });
        }
        query = query
            .eq('owner_agent_id', agentId)
            .eq('is_public', false);
    } else {
        query = query.eq('is_public', true);
    }

    if (block_id) query = query.eq('block_id', block_id);
    if (status)   query = query.eq('status', status);
    if (min_size) query = query.gte('size', Number(min_size));
    if (max_size) query = query.lte('size', Number(max_size));
    if (min_price) query = query.gte('demand_price', Number(min_price));
    if (max_price) query = query.lte('demand_price', Number(max_price));
    if (is_hot !== undefined) query = query.eq('is_hot_property', is_hot === 'true');
    if (unit) query = query.eq('unit', unit);

    const { data, error } = await query
        .order('created_at', { ascending: false })
        .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) return res.status(400).json({ error: error.message });
    return res.json({ data, count: data.length });
});

router.get('/my', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('listings')
        .select('*')
        .eq('owner_agent_id', req.agentId)
        .order('created_at', { ascending: false });

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
});

router.get('/:id', async (req, res) => {
    const { data, error } = await supabase
        .from('listings')
        .select('*, agents(name, agency_name, is_verified, work_areas)')
        .eq('id', req.params.id)
        .single();

    if (error || !data) return res.status(404).json({ error: 'Listing not found' });
    return res.json(data);
});

router.patch('/:id', requireAuth, async (req, res) => {
    const { data: existing, error: fetchErr } = await supabase
        .from('listings')
        .select('owner_agent_id')
        .eq('id', req.params.id)
        .single();

    if (fetchErr || !existing) return res.status(404).json({ error: 'Listing not found' });
    if (existing.owner_agent_id !== req.agentId) return res.status(403).json({ error: 'Not your listing' });

    const allowed = ['is_public', 'block_id', 'sub_location_raw', 'size', 'unit', 'features', 'demand_price', 'status', 'is_hot_property', 'notes'];
    const updates = Object.fromEntries(
        Object.entries(req.body).filter(([k]) => allowed.includes(k))
    );

    const { data, error } = await supabase
        .from('listings')
        .update(updates)
        .eq('id', req.params.id)
        .select()
        .single();

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
});

router.delete('/:id', requireAuth, async (req, res) => {
    const { data: existing } = await supabase
        .from('listings')
        .select('owner_agent_id, is_public')
        .eq('id', req.params.id)
        .single();

    if (!existing) return res.status(404).json({ error: 'Listing not found' });
    if (existing.owner_agent_id !== req.agentId) return res.status(403).json({ error: 'Not your listing' });

    await supabase.from('listings').delete().eq('id', req.params.id);

    if (existing.is_public) {
        const { data: agent } = await supabase
            .from('agents')
            .select('public_listings_count')
            .eq('id', req.agentId)
            .single();

        await supabase
            .from('agents')
            .update({ public_listings_count: Math.max(0, (agent?.public_listings_count || 1) - 1) })
            .eq('id', req.agentId);
    }

    return res.json({ message: 'Listing deleted' });
});

export default router;
