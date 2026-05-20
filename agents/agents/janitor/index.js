import supabase from '../../services/supabaseClient.js';

export async function runDailyReview() {
    console.log('[🧹 Janitor] Daily review started —', new Date().toISOString());

    const { data: listings, error } = await supabase
        .from('listings')
        .select('id, owner_agent_id, block_id, size, demand_price, updated_at')
        .eq('status', 'active');

    if (error) {
        console.error('[🧹 Janitor] Fetch error:', error.message);
        return;
    }

    if (!listings || listings.length === 0) {
        console.log('[🧹 Janitor] No active listings found for daily review');
        return;
    }

    const perListingNotifs = [];

    for (const l of listings) {
        const lastUpdatedMs = l.updated_at ? new Date(l.updated_at).getTime() : Date.now();
        const days = Math.floor((Date.now() - lastUpdatedMs) / (24 * 60 * 60 * 1000));
        const daysText = days === 0 ? 'aaj hi update kiya' : `${days} din pehle update kiya`;
        
        const priceText = l.demand_price ? `PKR ${l.demand_price.toLocaleString('en-PK')}` : 'Price not set';
        
        perListingNotifs.push({
            agent_id: l.owner_agent_id,
            listing_id: l.id,
            message: `📋 Daily Review: ${l.size}gz plot in ${l.block_id} — ${priceText} (${daysText}). Kya details bilkul correct hain?`,
            type: 'review'
        });
    }

    if (perListingNotifs.length > 0) {
        const { error: insertErr } = await supabase
            .from('notifications')
            .insert(perListingNotifs);

        if (insertErr) {
            console.error('[🧹 Janitor] Batch insert failed:', insertErr.message);
        } else {
            console.log(`[🧹 Janitor] Sent ${perListingNotifs.length} detailed daily review notification(s)`);
        }
    }
}

export async function autoArchiveStale() {
    const cutoff = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
    console.log('[🧹 Janitor] Auto-archiving listings stale since', cutoff);

    const { data, error } = await supabase
        .from('listings')
        .update({ status: 'archived' })
        .eq('status', 'active')
        .lt('updated_at', cutoff)
        .select('id, owner_agent_id');

    if (error) {
        console.error('[🧹 Janitor] Archive error:', error.message);
        return [];
    }

    console.log(`[🧹 Janitor] Archived ${data?.length || 0} stale listing(s)`);

    // Notify each affected agent
    for (const l of (data || [])) {
        await supabase.from('notifications').insert([{
            agent_id: l.owner_agent_id,
            listing_id: l.id,
            message: '⚠️ Tumhari ek listing archive ho gayi — 48 ghante se koi update nahi. App mein check karo.',
        }]);
    }

    return data || [];
}

// refreshBlockStats diagnostics: We now call the RPC to refresh the Materialized View
// to guarantee O(1) reads without blocking the database.
export async function refreshBlockStats() {
    console.log('[🧹 Janitor] Refreshing Materialized View block_market_stats via RPC...');

    try {
        // Trigger the materialized view refresh concurrently
        const { error: rpcError } = await supabase.rpc('refresh_block_market_stats');
        if (rpcError) {
            console.warn('[🧹 Janitor] RPC refresh failed (might not be created yet), falling back to standard read:', rpcError.message);
        }

        const { data, error } = await supabase
            .from('block_market_stats')
            .select('*');

        if (error) throw error;

        console.log(`[🧹 Janitor] block_market_stats check: ${data?.length || 0} block(s) fetched`);
        return data || [];

    } catch (err) {
        console.error('[🧹 Janitor] View check failed:', err.message);
        throw err;
    }
}

// Follow-up note attach karo kisi listing pe
export async function attachNote(listingId, noteText, agentId) {
    console.log(`[🧹 Janitor] Attaching note to listing ${listingId}`);

    const { data, error } = await supabase
        .from('listings')
        .select('notes, owner_agent_id')
        .eq('id', listingId)
        .single();

    if (error || !data) {
        console.error('[🧹 Janitor] Listing not found:', error?.message);
        return false;
    }

    if (data.owner_agent_id !== agentId) {
        console.error('[🧹 Janitor] Permission denied — agent does not own this listing');
        return false;
    }

    const existing = Array.isArray(data.notes) ? data.notes : [];
    const updated = [...existing, { timestamp: new Date().toISOString(), content: noteText }];

    const { error: updateErr } = await supabase
        .from('listings')
        .update({ notes: updated })
        .eq('id', listingId);

    if (updateErr) {
        console.error('[🧹 Janitor] Note update failed:', updateErr.message);
        return false;
    }

    console.log('[🧹 Janitor] Note attached ✅');
    return true;
}