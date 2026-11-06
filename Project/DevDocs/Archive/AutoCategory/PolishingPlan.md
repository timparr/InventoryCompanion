# Settings and AutoCategory polishing: implementation plan

**ARCHIVED 2026-11-04.** Completed work; retained decisions, sequencing and
historical acceptance criteria, not current work instructions. The
[master feature specification](../../FeatureSpecs/AutoCategoryIntegration.md)
consolidates final behavior and supersedes this plan where later tweaks differ,
including the dedicated participation editor and final settings layout.

## Open questions and decisions

These decisions must be settled before the affected implementation starts.
Recommendations below are proposals, not agreed requirements.

| ID | Decision needed | Proposed starting point |
| --- | --- | --- |
| Release UI | Keep the disabled TTC/FCO placeholders visible in the published build, or hide them? | Include them disabled during development/discussion. Decide visibility before release; neither choice enables their functionality. |

## Confirmed decisions

- **Q1 closed:** all integration `isEnabled` switches, item transfer delay,
  auto-merge chest stacks, Debug Mode and diagnostic timing thresholds are
  account-wide. All other user-facing preferences follow the selected profile,
  including panel visibility/positions, editor filters, tracking rules, TTC
  thresholds and FCO group configuration. Integration configuration is distinct
  from account-wide enablement. Inventory/cache data, schema metadata,
  diagnostic history and recovery backups are not profile preferences.
- **Q2 closed:** no bespoke migration is required to preserve the author's
  unreleased AutoCategory arrangements or reconcile conflicting DEV enablement.
  The author accepts using the existing confirmed recovery reset to rebuild
  them. Keep that recovery action reachable; this is not permission to wipe
  all addon settings automatically during upgrade.
- Released saves without IC AutoCategory data remain the primary upgrade path.
  Initialize integration disabled and setup incomplete.
- **Profile switching: Option 2 agreed.** Each character has exactly one active
  full profile: its own or the shared account profile. First-time character setup
  copies account profile content; later switches resume the retained character
  profile without merging or replacing it. Schema migrations upgrade every
  stored full profile, including inactive ones.
- **Q5 closed: full profile copy replaces, never merges.** Replace all
  destination profile content with an independent copy of source profile
  content. Remove destination-only profile settings/items/groups as part of
  replacement. Preserve destination identity, scope selection, current schema
  metadata and unrelated data; account-only controls are outside profile content.
  Do not add a groups-only or other partial-copy mode to this plan.
- **Q6-Q8 deferred to future development.** TTC/FCO functionality, API choices,
  price bands and marker/group behavior are outside this implementation. Include
  their planned UI controls as disabled placeholders, clearly marked not yet
  implemented. They may be hidden before release.
- **Q9 closed: visit-scoped undo on all three editors.** Automatically snapshot
  editable state when Items, Groups or AutoCategory opens. Show an
  `[Undo changes]` button only while the current scope differs from its opening
  baseline. Restore that baseline on click; discard it on close/tab switch.
  Edits apply immediately. No Store/Snapshot button, persistence, login snapshot
  or staged Save/Cancel workflow.
- **Recovery retained:** keep the attempted-recovery panel and last-resort
  integration reset, with the same functional purpose, diagnostics, recovery
  options and preservation guarantees. Internal code may change as required by
  profile/schema changes, but recovery must remain usable. Visit-scoped Undo
  changes does not replace recovery.
- **AutoCategory availability:** if AC is not loaded, hide its navigation button
  on Items and Groups. If AC is loaded but IC integration is off, show an enabled
  navigation button; the AC panel shows the same integration information label
  and account-wide enable toggle as Main Settings. Enabled integration shows
  ordering controls; integration failures retain the existing recovery panel.
- **Q10 closed:** AutoCategory context Copy From copies both Display and Priority
  orders in one operation, retaining the existing destination-membership rules.
  Explain that it copies both orders regardless of the currently displayed mode.
  This is separate from full-profile replacement.
- **Information typography confirmed:** increase AC explanatory text one font
  level from its current size, use regular rather than bold weight, and match
  the explanation text in Main Settings. Reuse the settings explanation font
  rather than introducing a separately styled approximation.
- **AutoCategory participation controls:** replace Included/Excluded text
  toggles with explicit action buttons. Included rows show `[Hide]`; excluded
  rows show `[Show]`. Other has neither button. These may use a subtly distinct,
  compact style from default buttons, while remaining clearly actionable and
  consistent with the editor. Use that same style for the bottom toolbar
  buttons.
- **Q11 closed:** the Groups filter searches the displayed group names in the
  left-hand group list, following the Items panel's text-filter behavior. It
  does not filter the right-hand rule/pattern editor or search pattern contents.
  Filtering is presentation-only and does not change group definitions,
  participation, matching or saved order.
- **Q12 closed:** retain the current item-row wording/content, but display it
  on one line instead of two. Truncate text that exceeds its available width
  rather than wrapping. Review the layout and truncation visually during
  development; no new label wording is required.

