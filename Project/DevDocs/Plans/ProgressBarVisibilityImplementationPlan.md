# HUD positioning and vanishing progress bars: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO items: [D10.1 and D10.2](../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](../FeatureSpecs/HUDLayoutAndVisibility.md)
Owner: Copilot (draft author)
Updated: 2026-11-06

Follow the [feature development process](../../Processes/FeatureDevelopment.md).
Track positioning (D10.1, Step 3) and bar visibility (D10.2, Steps 1-2) separately;
Step 4 covers their documentation and acceptance. Sequencing remains provisional,
not a product requirement to deliver bar hiding first.
Currency columns (D10.3) have a [separate plan](CurrencyGridColumnsImplementationPlan.md)
under the same spec. Coordinate profile/schema changes and positioning grid rendering
across tickets; the combined spec requires independent review before approval.

## Current implementation and prior art

- [ProgressBarResources.lua](../../../Banking/ProgressBarResources.lua): per-resource
  preferences, fractional thresholds, deviation storage, value discovery.
- [ResourceProgressBars.lua](../../../Banking/ResourceProgressBars.lua):
  UpdateProgressBar, refresh/init, SetProgressBarsHidden and enabled-state queries.
- [Settings.lua](../../../Core/Settings.lua): per-bar advanced LAM sliders,
  RefreshProgressBarSettings refreshes bars and event registration.
- [Events.lua](../../../Core/Events.lua): enabled bars drive inventory/currency/cap
  subscriptions and debounced refreshes. Hidden must not mean unmonitored.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua): all-profile validation,
  full-profile copy, active-profile refresh.
- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua) and
  [ItemTrackerPanel.lua](../../../Tracking/ItemTrackerPanel.lua): actual HUD
  rendering and position-save handlers; positioning must reuse these controls.
- [Bindings.xml](../../../Bindings.xml) and [Init.lua](../../../Core/Init.lua):
  existing ESO action definitions and binding-name strings; slash registration
  also exists in Init.
- [Core tests](../../../Core/Tests.lua) include resource preferences and listener
  isolation; [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) covers
  shared saved-data boundaries. Extend those patterns.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice |
|---|---|---|---|
| D1 | Global versus per-resource storage. | Per-resource `hideBelowThreshold` fraction, default 0; store deviations. | PENDING |
| D2 | Change visibility-named query semantics versus retain enabled-state contract. | Retain existing monitoring semantics; centralize render eligibility separately. Rename only if required for clarity, wiring every caller. | PENDING |
| D3 | New polling timer versus existing events. | Existing events; no polling. | PENDING |
| D4 | Reuse the local update function versus introduce a cross-module visibility call. | Keep the visibility decision in local UpdateProgressBar in ResourceProgressBars.lua; SetProgressBarsHidden calls it to reevaluate current values on cutscene exit. | AGREED by Tim, 2026-11-06. |

## Data, compatibility, and failure contracts

Agreed profile ownership: use the existing Use Character Settings switch and
GetSettingsProfile contract. Off reads/writes the account profile; on reads/writes
the character profile. Do not introduce a separate threshold ownership switch.

Default threshold 0 and Hide When Empty true are agreed by Tim, 2026-11-06.
Missing legacy preferences inherit these defaults: empty enabled bars now hide.
Proposed stored fraction 0-1, UI integer percentages. Validate finite numeric range
for every profile before use; missing legacy fields default to 0. Preserve unknown
resource preferences, unrelated fields and independent color thresholds.
Independent thresholds per bar are agreed; a single profile-wide threshold is
not part of the design. The exact stored field/representation remains provisional.
Agreed: add a per-resource Hide When Empty boolean, default true; proposed field
`hideWhenEmpty`, stored as a deviation. Include all-profile boundary validation,
copy/migration/downgrade assessment and positioning override for this field.
Agreed default representation, 2026-11-06: keep both new settings inside each
resource's existing progressBarPreferences table. Missing/nil Hide Below means 0;
missing/nil Hide When Empty means true. Store only non-default thresholds and
explicit false when Hide When Empty is unticked. No saved-data rewrite is needed
solely to populate those defaults. Exact field naming and percentage/fraction
representation remain to be finalized. Boundary validation and older-reader
preservation tests are still required; schema safety is a separate decision.
Keep showBar as the existing master enable switch, with its current defaults:
backpack and bank true; dynamically discovered capped-currency bars false.
Assess actual supported older builds' preservation of the new resource field;
bump schema if safe reading/preservation cannot be established, with non-destructive
migration and actual older-build refusal tests before normal UAT.
Do not repeatedly guard internal contracts. Unavailable external resource values
remain a permitted boundary case. Zero-cap behavior follows the approved spec.
Positioning mode and its visibility override are transient, not saved preferences.
Use real HUD data only; do not inject dummy entries/rows or fabricate values.
A small on-screen Done control is now required; decide its Lua/XML ownership and
whether a shared coordinator needs a manifest entry during detailed planning.
No new external dependency is expected.

