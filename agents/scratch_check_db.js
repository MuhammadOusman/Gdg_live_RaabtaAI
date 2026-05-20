import 'dotenv/config';
import supabase from './services/supabaseClient.js';

async function check() {
  const { data: requests } = await supabase.from('requests').select('*');
  console.log('--- Active Requests ---');
  console.log(requests);

  const { data: listings } = await supabase.from('listings').select('*');
  console.log('--- Active Listings ---');
  console.log(listings);
}
check();