## Status, source and authority

Created 2026-11-03; implementation authorized 2026-11-04 following discussion.
This is the approved implementation plan and basis of the polishing spec.
The remaining release-visibility decision does not block development.

- [Original polishing notes](PolishingNotes.md) and their reference
  images are read-only inputs; do not edit them during discussion.
- [Current AutoCategory feature document](../../FeatureSpecs/AutoCategoryIntegration.md) defines the
  existing integration baseline.
- [Current exclusion/Other implementation document](ExclusionsAndOther.md)
  owns the preceding change and its outstanding acceptance.
- [Archived spike results and dependency contracts](SpikeResults.md)
  retain prior load-order and dependency evidence. Their historical designs
  are not new requirements.

This plan describes future changes against the current DEV worktree, including
uncommitted work. No runtime changes or new test results are claimed here.
Do not modify the installed release tree as part of plan preparation.

## Released-user upgrade baseline

Confirmed by the author: most users will upgrade from a very low saved-variable
version, and no version containing AutoCategory information has been released.
Only the author has existing IC AutoCategory saved data.
The exact released schema versions still need to be established from release
evidence; do not assume users already have the current DEV schema.

- The primary migration path is an existing released save with no AC fields at
  all, not migration between the recent DEV AutoCategory schemas.
- Upgrade account-wide configuration and existing character-specific profiles,
  preserving their tracked items, groups, overrides, scope selection and
  unrelated data. For this release only, reset unused character profile content
  for characters already using account-wide settings to the minimal character
  record described in Phase 2.
- Missing AC fields are expected on this path, not malformed data. Initialize
  the new integration disabled and setup incomplete, preserving the existing
  opt-in first-time setup flow. Do not mark setup complete or publish native AC
  assignments just because the saved-variable schema was upgraded.
- Cover the supported older released schemas, including partially populated
  profiles, rather than testing only schema-9 DEV fixtures.
- The author's existing AC-bearing DEV arrangements may be rebuilt with the
  existing recovery reset. Do not add bespoke arrangement-preservation or
  enablement-conflict migration for this one-user case. Maintain the validated
  internal shape and access required to use recovery after the schema/scope
  change; the existing reset is not a generic repair for arbitrary malformed
  saved data.
- Recovery reset rebuilds the active arrangement, preserving tracked items,
  groups, per-area IC inclusion, native category definitions and inactive
  profiles; it replaces the arrangement and native AC exclusions. It is not a
  full saved-variable wipe. Shared DEV/release saved variables still require
  downgrade protection before normal game data is used.

## Intended outcome

1. One main-settings home for profile selection, complete profile copying,
   panel setup and integration controls.
2. Consistent navigation across Items, Groups and AutoCategory editors.
3. A complete account-derived starting point for first-time character setup,
   with existing character profiles retained when switching modes.
4. Clearer single-line item summaries and a working group filter.
5. An AC editor focused on independent Display/Priority editing, clearer help
   and grouped movement actions; visit-scoped Undo changes on all three editors.
6. Disabled TTC/FCO UI placeholders for planned future development, with
   publication visibility reviewed before release.

## Existing behavior to preserve or deliberately replace

- Profile choice currently selects tracked items, tracked rules and AC state,
  not all settings. Many panel preferences read/write `accountWide` directly.
- In the unreleased DEV implementation, AutoCategory enablement currently
  belongs to the selected profile. Moving it account-wide changes DEV behavior
  and saved data; released users have no prior IC AutoCategory setting.
- Extend existing first-use item-list copying to complete profile content.
  Previously initialized character profiles are retained and resumed.
- Current profile copy replaces item-list data and AC configuration, not all
  settings. Its UI lives in the Items editor.
- Current AC context copy copies both orders under destination-membership rules.
  Display and Priority remain independent; different orders are valid.
- Inclusion is per context but shared between both modes. Other exists only in
  Display and remains the automatic matching barrier.
- AC first-time setup, dependency-unavailable status and failure recovery
  remain supported. Preserve attempted recovery and last-resort reset through
  any necessary internal refactor; cosmetic cleanup must not remove or weaken
  their function.
- Existing show/notify overrides, area selections, rule identities and tracker
  behavior remain intact unless a question above explicitly changes them.

## Proposed settings layout

Use the existing LibAddonMenu panel and submenu patterns.

```text
Main Settings
  Account-wide settings
    Item Transfer Delay
    Auto-Merge Chest Stacks
  Profile settings
    Use Character Settings / Use Account-Wide Settings
    Copy From [source profile] [Go]
    Destination and replacement preview / confirmation

Panel Setup
  [Manage Items] [Manage Groups] [Manage AutoCategory]
  Item Tracker Panel
    Existing visibility, grouping, title, row and wrapping settings
    No duplicate character-specific-list control
  Currency Panel
    Existing currency/capacity settings
  Storage Gauges / Standalone Progress Bars
    Existing resource controls; confirm final section naming

Integrations
  AutoCategory explanation
  Enable AutoCategory [account-wide]
  [Manage AutoCategory]
  TTC explanation and account-wide enablement       [disabled: planned]
  TTC Groups: source's proposed threshold controls  [disabled: planned]
  FCO ItemSaver explanation and account-wide enablement [disabled: planned]

Debugging
  Existing diagnostics according to the agreed scope map

AutoCategory Information [collapsed expander at bottom]
  Status, explanatory text and relevant recovery entry point
```

