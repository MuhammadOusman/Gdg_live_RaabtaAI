import supabase from '../../services/supabaseClient.js';

const PRICE_OVERLAP = 0.05;

export async function checkDuplicates(parsedData, ownerAgentId) {
    const { block_id, size, demand_price, is_public } = parsedData;

    // Private listings duplicate check nahi hoti
    if (!is_public) {
        console.log(`[⚖️ Negotiator] Private listing — skipping duplicate check`);
        return { isDuplicate: false, conflicts: [] };
    }

    console.log(`[⚖️ Negotiator] Checking duplicates for ${block_id}, ${size}gz, PKR ${demand_price}`);

    const { data: existing, error } = await supabase
        .from('listings')
        .select('id, block_id, size, demand_price, sub_location_raw, owner_agent_id')
        .eq('block_id', block_id)
        .eq('size', size)
        .eq('is_public', true)
        .eq('status', 'active')
        .neq('owner_agent_id', ownerAgentId);

    if (error) throw new Error(`Negotiator: Duplicate check failed — ${error.message}`);

    const conflicts = (existing || []).filter(item => {
        const diff = Math.abs(item.demand_price - demand_price) / demand_price;
        return diff <= PRICE_OVERLAP;
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
    return `
⚠️ Duplicate Alert — Raabta AI

Ek aur agent ne similar property list ki hui hai:
📍 Block: ${newListing.block_id}
📐 Size: ${newListing.size} ${newListing.unit}
💰 Similar price: PKR ${conflicts[0].demand_price?.toLocaleString('en-PK')}

Duplicate avoid karne ke liye batao:
Tumhara plot kis line/range mein hai?
(Example: "50 ki line", "plot 52-58 ke darmiyan")
  `.trim();
}