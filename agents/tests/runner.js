import 'dotenv/config';
import { randomUUID } from 'crypto';
import supabase from '../services/supabaseClient.js';
import { handleMessage, confirmAndSave } from '../orchestrator/index.js';
import { checkDuplicates } from '../agents/negotiator/index.js';
import { matchDemandToListings, findAndNotifyMatches } from '../agents/matchmaker/index.js';
import { refreshBlockStats, autoArchiveStale } from '../agents/janitor/index.js';
import { generateRecommendations } from '../agents/recommender/index.js';

let passedTests = 0;
let failedTests = 0;

function assert(label, condition, detail = '') {
    if (condition) {
        console.log(`   ✅ ${label}`);
        passedTests++;
    } else {
        console.error(`   ❌ FAIL: ${label} ${detail ? '— ' + detail : ''}`);
        failedTests++;
    }
}

async function cleanup() {
    console.log('\n🧹 Cleaning up test data...');
    try {
        // Delete notifications linked to test listings
        const { data: testListings } = await supabase
            .from('listings')
            .select('id')
            .in('owner_agent_id', ['test_agent_supply', 'test_agent_buyer', 'test_agent_other']);

        if (testListings && testListings.length > 0) {
            const ids = testListings.map(l => l.id);
            await supabase.from('notifications').delete().in('listing_id', ids);
        }

        // Delete notifications directly sent to test agents
        await supabase.from('notifications').delete().in('agent_id', ['test_agent_supply', 'test_agent_buyer', 'test_agent_other']);

        // Delete test listings & requests
        await supabase.from('listings').delete().in('owner_agent_id', ['test_agent_supply', 'test_agent_buyer', 'test_agent_other']);
        await supabase.from('requests').delete().in('buyer_agent_id', ['test_agent_supply', 'test_agent_buyer', 'test_agent_other']);

        // Delete test agents
        await supabase.from('agents').delete().in('id', ['test_agent_supply', 'test_agent_buyer', 'test_agent_other']);
        
        console.log('✨ Cleanup complete!');
    } catch (err) {
        console.error('⚠️ Cleanup failed:', err.message);
    }
}

async function setup() {
    console.log('🚀 Setting up test agents...');
    const testAgents = [
        { id: 'test_agent_supply', name: 'Test Seller Agent', agency_name: 'Raabta Test', work_areas: ['North Nazimabad', 'Gulshan-e-Iqbal'], is_verified: true },
        { id: 'test_agent_buyer', name: 'Test Buyer Agent', agency_name: 'Raabta Test', work_areas: ['North Nazimabad'], is_verified: true },
        { id: 'test_agent_other', name: 'Test Other Agent', agency_name: 'Raabta Test', work_areas: ['North Nazimabad'], is_verified: true },
    ];

    const { error } = await supabase.from('agents').upsert(testAgents);
    if (error) {
        throw new Error(`Setup failed to insert test agents: ${error.message}`);
    }
    console.log('✅ Test agents ready.');
}

