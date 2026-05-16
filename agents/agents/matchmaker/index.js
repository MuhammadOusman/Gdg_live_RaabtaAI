import supabase from '../../services/supabaseClient.js';
import { getAdjacentBlocks } from './adjacentBlocks.js';

const BUDGET_FLEX = 0.15;

// Naya listing aaya → existing open requests se match karo
export async function findAndNotifyMatches(listing) {
    const { block_id, size, demand_price, is_public, owner_agent_id, id } = listing;

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
        const sizeMatch = req.target_size === size;
        const priceMatch = demand_price <= flexBudget;
        const exactBlock = req.target_blocks.includes(block_id);
        const adjBlock = req.target_blocks.some(b => adjacentBlocks.includes(b));

        if (sizeMatch && priceMatch && (exactBlock || adjBlock)) {
            console.log(`[🔗 Matchmaker] Match found! Request ${req.id} ← Listing ${id} (${exactBlock ? 'exact' : 'adjacent'} block)`);

            matches.push({ request: req, listing_id: id, matchType: exactBlock ? 'exact' : 'adjacent' });

            await supabase.from('notifications').insert([{
                agent_id: req.buyer_agent_id,
                listing_id: id,
                message: buildMatchMessage(listing, exactBlock, demand_price > req.max_budget),
            }]);
        }
    }

    console.log(`[🔗 Matchmaker] Total matches found: ${matches.length}`);
    return matches;
}

// Naya demand aaya → existing listings se turant match karo
export async function matchDemandToListings(parsedData, buyerAgentId) {
    const { block_id, size, max_budget } = parsedData;
    const flexBudget = Math.floor(max_budget * (1 + BUDGET_FLEX));
    const adjacentBlocks = getAdjacentBlocks(block_id);
    const allBlocks = [block_id, ...adjacentBlocks];

    console.log(`[🔗 Matchmaker] Demand search — Block: ${block_id}, Size: ${size}gz, Budget: ${max_budget} (flex: ${flexBudget})`);

    const { data, error } = await supabase
        .from('listings')
        .select('id, block_id, size, demand_price, features, sub_location_raw, owner_agent_id')
        .eq('is_public', true)
        .eq('status', 'active')
        .eq('size', size)
        .lte('demand_price', flexBudget)
        .in('block_id', allBlocks)
        .neq('owner_agent_id', buyerAgentId);

    if (error) throw new Error(`Matchmaker: Demand match failed — ${error.message}`);

    console.log(`[🔗 Matchmaker] Immediate matches: ${data?.length || 0}`);
    return data || [];
}

function buildMatchMessage(listing, isExact, isFlexUsed) {
    const price = listing.demand_price.toLocaleString('en-PK');
    const adjNote = isExact ? '' : ' (adjacent area)';
    const flex = isFlexUsed ? ' — thoda upar hai, negotiate ho sakta hai' : '';
    return `🚨 Match mila! ${listing.size}gz in ${listing.block_id}${adjNote} — PKR ${price}${flex}`;
}