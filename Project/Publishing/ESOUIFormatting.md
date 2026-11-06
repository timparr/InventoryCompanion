# ESOUI publishing text formatting

ESOUI's formatted text fields use BBCode (author-supplied reference, 2026-10-27). The authoritative readme header/body, manual, and changelog are `.bbcode` files in `Project\Publishing\Source Documents`. The packaging script combines the readme header and body into `ReadMe.bbcode` for both the ZIP and upload folder. Keep genuine Markdown documents, plans, and checklists as `.md`; the retired feature overview is archived under `Project\Publishing\Archive`. Historical release snapshots retain their original names. Source SVGs for the manual are in `Project\Publishing\Resources`.

For local editing, the VS Code extension **BBCode Preview** (`gimucco.bbcode-preview`) recognises `.bbcode` files and provides a live preview. Its rendering is a convenience, not a substitute for ESOUI's own preview.

The manual's relative schematic URLs identify companion files for the local handoff. Replace them with actual hosted URLs before pasting into ESOUI; relative local paths are not published image locations.

Use ordinary BBCode conversion and let the field wrap paragraphs naturally. Check the target site's preview before treating the converted text as ready; supported tags and code-block rendering can vary. Keep site-specific examples or workarounds here only if an actual rendering problem requires them.

Use size 2 bold for section headings, such as banking features. Reserve size 4 for document titles, sparingly; do not use size 4 for ordinary sections or size 5 titles.

Keep changelog versions newest first. Write concise player-facing changes, not review provenance or developer-only release-process details.

Do not manually combine, copy, or rename the readme parts during handoff. Stage generates the combined readme once and freezes the exact bytes into the release candidate; finalization places the same file in the ZIP and upload folder.
