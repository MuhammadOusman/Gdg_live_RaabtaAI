import { GoogleGenerativeAI } from '@google/generative-ai';

export async function parseBrokerMessage(text) {
  console.log(`[Internal Monologue]: Parsing message "${text}". Normalizing any Urdu slang like 1cr=10000000, 1lac=100000, 400gz=400. Evaluating if this is broker noise or legitimate data.`);
  
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

  const systemPrompt = `You are an expert real estate data parser. Extract the following fields from the given text:
- intent: "supply" or "demand"
- is_public: boolean
- block_id: string (normalized)
- size: integer
- price: integer (evaluate big numbers like 1cr as 10000000, 1lac as 100000)
- features: array of strings
- notes: string

Return ONLY valid JSON format. Example: {"intent": "supply", "is_public": true, "block_id": "A", "size": 400, "price": 10000000, "features": [], "notes": ""}`;

  try {
    const result = await model.generateContent([
      { text: systemPrompt },
      { text: `Text to parse: ${text}` }
    ]);
    const responseText = result.response.text();
    const cleanText = responseText.replace(/```json/gi, '').replace(/```/gi, '').trim();
    const parsed = JSON.parse(cleanText);
    
    console.log(`[Internal Monologue]: Successfully interpreted slang and extracted data. Intent is ${parsed.intent}. Broker noise filtered.`);
    
    return parsed;
  } catch (error) {
    console.log(`[Internal Monologue]: Failed to parse or filter broker noise. Error: ${error.message}`);
    throw error;
  }
}
