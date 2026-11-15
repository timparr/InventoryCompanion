# Configurable currency columns and scene behavior: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: [D10.3 (formerly F1)](../../Tasks/TODO.md)
Spec: [Configurable currency grid columns](../FeatureSpecs/CurrencyGridColumnsFeatureSpec.md)
Owner: Copilot (draft author)
Updated: 2026-11-15

## Open questions

| ID | Question | What is needed to resolve it |
|---|---|---|
| Q12 | Can the repeated tracker interaction-placement behavior be replaced outright without losing necessary corrective behavior? | **In-game investigation:** suspend only repeated positioning after initial scene placement; verify the panel stays put and becomes freely movable. Test protocol below; result PENDING. |

Use the [feature development process](../../Processes/FeatureDevelopment.md).
The spec is authoritative for product behavior. This plan groups technical work
into tasks and is not yet complete for the newer scene requirements. Previous
settings-overlay-only assumptions do not override the spec.

## Current implementation and prior art

- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua) uses a fixed
  `COLUMN_COUNT = 3`. `RefreshCurrencyPanel()` measures variable-width columns,
  anchors cells row-major, sizes the panel, and preserves its top-left anchor.
  `GetCurrencyPanelSettingsControls()` and `ResetCurrencyPanelPreferences()`
  provide the existing settings and reset path.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) owns the profile
  preference inventory, preparation, selection, and copying.
  `CopyItemListProfile()` is also used to initialize a character profile.
- [Settings.lua](../../../Core/Settings.lua) registers the settings controls
  and LAM callbacks. [Events.lua](../../../Core/Events.lua) includes the
  `InitCutsceneTicker()` scene-transition behavior.
- [ItemTrackerPanel.lua](../../../Tracking/ItemTrackerPanel.lua) contains
  tracker-specific interaction positioning and restoration. Standalone-bar
  behavior is in [ResourceProgressBars.lua](../../../Banking/ResourceProgressBars.lua).
  These are starting points, not a complete scene-lifecycle design.
- The previous settings-overlay work was reviewed provisionally, but the newer
  scene visibility, placement, persistence, transition, and reset requirements
  still need a complete design using the investigation results below. The
  [historical plans](../Archive/HUDLayoutAndVisibility/README.md) are context,
  not current requirements or approval.

## Technical options and decisions

**Entry-only placement - agreed with Tim, 2026-11-15:** calculate automatic
positions on supported screen entry/change and retain them in runtime state
for that visit only. Do not add size, visibility, window-movement, or screen-size
listeners or geometry polling to trigger repositioning while the scene remains
open. Existing content and visibility updates still run without reflowing scene
positions. On re-entry, calculate from the preserved non-scene anchor, not the
previous automatic result. A completed user drag saves its scene position and
leaves it there. This replaces the earlier coalesced-invalidation proposal.

**User-position precedence - Tim, 2026-11-15:** leave user-chosen scene anchors
unchanged when a panel grows or UI geometry changes,
even if they become obstructed or fit poorly; the user adjusts them. Restore
those saved anchors on scene entry without an automatic correction pass.

**Constrained-space fallback - agreed with Tim, 2026-11-15:** keep it simple.
If clear placement with normal spacing is impossible, allow IC-panel overlap
with a 20 px down-and-right stagger so panels can be grabbed independently.
Clamp to the screen if no clear fit remains, accepting unavoidable ZOS overlap;
for oversized panels keep the top-left accessible. Do not add elaborate
overlap minimization or packing. The in-game stagger test below will verify
20 px and try 40 px if needed; that is pending verification, not an open
fallback-policy question.

**Discovery timing - Tim, 2026-11-15:** use the existing initialization-time
currency discovery. Compute the selectable maximum from that session's grouped
resource roster; no new discovery listeners or live slider-bound refresh helper
is needed. Profile changes still refresh the effective selected value.

**Side-stack design - agreed with Tim, 2026-11-15:** generalize the existing
tracker's side-placement approach for all supported screens. Retain unobstructed
panels, then place displaced panels in a vertical stack beside the active
window: right if it fits, otherwise left, then the agreed fallback. Use stable
order: tracker, currency panel, then bars in resource order. Test 5 px gaps,
both sides, retained-panel obstacles, and fallback using Task 3's deterministic
anchor and fitting rules.

The earlier nearest-position candidate-search prototype is no longer the
selected design. Retain its results as historical investigation evidence, not
required production logic or proof of the new stack behavior.

**Integration constraint - Tim, 2026-11-15:** extend the existing scene-responsive
tracker functionality or replace it with a shared solution covering the tracker,
currency panel and standalone bars. Do not retain duplicate scene-placement
implementations or independent controllers that compete to move the tracker.

**Conditional replacement direction - Tim, 2026-11-15:** if the in-game
timer investigation below confirms there is no necessary corrective behavior,
replace the whole existing tracker interaction-placement behavior with the
shared controller, rather than preserving its repeated forced positioning.

Proposed shape for discussion: one scene-responsive layout controller owns
context selection, placement and normal-position restoration for all HUD panels.
The existing ticker, editor callbacks, profile refresh and panel refresh paths
must delegate to that owner rather than continuing to apply tracker-specific
anchors independently. Task 3 proposes the file, methods and caller wiring for
review; this is not approval to add addon code.

The appendix records source evidence and tested options, not approval of those
options. Discuss the remaining choices above before completing the task designs.
Product decisions belong in the spec.

Scene keys must represent the spec's screen/interaction types rather than raw
ZOS scene names. Map all IC editor tabs to one editor key, and distinguish bank
from house bank and merchant from fence. Retain the existing scene-response
lifecycle as the baseline, subject to the timer investigation above and the
spec's direct-transition and restoration requirements. Gamepad-specific keys,
scene repairs and placement are not part of this feature; preserve existing
gamepad behavior and defer comprehensive review to TODO F14.

## SavedVariables changes and migration

Assessment: a schema bump is required because the released schema-10 reader
does not copy unknown feature fields when copying profiles. A schema-11 fixture
is rejected without mutation by that reader in the offline test described in the
appendix. The following field mapping and data rules complete the Q11 design;
they remain subject to independent plan review and overall plan approval.

### Current structure (schema 10)

We already store X/Y coordinates for normal (non-scene) positions. The tracker
and currency panel use separate named fields; each standalone bar has an
`offsetX`/`offsetY` pair in its resource preferences. These are top-left offsets
relative to `GuiRoot`, not fields named `xpos`/`ypos`.

The enclosing keys match the inspected SavedVariables file; identifiers are
redacted. Values below illustrate existing fields, not live saved values.
Only representative settings and bars are expanded:

```lua
InventoryCompanion_SavedVariables = {
    ["Default"] = {
        ["<account>"] = {
            ["$AccountWide"] = {
                ["version"] = 10,
                ["showTrackedItemsPanel"] = true,
                ["trackerMaxRows"] = 20,
                ["trackerTitleSize"] = 20,
                ["trackerOffsetX"] = 50,
                ["trackerOffsetY"] = 50,
                ["showEmptyCurrencies"] = true,
                ["currencyOffsetX"] = 50,
                ["currencyOffsetY"] = 150,
                ["progressBarPreferences"] = {
                    ["capacity:bag"] = {
                        ["showBar"] = true,
                        ["offsetX"] = 50,
                        ["offsetY"] = 300,
                    },
                },
            },
            ["<profileCharacterId>"] = {
                -- Character profile and character-specific settings.
            },
        },
    },
}
```

The active profile key is `"$AccountWide"` or a character-ID string,
selected by the current character's
`useCharacterItemList` setting. Thus a character profile already has an outer
character-ID key; the shared profile does not.
Bar entries are created as preferences are saved; resource
keys include `capacity:bag`, `capacity:bank`, and `currency:<currencyType>`.

Source: `Core\Constants.lua.defaultsAccount`,
`Tracking\ItemDatabase.lua.preferenceDefaults`,
`Banking\ResourceProgressBars.lua.CreateProgressBarControl()`, and
`Banking\ProgressBarResources.lua.SetProgressBarPosition()`.

### Proposed structure (schema 11)

**Panel ownership - agreed with Tim, 2026-11-15:** each panel owns its settings
and named layouts under `PanelSettings`. Normal running uses `Layout_NoScene`;
supported screens use layouts such as `Layout_BankScene`. One layout-selection
path handles both, rather than a separate scene-position collection alongside
legacy normal-position fields. This supersedes the earlier `scenePositions`
proposal.