The integration enablement switches and diagnostic controls are explicit
exceptions to the general profile selector, alongside transfer delay and chest
auto-merge. Explain their scope visibly. TTC/FCO placeholders remain disabled
regardless of whether those addons are installed; explain that functionality is
planned, not merely waiting for a dependency.

Remove the DEV AutoCategory failure-simulation button and its dedicated
implementation/call sites. Do not remove unrelated test harnesses, synthetic
performance checks or currency demo functionality because they also simulate
something.

## Implementation sequence and exit gates

### Phase 1 - Agree scope and saved-data contracts

Settings scope, the DEV recovery-reset decision and Option 2 profile switching
are agreed. Editor undo snapshots are in-memory only and need no saved schema.

1. Inventory every maintained settings field and its reader/writer. Classify
   it as account-only preference, profile preference, character identity/scope,
   tracked configuration, cached inventory, diagnostics or recovery metadata.
2. Define the complete profile-content field set, minimal character record and
   reliable initialization marker. Preserve sparse rule overrides and explicit
   empty collections when migrating or copying full profiles.
3. Establish the supported released-schema migration paths and initial character
   seeding. For released saves without AC data, preserve opt-in initialization.
   For the author's DEV arrangements, retain a valid, reachable recovery reset
   rather than implementing bespoke preservation or conflict resolution.
4. Define each editor's editable undo scope and its dependent configuration.
   Keep runtime snapshots separate from saved profile content.
5. Extend the existing pre-constructor boundary validation and migration,
   validating every profile before any migration is committed. Upgrade the
   account profile first in the prepared result; apply this release's character
   cleanup/upgrade rules before constructors. Every future schema migration
   must upgrade all stored full profiles, active or inactive.
6. Increment the saved-variable schema when older builds cannot safely preserve
   the new profile shape. The current baseline is
   schema 9; allocate the next version against the actual implementation branch.
7. Preserve unrelated data. Only this release's specified unused character
   profile content is reset; later migrations retain inactive full profiles.
   Report malformed data explicitly rather than silently replacing it.

**Exit gate:** released pre-AC migration fixtures prove preservation and opt-in
initialization; a DEV fixture proves recovery reset remains usable after upgrade;
older supported builds reject new data without changing it. Establish downgrade
protection before loading normal shared DEV/release saved variables.

### Phase 2 - Complete profiles and Option 2 switching

#### Profile model

Each character has precisely one active full profile: either its own or the
shared account-wide profile. The account profile always exists. Across an
account there can be one stored full profile up to the number of characters
plus one, including character profiles retained while account mode is active.

Use the existing selector's meaning: `useCharacterItemList = false` selects
account-wide settings; `true` selects character settings. Its implementation
must select all profile-owned preferences, not just tracked items.

#### This release's migration

1. Prepare and validate the upgraded account-wide full profile.
2. Examine every character's saved scope selection.
3. If already using account-wide settings, reset its unused character profile
   content to a minimal record: account mode selected, character profile not
   initialized, current schema version and required character-only metadata.
   Preserve unrelated data and account-owned records. Do not create full
   character preferences through constructor defaults afterwards.
4. If using character settings, upgrade its full profile using the same current
   schema/default contracts as the account profile, preserving its own items,
   rules, overrides and preferences. Mark it initialized.
5. Validate all prepared results and commit before ZOS constructors, preserving
   the existing future-version rejection and non-destructive failure behavior.

After this migration, account-wide users have minimal character records;
character-specific users have their own complete profiles. No runtime merge
system is required.

#### Switching behavior: Option 2

| Transition | Behavior |
| --- | --- |
| Character -> account | Retain the full character profile unchanged and select the existing account profile. |
| Account -> character, never initialized | Deep-copy the complete account profile content into the character profile, mark it initialized and select it. Exclude account-only controls and retain character identity/scope metadata. |
| Account -> character, previously initialized | Select the retained character profile exactly as it stands. Do not replace, merge or import newer account preferences/groups. |

An initialized profile can legitimately contain empty tracked-item/group maps.
Use the profile initialization contract, not table emptiness, to identify first
use. Account edits made while character mode is inactive do not synchronize into
that character profile. The explicit Copy From tool is available when the user
wants to replace it with another profile's configuration.

#### Every future schema upgrade

Upgrade every stored full profile, including inactive character profiles, before
activation. Apply new defaults and structural transformations through explicit
migrations while preserving existing choices and unrelated data. Minimal
uninitialized character records remain minimal until first-time setup.

