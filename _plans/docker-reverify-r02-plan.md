# Docker re-verification r02 — plan & progress

Branch: `verify/docker-reverify-r02`. Relay: Opus plan → Sonnet execute → Opus validate.
Three workstreams run as a pipeline (file collisions in `_docs`/READMEs): **A → B → C**.

## Workstream A — Docker re-verification of all 10 demos — ✅ DONE (10/10 CONFIRMED PASS, Opus-validated)

Validated GO. Caveats (non-blocking): 07-outbox exit code not captured but full-transcript failure scan clean + ran past `verified`; 03-pmr fallback branch provably did not fire. `_config.yml` attribution flipped. 11 checkpoint commits.
Doc-drift found (deferred to B): `_examples/statelessness-10-grpc-microservices.md` has a dangling `CI verification:` ref to a non-existent `scripts/test-stateless-demo-10-grpc-microservices.sh`; demos 09 and 11 lack both a CI script and any CI-verification line.


Sequential, highest-risk-first (fixed host port 50051 reused; shared `~/.conan2` cache).
Transcripts → `.verify-transcripts/<demo>.log` (gitignored, ephemeral). Checkpoint commit per demo.
For scripted demos, pass = exit 0 via `${PIPESTATUS[0]}`. For 09/10/11 (no test script, no exit
gate) assert on specific transcript markers.

| # | Demo | Driver | Status |
|---|------|--------|--------|
| 1 | 07-outbox-pattern (never host-built) | scripts/test-stateless-demo-07-outbox-pattern.sh | PASS — reached final log_ok line, no exit 1 hit (set -euo pipefail) |
| 2 | 09-health-checks | examples/.../09-health-checks/demo.sh (grep) | PASS — liveness 200 throughout, readiness NOT_SERVING↔SERVING on SIGUSR1x2, ordered shutdown exit 0 |
| 3 | 10-grpc-microservices | examples/.../10-grpc-microservices/demo.sh (grep) | PASS — Act1 subtotal=8948 tax=626 (~7%) total=9574; Act2 carol tax=0 no tax call; Act3 replay same order_id |
| 4 | 11-build-tooling | examples/.../11-build-tooling/demo.sh (grep); --clean after | PASS — gtest 15/15; cpu 22→1.5→0.5 w/ hw_concurrency=22, mem=256.0MiB; --clean ran |
| 5 | 02-raii | scripts/test-stateless-demo-02-raii.sh | PASS — exit 0 + "RAII cleanup on every exit path"; acquire=3 release=3 balanced |
| 6 | 03-pmr | scripts/test-stateless-demo-03-pmr.sh (require literal heap-use-after-free) | PASS — real ASan run, literal "heap-use-after-free" caught (not shadow-memory fallback) |
| 7 | 04-process-scoped-state | scripts/test-stateless-demo-04-process-scoped-state.sh | PASS — exit 0 + "composition root, bounded cache, reverse teardown"; cache 4/4 w/ 4 evictions |
| 8 | 07-state-externalization | scripts/test-stateless-demo-07-state-externalization.sh | PASS — exit 0 + "pool RAII, DB-authoritative idempotency, read-back"; fresh/replay/distinct/read-back all correct |
| 9 | 08-ephemeral-filesystem | scripts/test-stateless-demo-08-ephemeral-filesystem.sh | PASS — exit 0 + "verified"; file logger EROFS under --read-only, stdout + tmpfs scratch both succeeded |
| 10 | 05-threading (prior smoke pass) | scripts/test-stateless-demo-05-threading.sh | PASS — exit 0 + "verified"; hw_concurrency=22, cgroup quota=2 under --cpus=2, throughput quota-bound (3205 vs 3189/s) |

Run each from repo root: `DEMO_NO_PAUSE=1 bash <driver> 2>&1 | tee .verify-transcripts/<demo>.log; echo "rc=${PIPESTATUS[0]}"`.
Guard each run: `docker ps` confirms 50051 free first. Never interrupt a build (poisons conan cache).

### Acceptance criteria (per demo)
- 07-outbox: exit 0; projection exactly 1 row for fresh event_id; outbox published_at non-NULL; Act3 duplicate logged + projection still 1.
- 09-health: liveness 200 throughout; readiness NOT_SERVING→SERVING, toggles on SIGUSR1; container exit 0.
- 10-grpc: Act1 alice taxed (7% on subtotal 8948, order_id); Act2 carol tax=0 (no outbound call); Act3 replay identical order_id.
- 11-build-tooling: gtest all-pass; cap sweep reads 1.5 then 0.5+~256MiB while hardware_concurrency stays host count.
- 02-raii: exit 0 + "RAII cleanup on every exit path".
- 03-pmr: exit 0 + literal `heap-use-after-free` (NOT shadow-memory fallback → else INCONCLUSIVE).
- 04-process-scoped-state: exit 0 + composition root / bounded cache / reverse teardown.
- 07-state-ext: exit 0 + fresh insert idempotent_replay=false, replay returns stored row, read-back.
- 08-ephemeral-fs: exit 0 + file logger EROFS under --read-only, stdout works, tmpfs scratch writable.
- 05-threading: exit 0 + cgroup limit=2 under --cpus=2 while hardware_concurrency=22, throughput quota-bounded.

### Attribution (A)
- Flip stale: `_config.yml:6` and `_config.yml:35` ("Podman examples" → "Docker").
- Refresh `_examples/*.md` representative-output blocks only where fresh Docker output materially differs.
- Leave the ~32 intentional "Podman differs" asides untouched.

## Workstream B — professional-voice pass (after A)
34 ban-tier hits. Edit prose only: 10-grpc README ("capstone"→"end-to-end example", drop "deliberately"),
`_docs/06,09,11` one-liners, deck sources `tools/build-statelessness-pptx.py` + sections_*.py. Keep code-file
comment hits (conanfile.py, CMakeLists.txt) and recorded transcripts. Re-scan after; ban-tier near zero.

## Workstream C — diagram review (after B)
Review 13 pairs for consistency + label voice. Fixes:
1. Create `08-deadline-budget-flow` (SVG + .excalidraw) — deadline budget across gRPC→Postgres→tax-svc hops.
   Embedded in `_docs/07-state-externalization.md:202` and `_docs/10-grpc-microservices.md:58` (currently placeholder).
2. `diagrams/statelessness/10-grpc-microservices.svg` title "gRPC capstone" → "gRPC end-to-end example"
   (regenerate SVG + .excalidraw), matching the doc caption.

## Push
Do NOT push. Final push only on explicit user permission.
