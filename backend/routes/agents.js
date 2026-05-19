import express from 'express';
import supabase from '../services/supabaseClient.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

router.get('/me', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('agents')
        .select('*')
        .eq('id', req.agent.agent_id)
        .single();

    if (error || !data) return res.status(404).json({ error: 'Agent not found' });
    return res.json(data);
});

router.patch('/me', requireAuth, async (req, res) => {
    const allowed = ['name', 'agency_name', 'work_areas'];
    const updates = Object.fromEntries(
        Object.entries(req.body).filter(([k]) => allowed.includes(k))
    );

    if (Object.keys(updates).length === 0) {
        return res.status(400).json({ error: 'No valid fields to update' });
    }

    const { data, error } = await supabase
        .from('agents')
        .update(updates)
        .eq('id', req.agentId)
        .select()
        .single();

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
});

router.get('/:id', async (req, res) => {
    const { data, error } = await supabase
        .from('agents')
        .select('id, name, agency_name, work_areas, public_listings_count, is_verified, created_at')
        .eq('id', req.params.id)
        .single();

    if (error || !data) return res.status(404).json({ error: 'Agent not found' });
    return res.json(data);
});

export default router;
