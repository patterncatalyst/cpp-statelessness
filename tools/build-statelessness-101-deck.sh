#!/usr/bin/env bash
# build-statelessness-101-deck.sh — rebuild the STATELESSNESS 101 PPTX.
#
# Companion to build-statelessness-deck.sh (the 201 compendium deck). The
# 101 deck is text-and-code only — no diagrams — so there is no SVG → JPG
# conversion phase here; this script just checks prerequisites and runs
# the Python build.
#
# Run from the project root:
#   ./tools/build-statelessness-101-deck.sh
#
# Prerequisites: python3 + python-pptx + Pillow.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_PPTX="$ROOT/presentation/cpp-statelessness-101.pptx"

echo "==> Checking Python prerequisites"
for mod in pptx PIL; do
    python3 -c "import $mod" 2>/dev/null || {
        echo "  ERROR: python module '$mod' not installed" >&2
        echo "  Install: pip install python-pptx Pillow" >&2
        exit 1
    }
done

echo "==> Building PPTX"
python3 "$ROOT/tools/build-statelessness-101-pptx.py"

echo
echo "==> Done."
echo "    Output: $OUT_PPTX"
echo "    Size:   $(du -h "$OUT_PPTX" | cut -f1)"
echo
echo "Visual QA — render the deck to JPGs for inspection:"
echo "  soffice --headless --convert-to pdf --outdir /tmp \"$OUT_PPTX\""
echo "  pdftoppm -jpeg -r 100 /tmp/cpp-statelessness-101.pdf /tmp/qa-101-slide"