The matching example below preserves the existing values while moving them
into panel-owned settings. Only the tracker's scene layouts are expanded;
scene coordinates are illustrative user choices, not migration defaults:

```lua
InventoryCompanion_SavedVariables = {
    ["Default"] = {
        ["<account>"] = {
            ["$AccountWide"] = {
                ["version"] = 11,
                ["PanelSettings"] = {
                    ["Tracker"] = {
                        ["showTrackedItemsPanel"] = true,
                        ["trackerMaxRows"] = 20,
                        ["trackerTitleSize"] = 20,
                        ["Layout_NoScene"] = {
                            ["offsetX"] = 50,
                            ["offsetY"] = 50,
                        },
                        ["Layout_BankScene"] = {
                            ["<characterId>"] = {
                                ["offsetX"] = 800,
                                ["offsetY"] = 100,
                            },
                        },
                        ["Layout_SettingsScene"] = {
                            ["<characterId>"] = {
                                ["offsetX"] = 600,
                                ["offsetY"] = 100,
                            },
                        },
                    },
                    ["Currency"] = {
                        ["showEmptyCurrencies"] = true,
                        ["currencyGridColumns"] = 3,
                        ["Layout_NoScene"] = {
                            ["offsetX"] = 50,
                            ["offsetY"] = 150,
                        },
                    },
                    ["capacity:bag"] = {
                        ["showBar"] = true,
                        ["Layout_NoScene"] = {
                            ["offsetX"] = 50,
                            ["offsetY"] = 300,
                        },
                    },
                },
            },
        },
    },
}
```

For a character profile, the outer `["$AccountWide"]` key becomes
`["<profileCharacterId>"]`; the panel structure stays the same.
`Layout_NoScene` retains current profile-level ownership. Scene layouts contain
positions keyed by the opaque string from `GetCurrentCharacterId()`, separating
characters even in a shared profile and retaining identities during full copy.
All layouts use top-left offsets relative to `GuiRoot`.

Migration will move existing panel settings and normal coordinates into the
corresponding `PanelSettings` entry and `Layout_NoScene`, preserve unrelated
data, default currency columns to three, and advance every migrated profile
to schema 11 before constructors. Remove migrated legacy fields only after
successful preparation; do not retain duplicate writable storage or legacy
read fallbacks. The field mapping is specified below.

Scene layouts are sparse: create entries only for user moves. A missing scene
position selects automatic placement, retained in runtime state for that visit
only. Adding a panel does not require adding it to every scene. Full-profile
copy includes all panel settings and layouts; position resets clear the
affected panel's scene positions, while settings-only resets preserve layouts.

### Field mapping and identifiers

Paths below are relative to the selected profile. Keep existing setting names
inside each panel to minimize unnecessary renaming.

| Schema-10 field(s) | Schema-11 destination |
|---|---|
| `showTrackedItemsPanel`, `showEmptyTrackedItems`, `wrapTrackedItemNames`, `trackerGroupThreshold`, `trackerMaxRows`, `trackerTitleSize` | Same names under `PanelSettings.Tracker`. |
| `trackerOffsetX`, `trackerOffsetY` | `PanelSettings.Tracker.Layout_NoScene.offsetX`, `.offsetY`. |
| `showEmptyCurrencies`, `currencyPreferences`, `capacityPreferences` | Same names under `PanelSettings.Currency`; preserve the complete resource/location preference trees, including notification flags and ordering. |
| `currencyOffsetX`, `currencyOffsetY` | `PanelSettings.Currency.Layout_NoScene.offsetX`, `.offsetY`. |
| New `currencyGridColumns` | `PanelSettings.Currency.currencyGridColumns`, default 3. |
| `progressBarPreferences[resourceKey]` except `offsetX`/`offsetY` | `PanelSettings[resourceKey]`; retain `showBar`, `warningThreshold`, `dangerThreshold`, `normalColor`, and any unrecognized settings. |
| Bar `offsetX`, `offsetY` | `PanelSettings[resourceKey].Layout_NoScene.offsetX`, `.offsetY`. |

`progressBarAlertColors` stays at profile level because its warning/danger colors
are shared across bars. `currencyNamesById` is account-level discovery metadata,
not panel configuration; leave it where it is. Tracked lists/rules, AutoCategory
data, `filterShow`, `filterNotify`, `filterCraftbag`, `filterMute`,
`filterUntracked`, profile flags, backups, and other unrelated data also stay
in place. Moving panel fields must not change notification or filtering behavior.

Panel IDs are `Tracker`, `Currency`, `capacity:bag`, `capacity:bank`, and
`currency:<currencyType>` using the existing resource-key formatting. Layout
IDs are `Layout_NoScene`, `Layout_InventoryScene`, `Layout_BankScene`,
`Layout_HouseBankScene`, `Layout_GuildBankScene`, `Layout_MerchantScene`,
`Layout_FenceScene`, `Layout_EditorScene`, and `Layout_SettingsScene`.
Editor tabs resolve to the same editor ID. These are addon-owned identifiers,
not localized labels or raw ZOS scene names.

### Read, write, and caller rules

Add these data helpers in `Tracking\ItemDatabase.lua`:

- `GetPanelSettings(panelKey)` returns the active profile's prepared panel
  settings. Unknown internal panel IDs are errors, not empty-table fallbacks.
- `GetPanelLayout(panelKey, layoutKey, characterId)` returns the normal
  coordinates, or the named scene layout's character coordinates. Only an
  absent optional scene entry returns nil, explicitly requesting automatic
  placement. Reads never create scene entries or copy normal coordinates into
  them. Character IDs are required nonempty strings for scene access.
- `SavePanelLayout(panelKey, layoutKey, characterId, offsetX, offsetY)` validates
  and writes one complete coordinate pair. Normal writes update only
  `Layout_NoScene`; scene writes update only that character in that layout,
  even if the panel had not been automatically displaced.
- `ResetPanelLayouts(panelKey)` restores that panel's normal default and
  removes its known scene layouts for all characters within the active profile.
  This supports the existing profile-owned reset scope; it adds no UI action.

The shared layout controller supplies the active layout ID and character ID to
these helpers. It owns visit-only calculated positions; it never calls the
save helper for automatic moves. On exit it selects `Layout_NoScene`; direct
transitions select the destination layout without writing the source or normal
layout. Panel refreshes retain the active position rather than reapplying normal
coordinates or bottom-clamping a saved scene anchor.

| Existing callers | Required wiring |
|---|---|
| `Core\Settings.lua.CreateSettingsPanel()` tracker getters/setters/defaults; `Core\Init.lua.ValidateTrackerSettings()` | Use `GetPanelSettings("Tracker")` and the corresponding nested defaults. Boundary preparation supplies missing defaults; runtime validation asserts established contracts. |
| `Tracking\ItemTrackerPanel.lua` initialization, context-menu toggles, grouping, rendering, visibility and move-stop; `Core\Events.lua` tracker visibility checks | Read Tracker settings; initialization/restoration use the controller's layout selection. `OnTrackerMoveStop()` saves through the controller to `SavePanelLayout()`. Remove legacy offset reads/writes. |
| `Tracking\CurrencyPanel.lua` preference helpers, resource ordering/filtering, notification getters/setters, initialization, settings, reset and rendering | Read Currency settings, including both resource preference trees and grid columns. Move-stop uses the same controller/save path as the tracker. No scene calculation inside grid refresh. |
| `Banking\ProgressBarResources.lua.EnsurePreferences()`, `GetStoredPreference()`, `GetProgressBarSettings()`, `SetProgressBarSetting()`, `SetProgressBarPosition()`, `InitializeProgressBarResources()` | Resolve individual bar settings under `PanelSettings[resourceKey]`; position writes delegate to the controller/save helper. Pruning default-valued settings must never delete layouts or unrelated fields. Shared alert-color helpers stay profile-level. |
| `Banking\ResourceProgressBars.lua.CreateProgressBarControl()`, `RefreshResourceProgressBars()` | Use the selected layout/current visit position, not unconditional normal-offset reanchoring. |
| `Tracking\ItemDatabase.lua.RefreshProfileSettings()`, profile switch/copy callbacks; editor/ticker placement callers | Discard old profile references and visit coordinates, refresh panel data, then let the shared controller apply the current context using the destination profile. No independent normal-anchor writes. |
| `Core\Tests.lua`, offline test fixtures and assertions | Replace moved-field paths and adapt deliberate malformed-data tests to the preparation boundary; retain save/restore cleanup and avoid live-data mutation in new tests. |

