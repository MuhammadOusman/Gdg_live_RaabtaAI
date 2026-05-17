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
  if (!senderId) {
    return '';
  }

  const rawValue = String(senderId);
  const digits = rawValue.replace(/\D/g, '');

  if (!digits) {
    return rawValue;
  }

  return `+${digits}`;
}

function pickBestSenderCandidate(candidates = []) {
  for (const candidate of candidates) {
    const normalized = normalizeSenderId(candidate);
    if (normalized && normalized.startsWith('+') && normalized.length >= 9) {
      return {
        raw: String(candidate),
        normalized,
      };
    }
  }

  const first = candidates.find(Boolean);
  return {
    raw: first ? String(first) : '',
    normalized: normalizeSenderId(first || ''),
  };
}

async function resolveSender(message) {
  const candidates = [];

  if (message.fromMe && message.to) {
    candidates.push(message.to);
  }

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
  } catch (error) {
    // Ignore contact fetch errors and continue with field-based fallbacks.
  }

  return pickBestSenderCandidate(candidates.filter(Boolean));
}

function createTranscriber(apiKey, modelName) {
  if (!apiKey) {
    return null;
  }

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
  if (!transcriber) {
    return '';
  }

  const media = await message.downloadMedia();
  if (!media?.data) {
    return '';
  }

  const mimeType = media.mimetype || 'audio/ogg';
  const result = await transcriber.generateContent([
    'Transcribe this WhatsApp voice message to English text only. If the message is in a non-English language (Urdu, Arabic, Hindi, etc.), translate it to English. Output plain text only, no explanation.',
    {
      inlineData: {
        data: media.data,
        mimeType,
      },
    },
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
    console.log('ℹ️ Saved WhatsApp session found. QR will only appear if WhatsApp asks to re-login.');
  } else {
    console.log('ℹ️ No saved WhatsApp session found. QR should appear on startup.');
  }

  if (transcriber) {
    console.log('🎤 Voice transcription: ENABLED (Gemini API detected)');
  } else {
    console.log('🎤 Voice transcription: DISABLED (set GEMINI_API_KEY env var to enable)');
    console.log('   → Tip: $env:GEMINI_API_KEY="your-key"; npm start\n');
  }

  const client = new Client({
    authStrategy: new LocalAuth({ dataPath: options.authPath || AUTH_PATH }),
    webVersionCache: {
      type: 'none',
    },
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
      console.log(`\n✅ QR saved (open PNG file to scan):\n📱 ${QR_IMAGE_PATH}\n📝 ${QR_TEXT_PATH}\n`);
      console.log('💡 Tip: Terminal QR is hard to scan. Open the .png file above with your phone or image viewer.\n');
    } catch (error) {
      console.error('❌ QR file save failed:', error.message);
    }

    emitter.emit('qr', qr);
  });

  client.on('ready', () => {
    console.log('\n✅ WhatsApp API is ready.\n');
    emitter.emit('ready');
    if (typeof options.onReady === 'function') {
      options.onReady();
    }
  });

  client.on('authenticated', () => {
    console.log('✅ WhatsApp session authenticated and saved.');
    emitter.emit('authenticated');
  });

  client.on('auth_failure', (error) => {
    console.error('❌ WhatsApp auth failed:', error.message);
    emitter.emit('auth_failure', error);
  });

  client.on('disconnected', (reason) => {
    console.log('⚠️ WhatsApp disconnected:', reason);
    emitter.emit('disconnected', reason);
  });

  client.on('message', async (message) => {
    try {
      const isVoice = message.type === 'ptt' || message.type === 'audio';
      const baseText = String(message.body || '').trim();
      const transcribedText = isVoice ? await transcribeVoiceMessage(message, transcriber) : '';
      const finalText = transcribedText || baseText || '[voice message]';
      const sender = await resolveSender(message);
      const payload = buildPayload(message, finalText, sender);

      console.log(`📨 ${payload.from || payload.rawFrom}: ${payload.text}`);
      emitter.emit('message', payload, message);

      if (typeof options.onMessage === 'function') {
        await options.onMessage(payload, message);
      }
    } catch (error) {
      console.error('❌ Message handling failed:', error.message);
      emitter.emit('error', error);

      if (typeof options.onError === 'function') {
        await options.onError(error, message);
      }
    }
  });

  return {
    client,
    emitter,
    start: () => client.initialize(),
    on: emitter.on.bind(emitter),
    once: emitter.once.bind(emitter),
    off: emitter.off.bind(emitter),
    normalizeSenderId,
  };
}

if (require.main === module) {
  const api = createWhatsAppApi();

  console.log('🚀 Starting WhatsApp API...');

  api.start().catch((error) => {
    console.error('❌ Failed to start WhatsApp API:', error.message);
    process.exit(1);
  });
}

module.exports = {
  createWhatsAppApi,
  normalizeSenderId,
  transcribeVoiceMessage,
};
