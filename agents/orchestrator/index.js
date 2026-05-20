import { randomUUID } from 'crypto';
import { parseMessage, saveListing, saveDemand } from '../agents/gatekeeper/index.js';
import { checkDuplicates } from '../agents/negotiator/index.js';
import { findAndNotifyMatches, matchDemandToListings } from '../agents/matchmaker/index.js';
import supabase from '../services/supabaseClient.js';
import { logStep } from '../services/logger.js';
import { callGemini } from '../services/geminiClient.js';

// ── Config Constants ────────────────────────────────────
const HOT_PROPERTY_THRESHOLD = 0.90;      // flag if price < 90% of block avg
const MIN_LISTINGS_FOR_HOT_CHECK = 3;     // need at least 3 listings to compare

export async function handleMessage(rawText, senderAgentId, source = 'whatsapp') {
    const sessionId = randomUUID();

    console.log(`\n${'='.repeat(55)}`);
    console.log(`[🚀 Orchestrator] Agent: ${senderAgentId} | Source: ${source}`);
    console.log(`[🚀 Orchestrator] Flow: Parse → Validate → Save → Match`);
    console.log('='.repeat(55));

    logStep(sessionId, 'Orchestrator', 'start', 'running', rawText, '');

    try {
        // Ensure agent exists in database to prevent foreign key constraint violations
        const { error: agentError } = await supabase
            .from('agents')
            .upsert({
                id: senderAgentId,
                name: `WhatsApp Broker (${senderAgentId})`,
                agency_name: 'WhatsApp Integration',
                is_verified: true
            }, { onConflict: 'id' });
            
        if (agentError) {
            console.warn(`[🚀 Orchestrator] Warning: Could not auto-register agent ${senderAgentId}:`, agentError.message);
        }

        // ── Agent 1: Gatekeeper — Parse ───────────────────
        logStep(sessionId, 'Gatekeeper', 'parsing', 'running', rawText, '');
        const { parsed, preview_message, maps_link } = await parseMessage(rawText, senderAgentId);
        logStep(sessionId, 'Gatekeeper', 'parsed', 'done',
            rawText,
            `Intent: ${parsed.intent} | Block: ${parsed.block_id} | Size: ${parsed.size}gz`
        );

        // ── MARKET QUERY FLOW ──────────────────────────────
        if (parsed.intent === 'market_query') {
            logStep(sessionId, 'Recommender', 'market_analysis', 'running', 
                `Block: ${parsed.block_id}`, ''
            );

            // Fetch dynamic block stats to find out about demand ratio and supply
            const { data: stats } = await supabase
                .from('block_market_stats')
                .select('*')
                .eq('block_id', parsed.block_id)
                .maybeSingle();

            // Also query recent listings in that block to get actual pricing ranges
            const { data: recentListings } = await supabase
                .from('listings')
                .select('size, unit, demand_price')
                .eq('block_id', parsed.block_id)
                .eq('status', 'active')
                .eq('is_public', true)
                .order('created_at', { ascending: false })
                .limit(5);

            // Use Recommender AI to generate an Urdu/English response detailing block market
            const marketData = {
                block_id: parsed.block_id,
                stats: stats || { supply: 0, demand: 0, demand_ratio: 0 },
                recent_listings: recentListings || []
            };

            const RECOMMENDER_CHAT_PROMPT = `You are a Pakistan Karachi real estate expert advisor.
The broker has sent a market query asking for details about "${parsed.block_id}".
Based on this raw data: ${JSON.stringify(marketData)}, generate a highly helpful response in Roman Urdu mixed with English (the way Pakistani brokers talk).
State the current supply/demand activity, average pricing if recent listings are available, and give some trading advice (e.g. "DHA Phase 6 ki market kafi tight hai, demand ratio 1.8 hai. Seller is time demand achi le sakte hain.").
Be brief (max 3-4 sentences).`;

            const aiResponseText = await callGemini(
                RECOMMENDER_CHAT_PROMPT,
                `Provide advice for broker based on: ${JSON.stringify(marketData)}`,
                1024
            );

            logStep(sessionId, 'Recommender', 'market_analysis', 'done', '', aiResponseText);
            logStep(sessionId, 'Orchestrator', 'complete', 'done', '', 'Market analysis returned');

            return {
                status: 'market_query_result',
                block_id: parsed.block_id,
                stats: stats || { supply: 0, demand: 0, demand_ratio: 0 },
                advice: aiResponseText,
                session_id: sessionId
            };
        }

        // ── SUPPLY FLOW ────────────────────────────────────
        if (parsed.intent === 'supply') {

            // App se aaya — seedha save karo, confirm nahi chahiye
            if (source === 'app') {
                logStep(sessionId, 'Negotiator', 'duplicate_check', 'running',
                    `Block: ${parsed.block_id}, Size: ${parsed.size}, Price: ${parsed.demand_price}`, ''
                );
                const dupCheck = await checkDuplicates(parsed, senderAgentId);
                if (dupCheck.isDuplicate) {
                    logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'Conflict found');
                    return {
                        status: 'conflict',
                        conflict_message: dupCheck.conflictMessage,
                        parsed,
                        session_id: sessionId,
                    };
                }
                logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'No conflicts — clear');

                logStep(sessionId, 'Gatekeeper', 'saving_listing', 'running', '', '');
                const savedListing = await saveListing(parsed, senderAgentId);
                logStep(sessionId, 'Gatekeeper', 'saving_listing', 'done', '', `ID: ${savedListing.id}`);

                await checkAndFlagHotProperty(savedListing);

                if (parsed.is_public) {
                    logStep(sessionId, 'Matchmaker', 'scanning_requests', 'running', '', '');
                    findAndNotifyMatches(savedListing)
                        .then(matches =>
                            logStep(sessionId, 'Matchmaker', 'scanning_requests', 'done', '',
                                `${matches.length} match(es) notified`
                            )
                        )
                        .catch(err => console.error('[Matchmaker] Error:', err.message));
                }

                logStep(sessionId, 'Orchestrator', 'complete', 'done', '', `Listing saved: ${savedListing.id}`);
                return {
                    status: 'listing_saved',
                    listing: savedListing,
                    preview: preview_message,
                    maps_link,
                    session_id: sessionId,
                    ambiguities: parsed.ambiguities || [],
                };
            }

            // WhatsApp se aaya — pehle duplicate check, phir confirm maango
            if (parsed.is_public) {
                logStep(sessionId, 'Negotiator', 'duplicate_check', 'running',
                    `Block: ${parsed.block_id}, Size: ${parsed.size}, Price: ${parsed.demand_price}`, ''
                );
                const dupCheck = await checkDuplicates(parsed, senderAgentId);
                if (dupCheck.isDuplicate) {
                    logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'Conflict found');
                    return {
                        status: 'conflict',
                        conflict_message: dupCheck.conflictMessage,
                        parsed,
                        session_id: sessionId,
                    };
                }
                logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'No conflicts — clear');
            }

            logStep(sessionId, 'Orchestrator', 'awaiting_confirm', 'running', '', 'Preview sent to broker');
            return {
                status: 'awaiting_confirm',
                parsed,
                preview: preview_message,
                maps_link,
                session_id: sessionId,
                ambiguities: parsed.ambiguities || [],
            };
        }

        // ── DEMAND FLOW ────────────────────────────────────
        if (parsed.intent === 'demand') {

            logStep(sessionId, 'Gatekeeper', 'saving_demand', 'running', '', '');
            const savedDemand = await saveDemand(parsed, senderAgentId);
            logStep(sessionId, 'Gatekeeper', 'saving_demand', 'done', '', `ID: ${savedDemand.id}`);

            logStep(sessionId, 'Matchmaker', 'immediate_match', 'running',
                `Block: ${parsed.block_id}, Budget: ${parsed.max_budget}`, ''
            );
            const immediateMatches = await matchDemandToListings(parsed, senderAgentId);
            logStep(sessionId, 'Matchmaker', 'immediate_match', 'done',
                '', `${immediateMatches.length} match(es) found`
            );

            logStep(sessionId, 'Orchestrator', 'complete', 'done', '',
                `Demand saved, ${immediateMatches.length} matches`
            );
            return {
                status: 'demand_saved',
                demand: savedDemand,
                immediate_matches: immediateMatches,
                match_count: immediateMatches.length,
                preview: preview_message,
                session_id: sessionId,
                ambiguities: parsed.ambiguities || [],
            };
        }

        // ── UNKNOWN INTENT ─────────────────────────────────
        logStep(sessionId, 'Orchestrator', 'unknown_intent', 'done', '', 'Intent unclear');
        return {
            status: 'unknown_intent',
            message: 'Could not detect intent. Please rephrase with block, size, and price.',
            session_id: sessionId,
        };

    } catch (err) {
        console.error('[🚀 Orchestrator] Error:', err.message);
        logStep(sessionId, 'Orchestrator', 'error', 'error', '', err.message);

        const code = err.message.includes('Vertex AI') ? 'AI_TIMEOUT'
            : err.message.includes('JSON parse') ? 'PARSE_ERROR'
            : 'DB_ERROR';

        return {
            status: code === 'AI_TIMEOUT' ? 'ai_unavailable' : 'error',
            code,
            message: err.message,
            session_id: sessionId,
        };
    }
}

