# Build notes — statelessness decks

Two decks share one python-pptx toolchain in `tools/`:

- **`build-pptx.py`** — shared theme, fonts, and slide-builder helpers
  (loaded via `importlib` by both deck builders below, since its filename
  has a hyphen and can't be `import`ed directly).

## 101 — Statelessness 101 (on-ramp)

- Output: `presentation/cpp-statelessness-101.pptx`
- Build: `./tools/build-statelessness-101-deck.sh`
- Generator: `tools/build-statelessness-101-pptx.py`
- Content source: `tools/sections_statelessness_101.py`
- Total slides: 22
- Sections: 5 (plus title, agenda, closing)
- No diagrams, no demo cues — introductory, text-and-code only, for a
  C++ developer who has not read the compendium. Covers: why
  statelessness matters, the kill/replace/replicate deployment posture,
  a shallow pass over request/process/external-state scope, RAII as the
  mechanism, and a concept map pointing into the 201 deck.
- Prerequisites: python3 + python-pptx + Pillow (no LibreOffice/poppler
  needed at build time — only for optional PDF-based visual QA).

## 201 — Statelessness Compendium (deep deck)

- Output: `presentation/cpp-statelessness-compendium.pptx`
- Build: `./tools/build-statelessness-deck.sh`
- Generator: `tools/build-statelessness-pptx.py`
- Content source: `tools/sections_statelessness.py`
- Total slides: 67
- Sections rendered: 11 (Docs 01–11)
- Diagrams: `diagrams/statelessness/*.svg`, converted to
  `/tmp/diagrams-png/<name>.jpg` by phase 1 of the build script
  (soffice + pdftoppm).
- Prerequisites: python3 + python-pptx + Pillow, soffice (LibreOffice),
  pdftoppm (poppler-utils).

## Note on this file

`build-statelessness-pptx.py` (the 201 builder) regenerates this file's
201-only version every time it runs, as part of its existing behavior —
that write path was left untouched so the 201 build stays unchanged.
If you rerun `./tools/build-statelessness-deck.sh` after this edit, it
will overwrite this combined file with the 201-only notes; re-add the
101 section above (or diff against git) if that happens.

## Visual QA (both decks)

```bash
soffice --headless --convert-to pdf --outdir /tmp "<pptx path>"
pdftoppm -jpeg -r 100 /tmp/<name>.pdf /tmp/qa-slide
```