## Ordered implementation

### Step 1: Establish preference and compatibility boundaries

- Depends on: approved spec/plan and explicit GO.
- Coverage: AC1, AC7.
- Extend resource defaults/getter/setter and all-profile validation; wire required
  schema/load safeguards. Copying already includes the preference table but must
  be verified for deep isolation and inactive profiles.
- Test missing/default values, valid endpoints, malformed explicit values,
  deviation removal, unrelated data and older-reader preservation/refusal.

### Step 2: Centralize rendering without disabling monitoring

- Depends on: Step 1.
- Coverage: AC1-AC6.
- Apply one value/enable/cutscene visibility decision in UpdateProgressBar.
  Include the agreed empty-amount check: hideWhenEmpty and amount == 0.
  Positive amounts still have to meet the independent percentage threshold.
  Init, refresh and cutscene exit must all reevaluate through that decision.
  Agreed: SetProgressBarsHidden uses the local UpdateProgressBar function in
  the same ResourceProgressBars.lua file; no cross-module visibility call is added.
- Keep event predicates and handler refresh gates based on enabled resources,
  even when below threshold. Audit currency cap discovery and capacity changes.
- Preserve position, colors and label update behavior; no stacking or extra timer.
- Add tests at below/equal/above, fractional rounding, 0/100, over-cap,
  unavailable/zero cap, master off, cutscene enter/exit and profile switching.
- Exercise hidden-bar events with tracker/summary/notifications disabled, proving
  subscription and refresh persist and allow the bar to reappear.

### Step 3: Shared HUD positioning

#### Implementation sequencing decision: pending

D10.1-D10.3 are separate tickets with no required implementation order. Decide
their sequencing in the approved implementation plan. One option is to introduce
the eventual D10.2/D10.3 controls as visibly disabled placeholders in an initial
D10.1 editor, then activate them with their behavior tickets; another is to wire
each control when its behavior is implemented. Placeholder staging is an
implementation choice, not a product requirement or an approval to leave controls
non-functional in the completed feature. If used, placeholders must not write
preferences, affect rendering, or register behavioral handlers. Reset Section
boundaries are agreed and should be functional when delivered, not held back as
placeholders solely because of ticket order.

Agreed by Tim, 2026-11-06: use the existing three HUD settings sections as the
initial floating-panel design, not a redesigned settings inventory. Preserve
controls, labels, tooltips and behavior except for explicitly agreed changes.

```text
+---------------- Manage HUD ----------------+
| v Item Tracker Panel                       |
|   Enable, group threshold, title size      |
|   Maximum rows, multiline, show empty      |
|                           [ Reset Section ]|
| v Currency Summary Panel                   |
|   Show empty, resource/location selection  |
|   Notify, visibility and ordering actions  |
|   Columns                                  |
|                           [ Reset Section ]|
| v Standalone Progress Bars                 |
|   Per-resource enable and visibility       |
|   Advanced warning/danger and normal color |
|   Shared warning/danger colors             |
|                           [ Reset Section ]|
|                          [ Cancel ] [ Done ]|
+--------------------------------------------+
```

Sections are collapsible; the editor moves independently of the real HUD.
Checkbox/slider bar layout trials still apply. HUD elements use real data only.
Preserve existing Notify controls in the lifted currency resource list; this does
not expand scope to relocating unrelated notification settings or behavior.

Implementation is **lift and shift and recode where needed**: inventory the LAM
definitions in Settings.lua and currency custom rows in CurrencyPanel.lua, then
adapt their presentation to the standalone window. Do not assume LAM controls can
be reparented unchanged. Reuse/extract existing getters, setters, resource-list
actions and refresh logic; avoid duplicate business logic or an unrelated settings
framework. Wire session-aware edits/position saves, Cancel restoration, section
reset and live refresh rather than copying callbacks that bypass the transaction.
Remove relocated LAM controls only once floating equivalents are fully wired;
replace them with Manage HUD navigation. Add necessary Lua/XML/load-order wiring
to the manifest, and test preservation of every lifted control's behavior.