Do not repeat this release's account-mode cleanup in later migrations: an
account-mode character may then have a deliberately retained full profile.
Migration guarantees compatibility; switching only selects a profile. Older
preferences may remain different from current account preferences by design.

Malformed external saved data must be reported at the loading/import boundary;
do not treat it as first use and silently replace it on a switch. Preserve
existing recovery actions where applicable.

#### Profile content and fully qualified saved-variable paths

The groups below document profile content, not separate merge units.
There is no current `character.TopLevel` table. `character.trackedItems` and
`character.trackedRules` are separate top-level nodes, but belong to one coherent
Tracking configuration area along with their dependent AC settings.

Here, `character` means the character profile object returned by ZOS, and
`accountWide` means the account profile object. The stored paths are:

```text
character   = InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"]
accountWide = InventoryCompanion_SavedVariables.Default["<account>"]["$AccountWide"]
```

The following are planned character-profile paths from the actual saved-variable
root. For the account profile, replace `"<character-id>"` with `"$AccountWide"`.
These are the existing field names, not a proposal to rename or nest them.
Panel preferences currently exist only in account-wide settings; editor filters
currently use the character profile directly. Implementation will give the
profile-selectable areas the agreed ownership without changing account-only
exceptions.

**Tracking configuration**

```lua
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackedItems
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackedRules
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].autoCategorySetupComplete
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].autoCategoryOrder
```

Object-relative equivalents are `character.trackedItems`,
`character.trackedRules`, `character.autoCategorySetupComplete` and
`character.autoCategoryOrder`. Built-in definitions come from maintained code,
not an additional saved root. Undo snapshots are in memory, not saved fields.

**Tracker panel**

```lua
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].showTrackedItemsPanel
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].showEmptyTrackedItems
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackerOffsetX
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackerOffsetY
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].wrapTrackedItemNames
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackerGroupThreshold
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackerMaxRows
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].trackerTitleSize
```

**Currency/capacity panel**

```lua
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].showEmptyCurrencies
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].currencyOffsetX
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].currencyOffsetY
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].currencyPreferences
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].capacityPreferences
```

**Standalone resource bars**

```lua
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].progressBarPreferences
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].progressBarAlertColors
```

**Editor preferences**

```lua
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].filterShow
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].filterNotify
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].filterMute
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].filterUntracked
InventoryCompanion_SavedVariables.Default["<account>"]["<character-id>"].filterCraftbag
```

**TTC and FCO configuration:** no implemented field paths yet. Disabled UI
placeholders do not create configuration data. Define saved nodes and
group-reference dependencies during their future implementation.

**Outside area copying:** `character.useCharacterItemList` is character scope
selection; `character.itemListInitialized` and `character.version` are metadata.
The existing `character.isEnabled` default is separate from integration switches
and still needs its supported use established. Account-only settings,
inventory/cache records, diagnostic history and recovery data are not included
in profile copying.

#### Current per-character settings and saved structure

This inventory describes the current DEV code, not the planned broader settings
scope. Examples are synthetic, abbreviated excerpts, not copies of user saves
or complete loadable test fixtures. Older released schemas may represent some
item/rule fields differently; migrate those shapes before activating or copying
full profiles.

| Current character-owned field | Contents and effective scope |
| --- | --- |
| `useCharacterItemList` | Character-specific selector. `true` selects this character's tracked items, rules and DEV AC profile; `false` selects `$AccountWide`. The selector itself must remain attached to the character, not be inherited from the selected profile or copied as ordinary content. |
| `trackedItems` | Item-ID-keyed map of individually tracked items, including saved item metadata and Show/Notify display flags. The character map is active only in character-list mode. |
| `trackedRules` | Stable-rule-keyed map of custom groups and overrides to built-in groups: display name, pattern additions/removals and display/notification/grouping/hidden/expanded overrides. The character map is active only in character-list mode. |
| `filterShow`, `filterNotify`, `filterMute`, `filterUntracked` | Items-editor filters. These currently read/write the character directly even when the account-wide list is selected. `filterMute` controls the UI's Inactive filter. The new plan deliberately changes these to follow the selected settings profile. |
| `filterCraftbag` | Character default and a read in untracked-item collection. It is not one of the four current main filter checkboxes; retain its distinction while inventorying/moving settings. |
| `isEnabled` | Existing character default (`true`). This is distinct from integration enablement switches. Its actual supported use must be checked when wiring the broader profile contract; its presence in defaults alone does not establish a working user-facing switch. |
| `autoCategoryIntegrationEnabled` | Unreleased DEV-only enablement in the selected list profile. Will become account-wide under Q1, not remain character-selectable. Released users have no such field. |
| `autoCategorySetupComplete`, `autoCategoryOrder` | Unreleased DEV-only setup state and per-area Display/Priority/inclusion configuration, currently owned by the selected list profile. Orders/inclusion remain profile content after enablement moves account-wide. |
| `itemListInitialized` | Profile initialization metadata, not a user preference. It controls existing first-use seeding and must not be confused with an intentionally empty initialized list. |

