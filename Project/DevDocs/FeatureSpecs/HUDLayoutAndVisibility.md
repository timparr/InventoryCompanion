# HUD layout and visibility

Status: Approved to Implementation
TODO items: [D10.1 positioning, D10.2 vanishing bars, D10.3 currency columns](../../Tasks/TODO.md)
Owner: Copilot (draft author)
Updated: 2026-11-06
Implementation plans: [Positioning and bars](../Plans/ProgressBarVisibilityImplementationPlan.md),
[currency columns](../Plans/CurrencyGridColumnsImplementationPlan.md)

Follow the [feature development process](../../Processes/FeatureDevelopment.md).
Behavior below is proposed except where explicitly recorded as agreed.

## Tickets and delivery boundaries

One product spec covers three separately tracked implementation tickets:

| Ticket | Outcome | Acceptance criteria |
|---|---|---|
| D10.1 | Provide the shared HUD positioning and configuration experience. | AC8-AC10, AC12-AC13 |
| D10.2 | Hide each enabled bar below its configured threshold, optionally also when empty. | AC1-AC7, AC11 |
| D10.3 (formerly F1) | Choose currency-grid columns. | CG1-CG6 |

Agreed by Tim, 2026-11-06: combine these in one spec, with separate tickets.
This spec defines the complete product behavior across all three tickets; the
tickets may be implemented in any order. Shared profile, editor-session and
lifecycle behavior must stay consistent across them. UI staging, including
whether any controls are initially placeholders, belongs in the implementation
plan and does not change the required final behavior. Global HUD show/hide
context-menu work (D5) remains separate, not implicitly included in
threshold-based bar visibility.

## Problem and intended outcome

Enabled standalone resource bars occupy HUD space even when capacity or currency
usage is comfortably low. Let users retain monitoring while showing a bar only
when its fill reaches a chosen level: less routine clutter, useful information
when approaching a limit.

Hidden elements also need a discoverable positioning mode. The fixed three-column
currency grid limits HUD layout choices; adjustable columns complement positioning,
although this is convenience rather than a reported usability defect.

## Scope and non-goals

- In scope (agreed per-bar control): independent visibility thresholds for existing backpack, bank, and
  capped-currency standalone bars.
- In scope (agreed): shared HUD positioning for the tracker, currency summary
  panel, and standalone bars, with settings, slash and keybinding entry points.
- In scope: configurable currency-summary grid columns, tracked separately as D10.3.
- In scope (Tim requested, 2026-11-06): live configuration during HUD positioning:
  bar enable/visibility controls, currency column count, and tracker maximum rows.
  Configuration-pane layout and relocation of existing addon settings remain open.
- Out of scope: normal-operation summary-grid hiding or tracker behavior changes, animations, bar stacking,
  automatic repositioning, notifications, and bank-transfer milestone messages.

## User experience and behavior

- Keep "Show <resource> Bar" as the master enable switch.
  Updated UI direction: an unlabelled enable checkbox with a resource-specific
  tooltip ("Show a bar for Transmutes", for example), beside the visibility slider.
  Agreed: the slider is disabled whenever that checkbox is off. Checkbox state
  remains showBar; changing it does not clear the saved threshold.
  Proposed row: `[x] Show above [slider] 0%`; final wording remains unsettled
  because visibility includes equality, not just values strictly above.
- Add "Hide Below (%)" to each bar's Advanced Settings: integer 0-100, default 0.
  Agreed defaults: Hide Below = 0 and Hide When Empty ticked.
  Add an independent per-bar "Hide When Empty" checkbox, default on (agreed).
  When enabled, hide the bar when the resource amount is zero, regardless of
  the percentage threshold. A positive amount must still meet Hide Below (%).
  Both visibility controls are disabled while the master Show Bar switch is off.
  UI preference (want, not a requirement): place Hide When Empty to the right
  of the slider in the same row, and make it invisible when Hide Below is above
  0. Retain its saved value while invisible so it applies again at 0.
  Verify LAM width/layout feasibility before choosing a custom row; a separate
  checkbox remains an acceptable fallback if the preferred layout is impractical.
  Explain: "Hide this bar while usage is below this percentage. 0 always shows
  an enabled bar; 100 shows it only when full."