### Validation and preparation

- Validate every stored profile, not only the active one. `PanelSettings`,
  known panel records and present layouts must be tables. Normal Tracker and
  Currency layouts get documented defaults only when optional fields are
  absent; explicit wrong types fail preparation.
- Coordinates must be finite numbers, including fractional offsets. Preserve
  existing signed Tracker/Currency coordinates; existing bar offsets retain
  their nonnegative rule. Scene pairs must contain both coordinates; never
  repair a malformed scene pair by mixing it with a normal/default position.
  Do not clamp saved coordinates to current screen bounds.
- Retain current boolean checks and integer ranges: group threshold 1-30,
  tracker rows 5-50, title size 16-28. Columns must be a positive finite integer;
  no saved upper bound. Rendering/settings use the effective roster cap without
  overwriting the selected value.
- Preserve existing resource/location validation, ordering rules, threshold
  ranges 0-1 and RGBA ranges 0-1. Retain the existing explicit warning/default
  normalization when a bar's warning threshold exceeds its danger threshold;
  do it at preparation, not repeatedly in maintained rendering code.
- Sparse bar preferences retain their documented resource defaults. For bars
  with one or neither legacy offset, preserve supplied components and complete
  missing ones from the existing resource descriptor before control creation.
  Capacity defaults remain (50,90)/(50,130); capped currencies retain
  `(50, 170 + (index-1)*30)` in the startup roster order. Startup discovery and
  `InitializeProgressBarResources()` prepare registered bars before getters or
  controls use them; this is initialization, not live layout recalculation.
- Validate all stored scene character keys as nonempty strings and all present
  known scene pairs, including characters other than the current one. Preserve
  unrecognized panel/layout keys and unrelated fields by deep copy, without
  activating them. Validate saved-value types/cycles through `CopySavedValue()`;
  unavailable resource entries must not be deleted merely because they are
  absent from this session's roster.
- Use the existing path-specific assertion/error convention in
  `PrepareSavedVariables()` for malformed saved data; stop initialization before
  constructors or publication. Do not silently drop bad coordinates, replace
  malformed tables, or partially commit a migration.

### Migration, copy, and reset sequencing

1. Extend `Core\Init.lua.SettingsVersion` and the explicit supported-migration
   check in `PrepareSavedVariables()` to schema 11. Keep the existing whole-tree
   newer-version scan before conversion. Versions 1-9 follow their existing
   conversions to the schema-10 candidate shape, then the field mapping above;
   version 10 maps directly. Version 11 validates the new structure and is
   idempotent on reload.
2. Keep legacy-field defaults/validation available to migration only. Build
   detached candidates for all profiles, map fields, deep-copy unknown data,
   prepare/validate the new representation, and stage removal of mapped old
   fields. Unexpected new `PanelSettings` data in an older-schema profile is
   a reported collision, not permission to overwrite it.
3. Preserve existing pre-10 inheritance and first-use character-profile rules.
   Schema-10 initialized character profiles retain their own settings even
   while inactive. Uninitialized character stubs remain stubs: validate any
   stored data but do not initialize them or discard unexpected panel data.
   Their first activation still copies the account profile through
   `CopyItemListProfile()`.
4. Publish converted panel trees, mapped-field removals, existing migration
   changes and version numbers only after every candidate passes. Update
   `preferenceFields`/`preferenceDefaults` and `defaultsAccount` to use
   `PanelSettings` rather than the removed panel fields. Keep shared preferences
   in the copy inventory. No live dual-writing or legacy fallback reads.
5. `CopyItemListProfile()` prepares and deep-copies the entire source
   `PanelSettings` tree before modifying the destination. Replace destination
   panel settings/layouts completely, preserving embedded character IDs and
   destination unrelated metadata. Use the same path for `CopyProfile()` and
   first-use `SetUseCharacterItemList()`; no aliasing or character-ID rebasing.
6. `ResetCurrencyPanelPreferences()` resets its existing resource preference
   trees/order plus columns to three; do not replace the Currency panel record
   or touch any layout or standalone bar. LAM settings-only defaults likewise
   preserve layouts. No dedicated position-reset action exists in inspected
   code; any position reset must use `ResetPanelLayouts()` rather than deleting
   an entire panel's settings.
7. Drag-stop saves immediately into the selected profile's new layout record.
   ESO's normal logout/reload persistence writes it to disk; no scene-close
   callback or special logout listener is needed.

Verification must cover the complete field mapping (including sparse offsets
and unknown data), all accounts/inactive profiles, legacy inheritance and
uninitialized stubs, schema-11 reload idempotence, malformed coordinates/IDs/
tables with no partial publication, deep-copy isolation and replacement,
settings-only versus position resets, and current-character-only drag writes.
Retain the pinned released-reader test: schema 10 must reject schema 11 before
constructors and leave the entire saved tree unchanged. Run migration UAT with
an actual older-schema backup under the project's safeguards. These are planned
checks, not results from an implemented migration.

## Data, compatibility, and failure contracts

- The column implementation stores `currencyGridColumns` in the currency
  panel's settings and validates it during saved-data
  preparation. Render and settings reads use the effective value without
  overwriting the saved value.
- The preceding section defines panel identifiers, field ownership, validation,
  migration, copy/reset and data-access rules. The controller's detailed scene
  lifecycle wiring remains part of Tasks 3-4; it does not reopen the data model.
- The previous supported schema-10 reader's guard and profile-copy behavior
  have been assessed as described in the appendix. Bump the schema, validate
  and migrate every profile before constructors, and retain the pinned-reader
  refusal test against the implemented new schema without mutation.
- Malformed saved data must be reported at the boundary, with unrelated data
  preserved and no partial migration published. Internal code consumes validated
  state and fails at broken internal contracts.
- If the schema changes, migration UAT requires an actual older-schema backup
  and the project's backup, logout, restore, verification, and recovery
  safeguards. Synthetic tests alone are insufficient.

## Implementation tasks

All tasks depend on an approved spec, an approved plan, and a separate GO to
code. The tasks below are planning drafts, not authorization to implement.
Pseudocode describes intended control flow, not addon code to load. New method
names are proposed implementation names; existing methods are identified below.
Tasks are work packages, not independently deployable builds: keep intermediate
schema/caller changes offline until the controller and drag wiring are complete.

### Task 1: Prepare profile data and compatibility

- Depends on: overall approval gates above.
- Spec coverage: CG1, CG4, CG5, CG7.
- Files/methods and affected callers: `Core\Constants.lua.defaultsAccount`;
  `Core\Init.lua.SettingsVersion`;
  `Tracking\ItemDatabase.lua.preferenceFields`, `preferenceDefaults`,
  `PrepareProfilePreferences()`, `CopyItemListProfile()`,
  `SetUseCharacterItemList()`, and `CopyProfile()`;
  `Project\Tests\SavedVariablesTests.lua`.
- Migrate panel-owned settings and coordinates into `PanelSettings`, including
  `Layout_NoScene`; update defaults, preparation, copy, and all affected settings,
  render, refresh, and position writers to the mapped paths and caller rules
  above; remove superseded fields rather than keeping
  two storage models. Use one layout-selection contract for normal and scene
  positions, preserving their different character-ownership rules.
- Provisional column design: add the scalar to the currency panel's settings;
  validate a finite positive integer without a resource-count upper bound.
  Prepare legacy profiles and include the value in the existing copy path.
- Implement the all-profile candidate preparation, field migration, validation,
  copy/reset, profile-switch and downgrade rules defined above.
- Verification: exercise valid, missing, malformed, and above-current-maximum
  column values; inactive profiles; copying; preservation; and the actual
  older-reader refusal where a schema change is required. Add corresponding
  scene-position, character-isolation, and migration cases defined above.

#### Migrate saved settings and update existing readers/writers

