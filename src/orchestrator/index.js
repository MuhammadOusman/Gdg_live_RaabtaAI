import { parseMessage, saveListing, saveDemand } from '../agents/gatekeeper/index.js';
import { checkDuplicates } from '../agents/negotiator/index.js';
import { findAndNotifyMatches, matchDemandToListings } from '../agents/matchmaker/index.js';
import supabase from '../services/supabaseClient.js';

export async function handleMessage(rawText, senderAgentId) {
    console.log(`\n${'='.repeat(55)}`);
    console.log(`[🚀 Orchestrator] Agent: ${senderAgentId}`);
    console.log(`[🚀 Orchestrator] Flow: Parse → Validate → Save → Match`);
    console.log('='.repeat(55));

    // ── Agent 1: Parse ─────────────────────────────────
    const { parsed, preview_message, maps_link } = await parseMessage(rawText, senderAgentId);

    // ── SUPPLY FLOW ────────────────────────────────────
    if (parsed.intent === 'supply') {

        // Agent 2: Duplicate check (only for public listings)
        const dupCheck = await checkDuplicates(parsed, senderAgentId);
        if (dupCheck.isDuplicate) {
            return {
                status: 'conflict',
                conflict_message: dupCheck.conflictMessage,
                parsed,
            };
        }

        // Agent 1: Save listing
        const savedListing = await saveListing(parsed, senderAgentId);

        // Hot property check
        await checkAndFlagHotProperty(savedListing);

        // Agent 3: Background match (non-blocking)
        if (parsed.is_public) {
            findAndNotifyMatches(savedListing)
                .catch(err => console.error('[Orchestrator] Matchmaker error:', err.message));
        }

        return {
            status: 'listing_saved',
            listing: savedListing,
            preview: preview_message,
            maps_link,
        };
    }

    // ── DEMAND FLOW ────────────────────────────────────
    if (parsed.intent === 'demand') {

        // Save demand
        const savedDemand = await saveDemand(parsed, senderAgentId);

        // Agent 3: Immediate match
        const immediateMatches = await matchDemandToListings(parsed, senderAgentId);

        return {
            status: 'demand_saved',
            demand: savedDemand,
            immediate_matches: immediateMatches,
            match_count: immediateMatches.length,
            preview: preview_message,
        };
    }

    return { status: 'unknown_intent', parsed };
}

async function checkAndFlagHotProperty(listing) {
    const { data } = await supabase
        .from('listings')
        .select('demand_price')
        .eq('block_id', listing.block_id)
        .eq('is_public', true)
        .eq('status', 'active');

    if (!data || data.length < 3) return;

    const avg = data.reduce((sum, l) => sum + l.demand_price, 0) / data.length;
    if (listing.demand_price < avg * 0.90) {
        await supabase.from('listings').update({ is_hot_property: true }).eq('id', listing.id);
        console.log(`[🔥 Orchestrator] Hot property flagged: ${listing.id}`);
    }
}