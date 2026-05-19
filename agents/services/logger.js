import supabase from './supabaseClient.js';

// Global sequential log queue to guarantee perfect DB chronological insertion order 
// without introducing blocking latency to the main agent execution thread.
let logQueue = Promise.resolve();

export function logStep(sessionId, agentName, step, status, inputSummary = '', outputSummary = '') {
    console.log(`[📋 Log] ${agentName} | ${step} | ${status}`);

    logQueue = logQueue.then(() => {
        return supabase.from('orchestration_logs').insert([{
            session_id: sessionId,
            agent_name: agentName,
            step,
            status,
            input_summary: inputSummary,
            output_summary: outputSummary,
        }]).then(({ error }) => {
            if (error) console.error('[Logger] Failed:', error.message);
        });
    }).catch(err => {
        console.error('[Logger Queue] Unexpected error:', err.message);
    });
}