Latest content agreement, 2026-11-06: real data only; remove earlier dummy-entry/
dummy-row requirements from implementation scope. Keep configuration sections
available for empty/unavailable elements without injecting fake data or geometry.
Test empty/nonempty rendering and no fabricated values. Q7 is closed.

Agreed by Tim, 2026-11-06: snapshot the edited HUD settings and positions at
entry; render edits and resets live in the session; only Done commits them.
Cancel and every automatic exit restore the starting state. Reset Section applies
documented addon defaults for that section and is reversible by Cancel. Enumerate
exact fields/defaults in the plan. Currency reset restores three columns and
currency-panel resource defaults while preserving position and standalone bars.
The existing Currency Panel Reset Panel action must adopt the same session
behavior: apply its reset locally, commit only on Done, and restore on Cancel.
Restore only the originating profile's edited fields before profile switch, and
clear transient editor state. Reload must not persist uncommitted edits: use
staged session values or a verified pre-save cancellation path rather than
assuming an in-memory snapshot survives reload. Snapshot only the agreed edited
fields, not the entire profile; do not overwrite unrelated tracking/inventory/
notification state on cancellation. Test edit/drag/reset followed by Done or
Cancel, repeated entry, profile changes and combat exit, preserving unrelated
data and preventing cross-profile rollback.

Agreed, 2026-11-06: full HUD configuration in one independently movable
Manage HUD panel, with collapsible bars/currency/tracker sections and Done.
Move HUD controls, including colors and on/off, here; LAM supplies navigation
rather than duplicates. Inventory all existing HUD controls and map their setters,
defaults/reset, profile refresh and event effects before relocation. Unrelated
banking/notification/rule/group controls stay in their current surfaces.
Edits should use existing setters and active-profile contracts through a session
staging mechanism; only Done commits, and Cancel/automatic exits restore the
snapshot. Coordinate currency controls with the D10.3 plan.

- Depends on: Step 2 and resolved positioning lifecycle/content questions.
- Before coding this editor/relocation piece: check the current branch (main at
  planning time). Obtain approval for a named feature branch and a pre-trial commit
  checkpoint, preserving all existing work; do not switch branches or commit merely
  because this plan records the requirement. If already on a suitable feature branch,
  use it and record the pre-trial source identity instead of creating another.
  Keep editor/relocation commits isolated from saved-schema/data-contract changes.
  A branch protects source history, not shared saved variables: back up data before
  approved UAT and retain downgrade safeguards. If the trial is rejected, discuss
  targeted revert/alternative work with Tim; no automatic reset or saved-data rollback.
- Coverage: AC8-AC10, AC12-AC13.
- Add one transient positioning state and shared enter/exit path, wired to settings,
  slash registration and an ESO action in Bindings.xml with its binding-name string.
  Exact coordinator placement and command/action names remain provisional.
- Settings entry closes LAM; create an on-screen Done button calling the same exit
  path. Agreed: exit on profile changes, reload and cutscene/interaction entry,
  retaining saved moves in their originating profile. Identify the concrete
  interaction events during detailed planning. Agreed: combat entry exits the
  mode; all entry points refuse positioning while the player is already in combat.
  Use ESO combat-state events and check current player combat state on entry;
  report the blocked entry to the user without changing positioning or preferences.
- Wire actual tracker, currency panel and bar renderers to transient positioning
  visibility without changing their saved show/filter settings or event-monitoring
  contracts. Use real current data only; empty or unavailable elements get no
  dummy entries, fabricated values or substitute geometry. Do not add labels that
  alter HUD element geometry.
- Adapt position-save handlers to the session transaction. Exit clears transient
  editor state and refreshes actual current state. Test all entry points,
  empty/nonempty/disabled cases, real control identity, and
  Done/Cancel/automatic-exit persistence.
- Trial acceptance: Tim evaluates editor clutter, collapsible sections, access to
  all HUD settings without menu switching, and ability to position elements accurately.
  Record acceptance or agreed revisions before merging the trial.

### Step 4: Settings, documentation and acceptance

