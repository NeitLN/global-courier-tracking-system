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
**Phase 5 — RLS and authorization** (IN PROGRESS)

*Explicit limitations of the current phase:*
- Phase 3 functions and triggers are implemented.
- Phase 4 Auth profiles and session foundation are remotely deployed and verified.
- Phase 5 establishes complete Row-Level Security, removing ambient privileges, creating private authorization helpers, defining explicitly constrained RPCs, and applying granular access controls across all 14 public tables.
- Current database validation is 239/239 tests passing locally.
- Phase 6 is NOT STARTED.
- Remote database deployment of Phase 5 migrations has not yet occurred.

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
