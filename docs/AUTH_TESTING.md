# Auth Testing Guide

This document outlines both the automated and manual testing procedures for the Phase 4 authentication implementation.

## Automated Database Tests (pgTAP)
Database integrity is verified automatically using the local pgTAP test suite.
Run tests using:
```bash
npx supabase test db
```

The automated suite verifies:
- `public.profiles` constraints and bindings.
- Automatic profile provisioning via the `auth.users` trigger.
- Security and privilege safety (rejecting direct execution by `anon` or `authenticated`).
- Rejection of malicious metadata during signup.

## Manual Browser Testing
To manually verify the end-to-end authentication flows, follow these steps:

### Setup
Ensure your local Supabase instance is running and the environment variables are configured:
```bash
npx supabase start
cp .env.example .env.local
npm run dev
```

### 1. Signup Flow
- Navigate to `http://localhost:3000/signup`.
- Enter a display name, email, and password.
- Submit the form.
- You should be securely redirected to the account page, confirming automatic session establishment.

### 2. Email Confirmation (If Required)
- *If Supabase Auth is configured to require email confirmations locally (check `supabase/config.toml`), you will need to retrieve the confirmation link via Inbucket (usually accessible at `http://localhost:54324`).*
- By default, local environments may auto-confirm.

### 3. Login Flow
- Log out of your session.
- Navigate to `http://localhost:3000/login`.
- Enter the credentials created in Step 1.
- You should be successfully authenticated and redirected to the account page.

### 4. Invalid Login Test
- Navigate to `http://localhost:3000/login`.
- Enter incorrect credentials.
- You should be redirected to the error page with a clear, safe message indicating failure without leaking sensitive stack traces.

### 5. Protected Account Page Test
- Navigate directly to `http://localhost:3000/account` while logged out.
- You should be intercepted and redirected to the login page.
- When logged in, the page should display your verified `auth.users` data. No domain tables (`customer`, `package`, etc.) are queried or exposed.

### 6. Logout Test
- Click the "Sign Out" button on the account page.
- You should be logged out and securely redirected to the login screen.

### 7. Profile Trigger & Malicious Metadata Verification
- Sign up attempting to pass malicious metadata (this can be simulated via API). 
- Using the local database dashboard (e.g., Supabase Studio at `http://localhost:54323`), inspect the `public.profiles` table.
- Confirm your test user was created, `app_role` is explicitly `NULL`, and any unauthorized bindings were rejected.