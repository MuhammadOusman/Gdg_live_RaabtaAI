import { GoogleGenAI } from '@google/genai';
import 'dotenv/config';

const ai = new GoogleGenAI({
    vertexai: true,
    project: process.env.GOOGLE_CLOUD_PROJECT,
    location: 'us-central1',
});

const RETRY_DELAYS_MS = [500, 1000]; // 2 retries: 500ms then 1000ms

export async function callGemini(systemPrompt, userMessage, maxTokens = 1024) {
    let lastError;

    for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt++) {
        try {
            const response = await ai.models.generateContent({
                model: 'gemini-2.5-flash',
                config: {
                    maxOutputTokens: maxTokens,
                    temperature: 0.1,
                    systemInstruction: systemPrompt,
                },
                contents: userMessage,
            });

            const text = response.text;
            return text.replace(/```json/gi, '').replace(/```/gi, '').trim();

        } catch (err) {
            lastError = err;
            if (attempt < RETRY_DELAYS_MS.length) {
                console.warn(`[Vertex AI] Attempt ${attempt + 1} failed — retrying in ${RETRY_DELAYS_MS[attempt]}ms: ${err.message}`);
                await new Promise(r => setTimeout(r, RETRY_DELAYS_MS[attempt]));
            }
        }
    }

    console.error('[Vertex AI] All retries exhausted:', lastError.message);
    throw new Error(`Vertex AI failed after ${RETRY_DELAYS_MS.length + 1} attempts: ${lastError.message}`);
}