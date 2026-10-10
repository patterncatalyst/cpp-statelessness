#!/usr/bin/env bash
# statelessness/05-threading — CPU-budget detection + pool-sizing demo.
#
# Builds a tiny image (two standalone binaries, no gRPC) and runs it
# under a `--cpus=2` CFS quota to show two things:
#
#   1. cpu-probe — std::thread::hardware_concurrency() reports the HOST's
#      core count, but the cgroup quota inside `--cpus=2` is 2 cores.
#      Sizing a pool from the host probe oversubscribes the CPU.
#
#   2. pool-bench — the same fixed CPU-bound workload run with pool sizes
#      1, 2 (= the quota), 4, and 8, all under `--cpus=2`. Throughput
#      plateaus at the quota; tail latency (p99/max) gets dramatically
#      worse as the pool oversubscribes, because hitting the quota
#      mid-period throttles every thread until the next period boundary.
#
# Uses `docker run --cpus` directly (like demo-05) rather than compose.
# A standard rootful Docker daemon enforces the CFS quota directly; only a
# rootless engine (rootless Docker, or Podman's rootless default) needs the
# cgroup v2 `cpu` controller delegated to your user slice first — which the
# script detects.
#
# Usage:
#   ./demo.sh           build + probe + pool-size sweep
#   ./demo.sh --clean   remove the built image

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
REPO_ROOT="$(cd "$DIR/../../.." && pwd)"

IMG=cpp-tut/stateless-05-threading:latest
CPUS=2
TASKS=2000
ITERS=400000

if [[ "${1:-}" == "--clean" ]]; then
    echo "==> Removing image $IMG"
    docker rmi -f "$IMG" 2>/dev/null || true
    exit 0
fi
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n '2,25p' "$0"; exit 0
fi

# ── cgroup v2 'cpu' controller delegation detection (G-40) ───────────
# This only matters for a ROOTLESS engine (rootless Docker, or Podman's
# rootless default): it needs the cgroup v2 'cpu' controller delegated to
# the user slice before --cpus enforces a real CFS quota. A standard
# rootful dockerd applies the quota directly as root and needs no
# delegation, so skip the check unless Docker is actually running rootless.
HAS_CPU_DELEGATED=1
if docker info --format '{{json .SecurityOptions}}' 2>/dev/null | grep -q 'name=rootless'; then
    HAS_CPU_DELEGATED=0
    DELEGATE_PATH="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.subtree_control"
    if [[ -r "$DELEGATE_PATH" ]]; then
        [[ "$(<"$DELEGATE_PATH")" == *cpu* ]] && HAS_CPU_DELEGATED=1
    fi
fi
if (( ! HAS_CPU_DELEGATED )); then
    echo "WARNING: Docker is running rootless and the cgroup v2 'cpu' controller is"
    echo "  not delegated to your user slice. --cpus=$CPUS will be accepted but the"
    echo "  CFS quota may not be enforced, so the throttling effect below may be"
    echo "  muted (results will reflect the host's cores). To enable real"
    echo "  enforcement:"
    echo "    $REPO_ROOT/scripts/cgroup-delegation.sh enable   # then re-login"
    echo
fi

echo "==> Building $IMG (no gRPC/Conan — this is quick)"
docker build -t "$IMG" -f Containerfile . >/dev/null
echo "    built"

echo
echo "==> Act 1: cpu-probe inside --cpus=$CPUS"
echo "    hardware_concurrency() reports the host; the cgroup quota is the"
echo "    truth the pool should be sized from."
echo "    ------------------------------------------------------------"
docker run --rm --cpus="$CPUS" "$IMG" /usr/local/bin/cpu-probe | sed 's/^/    /'
echo "    ------------------------------------------------------------"

echo
echo "==> Act 2: pool-bench under --cpus=$CPUS — same workload, varied pool size"
echo "    ($TASKS tasks; pool=2 matches the quota)"
echo "    ------------------------------------------------------------"
for p in 1 2 4 8; do
    label=""
    [[ "$p" == "$CPUS" ]] && label="   <- matches the --cpus=$CPUS quota"
    out="$(docker run --rm --cpus="$CPUS" "$IMG" /usr/local/bin/pool-bench "$p" "$TASKS" "$ITERS")"
    if [[ "$out" != pool=* ]]; then
        echo "    ERROR: pool-bench did not produce a result line (got:" >&2
        printf '%s\n' "$out" | head -3 | sed 's/^/      /' >&2
        echo "    ). Check the Containerfile CMD/ENTRYPOINT." >&2
        exit 1
    fi
    printf '    %s%s\n' "$out" "$label"
done
echo "    ------------------------------------------------------------"
echo "    Read across: throughput stops improving past pool=$CPUS (the quota"
echo "    is a fixed CPU-time slice regardless of thread count), while p99"
echo "    and max latency climb sharply as the pool oversubscribes and CFS"
echo "    throttling pauses spread across more threads. A pool sized to the"
echo "    cgroup quota gives the same throughput with far tighter tails."

echo
echo "Done. Re-run with --clean to remove the image."