Modify `PrepareSavedVariables()` and `PrepareProfilePreferences()` in
`Tracking\ItemDatabase.lua`; add the four panel-settings/layout helpers defined
above in that same file. Keep migration-only legacy preparation separate from
schema-11 runtime access. Update all callers in the preceding caller table in
the same implementation task so the schema change does not leave broken reads.

```text
PrepareSavedVariables():
    enumerate all accounts and profiles
    reject any unsupported/newer version before changing saved data
    for each profile:
        candidate = detached copy of profile
        if legacy version:
            run existing legacy conversions on candidate
            move mapped panel fields into candidate.PanelSettings
            move normal coordinates into each panel.Layout_NoScene
            set Currency.currencyGridColumns = 3
            remove mapped legacy fields from candidate
        validate/prepare candidate using the rules above
        stage candidate and version 11
    after every candidate passes:
        publish staged changes without replacing unrelated metadata

GetPanelLayout(panel, layout, character):
    settings = GetPanelSettings(panel)
    if layout == Layout_NoScene: return settings.Layout_NoScene
    if scene layout or its character entry is absent: return nil
    return settings[layout][character]

SavePanelLayout(panel, layout, character, x, y):
    assert known panel/layout and valid complete coordinates
    if normal layout: replace normal coordinate pair
    otherwise: create optional scene/character entry; replace its pair
```

Result: schema-11 storage is the only runtime source. `CopyItemListProfile()`
deep-copies `PanelSettings`; existing filters and shared alert colors remain
in the preference inventory. Do not copy coordinates into scene entries during
preparation. Keep the existing defaults for sparse/uninitialized profiles as
specified above, not a blanket initialization of every character.

### Task 2: Add the Grid Columns slider and reflow the currency panel

- Depends on: Task 1's validated column preference.
- Spec coverage: CG1-CG4.
- Files/methods and affected callers: `Tracking\CurrencyPanel.lua`:
  `RefreshCurrencyPanel()`, `GetCurrencyPanelSettingsControls()`,
  `ResetCurrencyPanelPreferences()`; `Core\Settings.lua` settings registration;
  inventory, currency, discovery, and profile-refresh callers.
- Provisional contracts: derive the available-cell count using the existing
  combined-location grouping before display filtering. Measure and anchor using
  the same effective count, retaining variable column widths and existing
  pooled-cell cleanup. The settings setter validates the selected range,
  updates the active profile, and refreshes the panel.
- Compute the slider bounds when registering settings, after the existing
  `InitializeCurrencyHelper()` startup call. Use normal LAM value refresh for
  profile changes; do not add live resource rediscovery or dynamic bound
  mutation. Extend the existing reset
  path rather than adding a second reset.
- Verification: production geometry and settings tests for empty and populated
  layouts, variable widths, ordering, grouping, filters, discovery changes,
  effective caps without writes, profile changes, slider refresh, and reset.

#### Update settings UI: add Grid Columns slider

Modify the existing `GetCurrencyPanelSettingsControls()` in
`Tracking\CurrencyPanel.lua`: insert a LAM slider immediately after Show Empty
Currencies, inside the existing Currency Summary Panel section registered by
`Core\Settings.lua.CreateSettingsPanel()`. No new XML or settings window.
Modify the existing reset button's tooltip/warning to mention columns.

Add `GetCurrencyGridColumnLimit()` and `GetEffectiveCurrencyGridColumns()` in
`Tracking\CurrencyPanel.lua`. The former counts the startup roster using the
same resource grouping as the panel, before visibility/zero-balance filters;
the latter returns the saved choice capped to that limit without writing it.
Initialize the limit after `InitializeCurrencyHelper()` and before
`CreateSettingsPanel()` in `Core\Init.lua`.

```text
GetCurrencyPanelSettingsControls():
    return existing controls with this slider after Show Empty Currencies:
        type = slider; name = "Grid Columns"
        min = 1; max = GetCurrencyGridColumnLimit(); step = 1; default = 3
        getter = GetEffectiveCurrencyGridColumns
        setter(value):
            assert integer 1 <= value <= session limit
            GetPanelSettings("Currency").currencyGridColumns = value
            RefreshCurrencyPanel()

ResetCurrencyPanelPreferences():
    reset existing currency/capacity preferences and ordering
    GetPanelSettings("Currency").currencyGridColumns = 3
    refresh existing settings controls through LAM's normal value refresh
    RefreshCurrencyPanel(); UpdateEventRegistry()
    do not change layouts or bar settings
```

The setter resolves the active profile at call time, not the profile selected
when the control was created. LAM refresh after reset/profile change reads the
getter without invoking the setter, preserving an above-limit saved choice.

#### Update currency-grid measurement and cell placement

Modify existing `RefreshCurrencyPanel()` in `Tracking\CurrencyPanel.lua`;
replace every fixed-three-column width/index calculation, not just its constant.
Keep existing resource entries, formatting and pooled controls.

```text
RefreshCurrencyPanel():
    remember current top-left
    entries = existing visible/grouped entries in existing order
    columns = min(GetEffectiveCurrencyGridColumns(), count(entries))
    if entries are empty:
        release/hide pooled cells; mark panel empty; update visibility
        do not divide by zero or create phantom columns
    otherwise:
        widths = zero-filled array of length columns
        for each entry at one-based index i:
            column = ((i - 1) modulo columns) + 1
            widths[column] = max(widths[column], measured existing cell width)
        for each entry at index i:
            row = floor((i - 1) / columns)
            column = ((i - 1) modulo columns) + 1
            place cell using preceding widths, existing gaps and row height
        size root from occupied widths and row count; release unused cells
    preserve current top-left; notify shared visibility owner
    do not recalculate scene placement because dimensions changed
```

### Task 3: Coordinate scene visibility and placement

- Depends on: Task 1's panel/layout access and Q12's positioning investigation.
  Task 2 can be developed independently of this controller.
- Spec coverage: CG6, CG7.
- Integration constraint: generalize or replace the existing tracker scene
  placement path; do not add a parallel implementation. Account explicitly for
  `AdjustTrackerPositionForEditor()`, `AdjustTrackerPositionForInteraction()`,
  `RestoreTrackerPosition()`, `originalTrackerPos`, the ticker's callers,
  `UpdateEditorLayout()`, and `RefreshProfileSettings()`. Remove superseded
  logic or retain only thin delegating adapters where callers still need them.
- Inspected integration surfaces: `Core\Events.lua.InitCutsceneTicker()`,
  `Core\Settings.lua.CreateSettingsPanel()`, scene and interaction paths in
  `Tracking\ItemTrackerPanel.lua`, `Tracking\CurrencyPanel.lua`, and
  `Banking\ResourceProgressBars.lua`, plus the associated XML and ZOS/LAM
  controls. See the appendix for all-panel lifecycle and external scene mapping.
- Create the shared controller and wire the entry/exit, visibility and
  placement paths described below. Keep Q12's client evidence pending; if it
  exposes a necessary corrective behavior, discuss it before changing this
  entry-only design.
- Verification: production visibility and geometry tests for scene transitions,
  panel types, normal-view visibility including placeholders, disabled panels,
  unobstructed placement, side-stack spacing,
  competing obstacles, screen bounds, dynamic bars, and no persistence of
  automatic moves. Verify size/geometry changes during a visit do not reflow
  positions and re-entry recalculates defaults from non-scene anchors. In-game
  checks are required for real scene geometry and event delivery.

#### Create one shared HUD layout controller

Create `Tracking\PanelLayout.lua`, owning `InventoryCompanion.PanelLayout`.
Add it to `InventoryCompanion_DEV.txt` after `Tracking\ItemDatabase.lua` and
before editor/panel Lua callers. It defines methods at load time; it does not
access controls or saved profiles until initialization. No XML change is needed.

Proposed methods:
- `Initialize()` registers the tracker/currency control adapters and available
  bar adapters after their controls/data exist; initializes runtime context.
- `UpdateContext()` resolves the logical layout and active ZOS/IC window, calls
  `EnterContext(layoutKey, window)` only when the logical context changes, and
  updates visibility. Repeated calls in the same context must not move panels.
- `EnterContext(layoutKey, window)` selects saved layouts or computes entry-only
  defaults, stores runtime positions and applies them without saving.
- `ApplyPanelPosition(panelKey)` applies that panel's selected runtime/layout
  position when creation or explicit restoration requires it.
- `UpdateVisibility()` applies existing enabled/content/cutscene rules with the
  spec's supported-screen exceptions; it does not perform placement.

