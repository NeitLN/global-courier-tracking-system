# Global Courier & Tracking System

A role-based courier database and dispatch control system built with Next.js, Supabase and PostgreSQL.

## Documentation
Please refer to the following files for the authoritative rules and project state:
- [PROJECT_SOURCE_OF_TRUTH.md](./docs/PROJECT_SOURCE_OF_TRUTH.md)
- [STATUS_FLOW.md](./docs/STATUS_FLOW.md)
- [TRACEABILITY_MATRIX.md](./docs/TRACEABILITY_MATRIX.md)
- [DECISION_LOG.md](./docs/DECISION_LOG.md)
- [PHASE_PROGRESS.md](./docs/PHASE_PROGRESS.md)

## Current Stage
**Phase 2 — Supabase Database Migrations** (COMPLETE)

*Explicit limitations of the current phase:*
- Local database structural schema is fully implemented and validated.
- Remote Supabase database has not been migrated yet.
- F1-F10, complex triggers, Auth, RLS, and UI modules do not exist yet.

## Technology Foundation
- Next.js (App Router)
- TypeScript
- Tailwind CSS
- ESLint
- Supabase (Backend platform)

## Required Software
- Node.js
- npm
- Git

## Installation

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd global-courier-tracking-system
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env.local
   ```
   *Warning: Never commit `.env.local` or expose any actual secrets, service-role keys, passwords, or tokens in tracked files.*

4. Run the development server:
   ```bash
   npm run dev
   ```

## Validation Commands
You can run the following commands to validate the foundation:
```bash
npm run lint
npm run typecheck
npm run build
npm run check
npx supabase --version
```

## Local URL
[http://localhost:3000](http://localhost:3000)
