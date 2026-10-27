# ESOUI publishing text formatting

ESOUI's formatted text fields use BBCode (author-supplied reference, 2026-10-27). All publishing text in `Packages\Reviewed\Current Documentation`, including the readme, manual, features, and changelog, uses BBCode despite retained `.md` filenames. Maintain those documents in BBCode when editing them. The root `readme.md` and `UserManual.md` also contain BBCode; do not assume every `.md` file elsewhere uses the same format.

The manual's relative schematic URLs identify companion files for the local handoff. Replace them with actual hosted URLs before pasting into ESOUI; relative local paths are not published image locations.

Use ordinary BBCode conversion and let the field wrap paragraphs naturally. Check the target site's preview before treating the converted text as ready; supported tags and code-block rendering can vary. Keep site-specific examples or workarounds here only if an actual rendering problem requires them.

Use size 2 bold for section headings, such as banking features. Reserve size 4 for document titles, sparingly; do not use size 4 for ordinary sections or size 5 titles.

Keep changelog versions newest first. Write concise player-facing changes, not review provenance or developer-only release-process details.

When combining the readme and features into `Readme_Features.md`, insert `[COLOR="#808080"]________________________________________________________________________________[/COLOR]` with a blank line on each side before the features title to separate the quick overview from the detailed features. This is a fixed-length text divider. The author tested `[HR]` in ESOUI on 2026-10-27 and reported that it does not work; do not use it.
