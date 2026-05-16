import { supabase } from './supabaseClient.js';

export async function findAndNotifyMatches(parsedData, senderId) {
  const { block_id, size, price } = parsedData;
  const flexPrice = Math.floor(price * 1.15); // 15% budget flex

  const { data, error } = await supabase
    .from('listings')
    .select('id')
    .eq('is_public', true)
    .eq('block_id', block_id)
    .eq('size', size)
    .lte('demand_price', flexPrice)
    .neq('owner_agent_id', senderId);

  if (error) {
    console.error("Error matching:", error);
    return;
  }

  console.log(`[Reasoning Trace]: Applied 15% budget flex. Found ${data ? data.length : 0} matches. Excluded self-listing.`);

  if (data && data.length > 0) {
    // Insert into notifications
    const notifications = data.map(match => ({
      agent_id: senderId,
      listing_id: match.id,
      message: `Match found for your demand in block ${block_id} (Size: ${size}).`
    }));

    const { error: insertError } = await supabase
      .from('notifications')
      .insert(notifications);

    if (insertError) {
      console.error("Error inserting notifications:", insertError);
    }
  }
}
