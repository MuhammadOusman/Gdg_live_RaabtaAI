// Initial Task Execution Plan for a "Demand" request
// This simulates the Orchestrator logic.

import { trigger_supabase_notification } from './supabaseClient.js';

export async function executeDemandWorkflow(demandData) {
  console.log("=== ORCHESTRATOR WORKPLAN STARTED ===");
  console.log("Plan: [Parse] -> [Match] -> [Notify] -> [Log Trace]\n");

  // Step 1: GATEKEEPER PARSING (Simulation)
  console.log("--- AGENT 1: THE GATEKEEPER ---");
  console.log(`[Internal Monologue]: Received raw demand string: "${demandData.rawText}". I need to extract budget, size, and location.`);
  const parsedDemand = {
    intent: 'demand',
    budget: 40000000, // 4cr
    targetBlock: 'Block C',
    size: 400 // 400gz
  };
  console.log(`[Tool Call: llm_extraction] -> Parsed Result:`, parsedDemand);

  // Step 2: MATCHMAKER (Simulation)
  console.log("\n--- AGENT 3: THE MATCHMAKER ---");
  const flexBudget = parsedDemand.budget * 1.15; // 15% flex
  console.log(`[Internal Monologue]: The buyer wants a property in ${parsedDemand.targetBlock} for ${parsedDemand.budget}. I am applying a 15% budget flex up to ${flexBudget}. I will now search the database.`);
  
  // Simulated vector search
  console.log(`[Tool Call: vector_search_listings] Querying for Block: ${parsedDemand.targetBlock}, Max Price: ${flexBudget}`);
  const matchedListings = [
    { id: 101, price: 42000000, block: 'Block C', agent_id: 'agent_xyz' }
  ];

  // Step 3 & 4: Notifications & Reasoning Trace
  console.log("\n--- NOTIFICATIONS & TRACE ---");
  for (const match of matchedListings) {
     const trace = `Matched Listing ${match.id} because price (${match.price}) is within the 15% flex range (up to ${flexBudget}) and features match the target block ${match.block}.`;
     console.log(`[Reasoning Trace]: ${trace}`);
     
     // Note: In real life this would run and connect to Supabase
     // await trigger_supabase_notification(match.agent_id, 'New Buyer Match Found!', {
     //   demand: parsedDemand,
     //   matched_listing_id: match.id,
     //   trace: trace
     // });
  }
  
  console.log("\n=== ORCHESTRATOR WORKPLAN COMPLETED ===");
}

executeDemandWorkflow({ rawText: "I need a 400gz plot in Block C around 4cr" });