The defaults are in [Constants](../../../../Core/Constants.lua); selection, item/rule
formats and initialization behavior are in
[ItemDatabase](../../../../Tracking/ItemDatabase.lua); current filter readers/writers
are in [the Items editor](../../../../Tracking/EditPanelItemsTab.lua).

**Example A - account list selected, but editor filters still character-owned
today**

```lua
InventoryCompanion_SavedVariables = {
    Default = {
        ["example-account"] = {
            ["$AccountWide"] = {
                trackedItems = {
                    [12345] = {
                        display = {
                            showBackpack = true,
                            showBank = false,
                            notifyChat = false,
                            notifyHud = false,
                        },
                    },
                },
                trackedRules = {},
                showTrackedItemsPanel = true,
                trackerGroupThreshold = 8,
            },
            ["example-character-id"] = {
                useCharacterItemList = false,
                isEnabled = true,
                filterShow = true,
                filterNotify = true,
                filterMute = true,
                filterUntracked = false,
                filterCraftbag = false,
                trackedItems = {},
                trackedRules = {},
            },
        },
    },
}
```

Schema/identity metadata and unrelated fields are omitted. With this selector,
tracking uses the account maps; Items-editor filters still use the character
values. An empty character map here is not evidence that account contents should
be merged into it on every login.

**Example B - character list selected, with independent item/group overrides**

```lua
local characterProfile = {
    useCharacterItemList = true,
    itemListInitialized = true,
    trackedItems = {
        [12345] = {
            display = {
                showBackpack = false,
                showBank = true,
                notifyChat = true,
                notifyHud = false,
            },
        },
    },
    trackedRules = {
        custom_materials = {
            displayName = "My Materials",
            addedPatterns = { "*Ore*", "*Ingot*" },
            display = {
                showBackpack = true,
                showBank = true,
                notifyChat = false,
                notifyHud = false,
                group = true,
                isExpanded = false,
                isHidden = false,
            },
        },
    },
}
```

Saved built-in rules are sparse overrides, not necessarily complete definitions.
Absent flags or patterns can intentionally inherit the maintained rule baseline.
Migration and full-profile copying must preserve that inheritance and explicit
pattern removals. Switching back to a retained profile changes neither.

**Example C - additional structure found only in the author's current DEV saves**

```lua
local devProfileExcerpt = {
    autoCategoryIntegrationEnabled = true,
    autoCategorySetupComplete = true,
    autoCategoryOrder = {
        contexts = {
            backpack = {
                display = {
                    "ic:custom_materials", "ac:Sets", "ic:__ic_other",
                },
                matching = { "ac:Sets", "ic:custom_materials" },
                hidden = { ["ac:Maps"] = true },
                displayPositions = { ["ac:Maps"] = 2 },
            },
        },
    },
}
```

Other contexts are omitted from this excerpt. `matching` is the saved field for
the UI's Priority order. Inclusion is shared by both modes through `hidden`;
Other appears only in Display. This structure is not expected in released-user
saves and does not justify a public AC-to-AC migration project.

**Currently account-only preferences that become profile-selectable**

- Tracker: `showTrackedItemsPanel`, `showEmptyTrackedItems`,
  `trackerOffsetX`, `trackerOffsetY`, `wrapTrackedItemNames`,
  `trackerGroupThreshold`, `trackerMaxRows`, `trackerTitleSize`.
- Currency/capacity panel: `showEmptyCurrencies`, `currencyOffsetX`,
  `currencyOffsetY`, `currencyPreferences` (keyed by currency ID, then
  `locations`, then location) and `capacityPreferences` (keyed by resource).
  These preference maps are created by the
  [currency panel](../../../../Tracking/CurrencyPanel.lua), not listed in the
  static defaults.
- Standalone resource bars: `progressBarPreferences` and
  `progressBarAlertColors`, including nested resource preferences.
- `houseBankNames` is populated from externally reported chest names by
  [bank transfers](../../../../Banking/BankTransfers.lua), not a user preference.
  `currencyNamesById` is maintained for diagnostics by
  [Tests](../../../../Core/Tests.lua), not the currency panel's preference map.
  Neither belongs in profile-content copying.
- TTC thresholds and FCO group configuration are planned additions, not existing
  character saved-variable fields.

Keep `bankItemDelay`, `autoMergeChests`, `debugEnabled`,
`autoCategoryTimingThresholdMs` and all integration enablement switches
account-wide under Q1. Do not move cached bank/inventory records or recovery data
merely because they are stored beside settings.

#### Profile access and copy implementation steps

1. Reuse the existing profile selector and lifecycle instead of adding a second
   competing account/character choice.
2. Establish one internal active-settings contract for profile-owned preferences.
   Update every relevant read/write surface, including tracker geometry,
   currency settings, resource bars, events, editor refreshes and diagnostics
   where their scope is changed.
3. Implement this release's migration and establish complete full profiles before
   constructors. Keep character constructor defaults minimal so uninitialized
   character records are not inadvertently turned into full profiles.