async function runTests() {
    console.log('\n======================================================');
    console.log('🧪 RaabtaAI Multi-Agent System — Integration Test Runner');
    console.log('======================================================\n');

    await cleanup();
    await setup();

    // ────────────────────────────────────────────────────────────────
    // 1. GATEKEEPER & ORCHESTRATOR TESTS
    // ────────────────────────────────────────────────────────────────
    console.log('\n👉 SECTION 1: Gatekeeper & Orchestrator');

    console.log('Running: Supply message parsing (App source - auto save)...');
    const supplyRes = await handleMessage(
        "North Nazimabad Block N mein 400gz plot hai, price 4.2cr. Private rakho.",
        'test_agent_supply',
        'app'
    );
    assert('Supply flow status is listing_saved', supplyRes.status === 'listing_saved');
    assert('Correct block parsed', supplyRes.listing?.block_id === 'North Nazimabad Block N');
    assert('Correct size parsed', supplyRes.listing?.size === 400);
    assert('Correct price parsed', supplyRes.listing?.demand_price === 42000000);
    assert('Correct visibility parsed', supplyRes.listing?.is_public === false);

    console.log('Running: Supply message parsing (WhatsApp source - confirmation)...');
    const waSupplyRes = await handleMessage(
        "PECHS Block 6 mein 500gz corner plot, demand 5cr. Public karo.",
        'test_agent_supply',
        'whatsapp'
    );
    assert('WhatsApp supply status is awaiting_confirm', waSupplyRes.status === 'awaiting_confirm');
    assert('Parsed details preserved', waSupplyRes.parsed?.block_id === 'PECHS Block 6');
    assert('Correct features parsed', waSupplyRes.parsed?.features?.includes('Corner'));

    console.log('Running: Confirm and save...');
    const savedWaListing = await confirmAndSave(waSupplyRes.parsed, 'test_agent_supply', waSupplyRes.session_id);
    assert('Listing successfully saved after confirm', savedWaListing?.id !== undefined);
    assert('Saved listing size is correct', savedWaListing?.size === 500);

    // ────────────────────────────────────────────────────────────────
    // 2. NEGOTIATOR (DUPLICATE CHECK & UNIT NORMALIZATION) TESTS
    // ────────────────────────────────────────────────────────────────
    console.log('\n👉 SECTION 2: Negotiator (Conflict Detection)');

    // Create a public listing to act as conflict trigger
    const { data: baseListing } = await supabase.from('listings').insert([{
        owner_agent_id: 'test_agent_other',
        is_public: true,
        block_id: 'North Nazimabad Block N',
        size: 400,
        unit: 'gaz',
        demand_price: 42000000,
        status: 'active'
    }]).select().single();

    console.log('Running: Identical duplicate listing detection...');
    const identDup = await checkDuplicates({
        block_id: 'North Nazimabad Block N',
        size: 400,
        unit: 'gaz',
        demand_price: 42000000,
        is_public: true
    }, 'test_agent_supply');
    assert('Duplicate check flags duplicate: true', identDup.isDuplicate === true);
    assert('Duplicate check includes conflictMessage', identDup.conflictMessage !== undefined);

    console.log('Running: Unit-normalized duplicate detection (10 marla vs 450gz)...');
    // 10 marla = 450gz. Let's insert a 450gz listing
    const { data: marlaListing } = await supabase.from('listings').insert([{
        owner_agent_id: 'test_agent_other',
        is_public: true,
        block_id: 'North Nazimabad Block N',
        size: 450,
        unit: 'gaz',
        demand_price: 25000000,
        status: 'active'
    }]).select().single();

    const crossUnitDup = await checkDuplicates({
        block_id: 'North Nazimabad Block N',
        size: 10,
        unit: 'marla', // 10 marla = 450gz, matching base 450gz
        demand_price: 25000000,
        is_public: true
    }, 'test_agent_supply');
    assert('Flags duplicate with cross-unit sizes', crossUnitDup.isDuplicate === true);

    // ────────────────────────────────────────────────────────────────
    // 3. MATCHMAKER (TOLERANCE & FEATURES) TESTS
    // ────────────────────────────────────────────────────────────────
    console.log('\n👉 SECTION 3: Matchmaker (Tolerance & Feature Filtering)');

    console.log('Running: Match demand to listings with ±10% size tolerance...');
    // Buyer wants 400gz, listing is 420gz (5% diff, within 10% limit)
    const { data: testMatchListing } = await supabase.from('listings').insert([{
        owner_agent_id: 'test_agent_other',
        is_public: true,
        block_id: 'Gulshan-e-Iqbal Block 13',
        size: 420,
        unit: 'gaz',
        demand_price: 30000000,
        status: 'active'
    }]).select().single();

    const matches = await matchDemandToListings({
        block_id: 'Gulshan-e-Iqbal Block 13',
        size: 400,
        max_budget: 35000000,
        features: []
    }, 'test_agent_buyer');
    assert('Finds match within 10% size tolerance (400gz req vs 420gz list)', matches.length > 0);
    assert('Correct match returned', matches.some(m => m.id === testMatchListing.id));

    console.log('Running: Feature-aware filtering (listing missing requested feature)...');
    // Listing has no features, but buyer requests 'Corner'
    const featMatches = await matchDemandToListings({
        block_id: 'Gulshan-e-Iqbal Block 13',
        size: 400,
        max_budget: 35000000,
        features: ['Corner']
    }, 'test_agent_buyer');
    assert('Filters out listing if it lacks the requested feature', featMatches.length === 0);

    console.log('Running: Feature-aware filtering (listing has requested feature)...');
    // Update listing to have the 'Corner' feature
    await supabase.from('listings').update({ features: ['Corner', 'West Open'] }).eq('id', testMatchListing.id);
    const featMatchesOk = await matchDemandToListings({
        block_id: 'Gulshan-e-Iqbal Block 13',
        size: 400,
        max_budget: 35000000,
        features: ['Corner']
    }, 'test_agent_buyer');
    assert('Finds match when listing contains requested feature', featMatchesOk.length > 0);

    console.log('Running: Bidirectional match scanning (Listing -> Demand)...');
    // Create demand
    const { data: demandReq } = await supabase.from('requests').insert([{
        buyer_agent_id: 'test_agent_buyer',
        target_blocks: ['Gulshan-e-Iqbal Block 13'],
        target_size: 400,
        unit: 'gaz',
        max_budget: 35000000,
        target_features: ['Corner'],
        status: 'searching'
    }]).select().single();

    // Reload the updated listing from the database so it contains features
    const { data: testMatchListingReloaded } = await supabase
        .from('listings')
        .select('*')
        .eq('id', testMatchListing.id)
        .single();

    const scanMatches = await findAndNotifyMatches(testMatchListingReloaded);
    assert('findAndNotifyMatches successfully triggers match', scanMatches.length > 0);
    assert('Notification is sent to buyer agent', scanMatches.some(m => m.request.buyer_agent_id === 'test_agent_buyer'));

    // ────────────────────────────────────────────────────────────────
    // 4. JANITOR & RECOMMENDER TESTS
    // ────────────────────────────────────────────────────────────────
    console.log('\n👉 SECTION 4: Janitor & Recommender');

    console.log('Running: Janitor refreshBlockStats() view read check...');
    const refreshedStats = await refreshBlockStats();
    assert('refreshBlockStats runs successfully as diagnostics read', refreshedStats !== undefined);

    console.log('Running: Recommender generateRecommendations()...');
    const recsResult = await generateRecommendations('test_agent_supply');
    assert('generateRecommendations runs without throwing', recsResult !== undefined);
    assert('Returns recommendations array', Array.isArray(recsResult.recommendations));

    // ────────────────────────────────────────────────────────────────
    // 5. MARKET QUERY (NEW INTENT) TESTS
    // ────────────────────────────────────────────────────────────────
    console.log('\n👉 SECTION 5: Market Query Intent');
    console.log('Running: Market Query Intent parsing & advice generation...');
    const marketQueryResult = await handleMessage(
        "Mere paas ek ghar hai dha phase 6 ma. Mujhe demand batao phase 6 ki.",
        'test_agent_supply',
        'whatsapp'
    );
    assert('Correctly maps intent to market_query_result', marketQueryResult.status === 'market_query_result');
    assert('Parses block_id correctly', marketQueryResult.block_id === 'DHA Phase 6');
    assert('Generates roman urdu advice content', typeof marketQueryResult.advice === 'string' && marketQueryResult.advice.length > 20);

    // ────────────────────────────────────────────────────────────────
    // SUMMARY
    // ────────────────────────────────────────────────────────────────
    console.log('\n======================================================');
    console.log('📊 TEST SUMMARY');
    console.log('======================================================');
    console.log(`   Passed: ${passedTests}`);
    console.log(`   Failed: ${failedTests}`);
    console.log('======================================================\n');

    await cleanup();

    if (failedTests > 0) {
        process.exit(1);
    } else {
        process.exit(0);
    }
}

runTests().catch(async (err) => {
    console.error('\n💥 CRITICAL TEST EXCEPTION:', err);
    await cleanup();
    process.exit(1);
});