- Depends on: Step 3.
- Coverage: AC4-AC10.
- Add per-bar percentage slider, disabled when master show is off.
  Agreed compact UI direction: unlabelled master checkbox with resource-specific
  tooltip beside the slider. Its unchecked state disables the slider; retain the
  threshold value. Resolve final "Show above"/inclusive label and LAM row layout
  before implementing, updating the earlier advanced-settings wireframe accordingly.
  Tim requested trials of both resource list-item layouts: single-line
  `[x] Transmutes show above: [slider] 75%`, and two-line `[x] Transmutes`
  followed by `Show when % > [slider] 75%`. Neither layout is selected yet.
  Verify available width and slider usability in-game; preserve inclusive
  threshold semantics while finalizing the label. These trials supersede the
  earlier separate enable/advanced-threshold placement proposal.
  Wire both resource-name and checkbox clicks to the same showBar toggle.
  Agreed: checkbox first and resource text to its right, following existing
  CreateSettingsCheckbox placement in CurrencyPanel.lua.
  Test each click toggles exactly once (no event-bubbling double toggle), updates
  slider enabled state immediately, and preserves threshold/empty preferences.
  Refresh immediately using existing settings helper. Follow the agreed spec wireframe:
  place Hide Below first inside each existing bar's Advanced Settings, above
  Warning Threshold; no separate threshold window or global threshold control.
  Keep standalone-bar settings outside the currency section reset; the existing
  Currency Panel Reset Panel action follows the session transaction described in
  Step 3.
  Add Hide When Empty, default on and disabled when Show Bar is off.
  Agreed optional UI want: place it right of the slider on the same row and hide
  it above 0 without clearing its preference. Assess LAM custom-row feasibility,
  width, refresh and keyboard/accessibility behavior before selecting that approach;
  standard separate checkbox is an acceptable fallback, not an acceptance failure.
  Test retained value after changing 0 to positive and back to 0 if combined UI is
  implemented. Test 0 versus 1 crystal at threshold 0, positive-threshold conjunction,
  default preservation, profile copying and temporary positioning override (AC11).
- Update [manual](../../Publishing/Source%20Documents/UserManual.bbcode), including
  how to move a currently hidden bar. Run focused tests and approved in-game checks.
- No release/version/commit work is authorized.

## Verification and acceptance mapping

| Criteria | Step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1-AC3 | 1-2 | Focused resource/render cases via `python Project\Tests\Run-RuleTests.py --test-filter "<final test names>"`. | Exact hidden-state boundary assertions. | PENDING |
| AC4-AC6 | 2-4 | Listener isolation and lifecycle cases; in-game resource crossing and cutscene return. | Hidden enabled bars receive updates and reappear; other surfaces unchanged outside positioning. | PENDING |
| AC7 | 1-4 | Profile/migration tests, actual older-build check; approved reload/copy UAT. | Data preserved; malformed input reported; unsafe downgrade refuses. | PENDING |
| AC8-AC10, AC12-AC13 | 3-4 | Positioning/configuration entry/exit, real-data-only rendering and session/reset tests; in-game drag/edit/Done checks. | Shared movable editor from all entries; real controls/data only; Done commits, Cancel/automatic exits restore, and resets remain reversible until Done. | PENDING |
| AC11 | 1-4 | Empty-resource preference/render/profile/positioning tests; in-game zero/positive transmute checks. | Default on; zero hidden by default; any positive amount shows at threshold 0; unticking shows empty bars at 0; normal thresholds still apply. | PENDING |

Final selectors await test naming. Synthetic tests use isolated values/profiles,
never live inventory or saved data. Back up shared saved variables before approved
UAT; schema changes require an actual older-schema backup and release-process
restore/recovery safeguards. Offline tests cannot prove real ZOS event delivery.

## Open questions and risks

- Q9 is closed: retain the existing zero/nonpositive-cap calculation of 0%;
  apply the agreed enable, empty-amount, threshold and cutscene checks normally.
  Profile/reload/cutscene/interaction/combat auto-exit and combat entry blocking
  are agreed.
  Positioning entry points, actual controls, empty-panel fallback and
  on-screen Done are agreed.
- Command/action naming, unavailable-bar positioning behavior and coordinator
  ownership remain to be settled during spec/plan discussion.
- Older-reader preservation/schema decision: PENDING; blocks coding.
- Main regression risk: treating hidden as disabled strands a bar below threshold.
- Exact crossing without hysteresis is agreed by Tim, 2026-11-06.
  Repeated real changes across the threshold may still toggle visibility.
  No additional show/hide debounce is included. Tim agreed to reconsider it
  only if users report a problem; preserve the existing event debounce.

## Independent plan review

Reviewer and reviewed spec/plan/source identity: PENDING
Findings, Tim's decisions, resolutions and re-review: PENDING

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

None - planning only.

## Independent code review and verification

Reviewer, diff identity, findings, corrections and re-review: PENDING
Actual test results, retained evidence and unavailable checks: PENDING

## Acceptance and handoff

Approved in-game scope, Tim-reported results and explicit acceptance: PENDING
Current spec/user docs/TODO/completed index/archive updates: PENDING
Commit/merge authorization: PENDING
Release follows its separate process.
