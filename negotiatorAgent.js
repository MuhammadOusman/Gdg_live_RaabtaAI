import { supabase } from './supabaseClient.js';

export async function checkDuplicates(parsedData) {
  const { block_id, size, price } = parsedData;
  const margin = price * 0.05;
  const lowerBound = price - margin;
  const upperBound = price + margin;

  const { data, error } = await supabase
    .from('listings')
    .select('id, demand_price')
    .eq('block_id', block_id)
    .eq('size', size)
    .gte('demand_price', lowerBound)
    .lte('demand_price', upperBound);

  if (error) {
    console.error("Error querying duplicates:", error);
    return { isDuplicate: false, conflictID: null };
  }

  if (data && data.length > 0) {
    const conflictID = data[0].id;
    console.log(`[Reasoning Trace]: Conflict detected with Listing ID ${conflictID}. Reasoning: Highly similar price and location. Suggesting user verify the plot line.`);
    return { isDuplicate: true, conflictID };
  }

  return { isDuplicate: false, conflictID: null };
}
