# Workspace

## Overview

pnpm workspace monorepo using TypeScript. Each package manages its own dependencies.

## Stack

- **Monorepo tool**: pnpm workspaces
- **Node.js version**: 24
- **Package manager**: pnpm
- **TypeScript version**: 5.9
- **API framework**: Express 5
- **Database**: PostgreSQL + Drizzle ORM
- **Validation**: Zod (`zod/v4`), `drizzle-zod`
- **API codegen**: Orval (from OpenAPI spec)
- **Build**: esbuild (CJS bundle)

## Key Commands

- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- `pnpm --filter @workspace/api-server run dev` — run API server locally

See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details.

## Artifacts

### SAKHII – Smart Women Safety & Travel Companion (`artifacts/sakhii`)
- Mobile-first React+Vite+Tailwind web app (max-width 430px)
- Dark glassmorphism design: #080c14 bg, #00e5a0 safe green, #ff4d6d danger
- Fonts: Syne (headings) + DM Sans (body)
- Tabs: Home, Safety Map, Travel, Health, **AI Chat**, Guardian
- Role-based: User vs Guardian (different nav tabs)
- Features: Live risk meter, QR safety card, Guardian scan, Check-In, Health (period+pregnancy), Demo panel
- **Real GPS**: `useGeolocation` hook via browser `watchPosition` API; reverse geocoding via Nominatim
- **Real Maps**: Leaflet + OpenStreetMap (free, no API key) on Safety Map and Travel screens
- **Real Routing**: OSRM public routing API (`router.project-osrm.org`) for walk/drive/cycle routes
- **ETA Timer**: Live countdown with progress bar when navigation is started
- **Place Search**: Nominatim geocoding autocomplete on both map screens
- **3-Strike Camera**: CheckInModal escalates → on 3rd unanswered alert, captures camera snapshot + GPS, sends to guardians
- **AI Agent**: Detects navigation intent (e.g. "take me to Forum Mall") from AI responses and shows action cards
- **Real Guardian System**: `POST /api/guardian/location/update` (user pushes state every 15s) + `GET /api/guardian/live/:code` (guardian polls every 5-8s)
- **Share Code**: UUID generated per user, stored in localStorage. QR code encodes `?guardian=CODE` URL
- **Guardian Live View**: Opens when `?guardian=CODE` URL param detected; shows real Leaflet map + all live stats, polls every 5s
- **Guardian Screen**: Watchlist of tracked users (stored in localStorage); real Leaflet map + live data polled every 8s; "Connect User" opens scan modal
- **GuardianScanModal**: Enter share code → fetches real live data → shows real Leaflet map + all stats + "Add to Watchlist"
- Key new files: `src/lib/shareCode.ts`, `src/lib/locationSync.ts`, `src/pages/GuardianLiveView.tsx`
- Key API files: `artifacts/api-server/src/lib/locationStore.ts`, `artifacts/api-server/src/routes/guardian.ts`

### API Server (`artifacts/api-server`)
- Express 5 + TypeScript, served at `/api`
- **AI Safety endpoint**: `POST /api/ai/safety-query` — streams responses via SSE using OpenAI
- **AI Quick Facts**: `GET /api/ai/quick-facts`
- OpenAI via Replit AI Integrations: `AI_INTEGRATIONS_OPENAI_BASE_URL` + `AI_INTEGRATIONS_OPENAI_API_KEY`
- NCRB 2022 crime data embedded in system prompt (src/lib/ncrb-data.ts)
- Model: gpt-5-mini, streaming SSE

## AI Integration
- Replit AI Integrations (OpenAI) provisioned
- Simulated RAG: NCRB crime data for 10+ major Indian cities embedded as context
- Streaming chat with conversation history support
- Frontend streams SSE chunks and renders progressively
