#!/usr/bin/env bash
# One-time / fresh clone setup (PostgreSQL must be reachable).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
  echo "PostgreSQL is not running. Start it first, e.g.: sudo service postgresql start"
  exit 1
fi

cd "$ROOT/backend"
npm install
npm run prisma:deploy

cd "$ROOT/dashboard"
pnpm install

export PATH="${HOME}/flutter/bin:${PATH}"
if command -v flutter >/dev/null 2>&1; then
  cd "$ROOT/mobile"
  flutter pub get
else
  echo "Flutter not found. Install to ~/flutter or add flutter to PATH, then: cd mobile && flutter pub get"
fi

echo "Setup complete. Run: ./scripts/dev-up.sh"
