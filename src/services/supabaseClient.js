import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

const supabaseUrl = process.env.SUPABASE_URL || 'https://placeholder.supabase.co'
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'placeholder-key'

const supabase = createClient(supabaseUrl, supabaseAnonKey);

export default supabase;