import { parseBrokerMessage } from './parserAgent.js';
import { checkDuplicates } from './negotiatorAgent.js';
import { findAndNotifyMatches } from './matchmakerAgent.js';
import { supabase } from './supabaseClient.js';

export async function handleMessage(rawText, senderId) {
  console.log(`[Workplan]: Ingesting -> Parsing -> Matching -> Notifying`);
  
  try {
    const parsedData = await parseBrokerMessage(rawText);
    
    if (parsedData.intent === 'supply') {
      const { isDuplicate, conflictID } = await checkDuplicates(parsedData);
      
      if (!isDuplicate) {
        const { error } = await supabase.from('listings').insert({
          block_id: parsedData.block_id,
          size: parsedData.size,
          demand_price: parsedData.price,
          is_public: parsedData.is_public,
          features: parsedData.features,
          notes: parsedData.notes,
          owner_agent_id: senderId
        });
        
        if (error) {
          console.error("Error saving listing:", error);
        } else {
          console.log("Listing saved successfully.");
        }
      }
    } else if (parsedData.intent === 'demand') {
      await findAndNotifyMatches(parsedData, senderId);
    }
  } catch (error) {
    console.error("Error in orchestrator:", error);
  }
}
