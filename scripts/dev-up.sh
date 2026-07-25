#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMUX="${TMUX:-tmux -f /exec-daemon/tmux.portal.conf}"

if ! pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
  echo "Starting PostgreSQL..."
  sudo service postgresql start
fi

start_tmux() {
  local name="$1"
  local dir="$2"
  local cmd="$3"
  if $TMUX has-session -t "=$name" 2>/dev/null; then
    echo "[$name] already running (tmux session: $name)"
    return
  fi
  $TMUX new-session -d -s "$name" -c "$dir" -- "${SHELL:-bash}" -l
  $TMUX send-keys -t "$name:0.0" "$cmd" C-m
  echo "[$name] started in tmux session: $name"
}

start_tmux backend-dev-server "$ROOT/backend" "npm run dev"
start_tmux dashboard-dev-server "$ROOT/dashboard" "pnpm dev"

echo ""
echo "Backend:   http://localhost:4000"
echo "Dashboard: http://localhost:3000"
echo ""
echo "Mobile (Chrome): cd mobile && flutter run -d chrome"
echo "Admin login:     admin@example.com / Admin@123"
echo "Viewer login:    viewer@test.com / Test@123"
