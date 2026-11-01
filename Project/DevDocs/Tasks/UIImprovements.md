# AutoCategory Pane UI Improvements (agreed)

All changes target the AutoCategory order editor: `Tracking/EditPanelAutoCategoryTab.xml` / `.lua`.

## 1. Edit Items / Edit Groups button position
Buttons sit too low. Re-anchor them to line up with the Title / Other Settings row so the pane matches the other editor panes.

## 2. Movement bar: reorder buttons and add single steps
New order, left to right: **Select block, Clear, Up 1, Down 1, Up 5, Down 5, Move to top, Move to bottom.**
- Add Up 1 / Down 1 to the toolbar (the movement loop already handles arbitrary step values).
- Drop Up 10 / Down 10.

## 3. Remove the filter box
Remove the FindBox/search icon and the `searchQuery` filtering. Filtering an ordering list makes no sense — you can't tell what you're moving against. Also removes the filtered-selection guard in Select block.

## 4. Rename "Copy both orders"
Replace the current `[CopyContext combo] [Copy both orders]` with: `Copy from: [backpack ▾] [Copy]`.
Keep the tooltip explaining that it copies **both** the priority and display orders from the chosen context.

## 5. AC category rows coloured per mode
Native AutoCategory category (heading) rows are currently always gold; tint them per mode like the group rows (two variants, one per mode).

## 6. Selection without checkboxes
Remove the left-hand selection checkbox from rows. New click semantics:
- **Single click** — start a new selection (just this row). Clicking the only selected row keeps it selected (no deselect toggle).
- **Shift-click** — add/remove the row from the current selection.
The **participation checkbox stays** — only the selection checkboxes go.

## 7. Info label text
Per-mode text:

> **Priority Order** — Choose the order that AutoCategory applies the rules to decide which group an item is in. Only applies when an item might be in more than one group.

> **Display Order** — Choose the order the categories appear in your inventory. You can untick an Inventory Companion group to have it ignored by AutoCategory completely.

Shared trailer under both:

> You can move several groups at once. Click a group to select it. Hold shift to add a group to the current selection, then use the buttons at the bottom to move them all together.

The combined text is longer than the current label; resize the Info label and shorten the list to fit.

## 8. Read-only order labels per row
Show the row's Priority number and Display position as read-only labels in each view (i.e. show the *other* order's index too). May need `AutoCategoryIntegration` to expose both indices per entry.

## 9. Remove icon from IC group names
IC group rows no longer need the icon in their name — they read as native entries now.

## On hold
- **Icons on/as buttons** (movement bar and the read-only order labels) — hold off for now; revisit after the layout changes land.
