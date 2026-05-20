import express from 'express';
import jwt from 'jsonwebtoken';
import supabase from '../services/supabaseClient.js';

const router = express.Router();

router.post('/login', async (req, res) => {
    try {
        if (!process.env.JWT_SECRET) {
            return res.status(500).json({ error: 'JWT_SECRET is not configured on the backend' });
        }

        const { phone_number, name } = req.body;
        if (!phone_number) return res.status(400).json({ error: 'phone_number required' });

        let { data: agent } = await supabase
            .from('agents').select('*').eq('id', phone_number).single();

        if (!agent) {
            const { data: newAgent, error } = await supabase
                .from('agents')
                .insert([{ id: phone_number, name: name || 'Agent', is_verified: false }])
                .select().single();
            if (error) throw error;
            agent = newAgent;
        }

        const token = jwt.sign(
            { agent_id: agent.id, name: agent.name },
            process.env.JWT_SECRET,
            { expiresIn: '30d' }
        );

        res.json({ token, agent });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.post('/send-otp', async (req, res) => {
    const { phone } = req.body;
    if (!phone) return res.status(400).json({ error: 'Phone number is required' });
    try {
        await supabase.auth.signInWithOtp({ phone });
        return res.json({ message: `OTP sent to ${phone}` });
    } catch (err) {
        return res.status(400).json({ error: err.message });
    }
});

router.post('/verify-otp', async (req, res) => {
    const { phone, token } = req.body;
    if (!phone || !token) return res.status(400).json({ error: 'Phone and token are required' });
    try {
        const { data, error } = await supabase.auth.verifyOtp({ phone, token, type: 'sms' });
        if (error) return res.status(401).json({ error: error.message });
        const { session, user } = data;
        const { data: existing } = await supabase.from('agents').select('id').eq('id', user.id).single();
        if (!existing) {
            await supabase.from('agents').insert({
                id: user.id, name: '', agency_name: '',
                work_areas: [], public_listings_count: 0, is_verified: false,
            });
        }
        return res.json({
            access_token: session.access_token,
            refresh_token: session.refresh_token,
            agent_id: user.id, is_new_agent: !existing,
        });
    } catch (err) {
        return res.status(400).json({ error: err.message });
    }
});

router.post('/refresh', async (req, res) => {
    const { refresh_token } = req.body;
    if (!refresh_token) return res.status(400).json({ error: 'refresh_token is required' });
    try {
        const { data, error } = await supabase.auth.refreshSession({ refresh_token });
        if (error) return res.status(401).json({ error: error.message });
        return res.json({
            access_token: data.session.access_token,
            refresh_token: data.session.refresh_token,
        });
    } catch (err) {
        return res.status(401).json({ error: err.message });
    }
});

export default router;
