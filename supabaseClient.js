import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL || 'https://placeholder.supabase.co'
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'placeholder-key'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Example Tool: Trigger Supabase Notification
export async function trigger_supabase_notification(agentId, message, payload) {
  console.log(`[Tool Call: trigger_supabase_notification] Agent: ${agentId}`);
  const { data, error } = await supabase
    .from('notifications')
    .insert([
      { agent_id: agentId, message: message, payload: payload }
    ])
  
  if (error) {
    console.error('Error triggering notification:', error);
    return false;
  }
  return true;
}

// Example Tool: Save Listing
export async function save_listing(listingData, isPublic = true) {
  console.log(`[Tool Call: save_listing] Type: ${isPublic ? 'Public' : 'Private'}`);
  const { data, error } = await supabase
    .from('listings')
    .insert([
      { ...listingData, is_public: isPublic }
    ])

  if (error) throw error;
  return data;
}
