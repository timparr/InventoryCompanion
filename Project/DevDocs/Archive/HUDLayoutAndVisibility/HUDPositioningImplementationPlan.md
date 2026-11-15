# HUD positioning and configuration: implementation plan

Status: ARCHIVED - ABANDONED 2026-11-15; no longer pursuing
TODO item: [D10.1 HUD Positioning](../../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](HUDLayoutAndVisibility.md)
Archive index: [HUD layout and visibility archive](README.md)
Owner: Copilot (draft author)
Updated: 2026-11-08

Follow the [feature development process](../../../Processes/FeatureDevelopment.md).
Delivery order is D10.1, then [D10.2](VanishingProgressBarsImplementationPlan.md),
then [D10.3](CurrencyGridColumnsImplementationPlan.md). This plan covers the
shared editor, session behavior, existing HUD settings, and presentation-only
controls for the later tickets. D10.2 and D10.3 wire their bar-visibility and
grid-column behavior into these controls.

## Current implementation and prior art

- [Settings.lua](../../../../Core/Settings.lua) owns the LAM tracker and bar
  controls, plus settings navigation. Its callbacks write preferences directly.
- [CurrencyPanel.lua](../../../../Tracking/CurrencyPanel.lua) owns currency and
  capacity selection, ordering, notifications, location toggles, the custom
  resource list, and Reset Panel. Reset currently writes preferences directly.
- [ItemTrackerPanel.lua](../../../../Tracking/ItemTrackerPanel.lua) owns tracker
  rendering and `trackerOffsetX/Y` position saves. The tracker settings are
  currently defined in Settings.lua.
- [ResourceProgressBars.lua](../../../../Banking/ResourceProgressBars.lua) owns
  standalone bar rendering and `offsetX/offsetY` saves for each resource.
- [Init.lua](../../../../Core/Init.lua), [Bindings.xml](../../../../Bindings.xml), and
  [Events.lua](../../../../Core/Events.lua) provide initialization, keybinding and
  slash-command registration patterns, plus cutscene/interaction refresh logic.
- [ItemDatabase.lua](../../../../Tracking/ItemDatabase.lua) owns profile defaults,
  preference copying, and profile validation. The DEV manifest controls load
  order; XML templates must load before their Lua consumers.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | A: edit the selected saved profile directly while persisting a pre-session HUD snapshot and active marker; restore on Cancel/recovery, clear on Done. B: make a complete working copy of the selected profile, have existing profile access use it during HUD mode, then copy the whole profile back on Done or discard it on Cancel. C: move HUD-owned settings into a dedicated saved-variable section, then swap that whole section with a working copy for the session. | Prefer A with a persisted recovery record: it uses the existing field access paths, while ESO's save-on-logout/`/reloadui` behavior lets startup detect and recover an unfinished session. C remains a cleaner data boundary at greater caller/migration cost; B carries unrelated-state risks. | APPROVED by Tim, 2026-11-08: Option A with a persisted pre-session HUD snapshot and active marker. This approves the architecture choice only; plan/code approval remains separate. |
| D2 | Reparent current LAM controls or recreate the presentation in XML and Lua. Recreating provides design flexibility without relying on LAM control layout/lifecycle assumptions. | Recreate the existing layout in XML and Lua, reusing maintained settings logic where applicable. | AGREED by Tim, 2026-11-08: recreate. "Lift and shift" means translating the layout into XML and Lua, not moving the actual LAM controls or their control code. |
| D3 | Include the later-ticket controls now to show the intended UI, or defer their creation until their behavior tickets. | Create the controls in D10.1 as presentation-only placeholders; wire their behavior in D10.2/D10.3. | AGREED by Tim, 2026-11-08: add controls now to show the UI appearance; they do nothing until the later tickets wire them up. |

## Data, compatibility, and failure contracts

Implement approved D1: edit the selected saved profile through existing access
paths, backed by a persisted HUD-only snapshot and active marker. Done keeps
edits and removes the record; Cancel restores the snapshot and removes it.
Startup detects unfinished sessions after a save/reload. Do not redirect
`GetSettingsProfile()`, reorganize existing fields, or restore the whole profile.

Use the existing profile-selection contract. Before changing profiles, cancel
the originating profile's session and clear it; never apply its preview values to
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

