# HUD positioning and configuration: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: [D10.1 HUD Positioning](../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](../FeatureSpecs/HUDLayoutAndVisibility.md)
Owner: Copilot (draft author)
Updated: 2026-11-08

Follow the [feature development process](../../Processes/FeatureDevelopment.md).
Delivery order is D10.1, then [D10.2](VanishingProgressBarsImplementationPlan.md),
then [D10.3](CurrencyGridColumnsImplementationPlan.md). This plan covers the
shared editor, session behavior, existing HUD settings, and presentation-only
controls for the later tickets. D10.2 and D10.3 wire their bar-visibility and
grid-column behavior into these controls.

## Current implementation and prior art

- [Settings.lua](../../../Core/Settings.lua) owns the LAM tracker and bar
  controls, plus settings navigation. Its callbacks write preferences directly.
- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua) owns currency and
  capacity selection, ordering, notifications, location toggles, the custom
  resource list, and Reset Panel. Reset currently writes preferences directly.
- [ItemTrackerPanel.lua](../../../Tracking/ItemTrackerPanel.lua) owns tracker
  rendering and `trackerOffsetX/Y` position saves. The tracker settings are
  currently defined in Settings.lua.
- [ResourceProgressBars.lua](../../../Banking/ResourceProgressBars.lua) owns
  standalone bar rendering and `offsetX/offsetY` saves for each resource.
- [Init.lua](../../../Core/Init.lua), [Bindings.xml](../../../Bindings.xml), and
  [Events.lua](../../../Core/Events.lua) provide initialization, keybinding and
  slash-command registration patterns, plus cutscene/interaction refresh logic.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) owns profile defaults,
  preference copying, and profile validation. The DEV manifest controls load
  order; XML templates must load before their Lua consumers.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | A: edit the selected saved profile directly and restore its HUD settings/positions from a snapshot on Cancel; Done discards the snapshot. B: make a complete working copy of the selected profile, have existing profile access use it during HUD mode, then copy the whole profile back on Done or discard it on Cancel. C: move HUD-owned settings into a dedicated saved-variable section, then swap that whole section with a working copy for the session. | Compare implementation scope and preservation risks. Do not assume a field-routing proxy. Determine whether B's full-profile commit can safely preserve non-HUD data, or whether C's one-time organization/migration yields a simpler bounded swap. | PENDING |
| D2 | Reparent current LAM controls or recreate the presentation in XML and Lua. Recreating provides design flexibility without relying on LAM control layout/lifecycle assumptions. | Recreate the existing layout in XML and Lua, reusing maintained settings logic where applicable. | AGREED by Tim, 2026-11-08: recreate. "Lift and shift" means translating the layout into XML and Lua, not moving the actual LAM controls or their control code. |
| D3 | Include the later-ticket controls now to show the intended UI, or defer their creation until their behavior tickets. | Create the controls in D10.1 as presentation-only placeholders; wire their behavior in D10.2/D10.3. | AGREED by Tim, 2026-11-08: add controls now to show the UI appearance; they do nothing until the later tickets wire them up. |

## Data, compatibility, and failure contracts

The positioning session itself is transient. Its saved-data architecture is
the subject of D1: compare direct profile edits with revert, a complete working
copy of the selected profile, and a dedicated HUD-settings section that can be
swapped as a unit. Preserve the existing account/character ownership contract,
and ensure Done, Cancel, every automatic exit, and reload have defined
commit/discard behavior. Do not copy or restore the entire profile without
accounting for non-HUD state that can change during the session.

Use the existing profile-selection contract. Before changing profiles, cancel
the originating profile's session and clear it; never apply its staged values to
the new profile. Entry is blocked during combat; combat entry, cutscene or
interaction entry, and other agreed automatic exits cancel. All entry points
share the same path and report blocked combat entry. Keep rendering and editor
state in their established module contracts; required internal state must fail
fast if absent.

The editor lifts the existing controls and behaviors:

- Tracker: `showTrackedItemsPanel`, `trackerGroupThreshold`, `trackerTitleSize`,
  `trackerMaxRows`, `wrapTrackedItemNames`, and `showEmptyTrackedItems`, with
  defaults `true`, 8, 20, 20, `false`, and `true`, respectively; position uses
  `trackerOffsetX/Y` (default 50, 50).
- Currency summary: `showEmptyCurrencies`, resource/location visibility,
  ordering, notification choices, and compact/combined display preferences in
  `currencyPreferences` and `capacityPreferences`. Reset to the current panel
  defaults (gold, backpack and bank shown; other currency rows hidden; default
  ordering and notification/compact/location preferences), with
  `showEmptyCurrencies = true`; position uses `currencyOffsetX/Y` (default
  50, 150).