Adapters identify panel keys, controls, enabled/content state and dimensions;
they reuse existing panel/resource checks rather than inventing saved visibility
flags. Runtime state holds the active logical layout, profile identity, window,
per-visit positions and drag state. None is added to SavedVariables.

#### Wire scene entry, exit, existing refreshes and visibility

In `Core\Init.lua.Initialize()`, preserve preparation/discovery order, create and
initially render all panels, then call `PanelLayout.Initialize()` before
`CreateSettingsPanel()`. Start `InitCutsceneTicker()` after controller
initialization, not before module setup.

Modify the existing ticker in `Core\Events.lua` to delegate to
`PanelLayout.UpdateContext()` instead of forcing tracker anchors every tick.
Retain its cutscene observation; no new geometry polling/listeners. Modify
`Tracking\EditPanelTabManager.lua.UpdateEditorLayout()` and settings/LAM
open/close callbacks in `Core\Settings.lua` to request the same context update.
Resolve the visible IC editor first, then the active supported settings or
interaction screen, otherwise normal context, using the inspected keyboard
scene/control mapping. Resolve after the destination screen is visible so its
bounds exist. Editor tab changes retaining the editor key are not a new visit.
Do not introduce the deferred gamepad-scene repairs.

Modify `RefreshItemTrackerPanel()`, `RefreshCurrencyPanel()` and
`RefreshResourceProgressBars()` to retain current coordinates and delegate
visibility, removing competing normal reanchors/bottom correction during scene
layouts. Register bars during normal resource initialization/control creation.
Content, size or visibility changes must not reflow already placed panels.
Remove `originalTrackerPos` and superseded adjustment/restoration bodies if Q12
confirms replacement; keep a thin adapter only where an existing caller remains.

```text
UpdateContext():
    context = resolve supported logical screen or Layout_NoScene
    if context.layout != active.layout:
        EnterContext(context.layout, context.window)
    UpdateVisibility()

EnterContext(layout, window):
    clear previous visit-only coordinates
    for each panel in tracker, currency, resource-bar order:
        saved = GetPanelLayout(panel, layout, currentCharacter)
        if saved exists: runtime[panel] = copy(saved)
        otherwise: runtime[panel] = copy(panel.Layout_NoScene)
    if layout is a supported scene:
        retain saved scene positions and unobstructed normal positions
        stack displaced automatic panels using entry geometry
    apply positions once; mark active context
    never call SavePanelLayout for these automatic moves

UpdateVisibility():
    for each panel:
        normalVisible = panel's existing no-scene visibility/content decision
        visible = normalVisible AND
                  (ordinary scene/cutscene gating allows it OR supported screen)
        apply hidden state, retaining existing out-of-scope gamepad behavior
```

The normal-visibility decision includes existing placeholders and user content
preferences. Do not equate an empty item list with a hidden tracker or introduce
a new nonempty gate. Test the normal placeholder both with Show Empty enabled
and disabled, carrying that same result into supported scenes.

#### Place displaced panels beside the active window

Use the registered window's bounds, known relevant ZOS rectangles and retained
IC panel rectangles, never generic third-party enumeration. Reserve user-saved
positions as obstacles without correcting them. Only automatic panels whose
normal rectangles conflict join the displaced set.

```text
TrySide(side):
    results = empty; cursorY = max(0, window.top)
    for panel in displaced stable order:
        x = window.right + 5 if right, otherwise window.left - 5 - panel.width
        y = cursorY
        if x < 0 or x + panel.width > screen.width: fail entire trial
        repeat:
            blockers = obstacles conflicting with panel rectangle at (x,y)
            if no blockers: stop repeat
            y = maximum(blocker.bottom + 5 across blockers)
        if y + panel.height > screen.height: fail entire trial
        record panel at (x,y); cursorY = y + panel.height + 5
    return complete results

PlaceDisplacedPanels():
    results = TrySide(right)
    if failed: discard trial and results = TrySide(left)
    if failed: results = StaggerFallback()
    store complete results for this visit only; then apply anchors
```

Use 5 px clearance in collision checks (touching the clearance edge is allowed).
Only blockers with horizontal intersection including that clearance can advance
Y; select the maximum bottom edge, not whichever table entry is visited first.
Each iteration passes at least one finite obstacle, so search terminates.
Previously placed panels are separated by the cursor; include retained visible
panels and known ZOS rectangles as obstacles. Whole-stack fit means every
displaced visible panel is fully on-screen and clears those obstacles plus
earlier stack members. Do not apply partial right-side results before trying
left. Off-screen automatic normal rectangles also count as needing placement.

`StaggerFallback()` deliberately drops IC-to-IC collision checks, not ZOS
avoidance or on-screen priority. For N displaced visible panels, construct a
group with panel i at `(baseX + 20*(i-1), baseY + 20*(i-1))`; its bounding
dimensions are the maxima of these offsets plus each panel's dimensions.
Try group anchors in this fixed order: beside the window's right edge at its
top, beside its left edge at its top, screen top-right, screen top-left,
screen bottom-right, screen bottom-left. Clamp each group anchor to the screen
before testing. Choose the first whose member rectangles avoid ZOS rectangles;
IC overlaps are permitted. If none clears ZOS, use the first clamped candidate
and accept that unavoidable overlap. Deduplicate identical candidates.

If the staggered group exceeds a screen dimension, clamp each member on that
axis instead; clamp coordinate to `[0, max(0, screenSize-panelSize)]`, keeping
an oversized panel's top-left at zero. This can reduce the stagger only where
screen bounds make it unavoidable. Do not change saved user anchors. Test exact
edge fits, multiple simultaneous blockers, right-trial rollback, asymmetric
panel widths, obstacle-order independence, stagger offsets and oversized clamps.

Calculate entry positions for registered panels even if currently hidden, but
only visible panels reserve collision space. Showing an already registered
panel uses its visit position without moving others. A newly created control
uses its registered position; registration must precede display. No size-change
or visibility-change placement pass is added. Test real panel appearances in
UAT, rather than treating static rectangle tests as event-delivery proof.

### Task 4: Persist scene positions and integrate resets

- Depends on: Task 1's profile data design and Task 3's scene lifecycle.
- Spec coverage: CG4, CG7.
- Inspected integration surfaces: existing position writers, drag-stop handlers,
  profile switching and copying, all panel-position reset actions, and
  logout/reload behavior for the tracker, currency panel, and standalone bars.
- Wire the layout helpers from Task 1 into drag-stop, profile refresh and reset
  paths through Task 3's single controller, as described below.
- Verification: user drag versus automatic movement, re-entry, scene-to-scene
  transitions, non-scene restoration, logout/reload, shared-profile character
  isolation, profile copy/switch, and each position-reset path. Verify actual
  logout behavior in game with appropriate backups.

#### Save user drags to the correct layout

Add `PanelLayout.OnMoveStart(panelKey)` and `OnMoveStop(panelKey)` in
`Tracking\PanelLayout.lua`. Wire tracker/currency drag-start handlers (including
child-control `StartMoving()` callers) and bar `OnMoveStart`/`OnMoveStop` handlers
in their existing Lua files. At start capture the active profile/layout/character;
at stop validate that identity before saving, so a context change cannot write
coordinates to a different profile or scene. On a context change during a drag,
stop movement and cancel that pending save before applying the destination;
do not reposition while the drag remains active.

```text
OnMoveStart(panel):
    record drag owner = active profile, layout, current character

OnMoveStop(panel):
    assert drag owner matches current profile/layout/character
    x, y = panel control's current top-left
    SavePanelLayout(panel, active layout, current character, x, y)
    runtime[panel] = { x, y }
    clear drag state
    do not move other panels
```

Replace the existing normal-offset writes in `OnTrackerMoveStop()`,
`OnCurrencyMoveStop()` and bar move-stop/`SetProgressBarPosition()` with this
path. Programmatic `SetAnchor()` calls never invoke user-save logic. A canceled
drag's later stop notification is explicitly recognized as cancellation, not
an assertion failure or a successful write.

#### Restore layouts on scene/profile changes and integrate resets

Add `PanelLayout.OnProfileChanged()` and `ResetPanelPosition(panelKey)`;
modify existing `RefreshProfileSettings()` to call the former after refreshing
destination-profile panel content and bar registration. Existing profile
switch/copy callbacks keep calling that refresh path; do not capture old profile
tables inside settings closures.