- The threshold slider is disabled while its bar is switched off. Warning and
  danger thresholds remain independent; hiding does not change alert colors or
  notification behavior.
- Compare the actual fill fraction, not rounded label text. Below the threshold
  the whole bar (icon, frame, fill, label) vanishes; exactly at or above it the
  whole bar appears, provided it is enabled and not cutscene-suppressed.
- Example: at threshold 75, 74/100 is hidden, 75/100 is visible, and dropping
  back to 74/100 hides it again. At threshold 0, an enabled empty bar is visible
  unless Hide When Empty is enabled.
- Reevaluate after relevant amount/capacity/cap updates through existing event
  refreshes, and immediately after changing the setting or active profile.
  Hidden bars continue monitoring. Do not add polling or promise a new timing
  guarantee beyond the existing event/debounce pipeline.
- Cutscenes still hide bars. On return, recompute against current values; do not
  reveal a below-threshold bar just because the cutscene ended.
- Keep each bar's saved position while hidden. It reappears in that position;
  other bars do not move into the gap. Use the agreed HUD positioning mode below
  to move hidden elements without changing thresholds.
- Missing resource values remain hidden as today. For a zero/nonpositive cap,
  retain the existing calculation of 0%: hidden for positive thresholds; at
  threshold 0, visibility follows Show Bar, Hide When Empty and cutscene state.
  This closes Q9 without adding special zero-cap behavior.
- Agreed: preferences follow the existing "Use Character Settings" switch.
  Off uses shared account-wide thresholds; on uses the character's thresholds,
  alongside its other bar settings. No separate ownership switch is added.
  Preferences participate in full-profile copy.
  Reset Panel in currency settings continues to leave standalone bars alone.

### Agreed settings layout

The settings-location examples below predate the live HUD configuration proposal.
They specify control behavior/layout trials, not a settled requirement to duplicate
controls in both addon settings and the HUD editor. The agreed Manage HUD panel
below owns enable/visibility, column and max-row controls without LAM duplicates.

Latest UI direction (Tim, 2026-11-06): treat each resource as a list item.
Evaluate both layouts below; the developer should choose the best-fitting option.
There is no conflict between the variants, and choosing between them must not
change the agreed inclusive threshold behavior. They supersede the earlier
separate Show Bar/Hide Below placement proposal. The unlabelled checkbox controls
showBar, has a resource-specific tooltip, and disables the slider when unchecked.
Agreed: clicking either the resource name ("Transmutes") or its checkbox toggles
the same showBar flag exactly once. This applies to every resource in both layout
trials; toggling retains the threshold and immediately updates slider enabled state.

```text
Variant A:
  [x] Transmutes  show above: [-------o--------] 75%

Variant B:
  [x] Transmutes
  Show when % > [-------o--------] 75%
```

Checkbox placement is agreed: checkbox first, resource name to its right,
matching existing currency-settings checkboxes; either remains clickable.
Final wording must reconcile "above" / ">" with showing at equality. Retain the
optional Hide When Empty control to the slider's right, visible only at 0 if
feasible. Existing warning/danger/color controls remain available; assess their
placement with these list-item variants.

Agreed by Tim, 2026-11-06: place "Hide Below (%)" first inside each bar's
existing Advanced Settings, above Warning Threshold. No separate threshold window
or global threshold control. This ASCII wireframe illustrates the layout; slider positions
are schematic and the existing advanced sections remain expandable.

```text
Standalone Progress Bars
  [x] Show Backpack Bar
  v Backpack Bar Advanced Settings
      Hide Below (%)         [o--------] 0
      [x] Hide When Empty
      Warning Threshold (%)  [----o----] 75
      Danger Threshold (%)   [-------o-] 90
      Normal Bar Color       [ colour ]

  [x] Show Bank Bar
  > Bank Bar Advanced Settings

  [ ] Show <capped currency> Bar
  > <currency> Bar Advanced Settings
  ... repeated for each capped currency ...

  Shared Alert Colors
      Warning Color          [ colour ]
      Danger Color           [ colour ]
```

