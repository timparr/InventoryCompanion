# UI improvements

Decision record for UI discussions. Agreed items are requirements; proposals
and open questions are not approved implementation scope.

## AutoCategory ordering editor

Updated: 2026-11-01. Status: design discussion; not implemented.

### Problem

Long mixed lists of IC groups and native AutoCategory assignments make repeated
single-row moves impractical, especially when moving all native AC assignments
below IC groups.

### Agreed decisions

- Add an ordering toolbar at the bottom of the editor, replacing the heading
  details/about area. The existing heading information is not useful here.
- Retain up-one and down-one controls on the selected block itself, rather than
  moving all movement controls into the toolbar.
- Every orderable row has `^` and `v` controls. On a selected row, either control
  moves the whole selection one step in that direction, not just the clicked row
  or its contiguous run. For non-contiguous selections, use the agreed
  selected-run movement below. Approved from P11.
- Support moving multiple rows together, not just repeated single-row moves.
- Give all selected rows a consistent, clearly visible background colour so
  adjacent selected rows read visually as one block that will move together.
  Keep the selection background visible without hovering and distinct from
  ordinary hover highlighting, while preserving readable row text and controls.
  The highlight follows the selected rows when they move.
- Bottom toolbar movement buttons: Move to top, Move to bottom, Up 5, Down 5,
  Up 10, and Down 10.
- Up/Down 5 and Up/Down 10 produce the same final order as pressing the
  corresponding one-step button five or ten times, including when selected
  runs meet or reach a boundary. Calculate the resulting order first and apply
  it once, as required for all bulk actions.
- Add Select block to the bottom toolbar. It adds to the current selection:
  use every selected row as a seed and select all immediately adjacent rows of
  the same type above and below each seed, stopping at a different type or the
  end of the list. Types are native AC headings and IC groups; this is not
  selection by matching name.
- Select block ticks the selection checkboxes for that contiguous run. For
  example, on an AC heading it selects the touching AC headings above and below
  as well as the current heading, but not AC headings beyond an intervening IC
  group.
- With multiple same-type seeds, Select block expands every seeded run, not
  only the run containing the current row. For example, with IC groups selected
  on either side of an unselected AC heading, it selects all touching IC groups
  around both seeds, leaving the intervening AC heading unselected. Existing
  selections remain checked.
- Disable Select block (also referred to as Select group) when the selected
  rows include both native AC headings and IC groups.
- Allow non-contiguous selections. Up/down one moves each selected run past
  one adjacent unselected row in that direction, without gathering separated
  runs together. A run already at the boundary stays put. Preserve relative
  order within both the selected and unselected sets.
  Example: selecting rows 2 and 4 in `1, [2], 3, [4], 5` and moving up one
  produces `[2], 1, [4], 3, 5`; the moved rows remain selected and highlighted.
- Move to top and Move to bottom gather selected rows into a contiguous block,
  preserving their existing relative order.
- Apply each bulk action as one reorder, rather than repeated single-row
  projections.
- Change only the current context and active order (Display or Priority).
- Nonparticipating IC groups have no ordering position and cannot be selected
  for ordering moves.
- Retain selection after movement and bring the moved selection into view.
- Preserve the relative order of selected rows and of unselected rows.
- Separate selection checkboxes from the existing IC participation checkboxes.
- Add Clear to the bottom toolbar to clear the row selection, not IC
  participation or saved ordering.

### Other questions before implementation

- **Q2.** Choose selection gestures: checkboxes, Shift-click range selection, or both.
- **Q4.** Define Select block behaviour with search active: adjacency in the full order
  versus visible results, without selecting hidden rows unexpectedly.
- **Q5.** Define selection behaviour when changing search, context, or order mode;
  hidden selections must not be moved unexpectedly.

Q6 is parked with the rejected Move to # option below.

### Rejected options

Rejected for now, retained for possible reconsideration: entering a position
number to move selected rows. The confirmed movement controls may make this
unnecessary.

- **P2 (rejected portion).** All AC and All IC selection shortcuts. Clear is
  included in the agreed toolbar instead.
- **P3.** Display row position numbers, including full-order positions when
  filtered. Not needed without numeric position entry.
- **P4.** Move to # places the first selected row at the requested final position.
- **P10.** Move to # gathers selected rows into one contiguous block, preserving
  their existing relative order.
- **Q6.** If revisited, define valid Move to # bounds for a multi-row block and
  show invalid input explicitly rather than silently clamping it.

### Existing implementation

- [Editor controls and selection](../../../Tracking/EditPanelAutoCategoryTab.lua)
- [Editor layout](../../../Tracking/EditPanelAutoCategoryTab.xml)
- [Ordering operations](../../../Tracking/AutoCategoryIntegration.lua)

The current editor selects one reference and exposes per-row one-position moves.
Bulk movement needs a dedicated reorder operation, not a loop over those moves.