```text
OnProfileChanged():
    cancel any drag; discard references/coordinates belonging to old profile
    resolve current context against the destination profile
    enter it once, selecting its saved layouts or automatic defaults
    refresh visibility and existing LAM getters

ResetPanelPosition(panel):
    ResetPanelLayouts(panel)
    discard that panel's visit position
    select its normal default or calculate its current-scene default
    apply only the affected panel; leave unrelated settings/panels alone

on scene exit:
    EnterContext(Layout_NoScene, no window)
on direct scene transition:
    EnterContext(destination layout, destination window)
```

Existing Currency Reset Panel remains settings-only: call Task 2's reset path,
not `ResetPanelPosition()`. No new reset button or logout listener. Saved scene
coordinates are already in the active profile before logout, including when
the scene is still open.

### Task 5: Complete regression coverage and user documentation

- Depends on: Tasks 1-4 for the corresponding tests and documentation.
- Spec coverage: CG1-CG7.
- Files: existing `Project\Tests\Run-RuleTests.py` and focused Lua suites;
  `Project\Publishing\Source Documents\UserManual.bbcode`.
- Register focused tests using production methods and ESO stubs; do not mutate
  live inventory or normal SavedVariables. Update user documentation to describe
  delivered behavior without treating unperformed checks as passing.
- Verification: run the focused selectors below, then separately approved
  in-game checks with required backups. Keep actual outcomes pending.

#### Add production-method tests and run focused verification

Extend `Project\Tests\SavedVariablesTests.lua`; add
`Project\Tests\CurrencyGridColumnsTests.lua` and
`Project\Tests\PanelLayoutTests.lua` to the existing runner with the required
stubbed controls/scenes. Add the new controller to the isolated runtime's load
order. Tests must call production methods, not copy the placement pseudocode or
use the superseded nearest-position experiment as regression coverage.

```text
SavedVariablesTests:
    migrate populated schema-10 and older fixtures; compare every mapped field
    verify unknown data, inactive profiles, sparse bars and character stubs
    inject malformed values in a late profile; assert entire tree unchanged
    reload schema 11; assert idempotent data; test pinned schema-10 refusal
    copy full profile; mutate destination layouts; assert source unchanged

CurrencyGridColumnsTests:
    capture actual returned LAM slider definition and invoke getter/setter/reset
    assert range, step, default, active-profile writes and above-cap retention
    render 0, 1, fewer-than-columns and multiple rows with variable-width cells
    assert exact row/column coordinates, order, occupied widths and fixed anchor

PanelLayoutTests:
    enter each context for all registered panel types
    assert visibility, side selection, 5 px gap and 20 px fallback stagger
    repeat same-context updates and change dimensions; assert no anchor writes
    leave/re-enter; assert fresh automatic calculation and normal restoration
    drag in scene/normal; assert only intended layout/character changed
    test direct transitions, profile copy/switch, canceled drags and resets
    assert automatic moves never create saved scene entries
```

Use stable test-name prefixes `Currency grid columns` and `Panel layout` for
the two new suites. Run:

```powershell
python Project\Tests\Run-RuleTests.py --test-filter "schema|profile|saved.variable|Currency grid columns|Panel layout"
```

The runner also performs its existing XML and Lua 5.1 compilation checks.
Run any additional directly affected notification/resource/tracker tests when
their moved-field fixtures are updated; record the exact selectors and results.

#### Update user documentation and record in-game acceptance

Modify `Project\Publishing\Source Documents\UserManual.bbcode` to describe the
slider under Currency Summary Panel, its reset behavior, supported screens,
per-character scene moves and restoration. This is feature documentation, not
release/version/package work.

```text
after offline safety checks:
    obtain approval for backed-up migration and in-game acceptance scope
    verify actual older-schema migration using the prescribed backup procedure
    preview slider at 1, 3 and maximum; test reset and profile switching
    open supported screens; compare normal-view visibility including placeholders
    check side stacks for all normally visible panel types
    resize/change columns while open; confirm no automatic repositioning
    drag, close/reopen, reload/logout and change character; verify ownership
    perform the pending 20 px untangling check and record actual results
    leave acceptance/review approvals pending until explicitly given
```

## Verification and acceptance mapping

| Spec criterion | Implementation task | Test / evidence | Actual result |
|---|---|---|---|
| CG1 | 1, 2, 5 | Default, layout, and settings preview | PENDING |
| CG2 | 2, 5 | Discovery, filtering, and range tests | PENDING |
| CG3 | 2, 5 | Layout and preservation tests | PENDING |
| CG4 | 1, 2, 4, 5 | Profile, copy, and reset tests | PENDING |
| CG5 | 1, 5 | Saved-data and older-reader safety tests | PENDING |
| CG6 | 3, 5 | Visibility and placement tests; in-game scene checks | PENDING |
| CG7 | 1, 3, 4, 5 | Persistence, isolation, transition, and logout tests | PENDING |

Offline tests cannot establish actual scene geometry, event delivery, or logout
persistence. In-game checks and any required backed-up migration UAT remain
pending separate approval.

### In-game investigation: repeated tracker positioning

Status: PENDING - protocol recorded; no timer or addon code changed.

- Purpose: determine whether another live-client path pushes the tracker back
  and whether repeated positioning serves any necessary corrective function.
- Controlled change: retain the initial interaction placement, then suspend
  only the timer's repeated call to `AdjustTrackerPositionForInteraction()`.
  Keep visibility checks and exit restoration active. Do not unregister the
  entire `_HideCheck` update: it also manages currency/bar visibility and
  cutscene hiding, which would confound this experiment.
- Preparation: back up SavedVariables before testing, since dragging currently
  writes normal profile offsets. Record the original anchor and test profile.
  Any temporary instrumentation needs separate execution authorization and
  must not be included in delivered runtime code.
- Exercise: open a bank, drag the tracker elsewhere and wait through multiple
  timer intervals. Trigger an inventory update and resulting tracker refresh;
  observe whether either undoes the drag. Close and reopen the interaction.
  Repeat for house bank, guild bank, inventory, merchant, and fence where
  available, noting any differences rather than assuming bank results apply
  everywhere.
- Expected, per Tim: no change apart from the panel becoming freely movable
  without repeated snap-back. Visibility, initial placement, ordinary content
  refresh, and normal-position restoration should otherwise behave as before.
  Record any unexpected movement, timing, or visibility changes explicitly.
- Cleanup: restore temporary instrumentation and the pre-test position/settings;
  verify the ordinary ticker behavior is restored before concluding the test.
- Result and evidence: PENDING. If confirmed, follow the conditional replacement
  direction above; if not, discuss the observed dependency before designing the
  replacement.

### In-game investigation: overlapping-panel stagger

Status: PENDING - protocol recorded; no panels moved or addon code changed.

- Purpose: check whether a proposed 20 px down-and-right stagger leaves
  overlapping panels easy to identify, grab, and move apart.
- Setup: capture the live anchors of the tracker, currency panel, and all
  currently enabled, non-empty standalone bars. Temporarily place them in a
  stack in a roomy on-screen area, each panel's top-left 20 px right and down
  from the previous one. Include all panel types and representative sizes.
  Keep the temporary moves runtime-only and prevent existing automatic
  positioning or refresh paths from undoing the test arrangement.
- Exercise: verify each panel can be identified and independently dragged out
  of the stack, including panels underneath others. Check actual mouse hit
  regions, not just whether a corner is visible. If 20 px is insufficient,
  repeat with 40 px and record which size works and why.
- Safeguards: back up SavedVariables before dragging, since current drag-stop
  handlers save normal offsets. Restore captured anchors and any preferences
  changed by dragging after each trial; do not save the test stack as a layout.
  Temporary instrumentation requires separate execution authorization and must
  not enter delivered runtime code.
- Result: PENDING. Verify the agreed fallback's initial 20 px stagger and
  discuss an adjustment to 40 px if the test shows it is needed.

## Verification risks

- Revalidate the installed LAM slider refresh contract and runtime event behavior
  during implementation and in-game testing.
- Verify that programmatic placement and restoration do not trigger saved
  position handlers or conflict with scene visibility updates.

## Independent plan review

