const fs = require('fs');
const path = require('path');
const { EventEmitter } = require('events');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const AUTH_PATH = path.join(__dirname, '.wwebjs_auth');
const QR_TEXT_PATH = path.join(__dirname, 'latest-whatsapp-qr.txt');
const QR_IMAGE_PATH = path.join(__dirname, 'latest-whatsapp-qr.png');

function shouldResetAuth() {
  return process.argv.includes('--reset-auth') || process.env.RESET_WWEBJS_AUTH === '1';
}

function clearAuthSession() {
  if (fs.existsSync(AUTH_PATH)) {
    fs.rmSync(AUTH_PATH, { recursive: true, force: true });
  }
}

function normalizeSenderId(senderId) {
  if (!senderId) return '';
  const rawValue = String(senderId);
  const digits = rawValue.replace(/\D/g, '');
  if (!digits) return rawValue;
  return `+${digits}`;
}

function pickBestSenderCandidate(candidates = []) {
  for (const candidate of candidates) {
    const normalized = normalizeSenderId(candidate);
    if (normalized && normalized.startsWith('+') && normalized.length >= 9) {
      return { raw: String(candidate), normalized };
    }
  }
  const first = candidates.find(Boolean);
  return { raw: first ? String(first) : '', normalized: normalizeSenderId(first || '') };
}

async function resolveSender(message) {
  const candidates = [];
  if (message.fromMe && message.to) candidates.push(message.to);
  candidates.push(
    message.author,
    message.from,
    message.id?.participant,
    message._data?.participant,
    message._data?.author,
    message._data?.from
  );
  try {
    const contact = await message.getContact();
    candidates.unshift(contact?.number);
    candidates.unshift(contact?.id?._serialized);
  } catch (error) {}
  return pickBestSenderCandidate(candidates.filter(Boolean));
}

function createTranscriber(apiKey, modelName) {
  if (!apiKey) return null;
  const genAI = new GoogleGenerativeAI(apiKey);
  return genAI.getGenerativeModel({ model: modelName || 'gemini-2.5-flash' });
}

async function saveQrFiles(qrText) {
  fs.writeFileSync(QR_TEXT_PATH, qrText, 'utf8');
  await QRCode.toFile(QR_IMAGE_PATH, qrText, {
    width: 512,
    margin: 1,
    errorCorrectionLevel: 'M',
  });
}

async function transcribeVoiceMessage(message, transcriber) {
  if (!transcriber) return '';
  const media = await message.downloadMedia();
  if (!media?.data) return '';
  const mimeType = media.mimetype || 'audio/ogg';
  const result = await transcriber.generateContent([
    'Transcribe this WhatsApp voice message to English text only. If the message is in a non-English language (Urdu, Arabic, Hindi, etc.), translate it to English. Output plain text only, no explanation.',
    { inlineData: { data: media.data, mimeType } },
  ]);
  return String(result.response?.text?.() || '').trim();
}

function buildPayload(message, text, sender) {
  const senderId = sender?.raw || message.author || message.from || '';
  return {
    from: sender?.normalized || normalizeSenderId(senderId),
    rawFrom: senderId,
    chatId: message.from || '',
    text,
    rawText: message.body || '',
    isVoice: message.type === 'ptt' || message.type === 'audio',
    messageType: message.type || '',
    messageId: message.id?._serialized || message.id?.id || '',
    timestamp: new Date().toISOString(),
  };
}

function createWhatsAppApi(options = {}) {
  const emitter = new EventEmitter();
  const geminiKey = options.geminiApiKey || process.env.GEMINI_API_KEY || '';
  const transcriber = createTranscriber(geminiKey, options.transcriptionModel || 'gemini-2.5-flash');

  if (options.resetAuth || shouldResetAuth()) {
    clearAuthSession();
    console.log('🧹 Saved WhatsApp session cleared. QR will be generated on startup.');
  } else if (fs.existsSync(AUTH_PATH)) {
    console.log('ℹ️ Saved WhatsApp session found. You should be logged in automatically!');
  }

  const client = new Client({
    authStrategy: new LocalAuth({ dataPath: options.authPath || AUTH_PATH }),
    webVersionCache: { type: 'none' },
    puppeteer: {
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-web-security',
        '--disable-features=VizDisplayCompositor',
        '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ],
    },
  });

  client.on('qr', async (qr) => {
    console.clear();
    console.log('\n╔═══════════════════════════════╗');
    console.log('║  WhatsApp API - Scan QR Code  ║');
    console.log('╚═══════════════════════════════╝\n');
    qrcode.generate(qr, { small: true });
    try {
      await saveQrFiles(qr);
      console.log(`\n✅ QR saved (open PNG file to scan):\n📱 ${QR_IMAGE_PATH}`);
    } catch (error) {}
    emitter.emit('qr', qr);
  });

  client.on('ready', () => {
    console.log('\n✅ WhatsApp API is ready. (Legacy Engine restored)\n');
    emitter.emit('ready');
  });

  client.on('message', async (message) => {
    try {
      // 🚫 CRITICAL FIX: Ignore all group chats and status broadcasts
      const isGroup = message.from.includes('@g.us') || (message.chat && message.chat.isGroup);
      if (isGroup || message.from === 'status@broadcast' || message.fromMe) {
          return;
      }

      const isVoice = message.type === 'ptt' || message.type === 'audio';
      const baseText = String(message.body || '').trim();
      const transcribedText = isVoice ? await transcribeVoiceMessage(message, transcriber) : '';
      const finalText = transcribedText || baseText || '[voice message]';
      const sender = await resolveSender(message);
      const payload = buildPayload(message, finalText, sender);

      console.log(`📨 ${payload.from || payload.rawFrom}: ${payload.text}`);
      emitter.emit('message', payload, message);
    } catch (error) {
      console.error('❌ Message handling failed:', error.message);
    }
  });

  return {
    client,
    emitter,
    start: () => client.initialize(),
    on: emitter.on.bind(emitter),
    sendMessage: async (chatId, content) => await client.sendMessage(chatId, content),
    normalizeSenderId,
  };
}

