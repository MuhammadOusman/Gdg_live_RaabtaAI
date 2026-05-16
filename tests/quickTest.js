import 'dotenv/config';
import { handleMessage } from '../src/orchestrator/index.js';
import { runDailyReview, attachNote } from '../src/agents/janitor/index.js';

async function run() {

    console.log('\n🧪 TEST 1: Private supply listing');
    const t1 = await handleMessage(
        "N. Naz Block N mein 400gz plot hai, 50 ki line, demand 4.2cr. Private rakho. Party tight hai yaar.",
        '03001234567'
    );
    console.log('Status:', t1.status, '| ID:', t1.listing?.id);

    console.log('\n🧪 TEST 2: Public supply (Agent 2 + 3 trigger hoga)');
    const t2 = await handleMessage(
        "Block N mein 400gz corner plot, 50 ki line, demand 3.85cr. Public karo.",
        '03009876543'
    );
    console.log('Status:', t2.status);
    if (t2.status === 'conflict') console.log('Conflict msg:\n', t2.conflict_message);

    console.log('\n🧪 TEST 3: Demand (Agent 3 immediate match)');
    const t3 = await handleMessage(
        "Mujhe Block N mein 400gz plot chahiye, budget 4cr. Corner ho toh acha.",
        '03211234567'
    );
    console.log('Status:', t3.status, '| Matches:', t3.match_count);

    console.log('\n🧪 TEST 4: Filler words ignore karo');
    const t4 = await handleMessage(
        "Bhai sun, duaon mein yaad rakhna. Gulshan Block 13 mein 240gz west open plot, 3.1cr. Sab ko dikhao.",
        '03331122334'
    );
    console.log('Status:', t4.status);

    console.log('\n🧪 TEST 5: Janitor daily review');
    await runDailyReview();
}

run().catch(console.error);