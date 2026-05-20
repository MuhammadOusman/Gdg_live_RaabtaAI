import express from 'express';
import supabase from '../services/supabaseClient.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

router.post('/', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('requests')
        .insert({ ...req.body, buyer_agent_id: req.agentId })
        .select()
        .single();

    if (error) return res.status(400).json({ error: error.message });
    return res.status(201).json(data);
});

router.get('/', async (req, res) => {
    const { block_id, status = 'searching', unit, limit = 50, offset = 0 } = req.query;

    let query = supabase
        .from('requests')
        .select('*, agents(name, agency_name, is_verified)');

    if (status)   query = query.eq('status', status);
    if (block_id) query = query.contains('target_blocks', [block_id]);
    if (unit)     query = query.eq('unit', unit);

    const { data, error } = await query
        .order('created_at', { ascending: false })
        .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) return res.status(400).json({ error: error.message });
    return res.json({ data, count: data.length });
});

router.get('/my', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('requests')
        .select('*')
        .eq('buyer_agent_id', req.agentId)
        .order('created_at', { ascending: false });

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
});

router.get('/:id', async (req, res) => {
    const { data, error } = await supabase
        .from('requests')
        .select('*, agents(name, agency_name, is_verified)')
        .eq('id', req.params.id)
        .single();

    if (error || !data) return res.status(404).json({ error: 'Request not found' });
    return res.json(data);
});

router.patch('/:id', requireAuth, async (req, res) => {
    const { data: existing } = await supabase
        .from('requests')
        .select('buyer_agent_id')
        .eq('id', req.params.id)
        .single();

    if (!existing) return res.status(404).json({ error: 'Request not found' });
    if (existing.buyer_agent_id !== req.agentId) return res.status(403).json({ error: 'Not your request' });

    const allowed = ['target_blocks', 'target_size', 'unit', 'target_features', 'max_budget', 'status'];
    const updates = Object.fromEntries(
        Object.entries(req.body).filter(([k]) => allowed.includes(k))
    );

    const { data, error } = await supabase
        .from('requests')
        .update(updates)
        .eq('id', req.params.id)
        .select()
        .single();

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
});

router.delete('/:id', requireAuth, async (req, res) => {
    const { data: existing } = await supabase
        .from('requests')
        .select('buyer_agent_id')
        .eq('id', req.params.id)
        .single();

    if (!existing) return res.status(404).json({ error: 'Request not found' });
    if (existing.buyer_agent_id !== req.agentId) return res.status(403).json({ error: 'Not your request' });

    await supabase.from('requests').delete().eq('id', req.params.id);
    return res.json({ message: 'Request deleted' });
});

export default router;
