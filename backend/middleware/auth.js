import jwt from 'jsonwebtoken';
import 'dotenv/config';

// const JWT_SECRET = process.env.SUPABASE_JWT_SECRET;
const JWT_SECRET = process.env.JWT_SECRET;

export function requireAuth(req, res, next) {
    if (!JWT_SECRET) {
        return res.status(500).json({ error: 'JWT_SECRET is not configured on the backend' });
    }

    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing or invalid Authorization header' });
    }

    const token = authHeader.split(' ')[1];

    try {
        // const payload = jwt.verify(token, JWT_SECRET, { audience: 'authenticated' });
        const payload = jwt.verify(token, JWT_SECRET);
        req.agent = { agent_id: payload.agent_id || payload.sub };
        req.agentId = payload.agent_id || payload.sub;
        next();
    } catch (err) {
        if (err.name === 'TokenExpiredError') {
            return res.status(401).json({ error: 'Token has expired' });
        }
        return res.status(401).json({ error: `Invalid token: ${err.message}` });
    }
}