4. Implement the three Option 2 transitions using the initialization marker.
   First-time copies must not alias account tables; later switching must leave
   retained profile content unchanged. Refresh matching caches, panels, events
   and AC synchronization through the existing lifecycle.
5. Extend the existing copy flow to replace the complete profile-content field
   set, removing destination-only content rather than merging. Exclude
   account-only controls, identity/scope/schema metadata, inventory caches,
   diagnostic history and recovery data. Offer full replacement only, with no
   groups-only mode. Restrict source resolution to the intended account,
   identify source and destination, reject self-copy, preview the impact and
   confirm replacement.
6. Validate and prepare the whole copy before committing it. Refresh effective
   settings, matching caches, panels, event registration and AC synchronization
   through the established lifecycle; do not copy external AC saved tables.
7. Move AutoCategory enablement to the account-wide setting while retaining
   profile-owned orders and inclusion. Switching profiles must not toggle it.

**Exit gate:** login, both switch directions and copying preserve explicit
values, isolate nested tables and update all affected behavior without reload
unless a verified dependency requires one.

### Phase 3 - Rebuild main settings and shared editor navigation

1. Move profile choice and copy controls out of the Items editor and into
   Main Settings, including preview, cancellation and confirmation behavior.
2. Reorganize existing settings into the layout above without losing controls.
3. Align each editor's header:
   `Title [Main Settings] [Manage Items] [Manage Groups] [Manage AutoCategory]`.
   Disable the current tab; use identical anchors/spacing and preserve Close.
4. Reuse the tab manager's scene switching, geometry synchronization and
   settings-opening endpoint. Hide the AutoCategory navigation button on Items
   and Groups when AC is not loaded; show it enabled when AC is loaded, including
   when IC integration is off. Adjust the panel-availability contract so opening
   the enablement view does not require active integration. Preserve hotkey
   reopening of that view when loaded; fall back to an available editor if AC is
   absent. Keep common header alignment when the AC button is hidden.
5. Move AC information to the bottom expander; retain the attempted-recovery
   panel and last-resort reset, including access while normal editing is blocked.
   Adapt their implementation for account-wide enablement and profile-owned
   configuration if necessary, preserving their existing function.
6. Remove the dedicated failure-simulation feature and update directly coupled
   tests/documentation.
7. Wire visit-scoped undo through the editor scene lifecycle:
   - Take an independent in-memory snapshot after opening initialization and
     synchronization, before user edits. Normal refreshes must not replace it.
   - Discard it when the panel closes, including switching editor tabs, opening
     Main Settings or closing through the hotkey. Reopening starts a new visit.
   - Bind it to the active profile and panel. Define Items/Groups editable state
     and dependent changes from their actual mutation paths; undo must restore
     coherent item/rule/AC configuration without resetting unrelated preferences.
   - Use the exact label `Undo changes`. Hide the button when there is no change
     in its restore scope, rather than leaving a disabled button visible.
   - Compare meaningful editable state with the baseline, excluding runtime
     caches/selection/scroll state. Reversing edits manually must hide the button
     too; a simple "an edit happened" flag is insufficient.
   - Validate and prepare the whole restore before committing it. Report
     externally changed dependencies explicitly and leave current data unchanged
     on failure. Never overwrite unrelated external addon data.
   - Refresh through the established lifecycle after undo. Retain the opening
     baseline for the visit so further edits can be undone; hide the button once
     state again matches that baseline.

**Exit gate:** all three headers line up, destinations open correctly and no
duplicate scope/copy controls remain. Undo is hidden on open/after restoration
or manual reversal, visible only for actual changes, and discarded on leaving
the panel. Reopening never offers undo from a previous visit.

### Phase 4 - Items and Groups editor polish

1. Make item Show, Notify and AutoCategory information single-line using the
   existing wording/content, rather than two lines. Truncate overlong text to
   available width without wrapping. Preserve Backpack/Bank/Grouped actions,
   notification modes, seven-area selectors and unavailable states. Review
   appearance and truncation in game during development.
2. Wire the Groups search box into the existing group-list population path.
   Filter displayed group names in the left pane using the Items panel's
   text-filter behavior; do not filter/search the right-hand patterns. Handle
   empty/cleared searches, no results, hidden groups, renames and the selected
   detail pane without mutating rules or saving filtered order.
3. Check keyboard focus, tooltip access, long labels and scrolled rows.

**Exit gate:** existing actions still operate on the correct rule/item/profile,
and filtering only changes the visible group list.

### Phase 5 - AutoCategory editing and visit-scoped undo

Distinguish dependency availability from integration enablement:

- **AC not loaded:** Items/Groups do not show its navigation button. Main
  Settings can still explain dependency availability using its existing status
  UI; do not expose an unusable enable action.
- **AC loaded, integration off:** the AC panel is accessible and displays the
  same information label and enable toggle as Main Settings, using the same
  status source and account-wide setter. Do not show usable ordering, movement,
  copy or Undo changes controls.
