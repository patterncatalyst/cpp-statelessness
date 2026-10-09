# Build notes — Statelessness decks

## cpp-statelessness-compendium.pptx (201)

- Total slides: 67
- Sections rendered: 11
- Generator: tools/build-statelessness-pptx.py
- Content source: tools/sections_statelessness.py
- Shared builders: tools/build-pptx.py (loaded via importlib)

## cpp-statelessness-101.pptx (101)

- Total slides: 22
- Sections rendered: 5
- Generator: tools/build-statelessness-101-pptx.py
- Content source: tools/sections_statelessness_101.py
- Shared builders: tools/build-pptx.py (loaded via importlib)

Note: tools/build-statelessness-101-pptx.py does not write its own build-notes
file (no NOTES_PATH/notes write step), and tools/build-statelessness-pptx.py
overwrites this file with 201-only content on every run of
build-statelessness-deck.sh. Re-add the 101 section above by hand after
rebuilding the 201 deck, or add a notes-write step to the 101 script so
regeneration doesn't need a manual merge step.