Earlier provisional settings-overlay reviews identified anchor restoration,
multi-panel placement, LAM slider refresh, schema safety, and reset coverage as
areas requiring explicit contracts. Those reviews assessed an older plan and
do not establish coverage of the newer scene requirements.

Provisional independent reviewer: `plan-reviewer` (general-purpose agent).
Reviewed source: working-tree spec/plan on `main`, HEAD
`6ee0ecb3f7b90fe925d882410e7ddceee6420267`, 2026-11-15; uncommitted drafts.

| Finding | Tim's decision and resolution | Focused re-review |
|---|---|---|
| Stale appendix left shared/per-tab editor layouts undecided. | Fix authorized; appendix now specifies one `Layout_EditorScene` for all tabs. | PENDING |
| Placement pseudocode lacked deterministic advancement, fit and fallback rules. | Fix authorized; Task 3 now defines trials, blocker advancement, atomic side selection, fallback anchors and clamps. | PENDING |
| Meaning of tracker placeholder for visibility needed clarification. | Tim confirmed placeholders count: preserve normal no-scene visibility, not stricter emptiness filtering. Spec and controller pseudocode updated. | PENDING |
| Q12 repeated-positioning client evidence unavailable. | Keep the in-game investigation pending; no result or execution approval inferred. | PENDING client investigation |

Reviewer reported no findings in migration/downgrade, copy/reset, slider/grid,
or shared visibility integration. These are design assessments, not runtime
verification. Final independent review and overall approvals remain PENDING.

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

Planning only. No addon code, tests, migration, or in-game behavior has been
changed or verified.

## Independent code review and verification

- Reviewer and reviewed diff/source identity: PENDING
- Findings, agreed corrections, and re-review: PENDING
- Actual test results and retained evidence: PENDING
- Unavailable checks and remaining limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope and required backups: PENDING
- Actual Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed-work index, and archive links updated: PENDING
- Commit/merge authorization: PENDING
- Release follows the separate release process and is not authorized here.

## Appendix: Investigation results

Results describe inspected current code and external contracts, not approved
implementation choices. Available offline source investigations below are
complete for discussion; live-client verification and the explicitly listed
design choices remain open.

### Saved data and profile copying

- [Init.lua](../../../Core/Init.lua) sets schema 10 and calls
  `PrepareSavedVariables()` before either ZOS SavedVariables constructor.
  [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) checks every stored
  profile's version before conversion, builds candidate profiles, and publishes
  their selected fields only after validation and conversion complete. Its
  migration whitelist explicitly stops at schema 10, so a newer schema also
  needs an explicit supported migration path.
- `GetSettingsProfile()` selects the account or current character block.
  Profile copying replaces fields in the explicit `preferenceFields` list;
  unrelated destination metadata is retained. The same
  `CopyItemListProfile()` initializes a previously uninitialized character
  profile from the account profile. Profile refresh reanchors all three panel
  types, so scene state must be reconciled with profile switches and copies.
- The sibling installation is release 1.6.3, schema 10. Its `ItemDatabase.lua`
  and `Constants.lua` match tag `v1.6.3` exactly; its `Init.lua` differs from
  the tag only in the runtime version string. The tagged release reader is
  pinned at commit `9a1bb7d3cdc76185f56ad2ee821ff2806960fee0` in the offline
  harness rather than reading the mutable sibling installation.
- The pinned release reader rejects schema-11 fixtures before constructors and
  without mutating the saved tree, including newer data in an inactive profile
  or another account. At schema 10, its full-profile copy ignores unknown
  source fields and leaves destination fields unchanged. Thus additive
  profile-owned feature fields are not safely preserved by older full-profile
  copy; a schema bump and migration are required.
- Offline evidence: `python Project\Tests\Run-RuleTests.py --test-filter
  "schema|profile|saved.variable|tracker keeps Miscellaneous"`: 42/42 tests
  passed, including explicit copy, first-use copy and older-reader rejection.
  The reader and SavedVariables constructors run in isolated Lua 5.1 stubs,
  not the live game.

### Position and visibility lifecycle

- The tracker and currency `OnMoveStop` handlers write profile-level offsets
  directly. Each bar's handler calls `SetProgressBarPosition()`, which writes
  offsets inside that resource's `progressBarPreferences` entry.
  `RefreshResourceProgressBars()` reanchors controls from those preferences on
  every refresh; this can undo a temporary scene position unless integrated
  with the scene lifecycle.
- `RefreshItemTrackerPanel()` currently inserts a visible “No tracked items”
  placeholder for an empty display list, while the 100-ms visibility ticker
  uses the enabled setting and scene state rather than a content check.
  Currency visibility is driven by cached resource-visibility flags, with a
  separate IC-settings exception; bars use `showBar` and cutscene suppression.
  Tim clarified that normal-view visibility is the reference, including this
  placeholder. Preserve that decision during supported scenes rather than
  adding a stricter empty-panel gate.
- The tracker has one temporary `originalTrackerPos` snapshot and a
  keyboard-interaction positioning list. The helper also moves it when
  `alwaysMove` is true, compares only left and right candidates, and applies
  an offset after screen-bound calculations. It is prior art, not a sufficient
  implementation of the spec's general placement and transition requirements.
- `ResetCurrencyPanelPreferences()` resets currency and capacity preferences,
  not panel offsets or standalone-bar preferences. A search of maintained
  runtime Lua and XML found no dedicated HUD position-reset action; the settings
  menu's registered defaults do not include position controls. Full-profile
  copy and first-use profile initialization do replace existing position
  preferences and must be considered separately from a position-reset action.
- Scene position writes cannot wait for an exit callback: the existing move
  handlers save immediately, while normal ESO SavedVariables persistence occurs
  at logout or reload. A runtime snapshot alone cannot meet logout persistence.
  The exact storage key and a real logout while a scene is open remain to be
  verified; no client logout was performed during this investigation.

### Scene identity, visibility, and UI boundaries

- [Utils.lua](../../../Core/Utils.lua) identifies keyboard/gamepad inventory,
  bank and store through interaction APIs and scene checks. The tracker helper's
  separate list covers keyboard inventory, bank, house bank, guild bank, store
  and fence controls; it has no gamepad entries. Visibility and positioning
  therefore do not share one authoritative scene mapping.
- [EditPanelTabManager.lua](../../../Tracking/EditPanelTabManager.lua) uses
  three distinct editor scenes, copies window geometry when switching tabs, and
  separately calls the tracker adjustment/restore helper. The 100-ms ticker is
  another caller of that helper. A scene coordinator must account for both
  paths and transitions without saving automatic anchors.
- The installed LibAddonMenu source opens `gameMenuInGame` and constructs the
  `LAMAddonSettingsWindow` top-level control. The addon's callbacks identify
  only its own LAM panel, not the whole game settings menu. These are concrete
  candidates for scene detection and bounds, not proof that one rectangle covers
  every settings screen, gamepad screen, or other visible UI.
- The character-ID contract has now been checked against matching public ZOS
  source and documentation, not just generated stubs; see the detailed result
  below.
- No complete enumeration of all on-screen third-party UI or reliable bounds
  for every gamepad, fence, and main-settings surface was established offline.
  Stubbed geometry tests can verify an algorithm against supplied rectangles;
  actual control availability, boundaries and event order need client checks.
  Tim subsequently excluded other addons' UI from placement scope; no generic
  third-party control enumeration is required. Implement obstacle selection
  using the ZOS scene/control mapping below and the addon's own panel registry,
  not an indiscriminate scan of every visible `GuiRoot` child. In-client bounds,
  visibility, and UI-scale checks remain verification work.

### Currency grid and discovery

- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua) builds resource
  entries per currency location plus two capacity entries. Its visible-grid
  pass combines character and bank locations by currency type before layout.
  The future slider maximum must count grouped available cells rather than raw
  location entries, without applying the visible-grid pass's filters.
- [CurrencyHelper.lua](../../../Banking/CurrencyHelper.lua) builds its currency
  list in `InitializeCurrencyHelper()`, whose only runtime caller is startup.
  Capped-resource rediscovery rebuilds the progress-bar list separately.
  Tim confirmed initialization-only roster discovery is sufficient; the
  conditional listeners need no changes for currency-roster discovery.
