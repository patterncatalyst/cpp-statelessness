#!/usr/bin/env bash
# statelessness/09-health-checks end-to-end verification.
#
# Pass criteria:
#   1. image builds; liveness /healthz answers "200 ok" from the moment the
#      process starts, straight through the whole run
#   2. staged startup: readiness (gRPC standard health service) reports
#      NOT_SERVING while the simulated init runs, then flips to SERVING —
#      while liveness stays 200 ok the entire time
#   3. first SIGUSR1 flips readiness back to NOT_SERVING while liveness
#      is unaffected
#   4. second SIGUSR1 restores readiness to SERVING
#   5. SIGTERM (docker stop) runs the staged graceful-shutdown sequence and
#      the container exits 0
#
# Readiness is probed via the in-image health-probe binary (docker exec);
# liveness via curl against the published HTTP port. No host gRPC tooling
# needed.

set -euo pipefail
export DEMO_NO_PAUSE=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/_helpers.sh"

require docker curl

DEMO="$REPO_ROOT/examples/statelessness/09-health-checks"
COMPOSE=(docker compose -f compose.yml)
CTR="stateless-09hc-svc"
SVC="demo.health.EchoService"
LIVENESS_URL="http://127.0.0.1:18080/healthz"
cd "$DEMO"

cleanup() { log_step "tearing down"; "${COMPOSE[@]}" down -v --remove-orphans 2>/dev/null || true; }
trap cleanup EXIT

ready() { docker exec "$CTR" /usr/local/bin/health-probe localhost:50051 "$SVC" 2>/dev/null || true; }
live_body() { curl -fsS --max-time 2 "$LIVENESS_URL" 2>/dev/null || true; }

log_step "Phase 1 — build + bring up health-svc"
"${COMPOSE[@]}" up -d --build

log_step "Phase 1 — waiting for liveness /healthz"
if ! wait_for_http "$LIVENESS_URL" 60; then
    log_err "liveness never answered. Logs:"
    "${COMPOSE[@]}" logs --tail=80 health-svc 2>&1 || true
    exit 1
fi
body="$(live_body)"
if [[ "$body" != "ok" ]]; then
    log_err "expected liveness body 'ok'; got: $body"
    exit 1
fi
log_ok "liveness /healthz: 200 ok"

log_step "Phase 2 — staged startup: readiness starts NOT_SERVING"
r1="$(ready)"
if ! printf '%s\n' "$r1" | grep -q "NOT_SERVING"; then
    log_err "expected readiness NOT_SERVING immediately after startup; got: $r1"
    exit 1
fi
log_ok "readiness NOT_SERVING during init (liveness already 200 ok)"

log_step "Phase 2 — waiting for readiness to flip to SERVING"
serving=0
for _ in $(seq 1 20); do
    if ready | grep -qw SERVING; then serving=1; break; fi
    sleep 0.5
done
if (( ! serving )); then
    log_err "readiness never reached SERVING after staged startup. Logs:"
    "${COMPOSE[@]}" logs --tail=80 health-svc 2>&1 || true
    exit 1
fi
if [[ "$(live_body)" != "ok" ]]; then
    log_err "liveness dropped while readiness was initializing"
    exit 1
fi
log_ok "readiness flipped NOT_SERVING -> SERVING; liveness stayed 200 ok throughout"

log_step "Phase 3 — first SIGUSR1: readiness -> NOT_SERVING, liveness unaffected"
docker kill -s SIGUSR1 "$CTR" >/dev/null
sleep 1
r2="$(ready)"
if ! printf '%s\n' "$r2" | grep -q "NOT_SERVING"; then
    log_err "expected readiness NOT_SERVING after first SIGUSR1; got: $r2"
    exit 1
fi
if [[ "$(live_body)" != "ok" ]]; then
    log_err "liveness went down after SIGUSR1 — it must stay up while only readiness drains"
    exit 1
fi
log_ok "readiness NOT_SERVING after SIGUSR1; liveness still 200 ok"

log_step "Phase 4 — second SIGUSR1: readiness -> SERVING again"
docker kill -s SIGUSR1 "$CTR" >/dev/null
sleep 1
r3="$(ready)"
if ! printf '%s\n' "$r3" | grep -qw SERVING; then
    log_err "expected readiness SERVING after second SIGUSR1; got: $r3"
    exit 1
fi
log_ok "readiness restored to SERVING without a restart"

log_step "Phase 5 — graceful shutdown (SIGTERM via docker stop)"
docker stop -t 30 "$CTR" >/dev/null
logs="$("${COMPOSE[@]}" logs health-svc 2>&1)"
for marker in \
    "SIGTERM: beginning graceful shutdown" \
    "readiness NOT_SERVING (draining" \
    "background worker drained and stopped" \
    "server->Wait() returned"
do
    if ! printf '%s\n' "$logs" | grep -qF "$marker"; then
        log_err "missing shutdown log marker: $marker"
        printf '%s\n' "$logs" | tail -40
        exit 1
    fi
done
exit_code="$(docker inspect "$CTR" --format '{{.State.ExitCode}}' 2>/dev/null || echo 'unknown')"
if [[ "$exit_code" != "0" ]]; then
    log_err "expected the container to exit 0 on graceful stop; got: $exit_code"
    exit 1
fi
log_ok "staged shutdown sequence observed; container exited 0"

log_step "RESULT"
log_ok "statelessness/09-health-checks verified — staged startup, liveness/readiness split, SIGUSR1 readiness toggle, graceful SIGTERM shutdown (exit 0)"
