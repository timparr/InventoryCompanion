# AutoCategory Pane UI Improvements (agreed)

All changes target the AutoCategory order editor: `Tracking/EditPanelAutoCategoryTab.xml` / `.lua`.

Status: items 1–9 implemented (offline suite passes; needs in-game verification). Button icons remain on hold.

## 1. Edit Items / Edit Groups button position — DONE
All three panes' tab-switch buttons were anchored 13px below the Title/Other Settings row; moved them up (offsetY 18 → 5) on the AutoCategory, Items, and Groups panes so they line up with Other Settings everywhere.

## 2. Movement bar: reorder buttons and add single steps — DONE
New order, left to right: **Select block, Clear, Up 1, Down 1, Up 5, Down 5, Move to top, Move to bottom.** Up 10 / Down 10 dropped.

## 3. Remove the filter box — DONE
FindBox, search icon, and `searchQuery` filtering removed, including the filtered-selection guard in Select block.

## 4. Rename "Copy both orders" — DONE
Now `Copy from: [context ▾] [Copy]`. Tooltip still explains that it copies **both** the priority and display orders.

## 5. AC category rows coloured per mode — DONE
Native AutoCategory heading rows now tint per mode (green-leaning in Display, violet-leaning in Priority), brighter than the group-row hues. Tune colours in-game if needed.

## 6. Selection without checkboxes — DONE
Selection checkboxes removed. Single click starts a new selection (re-clicking the only selected row keeps it selected); shift-click adds/removes. Participation checkboxes unchanged.

## 7. Info label text — DONE
Per-mode Display/Priority descriptions with the shared multi-select trailer; Info label grew 52 → 78px.

## 8. Read-only order labels per row — DONE
Each orderable row shows `P<n>  D<n>` (priority and display positions) in a dim label before the name; `–` when a position is unavailable (nonparticipants, or pre-reconcile divergence). `ResolveAutoCategoryOrder` now exposes `matchingPosition`/`displayPosition` per entry.

## 9. Distinguish IC group names from native AC categories — DONE (temporary)
Generated IC category names use the white no-op suffix `|cFFFFFF|r` for now; the heading keeps its normal color while the underlying name differs from a native AC category with the same label. The custom v5 SVG remains the planned icon once a game-ready DDS texture is available.

## On hold
- **Icons on/as buttons** (movement bar and the read-only order labels) — hold off for now; revisit after the layout changes land.