- **Enable from this panel:** follow the existing opt-in first-time setup and
  synchronization flow, preserving Confirm/Cancel behavior. Show ordering only
  when integration is ready; take the visit baseline after initial setup/sync,
  before ordering edits. The account-wide enable toggle is not undoable profile
  content.
- **Integration failure:** keep attempted recovery and last-resort reset
  available; do not present failure as an ordinary off state.

1. Present `[Edit Display Order] [Edit Priority Order]` together, with the
   context-copy controls aligned at the right. Copy From copies both Display
   and Priority orders using existing destination-membership rules; state this
   explicitly in its tooltip/help regardless of the active mode.
2. Increase information-panel readability with distinct `Display order:` and
   `Priority order:` headings and the source's guidance. Explanatory text goes
   up one font level, is not bold, and uses the same font as Main Settings
   explanations. Verify the actual explanation font used by the existing
   settings panel/library during implementation and confirm the match in game.
3. Replace Included/Excluded text toggles with actual `[Hide]` / `[Show]` action
   buttons: included rows offer Hide, excluded rows offer Show. Explain that Hide
   removes matching participation in this area, not the group definition, and
   applies to both modes. Explain that Other receives items unmatched by included
   categories; it has no Hide/Show button and no editable Priority row.
   Hide/Show buttons may have a distinct compact treatment, with clear button
   boundaries and hover/pressed states. Keep readable action labels; do not rely
   on colour alone or revert to plain clickable state text.
4. Group movement buttons as
   `[Up 1] [Up 5] [Move to Top]   [Down 1] [Down 5] [Move to Bottom]`.
   Preserve Shift multi-selection and existing block/clear actions unless
   their removal is explicitly requested. Style all bottom-toolbar buttons
   consistently with the Hide/Show buttons, including matching interaction
   feedback.
5. Remove order-mismatch warnings and ordinary arrangement reset/cross-mode
   copy actions. Keep attempted recovery and last-resort reset; these are
   independent of visit-scoped undo and remain available as recovery operations.
6. Use the Phase 3 opening snapshot for the active profile's AC contexts/orders
   and inclusion state. `[Undo changes]` restores only the current context/mode
   to its state when the panel opened. Changing context/mode within the panel
   does not replace the opening baseline. Its visibility follows changes in the
   currently displayed restore scope.
7. Inclusion is shared by Display/Priority within a context: undoing it affects
   both views in that context. Do not independently restore the opposite order;
   perform only membership reconciliation required by the existing inclusion
   contract. Explain this scope rather than promising page-isolated inclusion.
8. Prevent cross-profile/context/mode snapshot use and stale callbacks.
   Validate current group/category references before committing undo; if external
   changes prevent a valid restore, report failure and leave settings unchanged.
   Preserve Other's Display-only invariant and automatic matching barrier. Reuse
   existing validation/publication paths; never restore unrelated AC options or
   native definitions.
9. Keep order publication capacity checks and explicit external-boundary error
   reporting; internal contract failures must remain visible.

**Exit gate:** Undo changes restores the opening page order and context inclusion
without changing other contexts/profiles or independently restoring the opposite
order. Required membership reconciliation remains valid. Leaving the panel
discards undo history; no snapshot is saved across reloads or sessions.

### Phase 6 - Disabled future-integration UI

1. Add TTC and FCO information/sections in the planned settings layout. Show the
   source's proposed controls only as disabled placeholders.
2. Label both integrations as planned/not yet implemented. Keep enable switches
   off and all configuration controls disabled even if the addons are installed.
3. Do not add runtime classifiers, generated groups, notifications, price/marker
   API calls, dependency declarations or new saved settings for placeholders.
4. Review whether to retain or hide these sections before publishing.

**Exit gate:** placeholders cannot be enabled, modify saved data or trigger
integration behavior. Release visibility is explicitly decided.

### Phase 7 - Acceptance, specification and publication

1. Record decisions in this document, replacing proposals with explicit
   requirements; derive the final spec without changing the source notes.
2. Update the master feature document and user manual only for approved,
   implemented behavior. Keep historical spike evidence intact.
3. Run focused existing offline suites and then the applicable in-game matrix.
4. Record remaining compatibility/performance limits, not just passing examples.
5. Follow the release checklist separately when publication is requested.
   Do not stage, commit or change branches as part of this discussion draft.

## Validation matrix

