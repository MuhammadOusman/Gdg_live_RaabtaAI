import express from 'express';
import supabase from '../services/supabaseClient.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

router.get('/', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('notifications')
        .select('*, listings(block_id, size, unit, demand_price, status)')
        .eq('agent_id', req.agentId)
        .order('created_at', { ascending: false })
        .limit(100);

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
});

router.get('/unread-count', requireAuth, async (req, res) => {
    const { count, error } = await supabase
        .from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('agent_id', req.agentId)
        .eq('is_read', false);

    if (error) return res.status(400).json({ error: error.message });
    return res.json({ unread_count: count });
});

router.patch('/read-all', requireAuth, async (req, res) => {
    const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('agent_id', req.agentId)
        .eq('is_read', false);

    if (error) return res.status(400).json({ error: error.message });
    return res.json({ message: 'All notifications marked as read' });
});

router.patch('/:id/read', requireAuth, async (req, res) => {
    const { data: existing } = await supabase
        .from('notifications')
        .select('agent_id')
        .eq('id', req.params.id)
        .single();

    if (!existing) return res.status(404).json({ error: 'Notification not found' });
    if (existing.agent_id !== req.agentId) return res.status(403).json({ error: 'Not your notification' });

    await supabase.from('notifications').update({ is_read: true }).eq('id', req.params.id);
    return res.json({ message: 'Marked as read' });
});

export default router;
