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
**Phase 3 — Database Functions, Triggers, and Analytics** (IN PROGRESS)

*Explicit limitations of the current phase:*
- Phase 2 migrations are deployed to remote Supabase.
- The four original Phase 3 migrations were deployed early before final review.
- The local Phase 3 implementation has since been corrected.
- Corrective migration `20260726183243` is prepared locally and is pending final review and remote deployment.
- Phase 3 remains IN PROGRESS.
- Remote and local Phase 3 behavior will not be considered synchronized until the corrective migration is deployed and verified.
- Auth, RLS, and UI modules do not exist yet.

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