Agreed by Tim, 2026-11-08: every Reset Section restores all settings and
positions owned by that section to documented addon defaults. Tracker resets
its settings and position (50, 50); currency resets its settings, resource
preferences and position (50, 150), plus three columns when D10.3 is wired;
bars resets every resource's settings and default position, plus shared alert
colors. Each reset leaves the other sections and unrelated profile data alone.
This supersedes the currency position-preserving exception. Cancel restores
session-start settings and positions; Done keeps the reset. Unwired placeholders
remain inert. Verify exact reset coverage against `preferenceDefaults`,
`defaultsAccount`, resource defaults, and existing preference getters.

### Saved-variable structure findings (2026-11-08)

Source inspection, not a dump of live saved data:

- [PrepareSavedVariables](../../../../Tracking/ItemDatabase.lua#L772) validates
  profiles under `InventoryCompanion_SavedVariables.Default[account][profile]`.
  `$AccountWide` and character-ID profiles share this outer namespace.
- [GetSettingsProfile](../../../../Tracking/ItemDatabase.lua#L563) selects the
  character profile when `character.useCharacterItemList` is true, otherwise
  the account-wide profile. It returns a profile, not a HUD-specific section.
- [Profile preference fields/defaults](../../../../Tracking/ItemDatabase.lua#L548)
  and [account defaults](../../../../Core/Constants.lua#L209) place HUD fields
  alongside tracking/editor data. The groups in the sketch below are conceptual;
  they are not existing container tables. Current schema version is 10.
- [Currency preferences](../../../../Tracking/CurrencyPanel.lua#L79) have nested
  location tables, and currency/capacity preferences also hold notification
  choices. [Bar settings](../../../../Banking/ProgressBarResources.lua#L204)
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

Tim approved Option A with a persisted snapshot and marker on 2026-11-08.
Recording that architecture choice does not approve the implementation plan or
authorize a schema change or production code.

### D1 feasibility results (2026-11-08)

**Decision status: APPROVED by Tim, 2026-11-08.** The selected architecture is A
with a persisted pre-session HUD snapshot and active marker. This does not
approve the implementation plan or authorize coding.

#### Existing ownership and write boundaries

- `GetSettingsProfile()` returns `this.character` or `this.accountWide` according
  to `character.useCharacterItemList`; `SetUseCharacterItemList()` may initialize
  a character profile by copying account data before switching, and its settings
  callback then refreshes the displayed profile. No HUD-session cancellation
  currently exists.
- HUD-owned fields currently mixed into the profile root are:
  `showTrackedItemsPanel`, `showEmptyTrackedItems`, `trackerOffsetX/Y`,
  `wrapTrackedItemNames`, `trackerGroupThreshold`, `trackerMaxRows`,
  `trackerTitleSize`, `showEmptyCurrencies`, `currencyOffsetX/Y`,
  `currencyPreferences`, `capacityPreferences`, `progressBarPreferences`, and
  `progressBarAlertColors`. `currencyPreferences` and `capacityPreferences`
  include notification choices as well as display/ordering settings; these
  nested tables must move intact. `filterShow`, `filterNotify`, `filterCraftbag`,
  `filterMute`, and `filterUntracked` share the current preference list but are
  tracking-editor filters, not HUD fields. `currencyNamesById` is account-wide
  diagnostic data, not a HUD preference. D10.2/D10.3 fields are not yet saved;
  if C is chosen, their later additions belong in the HUD section.
- HUD readers/writers span `Core/Init.lua`, `Core/Settings.lua`,
  `Tracking/ItemDatabase.lua`, `Tracking/ItemTrackerPanel.lua`,
  `Tracking/CurrencyPanel.lua`, `Banking/ProgressBarResources.lua`, and
  `Banking/ResourceProgressBars.lua`. Currency notification consumers also read
  and update the nested currency/capacity preferences. Position handlers write
  saved offsets on `OnMoveStop`; Reset Panel replaces currency/capacity
  preference tables. A HUD section therefore needs field-path updates at all
  these surfaces, plus profile defaults, validation, copying, reset logic, and
  related tests.
- The inspected event path is mostly reads/refreshes, not saved HUD writes:
  `Core/Events.lua` reads the active HUD preferences and queues panel refreshes;
  inventory updates read the active tracked data/rules and update the runtime
  `itemCountsCache`; currency/capacity notification handlers update runtime
  baselines and pending-notification state. Those runtime values are not profile
  fields. However, routing `GetSettingsProfile()` to B's copy would also change
  the data those events read. Other persisted paths are outside that accessor:
  AutoCategory profile updates write `autoCategoryOrder`/setup state through
  `GetAutoCategoryProfile()`, while tracking-editor mutations write
  `GetActiveTrackedItems()`; both scopes must not be silently included in a HUD
  transaction.
- `GetSettingsProfile()` is not HUD-only: `GetActiveTrackedItems()` obtains
  tracked items through it, and its profile includes rules, tracking data, and
  editor filters. Rule/AutoCategory operations also use `GetAutoCategoryProfile()`
  or direct `accountWide`/`character` references, which bypass a replacement of
  `GetSettingsProfile()` alone. The current profile-copy helper copies item-list
  data and `preferenceFields` while preserving destination metadata; it is not a
  full-profile transaction. A full-copy implementation cannot safely assume
  every writer is routed through one accessor.

#### A/B/C comparison

| Option | Feasibility evidence | Principal limitation |
|---|---|---|
| **A — direct saved-profile edits plus a persisted recovery snapshot/marker** | Snapshot the 15 current HUD-owned root fields before editing, store the snapshot and active marker in the same profile, and keep existing setters/position handlers. Tim confirms ESO saves the addon SavedVariables together on logout and `/reloadui`: startup can detect the marker and offer resume or restore. If the process crashes before a save, unsaved edits and marker are both absent from disk. This is the least caller rewiring. | Requires a persisted transaction record and startup recovery flow; Cancel/automatic exit must restore only the originating profile. Restoring whole HUD preference tables can undo another writer's changes to those same HUD fields during the session. A marker left by this version must not be silently ignored by an older addon version. |
| **B — complete active-profile working copy** | A private copy naturally makes staged writes disappear on Cancel or reload, and a profile-bound copy can be committed on Done. | `GetSettingsProfile()` serves both HUD and tracking/editor state; redirecting it changes more than the HUD. Rule/AutoCategory and direct profile paths bypass it, so a whole-profile commit can overwrite their updates, while shared-accessor writes to tracking/editor fields can be unintentionally committed or discarded. The root must also be copied from the registered SavedVariables data, not presumed enumerable through its interface. A selective HUD merge would avoid the full-copy overwrite but would no longer be the proposed whole-profile commit. |
| **C — dedicated HUD section plus section working copy** | After one-time field organization, the editor can stage a deep copy of only `profile.hud`; Done replaces that section, while Cancel, automatic exits, profile switches, or reload discard it. Unrelated tracking/editor data remains outside the commit boundary. Keeping currency/capacity preference tables whole preserves notification behavior. | More upfront work: update every HUD field reader/writer, defaults/validation/profile-copy/reset paths, all-profile migration and tests. Current schema is 10; moving existing fields means older builds cannot safely read the new layout, so implementation would require a schema bump (to 11 if no intervening schema change), migration and downgrade refusal before constructors, plus backed-up older-schema UAT. |

#### Synthetic prototype evidence

[HUDSessionFeasibilityPrototype.lua](../../../Tests/HUDSessionFeasibilityPrototype.lua)
defines isolated account and character profiles with nested currency/location
preferences, notification flags, bars, tracking data, and unrelated account
settings. It exercises:

- A: nested/scalar direct edits, scoped rollback preserving a tracking update,
  profile-switch cancellation against the originating profile, a save boundary
  persisting preview/marker/snapshot together, startup restore or resume, Done
  clearing the marker at the next save, and crash-before-save leaving the
  previous saved state untouched.
- B: full-copy Done committing tracking data changed through the shared copy
  and overwriting unrelated raw-profile updates; Cancel/reload discarding the
  copy; and Lua 5.1 `pairs()` seeing no root fields on the repository's empty
  forwarding-proxy test shape.
- C: moving synthetic legacy fields into `hud`, staging nested edits and
  notification preferences, committing only `hud` while preserving a tracking
  update, and discarding the staged section on Cancel/reload/profile change.

Reproduce with the installed Lua 5.1 runtime:

```powershell
python -c "from pathlib import Path; from lupa.lua51 import LuaRuntime; runtime=LuaRuntime(unpack_returned_tuples=True); runtime.execute(Path(r'Project\Tests\HUDSessionFeasibilityPrototype.lua').read_text(encoding='utf-8-sig'))"
```

Actual result:

```text
PASS A+: saved recovery record supports save/startup restore and preserves crash semantics
PASS B: staging is transient, but full-profile copy/commit has proxy and overwrite scope risks
PASS C: isolated section staging commits only HUD fields and preserves non-HUD updates
3/3 synthetic HUD-session feasibility prototypes passed (Lua 5.1)
```

These are synthetic table tests only. They neither load addon code nor access
live inventory or SavedVariables. The save-boundary model follows Tim's
confirmation that ESO saves SavedVariables together on logout and `/reloadui`,
and does not save process changes on a crash/forced termination. The fixture
does not independently verify ZOS serialization. [AutoCategorySpikeTests.lua](../../../Tests/AutoCategorySpikeTests.lua)
models `ZO_SavedVars` interfaces as empty forwarding proxies, which demonstrates
why B's root-profile copy semantics need explicit treatment. Startup recovery
prompt timing and handling still require implementation and in-game validation.

#### Recommendation and bounded next work

**Approved architecture choice: A with a persisted recovery snapshot and
marker.** Since ESO saves the settings, marker,
and snapshot together on logout and `/reloadui`, a reload while editing can be
recovered on the next addon load; a crash before saving leaves the previous
on-disk profile unchanged. This avoids routing `GetSettingsProfile()` through a
whole-profile copy and avoids moving every HUD field into a new section. C is a
reasonable alternative if a separate HUD data boundary is preferred, but its
broader caller and migration work is not necessary just to recover the edit session. B remains the riskiest option.

The persistent marker/snapshot are new saved data. Because an older build would
not know an active marker means its HUD edits may be provisional, do not assume
an additive field is safe to ignore: plan a schema bump (to 11 if unchanged),
pre-constructor migration/validation, and older-build refusal without mutation.
These changes remain unimplemented; plan approval and a separate explicit GO to
code are still required.

Under approved A with recovery, store one deep snapshot and timestamp/active
marker on the originating saved profile before the first edit. Done clears the
recovery record; Cancel and automatic exits restore the snapshot and clear it
before switching profiles. At startup, a valid marker offers Resume or Restore;
Restore applies the snapshot, while Resume retains the current preview and
re-enters the editor. Validate that the record matches its profile and contains
only the HUD field set; do not restore unrelated settings. Test the schema
migration and older-reader refusal without mutation. The later rendered trial
remains necessary for startup-prompt timing, profile lifecycle, and UI
acceptance.

## Ordered implementation

### Step 1: Design the shared editor transaction

- Depends on: None for source-grounded planning. Production implementation
  requires spec/plan approvals and a separate GO to code.
- Spec coverage: AC10, AC12, AC13.
- **D1 feasibility check (planning only; evidence recorded above):** Source
  inspection established the account/character selection paths, current
  preference fields, nested-copy behavior, profile-copy scope, and proxy limits.
  The isolated Lua 5.1 A/B/C prototypes exercise Done/Cancel, unrelated writes,
  profile-bound cancellation, nested isolation, and reload persistence. They do
  not establish ESO serialization or reload-event ordering; those remain in-game
  verification limits.
- Before plan approval, finalize the approved D1 recovery contract with Tim.
  Do not assume copying a table or assigning a Lua field changes the table
  registered with ESO SavedVariables; verify the actual ZOS behavior in-game.
- **Feasibility decision criteria:** Prefer the least invasive option that
  reliably isolates Cancel/automatic-exit/reload behavior and does not overwrite
  unrelated state. A full-profile copy is suitable only if committing or
  discarding it cannot lose unrelated updates or unexpectedly commit unrelated
  changes. A dedicated HUD section is suitable only if the migration and caller
  changes are bounded and validated. Do not implement any production
  architecture as part of this check; Tim approved Option A with a persisted
  snapshot and marker on 2026-11-08. Plan approval and a separate explicit GO to
  code remain pending.
- Map every lifted control to its current getter/setter, refresh side effect,
  profile field, default and reset behavior, including all section-owned
  positions under the agreed reset policy.
- Implement the approved D1 transaction state and existing profile access path.
  Ensure profile change cancels before switching and edits cannot leak across
  profiles; ensure cancellation cannot discard unrelated profile updates.
- Verification design: isolated tests for snapshot, preview, Done, Cancel, reset,
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
  interaction, profile change, and saved-record recovery. Confirm exact ESO
  events and lifecycle ordering during implementation planning.
- Keep existing HUD `OnMoveStop` profile writes, protected by the session snapshot,
  and render the edited profile directly. Temporarily reveal actual movable controls without
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
- Add XML/Lua and manifest entries in dependency order. The persisted recovery
  record requires migration/schema/downgrade safeguards before normal-data testing.

### Step 3: Complete section resets and acceptance

- Depends on: Step 2.
- Spec coverage: AC9, AC10, AC12-AC13.
- Add one Reset Section control per section. Reset all of that section's settings
  and positions to defaults, leaving other sections untouched. Currency reset
  now resets its position as well as preferences; D10.3 later adds the column
  reset. Verify reset-then-Cancel restores pre-session positions/settings and
  reset-then-Done keeps defaults, including per-resource bar positions.
- Verify that Done commits only edited HUD fields to the originating profile;
  Cancel and automatic exits restore captured values and positions, preserving
  unrelated state. Test empty/nonempty HUDs and each entry/exit route.
- Obtain Tim's in-game trial of editor clutter, configuration access, dragging,
  and real-control sizing before acceptance. Update user documentation after
  implementation; no release, version, commit, or merge work is authorized here.

## Code blueprint for Steps 1-3

Names below are proposed APIs unless explicitly marked existing. They describe
implementation shape, not completed code. Keep snapshot logic separate from
window construction, but do not introduce a replacement settings framework.

#### Step 1: Snapshot ownership, validation and recovery

Create `Tracking\HUDSettingsSession.lua`, loaded after
`Tracking\ItemDatabase.lua` and before the new HUD editor Lua. It owns one
transient session reference and the HUD field inventory; the originating
profile owns the persisted `hudEditRecovery` record. Proposed record shape:
`formatVersion`, `active`, `startedAt`, `profileKey`, and `snapshot`.
The snapshot contains the 15 existing HUD root fields listed above, including
deep copies of currency/capacity/bar preference tables and alert colors.
Missing optional fields retain their missing state on restoration. D10.2/3
extend this inventory without moving existing fields. Snapshot capture uses
explicit field reads, not `pairs(profile)`, because the ZOS profile may be a
forwarding interface. Resolve profile identity from the registered account
profile/key and the selected ZOS handle; do not assume they are identical tables.

- Create local `CaptureHUDSettings(profile)` returning the HUD-only snapshot
  using existing `CopySavedValue`. Create local
  `RestoreHUDSettings(profile, snapshot)` assigning deep-copied captured
  fields, including removal of fields absent in the snapshot. Neither touches
  tracked items/rules, filters, AutoCategory data, or account automation settings.
- Create `ValidateHUDRecoveryRecord(record, profileKey, context)` in
  `Tracking\HUDSettingsSession.lua`: reject invalid format, marker, profile
  identity, timestamp, snapshot keys/types and malformed nested preferences.
  Reuse profile preference validation on an isolated candidate; never normalize
  an invalid record into apparent success or mutate live data during validation.
- Modify existing `PrepareSavedVariables()` in
  `Tracking\ItemDatabase.lua`: after collecting profiles and checking versions,
  validate all recovery records before publishing any migration. Carry the
  record through candidate migration; do not inherit or copy it into another
  profile. Extend the explicit migration-version gate and update
  `SettingsVersion` in `Core\Init.lua` (11 only if still the next schema).
  Validate every profile, including inactive characters, before ZOS constructors.
- Create `BeginHUDSettingsSession()` returning the selected profile's session:
  assert no unresolved recovery/session, resolve originating profile/key, capture
  the snapshot, and install the persisted record before edits. Create
  `FinishHUDSettingsSession(outcome)` accepting only `done` or `cancel`:
  verify originating identity; on Cancel restore its snapshot; on either outcome
  clear its recovery record and transient reference. Refreshing the HUD is the
  coordinator's responsibility, not the snapshot helper's.
- Modify existing `SetUseCharacterItemList(value)` and `CopyProfile(sourceKey)`
  in `Tracking\ItemDatabase.lua` to cancel an active HUD editor before changing
  profile selection or copying over its destination. `CopyItemListProfile`
  must never copy session/recovery records. Do not cancel ordinary non-HUD
  inventory updates; those remain outside the snapshot.
- Create `FindHUDRecoveryRecords()` returning validated current-account profile
  keys with unfinished records, not copies of entire SavedVariables. Create
  `ResolveHUDRecovery(profileKey, outcome)` for `resume` or `restore`; operate
  on the named originating profile, never whatever profile happens to be active.
  Resume preserves both the preview and original snapshot, not a new snapshot
  of the preview. Startup prompt timing, inactive-profile Resume behavior, and
  unavailable combat/interaction contexts need agreement before wiring this API.

Caller flow: `Core\Init.lua.Initialize` calls existing
`PrepareSavedVariables` before both `ZO_SavedVars` constructors. Once resources,
HUD controls, settings, and the new editor are initialized, call
`CheckHUDRecovery()` (new coordinator method) to present unresolved recovery
records. It calls `FindHUDRecoveryRecords`, then the approved recovery UI calls
`ResolveHUDRecovery`. No production recovery flow is considered approved solely
because its proposed methods are named here.

Verification: extend `Project\Tests\SavedVariablesTests.lua` with malformed
record/all-profile/no-partial-migration/copy-exclusion tests. Add
`Project\Tests\HUDSettingsSessionTests.lua` for Begin, Done, Cancel, nested
isolation, missing fields, unrelated writes, originating-profile restoration,
and serialized-preview-plus-record recovery. Existing standalone
`HUDSessionFeasibilityPrototype.lua` is evidence, not a substitute for tests
loading these production methods. Register `GetHUDSettingsSessionTests()` and
`GetHUDSettingsPanelTests()` suites in `Project\Tests\Run-RuleTests.py`, with
isolated Lua 5.1 runtimes, source-loading stubs and the session module loaded
after the database; include its source in the saved-variable validation runtime.
Run the existing offline runner with named
`HUDSession|HUDRecovery` test selectors once those tests are registered.

#### Step 2: Window, entry points and rendering lifecycle

Create `Tracking\HUDSettingsPanel.xml` and `Tracking\HUDSettingsPanel.lua`.
XML declares a movable top-level editor with title, collapsible tracker,
currency and bars containers, section reset buttons and persistent Done/Cancel
buttons. Lua owns construction, bindings, and editor lifecycle, not profile
selection or snapshot serialization.

- Create `InitHUDSettingsPanel()` to resolve XML controls once, bind Done to
  `ExitHUDSettingsMode("done")`, Cancel to `ExitHUDSettingsMode("cancel")`,
  and each section reset to `ResetHUDSettingsSection(sectionKey)`.
  Build controls through local `BuildTrackerSection(parent)`,
  `BuildCurrencySection(parent)` and `BuildBarsSection(parent)`.
  Their inputs are section containers; their outputs are control references
  used by `RefreshHUDSettingsPanel()`, not alternate saved settings.
- Create `EnterHUDSettingsMode(source)` for settings/slash/keybinding entry.
  Check player combat and interaction/cutscene boundary state first; report a
  blocked entry via existing `Utils.UserError` without starting a session.
  Begin the snapshot before editor callbacks can write. Close LAM on settings
  entry using verified ESO scene APIs; show the editor; call
  `RefreshHUDSettingsPresentation()` and `RefreshHUDSettingsPanel()`.
- Create `IsHUDSettingsModeActive()` returning coordinator state and
  `ExitHUDSettingsMode(outcome)` to finish the session, hide the editor, clear
  the positioning override and refresh normal HUD/event state. Repeated
  external cancel requests when closed are harmless lifecycle events; invalid
  internal outcome/session contracts assert.
- Create `RefreshHUDSettingsPresentation()` to call existing
  `RefreshResourceProgressBars`, `RefreshCurrencyPanel`,
  `RestoreTrackerPosition`, `RefreshItemTrackerPanel`, and
  `UpdateEventRegistry` in that order after profile edits/reset/exit.
  Explicitly restore tracker/currency anchors from the selected profile before
  reflow; do not save temporary interaction adjustments.
- Modify `Core\Settings.lua.CreatePanelNavigation`/`CreateSettingsPanel`:
  add Manage HUD navigation calling `EnterHUDSettingsMode("settings")`; remove
  the relocated tracker/currency/bar submenus only after the new equivalents
  are wired. Preserve all unrelated options and existing currency Notify actions.
  New `/iclayout` registration in `Core\Init.lua` and a new
  `InventoryCompanion_ManageHUD` action in `Bindings.xml` call this coordinator;
  register its display string with other bindings. These identifiers are proposed.
  Repeat-entry/toggle exit behavior needs an explicit Done-versus-Cancel policy.
- Modify `Banking\ResourceProgressBars.lua.RefreshResourceProgressBars` to
  create real controls for disabled resources during positioning. Existing local
  `UpdateProgressBar` bypasses saved enable state only while mode is active;
  unavailable external values remain hidden. Existing `OnMoveStop` continues
  calling `SetProgressBarPosition`. Preserve normal state outside mode.
- Modify `Tracking\CurrencyPanel.lua.RefreshCurrencyPanel` and
  `Tracking\ItemTrackerPanel.lua.RefreshItemTrackerPanel` visibility paths to
  respect the mode while retaining actual content/font/geometry and saved filters.
  Empty content remains empty; do not create dummy cells/rows.
  Keep `OnCurrencyMoveStop` and `OnTrackerMoveStop` writes to original profiles.
- Modify `Core\Events.lua.InitCutsceneTicker`: before normal visibility and
  interaction positioning, cancel an active session when a cutscene or
  `Utils.IsItemInteractionActive()` starts. When positioning remains active, do
  not let this ticker re-hide preview controls or snap the tracker into an
  interaction position. Register `EVENT_PLAYER_COMBAT_STATE` in editor
  initialization to cancel on combat entry; it is a lifecycle listener, not
  conditional on enabled resources. Exact supported interaction coverage is
  still to be verified; reuse the existing ticker, not another polling loop.
- Modify enabled-resource predicates in `Core\Events.lua` only to include
  positioning's temporary need to refresh disabled real bars. Keep saved
  monitoring predicates intact outside mode. After every exit,
  `UpdateEventRegistry` removes subscriptions needed solely by positioning.
- Manifest order: `Tracking\HUDSettingsPanel.xml` before its Lua;
  `Tracking\HUDSettingsSession.lua` after `Tracking\ItemDatabase.lua`;
  `Tracking\HUDSettingsPanel.lua` after currency/tracker modules and before
  `Core\Events.lua`. Add `InitHUDSettingsPanel()` near the end of
  `Core\Init.lua.Initialize`, before recovery checks and before marking UI ready.
  Earlier-loaded functions may call these APIs only after complete addon loading.

Verification: `HUDSettingsSessionTests.lua` and new
`Project\Tests\HUDSettingsPanelTests.lua` stub controls/entry state and assert
all three entry points, blocked combat, exact control identity, unchanged
preferences on entry, MoveStop restoration, ticker/combat/profile cancellation,
and listener cleanup. Add XML structural checks to
`Project\Tests\Run-RuleTests.py` for section and Done/Cancel names/anchors.
Layout, keybinding delivery and real ZOS scene transitions require in-game checks.

#### Step 3: Settings callbacks and reset call graph

- `BuildTrackerSection` binds each existing scalar setter or direct field write
  to the selected real profile; Show uses existing `SetItemTrackerPanelVisible`.
  Call `RefreshHUDSettingsPresentation` after changes and
  `RefreshHUDSettingsPanel` to update displayed values/disabled state.
- Refactor `Tracking\CurrencyPanel.lua` local `CreateResourceSettingsList`,
  `RefreshResourceSettingsList`, and `ResetCurrencyPanelPreferences` into reusable
  presentation-independent entry points `CreateCurrencyResourceSettingsList(parent)`,
  `RefreshCurrencyResourceSettingsList(control)` and
  `ResetCurrencyPanelPreferences()` as required by the new editor. Preserve the
  existing `MoveResource`, `SetCurrencyLocationVisibility`,
  `SetSettingsRowVisibility` and notification setters behind the resource rows;
  do not duplicate their ordering/combined-cell logic. Remove dependence on a
  LAM-owned global list control from reset; refresh the editor-owned list instead.
- `BuildBarsSection` uses existing `GetProgressBarSettings`,
  `SetProgressBarSetting`, normal/alert-color getters and setters. Its later-ticket
  visibility controls and currency columns are present but cannot write or
  alter rendering/reset data until the owning tickets wire them.
- Create `ResetHUDSettingsSection(sectionKey)` in
  `Tracking\HUDSettingsSession.lua`: require an active session and a valid
  tracker/currency/bars key; reset only the field subset documented above using
  deep copies of defaults. Currency resource defaults come from the extracted
  `ResetCurrencyPanelPreferences`, plus show-empty and position defaults.
  Bars clear known per-resource owned settings to documented resource defaults,
  preserving unknown unrelated preference fields; restore shared alert colors.
  The snapshot remains unchanged so Cancel undoes all resets.
- Reset button flow: callback -> `ResetHUDSettingsSection` ->
  `RefreshHUDSettingsPresentation` -> `RefreshHUDSettingsPanel`. Done/Cancel
  button flow: callback -> `ExitHUDSettingsMode` ->
  `FinishHUDSettingsSession` -> hide/clear override -> normal presentation refresh.

Verification: assert each reset changes exactly its section's fields/positions,
does not alter another section or the original snapshot, and remains reversible.
Test notification baselines/listener refresh when currency Notify is reset;
resetting preferences must not create fictional currency-change notifications.
Actual results remain PENDING; approved D1's durable recovery does not yet have
production implementation or in-game proof.

## Verification and acceptance mapping

| Spec criterion | Step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC8 | 2 | Offline entry-point tests; in-game Settings, slash, keybinding and Done. | All entry points use the same editor; settings closes; Done exits without reopening it. | PENDING |
| AC9 | 2-3 | Offline empty/nonempty fixtures; in-game drag checks. | Actual controls and real data only; no fabricated content or replacement geometry. | PENDING |
| AC10 | 1-3 | HUDSession/HUDRecovery fixtures and in-game Done, Cancel, reload recovery. | Done keeps edits; Cancel/automatic exits restore; a saved unfinished preview has a valid snapshot/marker and follows the agreed recovery flow. | PENDING |
| AC12 | 1-3 | Control/setter mapping, session/profile tests; in-game editor review. | One movable editor exposes existing HUD settings; LAM has navigation, not duplicates. D10.2/D10.3 controls appear as inert placeholders in D10.1; their functional acceptance belongs to later tickets. | PENDING |
| AC13 | 1, 3 | Reset-field assertions; in-game Reset, Cancel and Done. | Every section resets all its settings and positions; other sections remain unchanged. Cancel restores pre-session values; Done keeps defaults. | PENDING |

Synthetic tests must use isolated profiles and values, never live inventory or
saved variables. Offline tests cannot prove ESO event delivery, UI sizing, or
drag behavior. Back up shared saved variables before approved in-game tests.

## Open questions and risks

| ID | Question / risk | Blocking phase and mitigation | Resolution |
|---|---|---|---|
| Q2 | Which exact interaction events should automatically cancel positioning, and what slash/action identifiers should be used? | Detailed implementation planning; confirm against ESO event APIs and existing behavior. | PENDING |
| Q3 | Startup recovery prompt timing, Resume for inactive profiles or blocked contexts, and repeat-entry exit outcome. | Spec/plan approval; agree observable behavior before production recovery wiring. | PENDING |

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

### Exploratory HUD inspector prototypes (2026-11-10)

These are local experiments against the approved D10.1 design, not accepted
feature implementations. The shared D10.1 checkpoint is
`feature/hud-positioning` at `acbafef`.

- `feature/hud-inspector-fixed` at `27c6ca6` tests one fixed-position bar
  inspector: clicking a progress bar updates the settings shown in the same
  editor. This bars-only prototype still has the Done/Cancel shell separate
  from the editor. Done is inert; Cancel restores the opening state. Currency
  and tracker configuration are omitted. Offline validation passed 220/220;
  independent review found no actionable issues. It has not been tested in
  game.
- `feature/hud-inspector-contextual` started at `37c9e2a` as a bars-only
  inspector positioned beside the selected bar. Commit `4b45541` expands it
  into a floating, single-panel POC: the controls change for the selected bar
  or currency panel, with Done/Cancel in the same fixed footer. Done remains
  inert and Cancel restores the opening state. Currency configuration reuses
  the existing currency/capacity resource settings and adds the zero-balance
  toggle. Offline validation passed 221/221. Independent review found that an
  empty currency panel is hidden and cannot be selected. Tim approved a future
  follow-up: keep it selectable only during Manage HUD and show a truthful
  “No visible currency or capacity entries” cue, without fabricated resource
  data; that behavior is not implemented in `4b45541`.
- Neither prototype has had in-game visual testing, been copied to PTS, pushed,
  or merged. DEV was returned to `main` at `6d4a28c` for Tim to consider the
  alternatives. The fixed-versus-contextual interaction and final D10.1
  acceptance remain undecided.

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
