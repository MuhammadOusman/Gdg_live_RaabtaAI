# 🌐 Raabta AI: Interactive Web Demo Console

[![Vercel Deployment](https://img.shields.io/badge/Deploy-Vercel-black?logo=vercel)](https://gdg-live-raabta-ai-bp6s.vercel.app)
[![Tech Stack](https://img.shields.io/badge/React%20%7C%20Vite%20%7C%20Supabase-blue)](https://gdg-live-raabta-ai-bp6s.vercel.app)
[![Interface](https://img.shields.io/badge/UI-Sleek%20Dark%20Mode-purple)](https://gdg-live-raabta-ai-bp6s.vercel.app)

Welcome to the **Raabta AI Web Demo Console**. This frontend web application is a real-time reactive simulator designed to demonstrate the power, orchestration reasoning, and capabilities of the Raabta AI Multi-Agent real-estate ecosystem.

🔗 **Live URL:** [https://gdg-live-raabta-ai-bp6s.vercel.app](https://gdg-live-raabta-ai-bp6s.vercel.app)

---

## 🎨 Premium Visual Interface

The web demo is designed as an ultra-premium real-time monitoring deck.

*   **Cohesive Dark Palette:** Implements a modern dark-mode interface built on sophisticated dark slate HSL tones with accent highlight borders.
*   **Micro-Animations:** Includes active scanning gradient animations on running agent cards, pulse/blink indicator status effects, and smooth fade-in log streams.
*   **Highly Responsive:** Features a split-pane structural grid featuring inputs and live agent outputs side-by-side.

---

## 🚀 Key Features Demonstrated

### 💬 1. Natural Language Message Simulator
*   Simulate a WhatsApp real-estate broker's message in **Roman Urdu** or **English slang**.
*   *Preset Quick Simulator Buttons* representing actual Karachi DHA broker communications:
    *   **Public Supply:** *"Phase 8 Block C me 500 Gaz plot for sale. Demand 12.5 crore. Urgent sell."*
    *   **Private Supply:** *"Block E extension me 1 Kanal plot hai. Demand 5.5 Crore. Keep it private for now."*
    *   **Buyer Demand:** *"Need 250 gaz plot in Phase 6 Block H or nearby blocks. Budget 4.5 crore."*
    *   **Market Query:** *"DHA Phase 6 Block A ki kya market situation hai?"*

### 🤖 2. Dynamic Agent Status Grid
Visual status cards representing the active status of each specialist AI agent:
*   **Orchestrator (🚀):** Coordinates state flow, validation, saving, and matching.
*   **Gatekeeper (🔍):** Handles Vertex AI / Gemini LLM parsing, normalization, and WhatsApp preview construction.
*   **Negotiator (⚖️):** Runs real-time duplicate checks in the Postgres DB to avoid conflict double-listings.
*   **Matchmaker (🔗):** Automatically processes 15% budget flex and adjacent block listings to match buyers with sellers.
*   **Janitor (🧹):** Manages sweep archiving and aggregate block-level analytics.
*   **Recommender (💡):** Analyzes supply-demand ratios to provide direct Karachi market insights.

### ⚡ 3. Direct Agent Actions
Includes deep-diagnostic buttons to manually trigger the agents:
*   🧹 **Run Janitor Sweep:** Triggers automatic stale listing archiving and updates block-level stats.
*   💡 **Get Market Insights:** Requests current Karachi block recommendations and supply-demand ratios.

### 📝 4. Real-time Step-by-Step Log Stream
*   Connects directly to the backend orchestration logging database via **Supabase Realtime**.
*   Streams each agent's reasoning, input, and outputs line-by-line as the transaction takes place.

### 📐 5. Result Verification & Confirmation
*   **Interactive Confirmation Panel:** Review structured JSON extractions (size, budget, intent, blocks, features, visibility).
*   **Confirm/Cancel Actions:** Fully simulates the WhatsApp "Confirm" loop where listings are written permanently to the Database.

---

## 🛠️ Technology Stack

*   **React 19:** State-of-the-art declarative web application framework.
*   **Vite 8:** Extremely fast frontend tooling and HMR server.
*   **Supabase Client:** Handles real-time websocket connections to fetch orchestrator step logs.
*   **Pure Vanilla CSS:** Sleek styling system designed to provide absolute control over themes, animations, and custom typography (Outfit, Inter, and JetBrains Mono).

---

## 💻 Local Development Setup

To run the web simulator console locally on your machine:

### 1. Prerequisites
Ensure you have **Node.js** (v18+) and **npm** installed.

### 2. Installation
Navigate into the `web` folder and install dependencies:
```bash
cd web
npm install
```

### 3. Environment Variables Configuration
Create a `.env.local` file inside the `web/` directory and configure the target Agents API backend URL:
```env
VITE_BACKEND_URL=http://localhost:8080
```
> **Note:** The backend api generally runs on port `8080` (orchestrator/agents server) or port `3000` (core database server).

### 4. Running the Development Server
```bash
npm run dev
```
Open your browser and navigate to the address listed in your terminal (typically `http://localhost:5173`).

### 5. Production Build
To build a highly optimized bundle for production hosting:
```bash
npm run build
```

---

*Part of the Raabta AI Multi-Agent Real Estate Orchestrator Suite.*
