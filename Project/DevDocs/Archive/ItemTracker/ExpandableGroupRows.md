# Feature Specification: Expandable Group Rows in Item Tracker HUD

## 1. Overview
When a tracked rule is configured with `group = true` and `show = true`, it currently summarizes all matching items into a single row. This specification introduces an interactive expandable accordion pattern, allowing players to toggle between a collapsed summary view and an expanded detailed view directly on the HUD row without opening the settings panel.

## 2. User Experience & Interaction Design

### A. Display Modes
1. **Collapsed State (+ Icon Mode):**
   - Appears as a single consolidated row (identical to current behavior).
   - Displays the group icon, group name colorized by highest quality, and the total aggregated count.
   - A toggle indicator (e.g., `+`) is placed next to or in place of the standard icon.

2. **Expanded State (- Icon Mode):**
   - The parent group row remains visible at the top as a summary header, with its toggle indicator changing to `-`.
   - Directly underneath the group header, every individual item belonging to that group is rendered in its own dedicated sub-row.
   - **Sub-Row Indentation & Formatting:**
     - Sub-rows are indented slightly to the right to establish visual hierarchy.
     - Each sub-row displays the item's individual icon, exact link/name, and individual stack count.

### B. Persistence
- Group expansion states are maintained directly on each individual group property (`isExpanded = true/false`) to ensure clean persistence and state management during active play sessions and UI refreshes.

## 3. Technical Implementation Requirements

### A. State Management
- Utilize an `isExpanded` property directly on each group object to track its current view state.
- Provide a toggle interaction handler linked to the group row's icon or toggle button that flips this property and triggers a panel refresh.

### B. Snapshot & Display List Generation
- Modify the display list generation logic so that when a group rule matches and `isExpanded` is true, it inserts the group header row followed immediately by all underlying individual item rows belonging to that group.
- Flag sub-rows with appropriate metadata for custom formatting and indentation.

### C. Rendering & Layout
- Update row layout logic to differentiate between group headers and indented sub-rows, adjusting width constraints and text indentation dynamically.