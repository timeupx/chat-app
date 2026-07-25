# AGENTS.md

## Cursor Cloud specific instructions

This repo is a 3-part chat/live-room app. Only the two Node/web services below are set up for cloud development; `mobile/` (Flutter) is out of scope (see note at the end).

### Services

| Service | Path | Dev command | Port | Notes |
|---------|------|-------------|------|-------|
| Backend API (Express + Socket.IO + Prisma) | `backend/` | `npm run dev` | 4000 | Needs PostgreSQL running first. Seeds admin `admin@example.com` / `Admin@123` on startup. |
| Dashboard (Next.js admin UI) | `dashboard/` | `pnpm dev` | 3000 | Talks to backend via hardcoded `http://localhost:4000` in `dashboard/utils/config.ts`. Log in at `/login`. |

### Startup (must be done each session; NOT handled by the update script)

PostgreSQL is installed in the VM image but is a service, so start it before running the backend:

```bash
sudo pg_ctlcluster 16 main start
```

The `chat-app` database and the `postgres`/`postgres` credentials (matching `backend/.env` `DATABASE_URL`) already exist in the persisted data directory. If the DB is ever missing, recreate it:

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sudo -u postgres psql -c "CREATE DATABASE \"chat-app\";"
cd backend && npx prisma migrate deploy   # applies schema
```

Then start the services (each in its own long-lived shell):

```bash
cd backend && npm run dev      # http://localhost:4000
cd dashboard && pnpm dev       # http://localhost:3000
```

### Lint / test / build

- Dashboard lint: `pnpm lint` (passes with only warnings).
- Dashboard build: `pnpm build`.
- Backend has no test script (`npm test` is a placeholder that errors).
- Backend gotcha: `npm run build` (`tsc`) currently FAILS due to pre-existing type errors in `src/modules/page/*` (references `store`/`page` Prisma models that don't exist and a `MERCHANT` role). This is a pre-existing code issue, not an environment problem. `npm run dev` works because `ts-node-dev --transpile-only` skips type checking — use dev mode to run the backend.

### Other notes

- `dashboard/` has both `pnpm-lock.yaml` and `package-lock.json`; use pnpm (the update script and `pnpm-workspace.yaml` assume pnpm). pnpm ignores build scripts for `sharp`/`unrs-resolver`, which is fine for `next dev`.
- Prisma generates its client to `backend/generated/prisma` (gitignored), so `npx prisma generate` must run after installing backend deps (the update script does this).
- Secrets (JWT, LiveKit key/secret, DB creds) are committed in `backend/.env` and `mobile/.env`. LiveKit points at a hosted Cloud instance, so live audio/video works without a local LiveKit server. SMTP/SMS vars are empty; email/SMS flows degrade gracefully.
- `mobile/` (Flutter) is not set up in the cloud environment — the Flutter SDK is not installed. The `dashboard` is the web client used to exercise the product end-to-end. To work on mobile, install the Flutter SDK, then `cd mobile && flutter pub get && flutter run -d chrome` (Flutter Web talks to the backend via `WEB_BASE_URL=http://localhost:4000`).
