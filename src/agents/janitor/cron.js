import cron from 'node-cron';
import { runDailyReview, autoArchiveStale } from './index.js';

// 8:00 PM Pakistan time (UTC+5 → 15:00 UTC)
cron.schedule('0 15 * * *', async () => {
    console.log('[Cron] 8PM daily review triggered');
    await runDailyReview();
}, { timezone: 'Asia/Karachi' });

// Har 6 ghante auto-archive check
cron.schedule('0 */6 * * *', async () => {
    console.log('[Cron] Auto-archive check');
    await autoArchiveStale();
}, { timezone: 'Asia/Karachi' });

console.log('[Cron] Janitor jobs scheduled ✅');