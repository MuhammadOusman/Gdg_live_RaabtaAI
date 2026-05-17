import { parseMessage, saveListing, saveDemand } from '../agents/gatekeeper/index.js';
import { checkDuplicates } from '../agents/negotiator/index.js';
import { findAndNotifyMatches, matchDemandToListings } from '../agents/matchmaker/index.js';
import supabase from '../services/supabaseClient.js';
import { logStep } from '../services/logger.js';

export async function handleMessage(rawText, senderAgentId, source = 'whatsapp') {
    const sessionId = `session_${Date.now()}`;

    console.log(`\n${'='.repeat(55)}`);
    console.log(`[🚀 Orchestrator] Agent: ${senderAgentId}`);
    console.log(`[🚀 Orchestrator] Flow: Parse → Validate → Save → Match`);
    console.log('='.repeat(55));

    await logStep(sessionId, 'Orchestrator', 'start', 'running', rawText, '');

    // ── Agent 1: Gatekeeper — Parse ───────────────────
    await logStep(sessionId, 'Gatekeeper', 'parsing', 'running', rawText, '');
    const { parsed, preview_message, maps_link } = await parseMessage(rawText, senderAgentId);
    await logStep(sessionId, 'Gatekeeper', 'parsed', 'done',
        rawText,
        `Intent: ${parsed.intent} | Block: ${parsed.block_id} | Size: ${parsed.size}gz`
    );

    // ── SUPPLY FLOW ────────────────────────────────────
    if (parsed.intent === 'supply') {

        if (source === 'app') {
            const savedListing = await saveListing(parsed, senderAgentId);
            return { status: 'listing_saved', listing: savedListing };
        }
        // WA se aaya toh confirm maango
        return { status: 'awaiting_confirm', parsed, preview: preview_message };
    }

    // Agent 2: Negotiator — Duplicate check (only public)
    if (parsed.is_public) {
        await logStep(sessionId, 'Negotiator', 'duplicate_check', 'running',
            `Block: ${parsed.block_id}, Size: ${parsed.size}, Price: ${parsed.demand_price}`, ''
        );

        const dupCheck = await checkDuplicates(parsed, senderAgentId);

        if (dupCheck.isDuplicate) {
            await logStep(sessionId, 'Negotiator', 'duplicate_check', 'done',
                '', `Conflict found — asking for line/range`
            );
            return {
                status: 'conflict',
                conflict_message: dupCheck.conflictMessage,
                parsed,
                session_id: sessionId,
            };
        }

        await logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'No conflicts — clear');
    }

    // Human-in-loop: pehle confirm lo, phir save
    await logStep(sessionId, 'Orchestrator', 'awaiting_confirm', 'running', '', 'Preview sent to broker');
    return {
        status: 'awaiting_confirm',
        parsed,
        preview: preview_message,
        maps_link,
        session_id: sessionId,
    };
}

// ── DEMAND FLOW ────────────────────────────────────
if (parsed.intent === 'demand') {

    await logStep(sessionId, 'Gatekeeper', 'saving_demand', 'running', '', '');
    const savedDemand = await saveDemand(parsed, senderAgentId);
    await logStep(sessionId, 'Gatekeeper', 'saving_demand', 'done', '', `ID: ${savedDemand.id}`);

    await logStep(sessionId, 'Matchmaker', 'immediate_match', 'running',
        `Block: ${parsed.block_id}, Budget: ${parsed.max_budget}`, ''
    );
    const immediateMatches = await matchDemandToListings(parsed, senderAgentId);
    await logStep(sessionId, 'Matchmaker', 'immediate_match', 'done',
        '', `${immediateMatches.length} match(es) found`
    );

    await logStep(sessionId, 'Orchestrator', 'complete', 'done', '',
        `Demand saved, ${immediateMatches.length} matches`
    );

    return {
        status: 'demand_saved',
        demand: savedDemand,
        immediate_matches: immediateMatches,
        match_count: immediateMatches.length,
        preview: preview_message,
        session_id: sessionId,
    };
}

return { status: 'unknown_intent', parsed };


// Backend/WA bot ye call karega jab broker CONFIRM kare
export async function confirmAndSave(parsedData, senderAgentId, sessionId) {
    await logStep(sessionId, 'Gatekeeper', 'saving_listing', 'running', '', '');
    const savedListing = await saveListing(parsedData, senderAgentId);
    await logStep(sessionId, 'Gatekeeper', 'saving_listing', 'done', '', `ID: ${savedListing.id}`);

    await checkAndFlagHotProperty(savedListing);

    if (parsedData.is_public) {
        await logStep(sessionId, 'Matchmaker', 'scanning_requests', 'running', '', '');
        findAndNotifyMatches(savedListing)
            .then(matches =>
                logStep(sessionId, 'Matchmaker', 'scanning_requests', 'done', '',
                    `${matches.length} match(es) notified`
                )
            )
            .catch(err => console.error('[Matchmaker] Error:', err.message));
    }

    await logStep(sessionId, 'Orchestrator', 'complete', 'done', '', `Listing saved: ${savedListing.id}`);
    return savedListing;
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