Preferred combined row, if feasible (optional enhancement to the wireframe):

```text
      Hide Below (%)  [o--------] 0    [x] Hide When Empty
      Hide Below (%)  [----o----] 50   <checkbox invisible>
```

The hidden checkbox retains its value; it is redundant above 0 because an empty
bar already fails the percentage threshold.

### Agreed HUD positioning mode

Agreed by Tim, 2026-11-06:

- Provide all three entry points: a "Position HUD Elements" settings button,
  a slash command (proposed `/iclayout`), and a configurable ESO keybinding
  (proposed label "Position HUD Elements"; no default key proposed).
- Settings entry closes settings so they do not obscure the HUD. An on-screen
  **Done** button exits without returning to settings.
- Temporarily show all movable HUD elements, including normally disabled or
  threshold-hidden ones. Use their actual controls, fonts, spacing and sizing:
  no substitute boxes, added preview labels, or separate mock panels.
- Show real data only. Do not add dummy entries/rows or fabricate bar values;
  empty or unavailable HUD elements retain their normal rendering and are not
  given substitute geometry just to make them movable.
- Positioning may temporarily reveal actual bars that are disabled or below
  threshold, using current resource values. This visibility override must not
  change their saved enable switches or thresholds.
- Dragging and configuration edits are previewed in the active profile's
  positioning session. Done commits the session; Cancel and automatic exits
  discard its edits and restore the starting HUD settings and positions. Do not
  change tracked data or introduce synthetic data into matching, notifications
  or transfers.
- Slash command and hotkey are proposed to toggle this same mode; the on-screen
  Done button remains available regardless of how it was entered.
- Agreed: end positioning automatically on profile changes, reload, or entering
  a cutscene/interaction. Done commits moved positions only to the profile in
  which they were edited; automatic exits cancel the session and do not carry it
  into another profile.
  Agreed: entering combat also ends positioning; entry is blocked while already
  in combat, regardless of whether settings, slash command or hotkey is used.

Schematic placement only; real elements keep their normal appearance:

```text
Settings:
  HUD Positioning
      [ Position HUD Elements ]

On screen while positioning:
             Drag HUD elements into position.  [ Done ]

  <actual item tracker: current content, if any>
  <actual currency panel: current content, if any>
  <actual backpack, bank and capped-currency bars>
```

Command name and keybinding label remain proposals.

### Currency grid columns (D10.3)

These details remain proposals transferred from the initial F1 draft:

- Add a "Grid Columns" integer slider to the Manage HUD Currency Summary section:
  agreed range 1 through the number of available resource cells, default 3.
  Available means before visibility/zero filtering, using normal combined-cell
  grouping, not the currently displayed count. Keep the range large enough to
  represent the default 3. One column makes a vertical list; the maximum permits
  a horizontal strip. Reflow immediately without reload; commit the choice only
  when the positioning session is completed with Done.
  Visibility filtering must not alter the slider range or saved column choice.
  If resource discovery later yields fewer cells than a saved valid choice, cap
  the effective column count to the new maximum when the setting is read. Do not
  treat the previously valid saved choice as malformed.
- Preserve resource order, selected locations, combined-location cells, formatting,
  zero filtering, measured cell widths and spacing. Fill left-to-right, then
  top-to-bottom. Use only occupied columns when fewer cells exist; no cells
  means hidden during normal operation.
- Seven cells produce seven rows at 1 column, three rows (3/3/1) at 3 columns,
  and two rows (6/1) at 6 columns.
- Preserve the saved top-left anchor when reflowing. Automatic screen-edge fitting,
  overlap management and individually positioned cells are out of scope.
- Follow the existing account/character profile switch and full-profile copying.
  Missing legacy preference defaults to 3; validate explicit values in every profile.
- Resetting the currency section restores 3 columns along with the existing
  currency-panel resource defaults, disclosing this in its reset text; retain
  position and standalone bars. Apply the reset in the editor session, not as a
  permanent change until Done. This changes the existing Currency Panel Reset
  Panel button behavior: its reset is reversible by Cancel and commits only on
  Done.
- Positioning uses this same configured grid layout with real entries only.

