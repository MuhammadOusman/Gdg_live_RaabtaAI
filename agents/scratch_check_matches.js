import 'dotenv/config';
import supabase from './services/supabaseClient.js';

async function check() {
  const { data: requests } = await supabase.from('requests').select('*');
  console.log('Total Requests:', requests?.length);
  
  const matching = requests?.filter(r => {
    return r.target_blocks.includes('DHA Phase 6') && r.status === 'searching';
  });
  
  console.log('Matching Requests for DHA Phase 6:', matching);
}
check();
