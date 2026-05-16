import { GoogleGenAI } from '@google/genai';
import 'dotenv/config';

const ai = new GoogleGenAI({
    vertexai: true,
    project: process.env.GOOGLE_CLOUD_PROJECT,
    location: 'us-central1',
});

export async function callGemini(systemPrompt, userMessage, maxTokens = 1024) {
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
        console.error('[Vertex AI Client] Error:', err.message);
        throw new Error(`Vertex AI failed: ${err.message}`);
    }
}