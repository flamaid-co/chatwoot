#!/usr/bin/env bash
# FlamAid · Chatwoot deploy script
# Run from the server, inside the repo's deploy/ folder:
#   ./scripts/deploy.sh          # image mode (no source edits) — fast
#   ./scripts/deploy.sh --build  # build mode (your UI/source edits) — slower
#
# Idempotent: pulls latest code, updates containers, runs DB migrations, restarts.
set -euo pipefail

cd "$(dirname "$0")/.."   # -> deploy/

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi

COMPOSE=(docker compose -f docker-compose.yaml)
BUILD=false
if [[ "${1:-}" == "--build" ]]; then
  BUILD=true
  COMPOSE+=(-f docker-compose.build.yaml)
fi

echo "==> Pulling latest code (branch: $(git rev-parse --abbrev-ref HEAD))"
git pull --ff-only

if $BUILD; then
  echo "==> Building custom image from source (this can take a while)"
  "${COMPOSE[@]}" build
else
  echo "==> Pulling pinned official image"
  "${COMPOSE[@]}" pull
fi

echo "==> Starting datastores"
"${COMPOSE[@]}" up -d postgres redis
sleep 5

echo "==> Running DB migrations (safe on every deploy)"
"${COMPOSE[@]}" run --rm rails bundle exec rails db:chatwoot_prepare

echo "==> Starting app"
"${COMPOSE[@]}" up -d rails sidekiq

echo "==> Health check"
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api || true)
  [[ "$code" == "200" ]] && { echo "OK — Chatwoot healthy"; break; }
  echo "waiting... ($i) HTTP $code"; sleep 6
done

"${COMPOSE[@]}" ps