// ── Confirm & Save (WA confirm ke baad) ────────────────
export async function confirmAndSave(parsedData, senderAgentId, sessionId) {
    // Ensure agent exists
    await supabase.from('agents').upsert({
        id: senderAgentId,
        name: `WhatsApp Broker (${senderAgentId})`,
        agency_name: 'WhatsApp Integration',
        is_verified: true
    }, { onConflict: 'id' });

    if (parsedData.is_public) {
        logStep(sessionId, 'Negotiator', 'duplicate_check', 'running',
            `Block: ${parsedData.block_id}, Size: ${parsedData.size}, Price: ${parsedData.demand_price}`, ''
        );
        const dupCheck = await checkDuplicates(parsedData, senderAgentId);
        if (dupCheck.isDuplicate) {
            logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'Conflict found');
            return {
                status: 'conflict',
                message: dupCheck.conflictMessage,
                session_id: sessionId,
            };
        }
        logStep(sessionId, 'Negotiator', 'duplicate_check', 'done', '', 'No conflicts — clear');
    }

    logStep(sessionId, 'Gatekeeper', 'saving_listing', 'running', '', '');
    const savedListing = await saveListing(parsedData, senderAgentId);
    logStep(sessionId, 'Gatekeeper', 'saving_listing', 'done', '', `ID: ${savedListing.id}`);

    await checkAndFlagHotProperty(savedListing);

    let matchesCount = 0;
    if (parsedData.is_public) {
        logStep(sessionId, 'Matchmaker', 'scanning_requests', 'running', '', '');
        try {
            const matches = await findAndNotifyMatches(savedListing);
            matchesCount = matches.length;
            logStep(sessionId, 'Matchmaker', 'scanning_requests', 'done', '', `${matchesCount} match(es) notified`);
        } catch (err) {
            console.error('[Matchmaker] Error:', err.message);
        }
    }

    logStep(sessionId, 'Orchestrator', 'complete', 'done', '', `Listing saved: ${savedListing.id}`);
    return {
        ...savedListing,
        matches_count: matchesCount
    };
}

// ── Hot Property Calculator ─────────────────────────────
async function checkAndFlagHotProperty(listing) {
    try {
        const { data } = await supabase
            .from('listings')
            .select('demand_price')
            .eq('block_id', listing.block_id)
            .eq('is_public', true)
            .eq('status', 'active');

        if (!data || data.length < MIN_LISTINGS_FOR_HOT_CHECK) return;

        const avg = data.reduce((sum, l) => sum + l.demand_price, 0) / data.length;
        if (listing.demand_price < avg * HOT_PROPERTY_THRESHOLD) {
            await supabase
                .from('listings')
                .update({ is_hot_property: true })
                .eq('id', listing.id);
            console.log(`[🔥 Orchestrator] Hot property flagged: ${listing.id}`);
        }
    } catch (err) {
        // Non-critical — log but never crash the main flow
        console.error(`[🔥 Orchestrator] Hot property check failed: ${err.message}`);
    }
}