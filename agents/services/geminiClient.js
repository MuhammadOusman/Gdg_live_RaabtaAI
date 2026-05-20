import { GoogleGenAI } from '@google/genai';
import 'dotenv/config';
import fs from 'fs';

// Dynamically write GCP Service Account credentials on serverless environments if provided
const serviceAccountJson = process.env.GCP_SERVICE_ACCOUNT_JSON || process.env.GCP_SERVICE_ACCOUNT_KEY;
if (serviceAccountJson) {
    try {
        const credsPath = '/tmp/gcp-creds.json';
        fs.writeFileSync(credsPath, serviceAccountJson);
        process.env.GOOGLE_APPLICATION_CREDENTIALS = credsPath;
        console.log('[Gemini Client] Wrote GCP credentials from environment service account JSON');
    } catch (err) {
        console.error('[Gemini Client] Failed writing GCP credentials:', err.message);
    }
}

let ai;
if (process.env.GEMINI_API_KEY) {
    console.log('[Gemini Client] Initializing standard Gemini Developer API...');
    ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
} else {
    console.log('[Gemini Client] Initializing GCP Vertex AI...');
    ai = new GoogleGenAI({
        vertexai: true,
        project: process.env.GOOGLE_CLOUD_PROJECT || 'sonic-diorama-474318-f5',
        location: 'us-central1',
    });
}

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