import 'dotenv/config';
import { handleMessage } from '../orchestrator/index.js';
import { runDailyReview } from '../agents/janitor/index.js';
import { generateRecommendations } from '../agents/recommender/index.js';
import supabase from '../services/supabaseClient.js';

async function run() {

    console.log('\n🧪 TEST 1: Private supply listing');
    const t1 = await handleMessage(
        "N. Naz Block N mein 400gz plot hai, 50 ki line, demand 4.2cr. Private rakho. Party tight hai yaar.",
        '03001234567'
    );
    console.log('Status:', t1.status);

    console.log('\n🧪 TEST 2: Public supply — conflict check');
    const t2 = await handleMessage(
        "Block N mein 400gz corner plot, 50 ki line, demand 3.85cr. Public karo.",
        '03009876543'
    );
    console.log('Status:', t2.status);
    if (t2.status === 'conflict') console.log('Conflict msg:\n', t2.conflict_message);

    console.log('\n🧪 TEST 3: Demand — immediate match');
    const t3 = await handleMessage(
        "Mujhe Block N mein 400gz plot chahiye, budget 4cr. Corner ho toh acha.",
        '03211234567'
    );
    console.log('Status:', t3.status, '| Matches:', t3.match_count);

    console.log('\n🧪 TEST 4: Filler words ignore');
    const t4 = await handleMessage(
        "Bhai sun, duaon mein yaad rakhna. Gulshan Block 13 mein 240gz west open plot, 3.1cr. Sab ko dikhao.",
        '03331122334'
    );
    console.log('Status:', t4.status);

    console.log('\n🧪 TEST 5: Janitor daily review');
    await runDailyReview();

    // TEST 6: Recommendations
    console.log('\n🧪 TEST 6: Broker Recommendations');
    const recs = await generateRecommendations('03001234567');
    console.log(`Recommendations: ${recs.recommendations.length}`);
    recs.recommendations.forEach(r => {
        console.log(`\n[${r.priority.toUpperCase()}] ${r.title}`);
        console.log(r.message);
    });

    console.log('\n🧪 TEST 6: Orchestration logs check');
    const { data: logs } = await supabase
        .from('orchestration_logs')
        .select('agent_name, step, status, output_summary')
        .order('created_at', { ascending: false })
        .limit(10);
    console.log('Recent logs:');
    logs?.forEach(l => console.log(` → ${l.agent_name} | ${l.step} | ${l.status} | ${l.output_summary}`));
}

run().catch(console.error);