if (require.main === module) {
  if (fs.existsSync(path.join(__dirname, '.env'))) {
    require('dotenv').config({ path: path.join(__dirname, '.env') });
  } else {
    require('dotenv').config({ path: '../agents/.env' });
  }
  const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
  const axios = require('axios');
  const api = createWhatsAppApi();

  console.log('🚀 Starting WhatsApp API (Restoring original state)...');
  console.log(`📡 Connecting to Agents Backend at: ${BACKEND_URL}`);

  // In-memory state machine to track users waiting for confirmation
  const pendingConfirms = new Map();

  // ── SYNC AGENTS (BACKEND) WITH WHATSAPP ─────────────────────
  api.on('message', async (payload, rawMsg) => {
    if (!payload.text || payload.text === '[voice message]') return;
    
    try {
      const normalizedText = payload.text.toLowerCase().trim();
      const isPublicConfirm = normalizedText === 'confirm public' || normalizedText === 'public' || normalizedText === '1';
      const isPrivateConfirm = normalizedText === 'confirm private' || normalizedText === 'private' || normalizedText === '2' || normalizedText === 'confirm' || normalizedText === 'yes' || normalizedText === 'confirmed';
      const isConfirming = isPublicConfirm || isPrivateConfirm;

      // Check if user is in a pending confirmation state
      if (isConfirming && pendingConfirms.has(payload.from)) {
        console.log(`[🤖 Bot Sync] Forwarding CONFIRMATION to backend from ${payload.from}...`);
        
        const pendingData = pendingConfirms.get(payload.from);
        pendingConfirms.delete(payload.from); // Clear state

        // Override is_public based on their specific confirmation choice
        pendingData.parsed.is_public = isPublicConfirm;

        const response = await axios.post(`${BACKEND_URL}/api/confirm`, {
          parsed_data: pendingData.parsed,
          sender_agent_id: payload.from,
          session_id: pendingData.session_id
        });

        const result = response.data;
        if (result.status === 'listing_saved') {
            const count = result.matches_count || 0;
            if (pendingData.parsed.is_public) {
                if (count > 0) {
                    await rawMsg.reply(`🎉 Listing saved publicly! We found ${count} matching buyer(s) and notified them! Matchmaker is scanning for more...`);
                } else {
                    await rawMsg.reply(`🎉 Listing saved publicly! (0 matching buyers found right now). Matchmaker will alert you when a match is found.`);
                }
            } else {
                await rawMsg.reply(`🎉 Listing saved privately in your Vault! Only you can see it.`);
            }
        } else if (result.message) {
            await rawMsg.reply(result.message);
        }
        return;
      }

      console.log(`[🤖 Bot Sync] Forwarding message to backend from ${payload.from}...`);
      
      const response = await axios.post(`${BACKEND_URL}/api/message`, {
        raw_text: payload.text,
        sender_agent_id: payload.from,
        source: 'whatsapp'
      });

      const result = response.data;
      let replyText = '';

      if (result.status === 'conflict') {
        replyText = `⚠️ Conflict Detected:\n${result.conflict_message}`;
      } else if (result.status === 'awaiting_confirm') {
        // Save to state machine
        pendingConfirms.set(payload.from, {
          parsed: result.parsed,
          session_id: result.session_id
        });

        const f = result.parsed.features && result.parsed.features.length > 0 
            ? `\n✨ Features: ${result.parsed.features.join(', ')}` : '';
        replyText = `📋 Please Confirm:\n\n📍 Block: ${result.parsed.block_id}\n📐 Size: ${result.parsed.size}gz\n💰 Demand: PKR ${result.parsed.demand_price.toLocaleString('en-PK')}${f}\n\nChoose Visibility:\n1️⃣ Reply "confirm public" (makes it visible to all brokers & searches for matches)\n2️⃣ Reply "confirm private" (saves it only in your private vault)`;
      } else if (result.status === 'listing_saved') {
        replyText = `🎉 Listing saved successfully in our system! Matchmaker is scanning for buyers...`;
      } else if (result.status === 'market_query_result') {
        const stats = result.stats || {};
        replyText = `💡 Recommender Insights:\n\n${result.advice}\n\n📊 Stats for ${result.block_id}:\nSupply: ${stats.supply || 0} plots\nDemand: ${stats.demand || 0} requests\nRatio: ${stats.demand_ratio ? Number(stats.demand_ratio).toFixed(2) : 0}`;
      } else if (result.status === 'demand_saved') {
         replyText = `🔍 Searching... Demand saved. We found ${result.matches?.length || 0} immediate matches!`;
      } else {
        replyText = result.message || '';
      }

      if (replyText) {
         await rawMsg.reply(replyText);
      }

    } catch (error) {
       console.error('❌ Backend Sync Error:', error.message);
       await rawMsg.reply(`❌ Technical error connecting to AI agent backend. Please try again.`);
    }
  });

  api.start();
}

module.exports = {
  createWhatsAppApi,
  normalizeSenderId,
  transcribeVoiceMessage,
};