### Live HUD configuration

Agreed by Tim, 2026-11-06: show **real data only** in HUD elements. No dummy
tracker rows, currency entries or fabricated bar values, even when empty. This
supersedes all earlier dummy-content proposals, including gold/bag/bank.
Configuration sections remain accessible regardless of whether the corresponding
HUD currently has content. Empty/unavailable elements retain their real rendering;
do not manufacture geometry to make them draggable.

Updated agreement, 2026-11-06: provide **Done and Cancel**, plus a **Reset Section**
button in every HUD configuration section, including tracker, currency and bars.
Edits, dragging and resets preview live within the session; only Done commits
them. Cancel and automatic exits restore the session's starting HUD settings and
positions. Reset Section applies that section's documented addon defaults in the
session, not its session-start values; Cancel can undo it. No whole-HUD reset is
proposed. Currency section reset restores three columns and currency-panel
resource defaults while preserving position and standalone bars.
Agreed by Tim, 2026-11-06: Reset Section restores that section's settings to
their documented addon defaults, not session-start values. Cancel restores
session-start values. Record exact field/default coverage in the plan; retain the
currency reset's already-agreed position/standalone-bar exclusions.
Agreed by Tim, 2026-11-06: automatic exit acts as Cancel, restoring the session's
starting HUD settings and positions. Cancel the originating profile's session
before switching profiles; never restore its snapshot into the new profile.
Only Done commits session edits. This applies to the existing Currency Panel
Reset Panel button as well: reset changes are session-local and reversible by
Cancel, rather than immediately changing saved preferences.

Expose bar enable/visibility controls, currency-grid columns and tracker maximum
rows while positioning (requested by Tim, 2026-11-06). Setting edits apply to the
live session but are not committed to saved variables until Done; merely entering
the mode changes no saved preferences. Done exits the editor and restores normal
rendering with the chosen values. Configuration controls must not change the
measured bounds of the HUD elements.

Pane arrangement is settled: one independently movable shared panel, not panes
following individual elements. Its control scope is reopened by Tim, 2026-11-06:

| Option | Floating controls | Settings ownership and trade-offs |
|---|---|---|
| A: Minimal positioning/appearance | No bar configuration controls; tracker maximum height/rows; currency-panel currencies/layout. Empty elements remain empty and have no substitute geometry. | Keep behavioral settings, colors and enable/visibility controls in addon settings. Smaller editor focused on size/placement. |
| B: Full HUD configuration | All HUD settings, including colors, on/off and bar visibility, plus tracker and currency configuration. | Move HUD settings into the floating editor with addon-settings navigation rather than duplicates. More comprehensive but larger; enumerate all moved controls before implementation. |

Agreed by Tim, 2026-11-06: use option B, with collapsible sections in one
movable editor and on-screen Done. All HUD settings, including colors and on/off,
are available there; addon settings supplies Manage HUD navigation rather than
duplicates. Evaluate usability before final acceptance; the minimal option remains
a fallback requiring further product discussion, not an automatically authorized
second implementation. Use real data only; empty elements are not populated to
demonstrate configured maximum size.

Agreed by Tim, 2026-11-06: one independently movable shared **Manage HUD** panel,
with sections for bars, currency summary and tracker, plus an on-screen Done.
Use a Manage HUD button in addon settings as the entry point, like existing
item/group management; slash and hotkey open the same editor. Move the agreed
HUD settings here rather than duplicating them in addon settings, including bar
colors/enable/visibility, currency selection/ordering/layout and tracker appearance.
Enumerate the exact existing controls during detailed planning to avoid omissions;
unrelated banking, notifications and rule/group management are not moved implicitly.

```text
+--------- Manage HUD ---------+
| Bars                        |
| [x] Transmutes  [slider] 75% |
| ...                         |
| Currency Panel              |
| Columns         [slider] 3  |
| Item Tracker                |
| Maximum Rows   [slider] 20  |
|                     [ Done ]|
+-----------------------------+
```

## Preservation and compatibility

