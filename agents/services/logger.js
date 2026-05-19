import supabase from './supabaseClient.js';

// Global memory-safe log buffer and background processor to guarantee perfect 
// DB chronological insertion order without memory leaks or blocking latency.
const logBuffer = [];
let isProcessing = false;

async function processLogQueue() {
    if (isProcessing || logBuffer.length === 0) return;
    isProcessing = true;
    
    while (logBuffer.length > 0) {
        const logEntry = logBuffer.shift();
        const { error } = await supabase.from('orchestration_logs').insert([logEntry]);
        if (error) console.error('[Logger] Failed:', error.message);
    }
    
    isProcessing = false;
}

export function logStep(sessionId, agentName, step, status, inputSummary = '', outputSummary = '') {
    console.log(`[📋 Log] ${agentName} | ${step} | ${status}`);

    logBuffer.push({
        session_id: sessionId,
        agent_name: agentName,
        step,
        status,
        input_summary: inputSummary,
        output_summary: outputSummary,
    });

    // Fire and forget processor trigger
    processLogQueue().catch(err => {
        console.error('[Logger Queue] Unexpected error:', err.message);
        isProcessing = false;
    });
}