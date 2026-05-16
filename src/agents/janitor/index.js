import supabase from '../../services/supabaseClient.js';

export async function runDailyReview() {
    console.log('[🧹 Janitor] Daily review started —', new Date().toISOString());

    const { data: listings, error } = await supabase
        .from('listings')
        .select('id, owner_agent_id, block_id, size, demand_price')
        .eq('status', 'active');

    if (error) {
        console.error('[🧹 Janitor] Fetch error:', error.message);
        return;
    }

    // Group by agent
    const byAgent = {};
    for (const l of (listings || [])) {
        if (!byAgent[l.owner_agent_id]) byAgent[l.owner_agent_id] = [];
        byAgent[l.owner_agent_id].push(l);
    }

    for (const [agentId, agentListings] of Object.entries(byAgent)) {
        console.log(`[🧹 Janitor] Agent ${agentId} — ${agentListings.length} listing(s) to review`);
        await supabase.from('notifications').insert([{
            agent_id: agentId,
            listing_id: null,
            message: `📋 Daily Review: Tumhari ${agentListings.length} active listing(s) hain. App mein review karo.`,
        }]);
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
        return;
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