Default threshold 0 with Hide When Empty on intentionally hides enabled empty
bars, including profiles missing the new preferences. Positive amounts remain
visible at threshold 0. Unticking Hide When Empty restores always-show behavior.
Preserve show switches,
positions, colors, warning/danger levels, summary cells, notifications, and
unrelated saved data. Validate thresholds in every profile at the saved-data
boundary. Assess schema migration and older-build refusal before normal UAT.
No new external dependency.
For currency columns, preserve existing three-column behavior by default and
unrelated saved data; verify migration, copy, reset and older-reader safety.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | Missing/default preferences resolve to threshold 0 and Hide When Empty on: enabled empty bars hide, positive amounts with a positive cap show, and disabled bars remain hidden. Unticking Hide When Empty at 0 shows empty enabled bars. | Offline defaults/migration tests and in-game baseline. |
| AC2 | At 75, 74/100 is hidden and 75/100 and 76/100 are visible; 749/1000 remains hidden even if displayed percent rounds to 75. | Offline boundary fixtures; in-game crossing. |
| AC3 | At 100 only a full-or-over-cap enabled bar appears; disabled bars never appear; unavailable values hide the bar. | Offline boundary and external-data fixtures. |
| AC4 | A hidden enabled bar reappears after an amount or cap change without toggling settings; falling below hides it again. | Offline event-registry/handler tests with other consumers off; in-game backpack, bank, currency. |
| AC5 | Cutscene exit and setting changes apply current threshold/values. Profile changes cancel any positioning session, restore its starting positions/settings in the originating profile, and apply the new profile without cross-profile writes. | Offline lifecycle tests and in-game checks. |
| AC6 | Summary cells, notifications, colors and other bars remain unchanged. Currency Reset Panel retains its resource/position scope; its session and commit behavior is specified by AC13. | Offline assertions and in-game observations. |
| AC7 | Reload/copy/migration preserve each resource's preference and unrelated data; malformed values are reported; incompatible older builds refuse without mutation. | Offline profile/data tests and backed-up older-schema UAT. |
| AC8 | Settings, slash and keybinding enter the same positioning mode; settings closes; on-screen Done exits without opening settings. | Offline entry-point tests and in-game controls/keybinding checks. |
| AC9 | Positioning uses actual HUD controls and real current data only; empty/unavailable elements receive no dummy entries, fabricated values or substitute geometry. | Offline empty/nonempty fixtures and in-game sizing/drag checks. |
| AC10 | Done commits session-edited positions/settings; Cancel and automatic exits restore the starting state. Merely entering/exiting without edits changes no saved preferences, and no dummy data is created. | Offline saved-state assertions for Done/Cancel/automatic exit and in-game edit/exit checks. |
| AC12 | One independently movable Manage HUD panel contains the agreed bar, currency and tracker settings; addon settings provides Manage HUD navigation rather than duplicates; slash/hotkey use the same editor. Edits are live previews, not committed until Done. | Offline control/setter/navigation/session tests and in-game layout/edit checks. |
| AC11 | Hide When Empty defaults on per bar. At threshold 0 with it on, amount 0 is hidden and amount 1 with a positive cap is visible even below 1% fill. At a positive threshold both the nonempty and percentage requirements apply. Positioning temporarily overrides this checkbox without saving changes. | Offline zero/one, combined-threshold, profile/copy and positioning tests; in-game transmute checks. |
| AC13 | Reset Section applies documented defaults only to that section within the session; Cancel restores pre-session values and Done commits the reset. Currency reset restores three columns and currency-panel resource defaults while preserving position and standalone bars; the existing Currency Panel Reset Panel action follows this session behavior. | Offline reset/session-field assertions and in-game reset, Cancel and Done checks. |
| CG1 | Default/migrated profiles retain the existing three-column layout. | Offline geometry and in-game baseline. |
| CG2 | Every selectable integer from 1 to the available-resource-cell count (at least 3) reflows immediately; N visible cells use `ceil(N / columns)` rows in unchanged order without overlaps. One column gives a vertical list and the maximum allows a horizontal strip. If discovery shrinks the maximum below the saved setting, the effective setting is capped at the new maximum when read. | Offline anchors/dimensions across the range and in-game endpoints/intermediate settings. |
| CG3 | Zero, one and fewer-than-limit cells create no phantom columns; hidden/reordered resources reflow correctly. | Offline cases and in-game filtering/ordering. |
| CG4 | Anchor, formatting, combined cells and standalone bars remain unchanged by column selection; positioning uses the same layout. | Offline state/geometry and in-game checks. |
| CG5 | Reload, profile switching, full copy and Reset Panel obey the agreed ownership/reset rules. | Offline profile tests and approved UAT. |
| CG6 | Malformed columns fail explicitly; migration preserves unrelated data; unsafe older readers refuse without mutation. | Offline saved-data/actual older-build checks and backed-up migration UAT. |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | One global threshold (less UI) versus per-bar (different resources need different attention levels). | Per-bar, alongside existing advanced settings. | AGREED by Tim, 2026-11-06: definitely per bar. |
| D2 | Default 0 preserves HUD; nonzero default declutters immediately but surprises existing users. | 0, opt-in. | AGREED by Tim, 2026-11-06: default 0. |
| D3 | Exact crossing is predictable; hysteresis or visibility-specific debounce could reduce repeated transitions but changes when bars appear/disappear. | Exact crossing initially; no animation, hysteresis or additional visibility debounce. | AGREED by Tim, 2026-11-06: keep exact crossing; reconsider show/hide debounce only if users report a problem. Existing event debounce remains unchanged. |
| D4 | Change thresholds to position hidden bars versus temporary HUD positioning. | Dedicated temporary mode using actual controls and real data only. | AGREED by Tim, 2026-11-06: use HUD positioning with settings/slash/hotkey entry and on-screen Done; real data only, with no dummy entries or fabricated values. |
| D5 | Existing account/character settings switch versus separate threshold ownership. | Follow the existing switch. | AGREED by Tim, 2026-11-06: per-character when Use Character Settings is on; shared account-wide when off. |
| D6 | Add to existing advanced settings versus a new UI surface. | Hide Below slider first in each bar's Advanced Settings, as shown above. | AGREED by Tim, 2026-11-06: ASCII settings layout approved. |
| D7 | Fixed arbitrary limit versus resource-based column range. | 1 through available resource cells (at least 3), default 3; filtering does not alter the range or saved choice. | AGREED by Tim, 2026-11-06: support horizontal strips and vertical columns, without the arbitrary six-column limit. |
| D8 | Reset Panel restores three columns versus preserves layout like position. | Restore three and disclose in reset text. | AGREED by Tim, 2026-11-06: reset columns with other panel preferences; preserve position and standalone bars. |
| D9 | Keep positioning active through context changes versus automatically exit. | Exit on profile changes, reload and cutscene/interaction entry. | AGREED by Tim, 2026-11-06: Q4 yes. Combat is covered by D10. |
| D10 | Permit positioning in combat versus exit/block it. | Exit on combat entry and block entry while in combat. | AGREED by Tim, 2026-11-06: Q8 yes. Applies to every entry point. |
| D11 | Overload threshold 0 versus independent empty-resource hiding. | Per-bar Hide When Empty checkbox; threshold 0 retains its percentage meaning. | AGREED by Tim, 2026-11-06: defaults are 0 and ticked, superseding the earlier default-off choice. Empty enabled bars hide by default; unticking restores always-show at 0. |
| D12 | Standard separate checkbox versus combined slider/checkbox row. | If feasible, checkbox right of slider and invisible above 0, retaining its value. | Tim's agreed WANT, 2026-11-06; not a required acceptance condition. Separate checkbox is an acceptable fallback. |
| D14 | Per-element panes versus shared movable configuration; duplicate LAM controls versus navigation. | One movable Manage HUD panel and addon-settings navigation, with slash/hotkey entry. | AGREED by Tim, 2026-11-06: shared pane and wireframe; no duplicates for agreed controls. |
| D13 | Separate labelled master switch versus compact enable/threshold row. | Unlabelled checkbox with resource-specific tooltip beside slider; slider disabled when unchecked. | Agreed UI direction by Tim, 2026-11-06; disabled-slider behavior confirmed. Final threshold label and layout feasibility remain to be settled. |

