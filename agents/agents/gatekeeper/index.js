import { callGemini } from '../../services/geminiClient.js';
import supabase from '../../services/supabaseClient.js';
import { GATEKEEPER_PROMPT } from './prompt.js';

export async function parseMessage(rawMessage, ownerAgentId) {
    console.log(`[🔍 Gatekeeper] Parsing: "${rawMessage}"`);
    console.log(`[🔍 Gatekeeper] Stripping broker noise, normalizing slang...`);

    const responseText = await callGemini(GATEKEEPER_PROMPT, rawMessage);

    let parsed;
    try {
        parsed = JSON.parse(responseText);
    } catch (err) {
        console.warn('[🔍 Gatekeeper] JSON parse failed — retrying with explicit instruction...');
        const retryText = await callGemini(
            GATEKEEPER_PROMPT,
            `${rawMessage}\n\n[SYSTEM: Return ONLY a valid JSON object. No explanation, no markdown, no backticks.]`
        );
        try {
            parsed = JSON.parse(retryText);
        } catch (retryErr) {
            throw new Error(`Gatekeeper: JSON parse failed after retry — ${retryText.slice(0, 120)}`);
        }
    }

    console.log(`[🔍 Gatekeeper] Intent: ${parsed.intent} | Block: ${parsed.block_id} | Confidence: ${parsed.confidence}`);
    if (parsed.ambiguities?.length > 0) {
        console.log(`[🔍 Gatekeeper] Ambiguities: ${parsed.ambiguities.join(', ')}`);
    }

    const mapsQuery = encodeURIComponent(`${parsed.block_id}, Karachi, Pakistan`);
    const mapsLink = `https://www.google.com/maps/search/?api=1&query=${mapsQuery}`;

    return {
        parsed,
        owner_agent_id: ownerAgentId,
        maps_link: mapsLink,
        preview_message: buildPreviewMessage(parsed, mapsLink),
    };
}


export async function saveListing(parsedData, ownerAgentId) {

    if (!parsedData.demand_price && parsedData.price) {
        parsedData.demand_price = parsedData.price
    }

    const payload = {
        owner_agent_id: ownerAgentId,
        block_id: parsedData.block_id,
        sub_location_raw: parsedData.sub_location_raw || null,
        size: parsedData.size,
        unit: parsedData.unit || 'gaz',
        features: parsedData.features || [],
        demand_price: parsedData.demand_price,
        is_public: parsedData.is_public ?? false,
        status: 'active',
        is_hot_property: false,
        notes: parsedData.notes
            ? [{ timestamp: new Date().toISOString(), content: parsedData.notes }]
            : [],
    };

    const { data, error } = await supabase
        .from('listings')
        .insert([payload])
        .select()
        .single();

    if (error) throw new Error(`Gatekeeper: Save listing failed — ${error.message}`);
    console.log(`[🔍 Gatekeeper] Listing saved: ${data.id}`);
    return data;
}

export async function saveDemand(parsedData, buyerAgentId) {
    const { data, error } = await supabase
        .from('requests')
        .insert([{
            buyer_agent_id: buyerAgentId,
            target_blocks: [parsedData.block_id],
            target_size: parsedData.size,
            unit: parsedData.unit || 'gaz',
            target_features: parsedData.features || [],
            max_budget: parsedData.max_budget,
            status: 'searching',
        }])
        .select()
        .single();

    if (error) throw new Error(`Gatekeeper: Save demand failed — ${error.message}`);
    console.log(`[🔍 Gatekeeper] Demand saved: ${data.id}`);
    return data;
}

function buildPreviewMessage(parsed, mapsLink) {
    if (parsed.intent === 'supply') {
        return `
✅ Raabta AI — Listing Preview
📍 Block: ${parsed.block_id}
📌 Sub-location: ${parsed.sub_location_raw || 'Not specified'}
📐 Size: ${parsed.size} ${parsed.unit}
💰 Price: PKR ${parsed.demand_price?.toLocaleString('en-PK')}
🏷️ Features: ${parsed.features?.join(', ') || 'None'}
🔒 Visibility: ${parsed.is_public ? '🌐 Public' : '🔒 Private (Vault)'}
📊 Confidence: ${Math.round((parsed.confidence || 0) * 100)}%
🗺️ Location: ${mapsLink}
    `.trim();
    }
    return `
🔍 Raabta AI — Demand Preview
📍 Looking in: ${parsed.block_id}
📐 Size: ${parsed.size} ${parsed.unit}
💰 Max Budget: PKR ${parsed.max_budget?.toLocaleString('en-PK')}
🏷️ Features: ${parsed.features?.join(', ') || 'Any'}
  `.trim();
}