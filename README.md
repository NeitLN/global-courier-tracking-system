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
**Phase 4 — Authentication and role profiles** (IN PROGRESS)

*Explicit limitations of the current phase:*
- Phase 3 functions and triggers are implemented and locally synchronized.
- Phase 4 implements Supabase Auth, SSR clients, and public.profiles.
- Current database validation is 188/188 tests passing.
- Phase 5 is NOT STARTED.
- **WARNING:** RLS is not implemented until Phase 5, so real or sensitive data and public application access must not be enabled yet.

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
