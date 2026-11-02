# AutoCategory Pane UI Improvements (agreed)

All changes target the AutoCategory order editor: `Tracking/EditPanelAutoCategoryTab.xml` / `.lua`.

Status: items 1–4 and 6–7 remain implemented. Items 5, 8, and 9 were revised after the in-game review; rerun the offline suite and verify the revised colors, labels, and alignment in game. Button icons remain on hold.

## 1. Edit Items / Edit Groups button position — DONE
All three panes' tab-switch buttons were anchored 13px below the Title/Other Settings row; moved them up (offsetY 18 → 5) on the AutoCategory, Items, and Groups panes so they line up with Other Settings everywhere.

## 2. Movement bar: reorder buttons and add single steps — DONE
New order, left to right: **Select block, Clear, Up 1, Down 1, Up 5, Down 5, Move to top, Move to bottom.** Up 10 / Down 10 dropped.

## 3. Remove the filter box — DONE
FindBox, search icon, and `searchQuery` filtering removed, including the filtered-selection guard in Select block.

## 4. Rename "Copy both orders" — DONE
Now `Copy from: [context ▾] [Copy]`. Tooltip still explains that it copies **both** the priority and display orders.

## 5. Row colours — REVISED
Inventory Companion groups use a darker shared green in Display and pale green in Priority. Native AutoCategory headings use a non-green blue tint in both modes. Keep the row background available for block selection; verify contrast in game.

## 6. Selection without checkboxes — DONE
Selection checkboxes removed. Single click starts a new selection (re-clicking the only selected row keeps it selected); shift-click adds/removes. Participation checkboxes unchanged.

## 7. Info label text — DONE
Per-mode Display/Priority descriptions with the shared multi-select trailer; Info label grew 52 → 78px.

## 8. Read-only order labels per row — REVISED
The raw `P<n>  D<n>` labels were too obscure. Each orderable row shows an amber divergence marker only when the two lists disagree: `Priority <n>` in Display view or `Display <n>` in Priority view. Put the group name in column 1 and the warning in column 2, right-aligned immediately before the participation checkbox; both labels must align vertically. `ResolveAutoCategoryOrder` exposes `matchingPosition`/`displayPosition` per entry.

## 9. Distinguish IC group names from native AC categories — REVISED
Prefix native AutoCategory headings with `AutoCategory: ` and use a non-green text tint. Do not add a background that could conflict with block selection. Verify the prefix, colors, and clipping in game.

## On hold
- **Icons on/as buttons** (movement bar and the read-only order labels) — hold off for now; revisit after the layout changes land.
