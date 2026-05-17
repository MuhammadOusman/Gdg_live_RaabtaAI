import supabase from '../../services/supabaseClient.js';
import { callGemini } from '../../services/geminiClient.js';

const RECOMMENDER_PROMPT = `You are a real estate market advisor for Karachi, Pakistan.
You will receive market data about a broker's listings and block-level demand/supply stats.
Generate 2-4 actionable recommendations in Roman Urdu mixed with English (the way Pakistani brokers talk).
Be specific with block names, prices, and percentages.
Output ONLY a JSON array. No explanation. No markdown.

Format:
[
  {
    "type": "opportunity" | "pricing" | "visibility" | "market",
    "title": "Short title",
    "message": "Detailed recommendation in Roman Urdu/English mix",
    "priority": "high" | "medium" | "low"
  }
]`;

export async function generateRecommendations(agentId) {
    console.log(`[💡 Recommender] Generating recommendations for agent ${agentId}`);

    // ── 1. Agent ki listings fetch karo ───────────────
    const { data: myListings } = await supabase
        .from('listings')
        .select('id, block_id, size, demand_price, is_public, is_hot_property, created_at')
        .eq('owner_agent_id', agentId)
        .eq('status', 'active');

    // ── 2. Block market stats fetch karo ──────────────
    const { data: blockStats } = await supabase
        .from('block_market_stats')
        .select('*');

    // ── 3. Agent ka work_areas fetch karo ─────────────
    const { data: agent } = await supabase
        .from('agents')
        .select('work_areas, name')
        .eq('id', agentId)
        .single();

    if (!myListings || !blockStats) {
        return { recommendations: [], message: 'Insufficient data' };
    }

    // ── 4. Data prepare karo Gemini ke liye ───────────
    const marketData = {
        agent_work_areas: agent?.work_areas || [],
        my_listings: myListings.map(l => ({
            block: l.block_id,
            size: l.size,
            price: l.demand_price,
            is_public: l.is_public,
            is_hot: l.is_hot_property,
        })),
        block_stats: (blockStats || []).map(b => ({
            block: b.block_id,
            supply: b.supply,
            demand: b.demand,
            demand_ratio: b.demand_ratio,
        })),
        // Private listings jo public ho sakti hain
        private_in_hot_blocks: myListings.filter(l => {
            if (l.is_public) return false;
            const stat = blockStats.find(b => b.block_id === l.block_id);
            return stat && stat.demand_ratio > 1.5;
        }).map(l => l.block_id),
        // Overpriced listings detect karo
        overpriced: detectOverpriced(myListings, blockStats),
    };

    // ── 5. Gemini se recommendations lo ───────────────
    const responseText = await callGemini(
        RECOMMENDER_PROMPT,
        `Generate recommendations based on this data: ${JSON.stringify(marketData)}`,
        2048
    );

    let recommendations;
    try {
        recommendations = JSON.parse(responseText);
    } catch {
        console.error('[Recommender] JSON parse failed:', responseText);
        recommendations = [];
    }

    console.log(`[💡 Recommender] Generated ${recommendations.length} recommendations`);

    // ── 6. Supabase mein notifications ke roop mein save karo ──
    for (const rec of recommendations) {
        if (rec.priority === 'high') {
            await supabase.from('notifications').insert([{
                agent_id: agentId,
                message: `💡 ${rec.title}: ${rec.message}`,
                type: 'recommendation',
            }]);
        }
    }

    return { recommendations, agent_id: agentId };
}

// Helper: block average se 15%+ upar wali listings
function detectOverpriced(myListings, blockStats) {
    const overpriced = [];

    for (const listing of myListings) {
        if (!listing.is_public) continue;

        const stat = blockStats.find(b => b.block_id === listing.block_id);
        if (!stat || stat.supply < 2) continue;

        // Block average price calculate karo
        // (block_market_stats mein avg price nahi hai — listings se calculate karo)
        // Simple heuristic: agar demand_ratio < 0.5 aur listing exist kare toh oversupplied
        if (stat.demand_ratio < 0.5) {
            overpriced.push({
                block: listing.block_id,
                price: listing.demand_price,
                note: 'Low demand area — price reconsider karo'
            });
        }
    }

    return overpriced;
}