#!/usr/bin/env bash
# statelessness/11-build-tooling end-to-end verification (the vendored
# cgroup/PSI helpers, swept under different cgroup caps).
#
# Pass criteria:
#   1. image builds (the build itself gates on ctest; this script also runs
#      the gtest binary directly so its PASS summary is on the record)
#   2. the gtest suite over the helpers' pure parsers passes in full:
#      "[  PASSED  ] 15 tests." and no "[  FAILED  ]" line
#   3. unconstrained run: with no cpu.max quota set, cpu_limit_cores() falls
#      back to sched affinity and reports the host core count (the SAME
#      number hardware_concurrency() reports); memory_limit_bytes() reports
#      "unbounded". (The literal string "unconstrained" is cpu_limit_cores()'s
#      fallback-of-last-resort when even sched_getaffinity fails — under
#      Docker that never happens, so this is the real, demonstrated path,
#      matching demo.sh's own "cpu falls back to the host core count" note.)
#   4. `--cpus=1.5`: cpu_limit_cores() reads back "1.5 cores" from cgroup
#      v2 cpu.max
#   5. `--cpus=0.5 --memory=256m`: cpu_limit_cores() reads "0.5 cores" and
#      memory_limit_bytes() reads "268435456 bytes (256.0 MiB)"
#   6. across all of the above, hardware_concurrency() — "what a naive pool
#      would use" — stays pinned to the SAME host core count regardless of
#      the cgroup cap. This is asserted by comparing to the unconstrained
#      reading rather than a hard-coded number, since the host's core count
#      varies by machine.

set -euo pipefail
export DEMO_NO_PAUSE=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/_helpers.sh"

require docker

DEMO="$REPO_ROOT/examples/statelessness/11-build-tooling"
IMG=cpp-tut/stateless-11-build-tooling:latest
cd "$DEMO"

cleanup() { log_step "removing image"; docker rmi -f "$IMG" 2>/dev/null || true; }
trap cleanup EXIT

run() { docker run --rm "$@" "$IMG"; }           # cap flags BEFORE the image
run_cmd() { docker run --rm "$IMG" "$@"; }        # command AFTER the image

hw_concurrency() { printf '%s\n' "$1" | grep -oE 'hardware_concurrency\(\): [0-9]+' | grep -oE '[0-9]+' | head -1; }

log_step "Phase 1 — build the image (compiles GoogleTest + runs the gtest gate)"
docker build -t "$IMG" -f Containerfile . >/dev/null
log_ok "image built (ctest gate passed at build time)"

log_step "Phase 2 — unit tests: gtest suite over the pure parsers"
out="$(run_cmd /usr/local/bin/helper-tests 2>&1)" || {
    log_err "helper-tests exited non-zero"
    printf '%s\n' "$out"
    exit 1
}
if printf '%s\n' "$out" | grep -q '\[  FAILED  \]'; then
    log_err "gtest reported a failure:"
    printf '%s\n' "$out"
    exit 1
fi
if ! printf '%s\n' "$out" | grep -qE '\[  PASSED  \] 15 tests\.'; then
    log_err "expected '[  PASSED  ] 15 tests.'; got:"
    printf '%s\n' "$out"
    exit 1
fi
log_ok "gtest suite: 15/15 tests passed"

cpu_limit_val() { printf '%s\n' "$1" | grep -oE 'cpu_limit_cores\(\)[[:space:]]*: [0-9.]+ cores' | grep -oE '[0-9.]+ cores' | cut -d' ' -f1; }

log_step "Phase 3 — unconstrained: no cgroup caps"
out="$(run 2>&1)" || { log_err "unconstrained run failed"; printf '%s\n' "$out"; exit 1; }
if ! printf '%s\n' "$out" | grep -qE 'memory_limit_bytes\(\)[[:space:]]*: unbounded'; then
    log_err "expected memory_limit_bytes() : unbounded; got:"
    printf '%s\n' "$out"
    exit 1
fi
hwconc="$(hw_concurrency "$out")"
if [[ -z "$hwconc" || "$hwconc" -lt 1 ]]; then
    log_err "could not read a sane hardware_concurrency() baseline from:"
    printf '%s\n' "$out"
    exit 1
fi
cpu0="$(cpu_limit_val "$out")"
if [[ -z "$cpu0" ]]; then
    log_err "could not read cpu_limit_cores() from unconstrained run:"
    printf '%s\n' "$out"
    exit 1
fi
if [[ "$cpu0" != "$hwconc" ]]; then
    log_err "unconstrained cpu_limit_cores()=$cpu0 should equal the sched-affinity fallback = hardware_concurrency()=$hwconc"
    exit 1
fi
log_ok "unconstrained: memory unbounded; cpu_limit_cores() falls back to sched affinity = hardware_concurrency()=$hwconc (host core count, baseline)"

log_step "Phase 4 — docker run --cpus=1.5"
out="$(run --cpus=1.5 2>&1)" || { log_err "--cpus=1.5 run failed"; printf '%s\n' "$out"; exit 1; }
if ! printf '%s\n' "$out" | grep -qE 'cpu_limit_cores\(\)[[:space:]]*: 1.5 cores'; then
    log_err "expected cpu_limit_cores() : 1.5 cores; got:"
    printf '%s\n' "$out"
    exit 1
fi
hwconc2="$(hw_concurrency "$out")"
if [[ "$hwconc2" != "$hwconc" ]]; then
    log_err "hardware_concurrency() changed under --cpus=1.5 (baseline=$hwconc, got=$hwconc2) — it must stay pinned to the host count"
    exit 1
fi
log_ok "cpu.max read back as 1.5 cores; hardware_concurrency() still $hwconc2 (unchanged from baseline)"

log_step "Phase 5 — docker run --cpus=0.5 --memory=256m"
out="$(run --cpus=0.5 --memory=256m 2>&1)" || { log_err "--cpus=0.5 --memory=256m run failed"; printf '%s\n' "$out"; exit 1; }
if ! printf '%s\n' "$out" | grep -qE 'cpu_limit_cores\(\)[[:space:]]*: 0.5 cores'; then
    log_err "expected cpu_limit_cores() : 0.5 cores; got:"
    printf '%s\n' "$out"
    exit 1
fi
if ! printf '%s\n' "$out" | grep -qF '268435456 bytes (256.0 MiB)'; then
    log_err "expected memory_limit_bytes() : 268435456 bytes (256.0 MiB); got:"
    printf '%s\n' "$out"
    exit 1
fi
hwconc3="$(hw_concurrency "$out")"
if [[ "$hwconc3" != "$hwconc" ]]; then
    log_err "hardware_concurrency() changed under --cpus=0.5 --memory=256m (baseline=$hwconc, got=$hwconc3) — it must stay pinned to the host count"
    exit 1
fi
log_ok "cpu.max read back as 0.5 cores; memory.max read back as 256 MiB; hardware_concurrency() still $hwconc3 (unchanged — the Doc 05 trap)"

log_step "RESULT"
log_ok "statelessness/11-build-tooling verified — gtest gate (15/15), cgroup-aware cpu/memory readings track --cpus/--memory, hardware_concurrency() stays pinned to the host count"