## Feasibility notes

[ResourceProgressBars](../../../Banking/ResourceProgressBars.lua) centralizes
rendering, but its cutscene-exit path currently bypasses value-based visibility.
[Events](../../../Core/Events.lua) uses visibility-named helpers to decide whether
to listen and refresh. Those helpers currently mean "enabled": changing them to
mean "currently on screen" would strand hidden bars. Preserve monitoring intent
separately from rendering. This is the main risk, not the percentage comparison.

[CurrencyPanel](../../../Tracking/CurrencyPanel.lua) uses a fixed column constant
and three-element width table. Column work is localized, but profile validation,
copying and saved-data safety are part of D10.3 rather than just replacing a constant.

## Independent spec review

Reviewer: PENDING
Reviewed document revision/source identity: PENDING

Preliminary review findings (2026-11-06; direct review, not the required
independent review):

1. **Blocking - Dummy-content behavior conflicts.** Positioning requirements and
   AC9 still require dummy currency/tracker content, while the later real-data-only
   agreement forbids dummy content and manufactured geometry; another later
   paragraph revives display-only dummy content. Reconcile the superseded text,
   including AC9 and D4.
2. **Blocking - Save, Cancel and automatic-exit behavior conflicts.** The spec says
   only Done commits and Cancel/automatic exits restore the starting state, but
   also says configuration edits save immediately. Specify the distinction
   between live preview and persistence, and cover Done, Cancel, reset-then-Cancel
   and automatic exit in acceptance criteria.