- The installed LAM slider's `UpdateValue()` without an explicit value reads
  the getter, while its software-origin `OnValueChanged` is ignored. Its
  exposed slider and maximum label supported an earlier live-range proposal.
  That proposal is unnecessary under the agreed initialization-only discovery.

### Matching-version ZOS contracts: identities and scene mapping

External evidence is pinned to public ESO UI `live` commit
[`f819c808d57e237707c76e7b52518e2589c9e191`](https://github.com/esoui/esoui/tree/f819c808d57e237707c76e7b52518e2589c9e191).
Its `ESOUIDocumentation.txt` reports API 101051, matching the addon manifest.
An initial check of `master` found older API 101041; the contracts below were
rechecked against `live`. Matching API versions do not replace client validation.

- **Character identity resolved:** `GetCurrentCharacterId()` returns a string,
  not a Lua number or an `id64` value needing conversion. ZOS
  `esoui/libraries/utility/zo_savedvars.lua.NewCharacterIdSettings()` uses it
  directly as the character key. Use that opaque, non-empty string unchanged
  for scene-position ownership; do not convert it to a number, derive it from a
  character name, or pass it through an id64 conversion. Validate stored keys
  at the saved-data boundary, including entries for inactive characters.
- **Scene lifecycle established:** `ZO_SceneManager_Base:IsShowing(name)` tests
  the manager's current scene and accepts `SCENE_SHOWING` or `SCENE_SHOWN`.
  `GetCurrentSceneName()` exposes that identity. Scenes fire `StateChange`
  with old/new states. Old scene fragments can still animate while the current
  scene changes; distinguishing logical destination from visible obstacles is
  necessary, not a reason to invent multiple simultaneously current scenes.

Source-mapped controls (obstacle candidates, not an approved obstacle policy):

| Context | Scene / contextual distinction | Control sources |
|---|---|---|
| Keyboard inventory and banking | `inventory`, `bank`, `houseBank`, `guildBank` | Existing tracker map; confirmed by `esoui/ingame/scenes/keyboard/keyboardingamescenes.lua` and `esoui/ingame/inventory/inventory.xml`: `ZO_PlayerInventory`, `ZO_PlayerBank`, `ZO_HouseBank`, `ZO_GuildBank`. |
| Keyboard merchant and fence | `store`, `fence_keyboard` | Store and fence initialization sources; inventory and related scene fragments must be considered, not just one window. |
| Gamepad inventory | `gamepad_inventory_root` | `esoui/ingame/inventory/gamepad/gamepadinventory.lua/.xml`: `ZO_GamepadInventoryTopLevel`. |
| Gamepad bank / house bank | `gamepad_banking`; inspect `GetBankingBag()` to distinguish context | `esoui/ingame/banking/gamepad/banking_gamepad.lua/.xml`: `ZO_GamepadBankingTopLevel`; its bank-open handler handles house-bank bags too. |
| Gamepad guild bank | `gamepad_guild_bank` | `esoui/ingame/inventory/gamepad/guildbank_gamepad.lua/.xml`: `ZO_GuildBankTopLevel_Gamepad`. |
| Gamepad merchant / fence | `gamepad_store`; fence reuses the store scene | `esoui/ingame/storewindow/gamepad/storewindow_gamepad.lua/.xml` and `esoui/ingame/fence/gamepad/fence_gamepad.lua/.xml`: `ZO_StoreWindow_Gamepad`, `ZO_FenceWindow_Gamepad`. |
| Keyboard settings / LAM | `gameMenuInGame` with changing visible settings controls | ZOS `gamemenu_ingame` and `zo_options/keyboard` sources plus installed LAM: `ZO_GameMenu_InGame`, `ZO_OptionsWindow`, `LAMAddonSettingsWindow`. |
| Gamepad settings | `gamepad_options_root`, `gamepad_options_panel` | `esoui/pregameandingame/zo_options/gamepad/zo_options_gamepad.lua/.xml`: `ZO_GamepadOptionsTopLevel`. |
| IC editor | Three existing addon scenes | `EditPanelTabManager.lua` maps each scene to its editor window; all tabs share the agreed `Layout_EditorScene` position set. |

The current interaction helper's `gamepad_inventory` and `gamepad_bank` checks
do not match the verified scene names. Its other interaction APIs may sometimes
mask this. These observations are retained for the deferred whole-addon gamepad
review, not instructions to repair gamepad handling in this feature. No addon
code was changed to correct them during planning.

Gamepad root controls inherit `ZO_Gamepad_ParametricList_Screen`; its `Mask`
uses navigation-quadrant anchors. `gamepadquadrants.lua` reanchors their roots
to `ZO_SharedGamepadNavQuadrant_1_Background` when shown. Read effective bounds
after layout rather than assuming a full-screen or fixed-size obstacle.
Tooltips, headers, menus, and dialogs can occupy separate rectangles. Client
checks must confirm which visible rectangles represent the approved policy.

### Discovery triggers and placement lifecycle

- The API exposes `EVENT_CURRENCY_UPDATE`, `EVENT_CURRENCY_CAPS_CHANGED`, and
  `EVENT_PLAYER_ACTIVATED`. Existing currency/cap listeners depend on already
  visible/tracked resources. A hidden or newly available resource therefore
  cannot rely on those existing filtered paths to refresh discovery.
- A new isolated test executes the actual `InitializeCurrencyHelper()`: calling
  it again discovers added currencies and removes unavailable ones from its
  runtime list without changing saved preferences. Reusing the initializer is
  feasible; choosing when to call it remains a wiring/performance decision.
- Resolution: Tim confirmed roster discovery is needed only at logon/reload.
  The event-driven and UI-entry rediscovery alternatives investigated here are
  not selected; retain existing startup discovery and normal balance updates.
- Placement invalidation surfaces are now traced: scene `StateChange`; editor
  effectively-shown/hidden callbacks; LAM open/close; profile switch/copy
  followed by `RefreshProfileSettings()`; tracker and currency refreshes that
  resize roots; progress-bar refresh/discovery; user move-stop; and screen/UI
  geometry changes. ZOS documents `OnRectChanged`, `EVENT_SCREEN_RESIZED`,
  `EVENT_ALL_GUI_SCREENS_RESIZED`, and `EVENT_GAMEPAD_PREFERRED_MODE_CHANGED`.
- Resolution: Tim selected entry-only placement. The geometry events above
  are investigation evidence, not required listeners. Do not implement the
  earlier dirty/coalesced layout or geometry-signature polling proposal.
  Existing refresh callers must preserve the visit's current positions;
  calculate defaults again only on scene entry/change.

### Offline placement feasibility experiment

[ScenePlacementInvestigationTests.lua](../../Tests/ScenePlacementInvestigationTests.lua)
contains an isolated, unapproved candidate algorithm, never loaded by the addon.
For axis-aligned rectangular obstacles, expand each obstacle by the panel's
size in top-left-coordinate space. Test combinations of the clamped requested
coordinate, screen edges, and obstacle-edge coordinates; discard overlaps and
choose the smallest squared Euclidean displacement.

- The candidate matches an independent exhaustive integer-coordinate search for
  975 combinations of origin and obstacle fixtures, including intersecting and
  off-screen obstacles and a fully blocked screen.
- Separate cases retain a fractional unobstructed anchor, find a fractional
  nearest placement, and identify an oversized panel or fully blocked screen.
- The experiment allows edge contact and assumes no margins. It does not choose
  production tie-breaking, obstacle priority, panel order, impossible-fit
  fallback, or treatment of saved positions that become obstructed. Candidate
  search is roughly cubic in obstacle count per panel; bound obstacle selection
  and measure realistic panel/obstacle loads before adopting it.
- These are finite feasibility tests, not proof for every geometry or production
  regression coverage. Once an algorithm is agreed and implemented, tests must
  exercise the production methods instead of treating this prototype as delivery.

Additional evidence: `python Project\Tests\Run-RuleTests.py --test-filter
"Currency discovery|Scene placement experiment|Released schema 10"`: 5/5
passed in isolated Lua 5.1. No live inventory, SavedVariables, or UI was used.

Combined regression run: `python Project\Tests\Run-RuleTests.py --test-filter
"schema|profile|saved.variable|tracker keeps Miscellaneous|Currency discovery|Scene placement experiment"`:
45/45 passed; addon Lua syntax checked with Lua 5.1. This includes the new
discovery and geometry investigations and existing saved-data/profile coverage.
