#!/usr/bin/env bash
# statelessness/10-grpc-microservices end-to-end verification (the gRPC
# capstone: postgres + an outbound gRPC upstream + idempotency).
#
# Pass criteria:
#   1. postgres + tax-svc + pricing-svc come up; pricing-svc reports SERVING
#   2. Act 1 (alice, US, taxable): subtotal=8948, tax=626 (7% of 8948),
#      total=9574, and a fresh order_id is minted. Tax MUST be non-zero —
#      a slow-tax-svc deadline that silently returned tax=0 must not
#      masquerade as a pass, so this is asserted as its own check before
#      the exact-value check.
#   3. Act 2 (carol, tax_exempt), run with tax-svc STOPPED: the request
#      still succeeds with tax=0. Stopping the upstream first is the point
#      — if the exempt branch accidentally called out to tax-svc, the RPC
#      would fail (tax-svc unreachable) and the client would print an
#      ERROR, which this script treats as a failure. A pass here is proof
#      of NO outbound call, not just a cheap answer from a live service.
#   4. Act 3 (replay Act 1's idempotency key): returns the SAME order_id as
#      Act 1, and pricing-svc's log shows an "idempotent replay" line for
#      that key (the stored row, not a recomputation).
#
# Calls go through the in-image pricing-client via `docker exec` — no host
# gRPC tooling needed.

set -euo pipefail
export DEMO_NO_PAUSE=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/_helpers.sh"

require docker

DEMO="$REPO_ROOT/examples/statelessness/10-grpc-microservices"
COMPOSE=(docker compose -f compose.yml)
PRICING="stateless-10-pricing"
TAXSVC="stateless-10-tax"
KEY1="K1-$(date +%s)"
cd "$DEMO"

cleanup() { log_step "tearing down"; "${COMPOSE[@]}" down -v --remove-orphans 2>/dev/null || true; }
trap cleanup EXIT

price() { docker exec "$PRICING" /usr/local/bin/pricing-client localhost:50051 "$@" 2>/dev/null; }
# \b matters here: "total=" is a substring of "subtotal=", so an
# unanchored match would read subtotal's value back out under the key
# "total". The word boundary keeps the two fields distinct.
field() { grep -oE "\b$1=[0-9a-zA-Z-]+" | head -1 | cut -d= -f2; }

log_step "Phase 1 — build + bring up postgres + tax-svc + pricing-svc"
"${COMPOSE[@]}" up -d --build

log_step "Phase 1 — waiting for pricing-svc to report SERVING"
serving=0
for _ in $(seq 1 60); do
    if docker exec "$PRICING" /usr/local/bin/health-probe localhost:50051 pricing.v1.Pricing 2>/dev/null | grep -q SERVING; then
        serving=1; break
    fi
    sleep 1
done
if (( ! serving )); then
    log_err "pricing-svc never reported SERVING. Logs:"
    "${COMPOSE[@]}" logs --tail=80 pricing-svc tax-svc postgres 2>&1 || true
    exit 1
fi
log_ok "pricing-svc SERVING"

log_step "Phase 2 — Act 1: price alice (US, taxable) — PG lookups + outbound tax-svc call"
o1="$(price "$KEY1" alice widget:2 gadget:1)"; printf '    %s\n' "$o1"
id1="$(printf '%s\n' "$o1" | field order_id)"
subtotal1="$(printf '%s\n' "$o1" | field subtotal)"
tax1="$(printf '%s\n' "$o1" | field tax)"
total1="$(printf '%s\n' "$o1" | field total)"
if [[ -z "$id1" ]]; then
    log_err "Act 1 did not mint an order_id; got: $o1"
    exit 1
fi
# CRITICAL: tax must be non-zero. A slow-tax-svc deadline that silently
# returns tax=0 must not masquerade as a pass — check this before the
# exact-value check below.
if [[ -z "$tax1" || "$tax1" == "0" ]]; then
    log_err "Act 1 tax is zero/missing — the outbound tax-svc call did not actually compute a tax; got: $o1"
    exit 1
fi
if [[ "$subtotal1" != "8948" || "$tax1" != "626" || "$total1" != "9574" ]]; then
    log_err "Act 1 pricing mismatch: expected subtotal=8948 tax=626 total=9574; got: $o1"
    exit 1
fi
log_ok "order_id=$id1 minted; subtotal=$subtotal1 tax=$tax1 (non-zero, via outbound tax-svc) total=$total1"

log_step "Phase 3 — Act 2: price carol (tax_exempt) with tax-svc STOPPED"
log_info "stopping $TAXSVC first — the exempt path must need no outbound call at all"
docker stop "$TAXSVC" >/dev/null
o2="$(price "K2-$(date +%s)" carol widget:2 gadget:1)"; printf '    %s\n' "$o2"
if [[ "$o2" == ERROR* ]]; then
    log_err "Act 2 failed while tax-svc was stopped — the exempt path must not call tax-svc at all; got: $o2"
    exit 1
fi
tax2="$(printf '%s\n' "$o2" | field tax)"
if [[ "$tax2" != "0" ]]; then
    log_err "Act 2 expected tax=0 for a tax-exempt customer; got: $o2"
    exit 1
fi
log_ok "carol priced with tax=0 while tax-svc was unreachable — exempt path never calls out"

log_step "Phase 4 — Act 3: replay Act 1's idempotency key ($KEY1)"
o3="$(price "$KEY1" alice widget:2 gadget:1)"; printf '    %s\n' "$o3"
id3="$(printf '%s\n' "$o3" | field order_id)"
if [[ -z "$id3" || "$id3" != "$id1" ]]; then
    log_err "replay returned a different order_id ($id3) than Act 1 ($id1) — not idempotent"
    exit 1
fi
if ! "${COMPOSE[@]}" logs pricing-svc 2>/dev/null | grep -qF "idempotent replay key=$KEY1"; then
    log_err "pricing-svc logs do not show an idempotent replay for key=$KEY1"
    "${COMPOSE[@]}" logs --tail=40 pricing-svc 2>&1 || true
    exit 1
fi
log_ok "replay returned the SAME order_id=$id3 from the idempotency store (no recomputation)"

log_step "RESULT"
log_ok "statelessness/10-grpc-microservices verified — composed PG+outbound-gRPC pricing (non-zero tax), tax-exempt short-circuit with NO outbound call, idempotent replay (same order_id)"