3. **Blocking - Ticket boundaries are stale.** D10.1 calls for disabled
   placeholders, while later agreements describe a functional full Manage HUD
   editor with relocated controls and Done/Cancel/reset behavior. The ticket map
   omits AC12 and does not assign the editor relocation or session/reset behavior.
   Clarify which ticket owns each behavior and when controls become functional.
4. **Major - Open questions and acceptance mapping are incomplete.** The Open
   Questions table is empty despite stale Q12/Q13 references; threshold wording
   and layout also remain unsettled. Resolve or list the remaining questions and
   add observable acceptance criteria for reset scope, cancellation and relocated
   settings.
5. **Major - Currency-column slider range is underspecified.** A saved column
   choice may exceed the current slider maximum after resource discovery shrinks.
   Define how the Manage HUD slider represents that retained value.

These are review findings, not decisions. Tim's decisions/resolutions: PENDING.
Required independent spec review: PENDING.

## Patch Review

Tim's responses and resulting spec updates, 2026-11-06:

1. **Real data only:** Resolved in favor of real HUD data. Dummy tracker rows,
   currency entries and fabricated bar values are not used; empty/unavailable
   elements receive no substitute geometry. The superseded dummy-content text was
   removed from positioning, currency layout, options and acceptance criteria.
2. **Done is the only commit:** Live settings, position and reset edits are session
   previews. Only Done commits them; Cancel and automatic exits restore the
   session-start values. Immediate saved-variable writes were removed as a
   requirement. Currency resets are session-local and reversible; this changes
   the existing Currency Panel Reset Panel behavior, which must commit only on
   Done and restore on Cancel.
3. **All three tickets:** This spec defines the combined product behavior for
   D10.1-D10.3, and implementation order is flexible. Placeholder-first UI staging
   is an implementation-plan choice, not a product requirement; the corresponding
   implementation detail is recorded in the positioning plan.
4. **Open questions and mapping:** Q12/Q13 decisions are resolved in the current
   requirements; the original finding is retained above as review history.
   Acceptance coverage now includes the shared editor and reset/session behavior.
   The threshold label/layout question is resolved as an implementation choice:
   the developer evaluates both variants and selects the best fit.
5. **Currency-column range:** The agreed dynamic range is unchanged. If discovery
   reduces its maximum below the saved setting, cap the effective column count at
   the new maximum when read; the saved value is not malformed.

Required independent spec review and explicit spec approval remain pending.

## Approvals and acceptance

- Product discussion agreement: PENDING
- Explicit spec approval: PENDING
- Feature acceptance and actual evidence: PENDING

Spec approval does not authorize coding.