- Standalone bars: per-resource `showBar`, warning/danger thresholds and normal
  color, plus shared warning/danger colors; reset each resource to its
  `ProgressBarResources.lua` defaults (including per-resource enabled state,
  offsets, warning/danger thresholds) and shared alert-color defaults. D10.2
  adds hide-below and hide-when-empty controls and their reset defaults.
- D10.3 adds currency grid columns and extends the currency reset to restore
  three columns.

Reset Section applies documented defaults in the session; Cancel restores
session-start values and Done commits the reset. Currency reset preserves panel
position and standalone bars. D10.1 must preserve current Reset Panel scope and
make it session-local. For D10.1, tracker and bar position-reset behavior remains
an open decision below. Verify reset defaults against `preferenceDefaults`,
`defaultsAccount`, resource defaults, and existing preference getters before
final approval.

### Saved-variable structure findings (2026-11-08)

Source inspection, not a dump of live saved data:

- [PrepareSavedVariables](../../../Tracking/ItemDatabase.lua#L772) validates
  profiles under `InventoryCompanion_SavedVariables.Default[account][profile]`.
  `$AccountWide` and character-ID profiles share this outer namespace.
- [GetSettingsProfile](../../../Tracking/ItemDatabase.lua#L563) selects the
  character profile when `character.useCharacterItemList` is true, otherwise
  the account-wide profile. It returns a profile, not a HUD-specific section.
- [Profile preference fields/defaults](../../../Tracking/ItemDatabase.lua#L548)
  and [account defaults](../../../Core/Constants.lua#L209) place HUD fields
  alongside tracking/editor data. The groups in the sketch below are conceptual;
  they are not existing container tables. Current schema version is 10.
- [Currency preferences](../../../Tracking/CurrencyPanel.lua#L79) have nested
  location tables, and currency/capacity preferences also hold notification
  choices. [Bar settings](../../../Banking/ProgressBarResources.lua#L204)
  resolve defaults from per-resource preference deviations.

Legend: `*` identifies existing fields involved in the HUD work; `+` identifies
planned additions. Metadata and unrelated fields are abbreviated.

```text
InventoryCompanion_SavedVariables
  Default
    <account>
      $AccountWide
        version
        bankItemDelay, guildBankPartialWithdrawEnabled, autoMergeChests
        houseBankNames, debugEnabled, debug, autoCategoryTimingThresholdMs
        trackedItems, trackedRules, filterShow/filterNotify/...
        AutoCategory settings/order/setup flags, accountWideListBackup
        currencyNamesById                      diagnostic data

        showTrackedItemsPanel                 *
        showEmptyTrackedItems                 *
        trackerOffsetX, trackerOffsetY        *
        wrapTrackedItemNames                  *
        trackerGroupThreshold                 *
        trackerMaxRows, trackerTitleSize      *

        showEmptyCurrencies                   *
        currencyOffsetX, currencyOffsetY      *
        currencyGridColumns                   + D10.3
        currencyPreferences                   *
          [currency ID]
            showCompact, order, notify
            locations
              [location ID]
                hidden, order
        capacityPreferences                   *
          [bag or bank]
            hidden, order, notify

        progressBarPreferences                *
          [resource key]
            showBar, offsetX, offsetY
            warningThreshold, dangerThreshold, normalColor
            hideBelowThreshold                + D10.2
            hideWhenEmpty                     + D10.2
        progressBarAlertColors                *
          warning, danger

      <character ID>
        version, character metadata
        isEnabled, itemListInitialized, useCharacterItemList
        profile-owned tracking/editor/HUD fields above when initialized
```

Option C could preserve the outer account/character structure and introduce
one isolated section per profile:

```text
<profile>
  version, metadata, profile-selection/initialization flags
  tracking data, editor filters, AutoCategory data, unrelated settings
  hud                                         PROPOSED
    tracker                                   settings and position
    currency                                  settings, preferences, columns
    bars                                      resource preferences, alert colors
```

This is a proposal, not an agreed schema or field-renaming contract. A bounded
HUD-section migration is preferable to a wholesale SavedVariables redesign as
an option to assess: it gives both working-copy and snapshot/revert approaches
a clear unit to swap without touching rules or tracked items. It still requires
an upfront change to every moved-field reader/writer. Merely isolating a section
does not make direct-edit/revert safe across reload.

If Option C is selected:

- Map all existing HUD fields to their destination, including positions and
  D10.2/D10.3 additions; update HUD readers/writers and notification consumers
  that use currency/capacity preferences. Decide whether those preference tables
  move intact; separating notification fields is not implicitly approved.
- Update defaults, all-profile validation, character initialization, full-profile
  copying, reset and refresh paths. Migrate inactive profiles as well as active
  ones, preserving unrelated data and existing values.
- Bump the saved-variable schema: older builds expect the flat fields and cannot
  safely read the reorganized data. Extend migration/downgrade gates before ZOS
  constructors; test actual older-reader refusal without mutation.
- Keep session copies transient, verify the saved table ownership when swapping
  a section, and perform backed-up UAT using an actual older-schema backup.

No reorganization, migration, schema bump, or transaction option is authorized
by recording these findings. D1 remains pending feasibility evidence and Tim's
decision.

## Ordered implementation

### Step 1: Design the shared editor transaction

- Depends on: spec approval and explicit GO to plan finalization; no code GO yet.
- Spec coverage: AC10, AC12, AC13.
- **D1 feasibility check (planning only):** Inspect how
  `GetSettingsProfile()` selects account versus character settings, how profile
  tables are held by the saved-variable system, and how `CopySavedValue`
  handles nested tables. Inventory writes to profile data that may occur while
  HUD mode is open, including non-HUD state and event-driven updates. Do not
  assume copying a table and assigning a Lua field changes the table registered
  with ESO SavedVariables.
- Prototype Option B in an isolated Lua 5.1 fixture: copy the complete active
  profile, direct existing-style `GetSettingsProfile()` accesses to that copy
  during HUD mode, then test Done/Cancel. Establish exactly which fields the
  complete profile contains and whether Done would commit unrelated tracking,
  rules, groups, or event-updated data; test profile switching, nested table
  isolation, copy semantics, and reload persistence.
- Prototype Option C separately: define the proposed HUD-settings section,
  enumerate every field to move, identify all readers/writers and required
  migration/default handling, then test swapping the section without changing
  non-HUD settings. Estimate the one-time caller/migration work against the
  simpler session swap it enables.
- Compare both prototypes with Option A (direct writes plus a narrowly scoped
  pre-session snapshot and revert). Test unrelated setting changes during the
  session, automatic exits, and reload behavior; explicitly establish whether
  each option can meet AC10 without losing or committing unintended data.
  Record caller scope, test evidence, limitations, and recommendation in D1.
- **Feasibility decision criteria:** Prefer the least invasive option that
  reliably isolates Cancel/automatic-exit/reload behavior and does not overwrite
  unrelated state. A full-profile copy is suitable only if committing or
  discarding it cannot lose unrelated updates or unexpectedly commit unrelated
  changes. A dedicated HUD section is suitable only if the migration and caller
  changes are bounded and validated. Do not implement any production
  architecture as part of this check; discuss evidence and recommendation with
  Tim before deciding.
- Map every lifted control to its current getter/setter, refresh side effect,
  profile field, default and reset behavior. Resolve the open reset-position
  question below before freezing the transaction contract.
- After D1 is resolved, define the transaction state and access path accordingly.
  Ensure profile change cancels before switching and edits cannot leak across
  profiles; ensure cancellation cannot discard unrelated profile updates.
- Verification design: isolated tests for stage, preview, Done, Cancel, reset,
  repeated entry, reload-safe non-persistence, and preservation of unrelated
  profile data.

### Step 2: Build and wire Manage HUD

- Depends on: Step 1 and approved implementation plan plus separate explicit GO.
- Spec coverage: AC8-AC10, AC12-AC13.
- Before coding this substantial editor change, discuss whether to work on a
  named feature branch and establish a pre-trial commit checkpoint. The branch
  at planning time is `main`; do not switch branches or commit without Tim's
  approval. Preserve existing work and keep any UI trial isolated from unrelated
  saved-data/schema changes.
- Add one independently movable window with collapsible tracker, currency, and
  bars sections, plus on-screen Done and Cancel. Add Settings navigation and
  slash/keybinding entry points to the same mode; settings entry closes LAM.
- Layout decision timing agreed by Tim, 2026-11-08: decide the detailed layout
  after seeing the rendered editor. Treat scrolling, sizing, spacing, and initial
  expanded/collapsed states as provisional choices for the visual trial, not
  settled design or blocking questions that must be answered before a preview.
  Review the appearance with Tim and record agreed adjustments before acceptance.
- Create the D10.2 Hide Below and Hide When Empty controls and the D10.3 Grid
  Columns control now, in their intended locations, so the UI trial includes
  their appearance and space requirements. They are presentation-only until
  their owning tickets wire them up: no settings/session writes, rendering
  changes, behavioral handlers, or new saved fields just for placeholders.
  Clearly indicate that their functionality is not yet available. Test their
  inertness, including Done, Cancel, and section resets; existing controls and
  resets remain functional.
- Add the combat entry guard and shared cancellation path for combat, cutscene,
  interaction, profile change, and reload-safe staged state. Confirm exact ESO
  events and lifecycle ordering during implementation planning.
- Adapt the existing HUD `OnMoveStop` handlers and rendering to preview staged
  positions/preferences. Temporarily reveal actual movable controls without
  changing their saved enable/filter values. Use actual current data only; empty
  elements remain empty and receive no substitute geometry.
- Recreate the existing settings layout in XML and Lua; do not reparent LAM
  controls or assume their control code can be transplanted unchanged. "Lift
  and shift" applies to the layout and configuration coverage, translated into
  the standalone editor. Reuse existing getters, setters, refresh paths and
  reset logic where applicable; preserve labels, tooltips, defaults, and effects
  except for agreed changes. Recreation provides design flexibility, not
  implicit authorization to change product behavior or scope.
  Keep unrelated profile, banking, notification, rule/group, and integration
  controls where they are. Replace relocated LAM controls with Manage HUD
  navigation only after the floating equivalents work.
- Add XML/Lua and manifest entries in dependency order. Transient session state
  alone needs no schema change; if D1 selects a saved HUD-section reorganization,
  complete its migration/schema/downgrade safeguards before normal-data testing.

### Step 3: Complete section resets and acceptance

- Depends on: Step 2.
- Spec coverage: AC9, AC10, AC12-AC13.
- Add one Reset Section control per section. Confirm exact field/default coverage;
  currency reset preserves panel position and all standalone-bar settings.
  Currency reset becomes reversible until Done; D10.3 later adds the column
  reset.
- Verify that Done commits only edited HUD fields to the originating profile;
  Cancel and automatic exits restore all staged values and positions, preserving
  unrelated state. Test empty/nonempty HUDs and each entry/exit route.
- Obtain Tim's in-game trial of editor clutter, configuration access, dragging,
  and real-control sizing before acceptance. Update user documentation after
  implementation; no release, version, commit, or merge work is authorized here.

## Verification and acceptance mapping

| Spec criterion | Step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC8 | 2 | Offline entry-point tests; in-game Settings, slash, keybinding and Done. | All entry points use the same editor; settings closes; Done exits without reopening it. | PENDING |
| AC9 | 2-3 | Offline empty/nonempty fixtures; in-game drag checks. | Actual controls and real data only; no fabricated content or replacement geometry. | PENDING |
| AC10 | 1-3 | Isolated state/persistence tests; in-game Done, Cancel and automatic exits. | Done commits; Cancel/automatic exits restore; reload does not save staged edits. | PENDING |
| AC12 | 1-3 | Control/setter mapping, session/profile tests; in-game editor review. | One movable editor exposes existing HUD settings; LAM has navigation, not duplicates. D10.2/D10.3 controls appear as inert placeholders in D10.1; their functional acceptance belongs to later tickets. | PENDING |
| AC13 | 1, 3 | Reset-field assertions; in-game Reset, Cancel and Done. | Defaults are session-local; Cancel restores; currency position and standalone bars are preserved. | PENDING |

Synthetic tests must use isolated profiles and values, never live inventory or
saved variables. Offline tests cannot prove ESO event delivery, UI sizing, or
drag behavior. Back up shared saved variables before approved in-game tests.

## Open questions and risks

| ID | Question / risk | Blocking phase and mitigation | Resolution |
|---|---|---|---|
| Q1 | Should tracker and bar Reset Section restore their saved HUD positions, or preserve them as the currency reset does? | Plan approval; settle exact reset field coverage before implementation. | PENDING |
| Q2 | Which exact interaction events should automatically cancel positioning, and what slash/action identifiers should be used? | Detailed implementation planning; confirm against ESO event APIs and existing behavior. | PENDING |
| Q3 | Main risk: settings callbacks and position handlers currently write directly to saved profiles. | Step 1; stage all edited values and test profile/reload boundaries before UI wiring. | PENDING |

## Independent plan review

Reviewer: PENDING
Reviewed plan/spec revision and source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING |

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

None - planning only.

## Independent code review and verification

- Reviewer and reviewed diff/source identity: PENDING
- Findings, agreed corrections, and re-review: PENDING
- Actual test results and retained evidence: PENDING
- Unavailable checks and remaining limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope and Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed index, and archive links updated: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized by feature acceptance.
