#!/usr/bin/env bash
set -euo pipefail

# Pretty output
bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "➜ %s\n" "$*"; }
ok() {   printf "✔ %s\n" "$*"; }
err() {  printf "\033[31m✖ %s\n" "$*" >&2; }

# Config
IMAGE="vdtyson/demo-dogs:latest"
APP_CNAME="demo-dogs"
LOAD_CNAME="demo-dogs-load-gen"
APP_PORT_HOST="${APP_PORT_HOST:-8000}"

# Helpers
have() { command -v "$1" >/dev/null 2>&1; }
die() { err "$1"; exit 1; }

# Check that Docker is present & running
have docker || die "Docker not found. Install Docker and retry."
docker info >/dev/null 2>&1 || die "Docker daemon not running."

# Check if the Insights agent is missing
have postman-insights-agent || die "Postman Insights Agent not found. Install the Insights Agent and retry."

# Check required env. variables
[[ -n "${SERVICE_ID:-}" ]] || die "Missing SERVICE_ID environment variable."
[[ -n "${POSTMAN_API_KEY:-}" ]] || die "Missing POSTMAN_API_KEY environment variable."

# Cleanup on exit
cleanup() {
	info "Cleaning up..."
	docker rm -f "$LOAD_CNAME" "$APP_CNAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Pull & run app (host-published port so agent can see traffic)
bold "Starting Demo Dogs service and load generation"
info "Using port ${APP_PORT_HOST}. Change with APP_PORT_HOST=<port>."

docker pull "$IMAGE" >/dev/null
docker rm -f "$APP_CNAME" >/dev/null 2>&1 || true
docker run --rm -d --name "$APP_CNAME" -p "${APP_PORT_HOST}:80" "$IMAGE" >/dev/null
ok "Service started: http://localhost:${APP_PORT_HOST}"

# Readiness check
for i in {1..30}; do
  if curl -fsS "http://localhost:${APP_PORT_HOST}/health" >/dev/null 2>&1; then
    ok "Service is ready"
    break
  fi
  [[ $i -eq 30 ]] && die "Service did not become ready on port ${APP_PORT_HOST}."
  sleep 1
done

# Start the load generator (container hitting host service)
TARGET_URL="http://host.docker.internal:${APP_PORT_HOST}"
docker run -d --rm --name "$LOAD_CNAME" \
  --add-host=host.docker.internal:host-gateway \
  "$IMAGE" python load_gen.py "$TARGET_URL"
ok "Load generator started"

# Start the Insights agent w/ Repro mode
bold "Starting the Postman Insights Agent (sudo may prompt)…"
info "Press Ctrl+C to stop; cleanup runs automatically."

sudo POSTMAN_API_KEY="$POSTMAN_API_KEY" \
  postman-insights-agent apidump \
  --project "$SERVICE_ID" \
  --repro-mode
