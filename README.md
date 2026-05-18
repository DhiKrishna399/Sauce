# Sauce

A macOS assistant that sees your screen and helps you get things done. Ask questions about what's on your screen, get step-by-step guidance with visual highlights, or let it take actions like making calls and sending emails on your behalf.

## Overview

Sauce consists of two components:

- **macOS App** — A floating panel that lives in your menu bar. Captures your screen when you ask a question and displays AI-generated responses.
- **Backend Server** — A Node.js API that processes screenshots using Google Gemini AI and orchestrates actions via AgentPhone and AgentMail.

## Features

- **Guide Mode** — Ask anything about your screen. Get explanations with step-by-step instructions and on-screen highlights.
- **Action Mode** — Say "call this restaurant" or "email them about my order" and Sauce handles it automatically.

## Prerequisites

- macOS 13.0+
- Xcode 15+
- Node.js 18+
- npm or yarn

## Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd Hackathon
```

### 2. Configure the Backend

```bash
cd guidebot
npm install
```

Create a `.env` file in the `guidebot` folder:

```env
# Required
GEMINI_API_KEY=your_gemini_api_key

# Server
PORT=3000
NODE_ENV=development

# Optional: AgentPhone (for phone calls)
# Get your key from https://agentphone.ai
AGENTPHONE_API_KEY=your_agentphone_api_key
AGENTPHONE_AGENT_ID=your_agent_id
AGENTPHONE_MOCK=true

# Optional: AgentMail (for emails)
# Get your key from https://console.agentmail.to
AGENTMAIL_API_KEY=your_agentmail_api_key
AGENTMAIL_INBOX_ID=your_inbox@agentmail.to
AGENTMAIL_MOCK=true
```

> Set `AGENTPHONE_MOCK=true` and `AGENTMAIL_MOCK=true` to test without real API keys. The app will simulate calls and emails.

### 3. Start the Backend

```bash
npm run dev
```

The server starts at `http://localhost:3000`. You should see:

```
Guidebot backend starting up
Server listening on http://localhost:3000
```

### 4. Build and Run the macOS App

1. Open `backend-macOS-app/CrackedSiri/CrackedSiri.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

The app appears as a sparkle icon (✨) in your menu bar. Click to open the floating panel.

## Usage

1. Click the menu bar icon to open Sauce
2. Make sure the status shows "Ready" (green dot)
3. Type your question and press Enter

**Example queries:**

| Query | Mode | What happens |
|-------|------|--------------|
| "How do I change my profile picture?" | Guide | Step-by-step instructions with screen highlights |
| "What's the cheapest option here?" | Guide | Direct answer pointing to the element |
| "Call this restaurant and book a table for 2 at 7pm" | Action | Makes the call via AgentPhone |
| "Email them asking about my refund" | Action | Sends the email via AgentMail |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/analyze` | POST | Main endpoint for guide/action requests |
| `/call/:callId` | GET | Get status of an ongoing call |
| `/webhook/agentphone` | POST | AgentPhone webhook receiver |
| `/webhook/agentmail` | POST | AgentMail webhook receiver |

### Request Format

```json
{
  "imageBase64": "<base64-encoded-screenshot>",
  "query": "How do I do this?",
  "mode": "guide"
}
```

### Response Format (Guide Mode)

```json
{
  "mode": "guide",
  "answerType": "howto",
  "explanation": "Here's how to do it:",
  "steps": [
    {
      "step": 1,
      "instruction": "Click the Settings button",
      "elementDescription": "Gear icon in top right"
    }
  ],
  "highlights": [
    {
      "type": "circle",
      "x": 850,
      "y": 120,
      "radius": 30,
      "label": "Step 1"
    }
  ]
}
```

## Project Structure

```
Hackathon/
├── guidebot/                    # Backend server
│   ├── src/
│   │   ├── index.ts             # Express server & routes
│   │   ├── guideAgent.ts        # Gemini integration for guide mode
│   │   ├── actionAgent.ts       # Action parsing & execution
│   │   ├── agentPhone.ts        # Phone call integration
│   │   ├── agentMail.ts         # Email integration
│   │   ├── logger.ts            # Request logging
│   │   └── types.ts             # TypeScript types
│   ├── package.json
│   └── .env
│
└── backend-macOS-app/
    └── CrackedSiri/
        └── CrackedSiri/         # Swift source files
            ├── CrackedSiriApp.swift      # App entry point
            ├── MainWindowView.swift      # Main UI
            ├── GuideModeView.swift       # Guide response display
            ├── APIClient.swift           # Backend communication
            ├── ScreenCaptureManager.swift # Screenshot capture
            └── HighlightOverlayManager.swift # On-screen highlights
```

## Troubleshooting

**"Offline" status in the app**
- Make sure the backend is running on port 3000
- Check that no firewall is blocking localhost connections

**"MISSING!" for Gemini API Key**
- Verify your `.env` file exists in the `guidebot` folder
- Ensure `GEMINI_API_KEY` is set correctly

**Screen capture not working**
- Grant Screen Recording permission to the app in System Settings → Privacy & Security → Screen Recording

**Highlights not showing**
- Grant Accessibility permission in System Settings → Privacy & Security → Accessibility

## Development

### Backend

```bash
cd guidebot
npm run dev     # Development with hot reload
npm run build   # Compile TypeScript
npm start       # Run compiled JS
```

### macOS App

Open in Xcode and use standard build/run commands.

## License

ISC
