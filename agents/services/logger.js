import supabase from './supabaseClient.js';

export async function logStep(sessionId, agentName, step, status, inputSummary = '', outputSummary = '') {
    console.log(`[📋 Log] ${agentName} | ${step} | ${status}`);

    const { error } = await supabase.from('orchestration_logs').insert([{
        session_id: sessionId,
        agent_name: agentName,
        step,
        status,
        input_summary: inputSummary,
        output_summary: outputSummary,
    }]);

    if (error) console.error('[Logger] Failed:', error.message);
}