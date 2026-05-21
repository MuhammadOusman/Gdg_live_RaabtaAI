# 🚀 Raabta AI: The B2B Real Estate Orchestrator

[![Tech Stack](https://img.shields.io/badge/Stack-Flutter%20%7C%20Node.js%20%7C%20Gemini%20%7C%20Supabase-blue)](https://github.com/MuhammadOusman/Gdg_live_RaabtaAI)
[![Market](https://img.shields.io/badge/Market-Karachi%2C%20Pakistan-green)](https://github.com/MuhammadOusman/Gdg_live_RaabtaAI)

Raabta AI is a B2B "Invisible MLS" (Multiple Listing Service) designed for the informal real estate economy of Pakistan. It captures the chaos of broker-to-broker WhatsApp groups and transforms it into a structured, visual, and intelligent marketplace.

---

## 🌟 Project Identity & Vision

In Pakistan's real estate market, thousands of brokers communicate via unstructured Roman Urdu voice notes and text messages on WhatsApp. This leads to:
- **Fragmented Inventory:** Data is lost in chat history.
- **Client Bypassing Fear:** Brokers avoid sharing exact plot numbers to protect their commission.
- **Lack of Intelligence:** No centralized way to see where the demand is moving.

**Raabta AI** solves this by providing a frictionless AI-powered bridge between WhatsApp and a structured B2B marketplace.

---

## 🏗️ Technical Architecture

Raabta AI is built with a modern, scalable stack designed for real-time performance and intelligent reasoning.

- **Frontend:** [Flutter](https://flutter.dev/) (Mobile App) with Google Maps SDK (Custom Dark Theme).
- **Backend/Orchestrator:** [Node.js](https://nodejs.org/) (Express) powering the Agentic Multi-Agent System.
- **AI Brain:** [Gemini 1.5 Flash](https://deepmind.google/technologies/gemini/) (via Google Cloud Vertex AI / Google Generative AI SDK).
- **Database:** [Supabase](https://supabase.com/) (PostgreSQL) + [PostGIS](https://postgis.net/) for spatial intelligence and real-time updates.
- **WhatsApp Integration:** [whatsapp-web.js](https://wwebjs.dev/) + AI Speech-to-Text (STT) for voice note transcription.

---

## 🤖 The Agentic Multi-Agent System (Antigravity Logic)

Our system uses a specialized team of AI agents that reason, match, and maintain data hygiene.

### 1. The Gatekeeper (Parser)
- **Goal:** Extract structured JSON from messy Roman Urdu/English slang.
- **Logic:** Normalizes currency (1cr → 10M, 1lac → 100k) and strips broker noise ("party tight hai", "duaon mein yaad rakhna").
- **Output:** Identifies intent (Supply/Demand) and visibility (Private Vault vs. Public Marketplace).

### 2. The Negotiator (Deduplicator)
- **Goal:** Maintain market integrity.
- **Logic:** Checks for duplicate listings within a 5% price/size band in the same block.
- **Action:** Proactively asks for "Plot Line/Range" (e.g., "50 ki line") to differentiate similar entries without requiring exact plot numbers.

### 3. The Matchmaker (The Strategist)
- **Goal:** Proactive B2B lead generation.
- **Agentic Logic:** Applies a **15% Budget Flex** (searches up to 4.6cr for a 4cr buyer) and suggests properties in **adjacent blocks** (Spatial Proximity).
- **Action:** Triggers real-time app notifications when a high-potential match is found.

### 4. The Janitor (State Manager)
- **Goal:** Data hygiene and lifecycle management.
- **Logic:** Manages "Daily Board Reviews," archives inactive posts, and attaches smart voice-note updates to existing listings.

---

## 📱 Mobile App Features

### 📍 Home: The Pulse Map
- **Custom Dark Theme:** Optimized for broker field work.
- **Intelligent Markers:** 🔥 Red (Hot Property), ✨ Green (New), 🔵 Blue (Active).
- **Demand Heatmap:** Uses `demand_ratio` (Requests vs. Listings) to show "Hot Blocks" with high buyer interest.

### 🔒 The Vault: Personal CRM
- **Private Mode:** Brokers can store "exclusive" listings that only they can see.
- **Smart Timeline:** AI-captured voice notes and updates for every property entry.

### 🤝 Match Center: AI Lead Feed
- **Insight Cards:** Explains *why* a match was made (e.g., "Matched because price is within 15% flex and is West-Open").
- **Real-time Alerts:** Powered by Supabase Realtime for instant B2B matching.

---

## 📊 Database Schema (PostgreSQL + PostGIS)

```sql
-- Core Listings Table
CREATE TABLE listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_agent_id text REFERENCES agents(id),
  is_public boolean DEFAULT false,
  geo_point geography(Point, 4326),
  block_id text,
  size integer,
  demand_price bigint,
  status text DEFAULT 'active',
  is_hot_property boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Real-time Market Intelligence View
CREATE VIEW block_market_stats AS
SELECT
  block_id,
  count(id) as supply,
  (SELECT count(*) FROM requests r WHERE r.target_blocks @> ARRAY[l.block_id]) as demand,
  CAST(...) / NULLIF(count(id), 0) as demand_ratio
FROM listings l
GROUP BY block_id;
```

---

## 🚀 Getting Started

### Prerequisites
- Node.js (v18+)
- Flutter SDK
- Supabase Account (with PostGIS enabled)
- Gemini API Key

### Installation

1. **Clone the Repo**
   ```bash
   git clone https://github.com/MuhammadOusman/Gdg_live_RaabtaAI
   ```

2. **Backend & Orchestrator**
   ```bash
   cd agents
   npm install
   # Create .env with SUPABASE_URL, SUPABASE_KEY, GEMINI_API_KEY
   npm start
   ```

3. **WhatsApp Bot**
   ```bash
   cd whatsapp
   npm install
   node munshi-core.js
   ```

4. **Mobile App**
   ```bash
   cd mobile/app
   flutter pub get
   flutter run
   ```

---

## 👥 Team Raabta AI
- **Ousman**
- **Hazib**
- **Zunnoorain**
- **Abdullah**

---
*Developed for Challenge 2 - AI Service Orchestrator for Informal Economy*
