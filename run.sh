#!/usr/bin/env bash
set -euo pipefail

# --- Styling (ANSI if TTY) ---
if [ -t 1 ]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; CYAN="\033[36m"; GREEN="\033[32m"; RESET="\033[0m"
else
  BOLD=""; DIM=""; RED=""; CYAN=""; GREEN=""; RESET=""
fi

# Pretty output
bold()    { printf "${BOLD}%s${RESET}\n" "$*"; }
info()    { printf "${CYAN}➜%s ${RESET}%s\n" "" "$*"; }
ok()      { printf "${GREEN}✔ %s${RESET}\n" "$*"; }
err()     { printf "${RED}✖ %s${RESET}\n" "$*" >&2; }
success() { printf "${GREEN}✅ %s${RESET}\n" "$*"; }

# Config
IMAGE="vdtyson/demo-dogs:latest"
APP_CNAME="demo-dogs"
LOAD_CNAME="demo-dogs-load-gen"
APP_PORT_HOST="${APP_PORT_HOST:-8000}"

# Helpers
have() { command -v "$1" >/dev/null 2>&1; }
die()  { err "$1"; exit 1; }

# Cleanup on exit
cleanup() {
  info "Cleaning up containers (service + load generator)…"
  docker rm -f "$LOAD_CNAME" "$APP_CNAME" >/dev/null 2>&1 || true
  success "Demo stopped cleanly. Thanks for trying Insights! 🎉"
}
trap cleanup EXIT

# Ctrl-C handler: only acknowledge user input (agent prints its own stop msg)
trap 'bold "Ctrl+C detected — shutting down demo…"' INT

# --- Preflight ---
info "Checking prerequisites…"

# Docker check
have docker || die "Docker not found. Please install Docker: https://docs.docker.com/get-docker/"
docker info >/dev/null 2>&1 || die "Docker daemon not running."

# Insights Agent check (auto-install if missing)
if ! have postman-insights-agent; then
  err "Postman Insights Agent not found."
  info "Installing Insights Agent automatically…"
  bash -c "$(curl -L https://releases.observability.postman.com/scripts/install-postman-insights-agent.sh)" \
    || die "Failed to install Postman Insights Agent."
  # Refresh PATH cache
  hash -r || true
  ok "Postman Insights Agent installed."
fi

# Required env vars
[[ -n "${SERVICE_ID:-}" ]] || die "Missing SERVICE_ID environment variable."
[[ -n "${POSTMAN_API_KEY:-}" ]] || die "Missing POSTMAN_API_KEY environment variable."

echo

# --- App container ---
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

echo
# --- Load generator (quiet: suppress container id) ---
TARGET_URL="http://host.docker.internal:${APP_PORT_HOST}"
docker run -d --rm --name "$LOAD_CNAME" \
  --add-host=host.docker.internal:host-gateway \
  "$IMAGE" python load_gen.py "$TARGET_URL" >/dev/null
ok "Load generator started"

echo

# --- Run the Insights Agent with Repro Mode enabled ---
bold "🚀 Starting the Postman Insights Agent (sudo may prompt)…"
info "Press Ctrl+C to stop; cleanup runs automatically."
echo

sudo POSTMAN_API_KEY="$POSTMAN_API_KEY" \
  postman-insights-agent apidump \
  --project "$SERVICE_ID" \
  --filter "port ${APP_PORT_HOST}" \
  --repro-mode

