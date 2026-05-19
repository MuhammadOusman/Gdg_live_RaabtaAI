import cron from 'node-cron';
import { runDailyReview, autoArchiveStale, refreshBlockStats } from './index.js';
import { generateRecommendations } from '../recommender/index.js';
import supabase from '../../services/supabaseClient.js';

// 8:00 PM Pakistan time (UTC+5 → 15:00 UTC)
cron.schedule('0 15 * * *', async () => {
    console.log('[Cron] 8PM daily review triggered');
    await runDailyReview();
}, { timezone: 'Asia/Karachi' });

// Har 6 ghante auto-archive aur stats refresh check
cron.schedule('0 */6 * * *', async () => {
    console.log('[Cron] Auto-archive and stats refresh check');
    await autoArchiveStale();
    await refreshBlockStats();
}, { timezone: 'Asia/Karachi' });

// Sunday 10:00 AM Pakistan time — Weekly Recommendations Cron
cron.schedule('0 10 * * 0', async () => {
    console.log('[Cron] Sunday 10AM weekly recommendations triggered');
    try {
        // Fetch all distinct agent IDs from active listings
        const { data: listings, error } = await supabase
            .from('listings')
            .select('owner_agent_id')
            .eq('status', 'active');

        if (error) throw error;

        const agentIds = [...new Set((listings || []).map(l => l.owner_agent_id).filter(Boolean))];
        console.log(`[Cron] Found ${agentIds.length} unique agent(s) to generate recommendations for`);

        for (const agentId of agentIds) {
            try {
                await generateRecommendations(agentId);
            } catch (innerErr) {
                console.error(`[Cron] Recommender failed for agent ${agentId}:`, innerErr.message);
            }
        }
    } catch (err) {
        console.error('[Cron Recommender] Main job failed:', err.message);
    }
}, { timezone: 'Asia/Karachi' });

// Initial run to ensure block stats are filled on startup
console.log('[Cron] Triggering startup block stats refresh...');
refreshBlockStats().catch(err => console.error('[Cron Startup] Failed to refresh stats:', err.message));

console.log('[Cron] Janitor jobs scheduled ✅');