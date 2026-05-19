import supabase from '../../services/supabaseClient.js';

const PRICE_OVERLAP = 0.05; // 5% price band for conflict detection

// Convert any unit to gaz for fair size comparison
function toGaz(size, unit) {
    if (unit === 'kanal') return size * 800;
    if (unit === 'marla') return size * 45;
    return size; // gaz is default
}

export async function checkDuplicates(parsedData, ownerAgentId) {
    const { block_id, size, unit, demand_price, is_public } = parsedData;

    // Private listings — no duplicate check needed
    if (!is_public) {
        console.log(`[⚖️ Negotiator] Private listing — skipping duplicate check`);
        return { isDuplicate: false, conflicts: [] };
    }

    if (!demand_price) {
        console.log(`[⚖️ Negotiator] No price provided — skipping duplicate check`);
        return { isDuplicate: false, conflicts: [] };
    }

    console.log(`[⚖️ Negotiator] Checking duplicates for ${block_id}, ${size} ${unit || 'gaz'}, PKR ${demand_price}`);

    // Fetch all active public listings in same block (any size) — we normalize in JS
    const { data: existing, error } = await supabase
        .from('listings')
        .select('id, block_id, size, unit, demand_price, sub_location_raw, owner_agent_id')
        .eq('block_id', block_id)
        .eq('is_public', true)
        .eq('status', 'active')
        .neq('owner_agent_id', ownerAgentId);

    if (error) throw new Error(`Negotiator: Duplicate check failed — ${error.message}`);

    const incomingGaz = toGaz(size, unit || 'gaz');

    const conflicts = (existing || []).filter(item => {
        if (!item.demand_price) return false;

        // Normalize both sizes to gaz before comparing (handles cross-unit duplicates)
        const itemGaz = toGaz(item.size, item.unit || 'gaz');
        const sizeDiff = Math.abs(itemGaz - incomingGaz) / incomingGaz;
        if (sizeDiff > 0.05) return false; // >5% size difference = not a duplicate

        // Price overlap check
        const priceDiff = Math.abs(item.demand_price - demand_price) / demand_price;
        return priceDiff <= PRICE_OVERLAP;
    });

    if (conflicts.length === 0) {
        console.log(`[⚖️ Negotiator] No conflicts found — clear to save`);
        return { isDuplicate: false, conflicts: [] };
    }

    console.log(`[⚖️ Negotiator] ${conflicts.length} conflict(s) detected`);
    return {
        isDuplicate: true,
        conflicts,
        conflictMessage: buildConflictMessage(conflicts, parsedData),
    };
}

function buildConflictMessage(conflicts, newListing) {
    const conflictLines = conflicts.map((c, i) => {
        const price = c.demand_price?.toLocaleString('en-PK') ?? '?';
        const sub = c.sub_location_raw ? ` — ${c.sub_location_raw}` : '';
        return `  ${i + 1}. ${c.size}${c.unit || 'gz'}${sub} @ PKR ${price}`;
    }).join('\n');

    return `⚠️ Duplicate Alert — Raabta AI

${conflicts.length} similar listing(s) already exist:
${conflictLines}

📍 Block: ${newListing.block_id}
📐 Size: ${newListing.size} ${newListing.unit || 'gaz'}
💰 Your price: PKR ${newListing.demand_price?.toLocaleString('en-PK')}

Duplicate avoid karne ke liye sub-location batao:
(Example: "50 ki line", "plot 52-58 ke darmiyan")`.trim();
}