| Area | Required evidence |
| --- | --- |
| Migration | Released low-version saves: upgrade account profile; reset unused account-mode character content to minimal records for this release only; upgrade character-mode full profiles preserving choices; initialize AC disabled/setup incomplete without publication; future migrations upgrade inactive full profiles without clearing them; validate all profiles before changes; malformed/future schema rejected; supported older builds reject new data without mutation; DEV recovery reset remains usable. |
| Profile switching | First-time character setup independently copies all eligible account content; character -> account retains character content; switching back resumes it unchanged despite account edits; initialized empty lists are not reseeded; several future schema upgrades update inactive profiles before return; no runtime merge, aliasing or partial copy on validation failure; account-only switches remain unchanged. |
| Full copy | Account-to-character, character-to-account and character-to-character replace all profile content, including removing destination-only entries; source unchanged and nested tables independent; account-only controls and destination identity/scope/schema/unrelated data preserved; no partial-copy mode; self-copy/cancel/no source handled visibly; malformed source cannot partially replace destination; correct account source resolution. |
| Settings behavior | Every re-scoped control reads/writes its intended profile; inactive profile unchanged; panels/events/geometry refresh; global AC enablement unchanged by profile switching. |
| Editors | Shared header geometry with AC button hidden on Items/Groups when dependency absent, visible/enabled when loaded but integration off; off panel matches Main Settings info/toggle and uses account-wide enablement; setup confirmation/cancellation, active ordering, hotkey navigation and recovery states remain correct; compact item summaries/toggles/popups and Groups search/clear/rename/no-results behavior preserved. |
| AC context copy | Copy From copies both Display/Priority orders from either editor mode, preserving existing destination-membership and Other rules; tooltip/help accurately describes both-order scope. |
| Information typography | AC explanations use the Main Settings explanation font, regular weight and one level larger than the current AC explanatory text; verify visual consistency and wrapping in game. |
| AC participation buttons | Included rows have a Hide action button; excluded rows have a Show action button; Other has neither. Actions retain the existing shared per-context participation behavior and are not merely clickable state labels. |
| Editor undo | All three panels: button hidden initially, shown for actual changes, hidden after undo/manual reversal; independent opening snapshots survive refresh but are discarded on close/tab switch; Items/Groups restore coherent editable state and dependencies; AC current-page order/context inclusion scope and Other remain valid; external dependency changes cause explicit failure without partial restore; reopening/reload starts fresh; no saved snapshot fields. |
| Recovery | Attempted-recovery panel, diagnostics, retry/repair and confirmed last-resort reset retain their existing function after profile/schema refactoring; reachable when editing is blocked; active-profile scope and existing preservation/rollback guarantees maintained; Undo changes is not required for recovery. |
| Future integration UI | TTC/FCO placeholders are clearly labelled, off and disabled with dependencies present or absent; no saved-data writes, dependency calls or generated groups; release visibility follows the publication decision. |
| In-game acceptance | Visual review at supported editor sizes; normal profile switching/copying; rule matching/overrides; Display versus Priority independence across supported contexts; recovery access. |
| Performance safety | Synthetic bursts never mutate live inventory or saved variables; agree numerical workload/timing limits before declaring a pass. No live transfers for performance testing. |

Extend the existing
[saved-variable tests](../../../Tests/SavedVariablesTests.lua),
[rule persistence tests](../../../Tests/RulePersistenceTests.lua),
[item editor tests](../../../Tests/ItemEditorTests.lua),
[group editor tests](../../../Tests/GroupEditorTests.lua),
[AutoCategory editor tests](../../../Tests/AutoCategoryEditorTests.lua),
[integration tests](../../../Tests/AutoCategoryIntegrationTests.lua) and
[tracker panel tests](../../../Tests/TrackerPanelTests.lua).
Use the existing [Lua 5.1 runner](../../../Tests/Run-RuleTests.py), selecting the
smallest supported test scope at implementation time. Its XML assertions are
coupled to current controls and must change alongside approved UI changes.

Documentation-only preparation requires no runtime test pass. Implementation
is complete only when approved requirements have persistent, verified outcomes;
offline results do not replace ESO visual or dependency acceptance.

## Expected implementation surfaces

- [Constants](../../../../Core/Constants.lua), [initialization](../../../../Core/Init.lua)
  and [item database/profile lifecycle](../../../../Tracking/ItemDatabase.lua):
  field ownership, defaults, boundary validation, all-profile schema migration,
  first-use copying and retained-profile switching.
- [Main settings](../../../../Core/Settings.lua): layout and relocated profile tools.
- [Tab manager](../../../../Tracking/EditPanelTabManager.lua) and all three editor
  Lua/XML pairs: navigation, item summaries, group search and AC view controls.
- [AutoCategory adapter](../../../../Tracking/AutoCategoryIntegration.lua):
  account enablement, validated runtime undo through existing publication,
  existing group/profile synchronization and dedicated simulation removal.
- [Tracker](../../../../Tracking/ItemTrackerPanel.lua),
  [currency panel](../../../../Tracking/CurrencyPanel.lua),
  [resource progress bars](../../../../Banking/ResourceProgressBars.lua) and
  [events](../../../../Core/Events.lua): every reader/writer affected by scope.
- Relevant tests, manifests only if this implementation changes load requirements,
  and directly related feature/user documentation.

Keep implementation on the current branch until branch choice is discussed.
The current branch is `main`; the profile/schema redesign is substantial enough
to recommend a separate feature branch once implementation is approved. Existing
uncommitted changes must be preserved and distinguished from this new work.
