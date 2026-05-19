import supabase from '../../services/supabaseClient.js';
import { getAdjacentBlocks } from './adjacentBlocks.js';

const BUDGET_FLEX  = 0.15; // buyer's budget can stretch 15% above stated max
const SIZE_FLEX    = 0.10; // ±10% size tolerance

// ── New listing → scan open requests ──────────────────────
export async function findAndNotifyMatches(listing) {
    const { block_id, size, demand_price, features, is_public, owner_agent_id, id } = listing;

    if (!is_public) return [];

    console.log(`[🔗 Matchmaker] New listing ${id} — scanning open requests...`);

    const { data: requests, error } = await supabase
        .from('requests')
        .select('*')
        .eq('status', 'searching')
        .neq('buyer_agent_id', owner_agent_id);

    if (error) throw new Error(`Matchmaker: Request fetch failed — ${error.message}`);

    const adjacentBlocks = getAdjacentBlocks(block_id);
    const matches = [];

    for (const req of (requests || [])) {
        const flexBudget = req.max_budget * (1 + BUDGET_FLEX);

        // Size match with ±10% tolerance
        const sizeDiff = Math.abs(req.target_size - size) / req.target_size;
        const sizeMatch = sizeDiff <= SIZE_FLEX;

        const priceMatch  = demand_price <= flexBudget;
        const exactBlock  = req.target_blocks.includes(block_id);
        const adjBlock    = req.target_blocks.some(b => adjacentBlocks.includes(b));

        // Feature match: if buyer wants specific features, listing must have at least one
        const featureMatch =
            !req.target_features ||
            req.target_features.length === 0 ||
            req.target_features.some(f => features?.includes(f));

        if (sizeMatch && priceMatch && (exactBlock || adjBlock) && featureMatch) {
            const isFlexUsed = demand_price > req.max_budget;
            console.log(`[🔗 Matchmaker] Match! Request ${req.id} ← Listing ${id} (${exactBlock ? 'exact' : 'adjacent'} block)`);

            matches.push({ request: req, listing_id: id, matchType: exactBlock ? 'exact' : 'adjacent' });

            await supabase.from('notifications').insert([{
                agent_id: req.buyer_agent_id,
                listing_id: id,
                message: buildMatchMessage(listing, exactBlock, isFlexUsed),
            }]);
        }
    }

    console.log(`[🔗 Matchmaker] Total matches: ${matches.length}`);
    return matches;
}

// ── New demand → scan existing listings ───────────────────
export async function matchDemandToListings(parsedData, buyerAgentId) {
    const { block_id, size, max_budget, features } = parsedData;

    if (!max_budget) {
        console.log(`[🔗 Matchmaker] No budget provided — skipping demand match`);
        return [];
    }

    const flexBudget    = Math.floor(max_budget * (1 + BUDGET_FLEX));
    const sizeMin       = Math.floor(size * (1 - SIZE_FLEX));
    const sizeMax       = Math.ceil(size  * (1 + SIZE_FLEX));
    const adjacentBlocks = getAdjacentBlocks(block_id);
    const allBlocks      = [block_id, ...adjacentBlocks];

    console.log(`[🔗 Matchmaker] Demand search — Block: ${block_id}, Size: ${sizeMin}–${sizeMax}gz, Budget: ${max_budget} (flex: ${flexBudget})`);

    const { data, error } = await supabase
        .from('listings')
        .select('id, block_id, size, unit, demand_price, features, sub_location_raw, owner_agent_id')
        .eq('is_public', true)
        .eq('status', 'active')
        .gte('size', sizeMin)
        .lte('size', sizeMax)
        .lte('demand_price', flexBudget)
        .in('block_id', allBlocks)
        .neq('owner_agent_id', buyerAgentId);

    if (error) throw new Error(`Matchmaker: Demand match failed — ${error.message}`);

    let results = data || [];

    // Feature filter — only apply when buyer specified desired features
    if (features && features.length > 0) {
        results = results.filter(listing =>
            listing.features?.length > 0 &&
            features.some(f => listing.features.includes(f))
        );
    }

    console.log(`[🔗 Matchmaker] Immediate matches: ${results.length}`);
    return results;
}

function buildMatchMessage(listing, isExact, isFlexUsed) {
    const price   = listing.demand_price.toLocaleString('en-PK');
    const adjNote = isExact ? '' : ' (adjacent area)';
    const flex    = isFlexUsed ? ' — thoda upar hai, negotiate ho sakta hai' : '';
    const feats   = listing.features?.length > 0 ? ` • ${listing.features.join(', ')}` : '';
    return `🚨 Match mila! ${listing.size}gz in ${listing.block_id}${adjNote}${feats} — PKR ${price}${flex}`;
}