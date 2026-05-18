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

    const overpricedOrOversupplied = await detectOversuppliedOrOverpriced(myListings, blockStats);

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
        overpriced_or_oversupplied: overpricedOrOversupplied,
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
        console.error('[Recommender] JSON parse failed — trying recovery...');
        try {
            const recoveryText = await callGemini(
                RECOMMENDER_PROMPT,
                `${responseText}\n\n[SYSTEM: Return ONLY a valid JSON array of recommendations.]`
            );
            recommendations = JSON.parse(recoveryText);
        } catch {
            recommendations = [];
        }
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

// Helper: block average se 15%+ upar wali listings OR low demand blocks detect karo
async function detectOversuppliedOrOverpriced(myListings, blockStats) {
    const overpricedOrOversupplied = [];
    const uniqueBlocks = [...new Set(myListings.map(l => l.block_id).filter(Boolean))];

    if (uniqueBlocks.length === 0) return overpricedOrOversupplied;

    // Fetch all listings in the same blocks to calculate averages
    const { data: allListings } = await supabase
        .from('listings')
        .select('block_id, demand_price')
        .eq('status', 'active')
        .eq('is_public', true)
        .in('block_id', uniqueBlocks);

    // Group by block to find average
    const blockAverages = {};
    if (allListings) {
        for (const l of allListings) {
            if (!blockAverages[l.block_id]) {
                blockAverages[l.block_id] = { sum: 0, count: 0 };
            }
            blockAverages[l.block_id].sum += l.demand_price;
            blockAverages[l.block_id].count += 1;
        }
    }

    for (const listing of myListings) {
        if (!listing.is_public) continue;

        const stat = blockStats.find(b => b.block_id === listing.block_id);
        if (!stat) continue;

        // 1. Oversupplied check (demand_ratio < 0.5)
        if (stat.demand_ratio < 0.5) {
            overpricedOrOversupplied.push({
                block: listing.block_id,
                price: listing.demand_price,
                type: 'oversupplied',
                note: 'Low demand area — supply is very high compared to demand'
            });
            continue;
        }

        // 2. Overpriced check (15%+ above block average)
        const avgData = blockAverages[listing.block_id];
        if (avgData && avgData.count >= 2) {
            const avg = avgData.sum / avgData.count;
            if (listing.demand_price > avg * 1.15) {
                overpricedOrOversupplied.push({
                    block: listing.block_id,
                    price: listing.demand_price,
                    type: 'overpriced',
                    note: `Your listing price is 15%+ above block average of PKR ${Math.round(avg).toLocaleString('en-PK')}`
                });
            }
        }
    }

    return overpricedOrOversupplied;
}