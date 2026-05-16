import 'dotenv/config';
import { GoogleGenerativeAI } from '@google/generative-ai';

async function list() {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  // Wait, the SDK doesn't expose listModels directly. Let's just try fetch on REST API if it fails.
  // We'll test with gemini-1.5-flash
}
