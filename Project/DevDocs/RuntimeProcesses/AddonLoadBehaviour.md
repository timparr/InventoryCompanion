# Addon Load Behaviour

**Document version: 0.1**

This document describes the addon's runtime load and SavedVariables preparation
flow in pseudocode. It is technical process documentation, separate from the
contributor and release workflows in `Project/Processes`.

The pseudocode describes the current process; its conceptual steps do not
require new Lua methods or refactoring.

## Load and initialize

```text
ESO client starts
    load persisted SavedVariables into the addon's global table when present
    load addon files in InventoryCompanion_DEV.txt manifest order

Core/Init.lua registers for EVENT_ADD_ON_LOADED
after the addon's files have loaded:
    OnAddOnLoaded(eventCode, name)
        if name is not InventoryCompanion_DEV:
            do nothing
        unregister this addon's load-event handler
        Initialize()

Initialize()
    PrepareSavedVariables()                         # before constructors
    register keybind display names
    create account-wide and character ZO_SavedVars objects
    validate tracker, debug, withdraw, and saved-rule-profile settings
    AutoCategoryIntegration.Initialize()
    initialize helpers, panels, settings, and event handlers
    mark the addon loaded
```

`/reloadui` repeats addon initialization using ESO's current in-memory
SavedVariables. A normal client start loads the last saved values from disk.

## Prepare SavedVariables

`PrepareSavedVariables()` validates and prepares every stored account/profile
before the `ZO_SavedVars` constructors or AutoCategory integration use them.
It also runs when the schema is already current; schema migration is only one
conditional part of preparation.

```text
PrepareSavedVariables()
    validate built-in/virtual name separation
    read the loaded SavedVariables root
    if the root is absent:
        return
    require the root to be a table
    if Default is absent:
        return
    require Default to be a table

    collect every account/profile and retain each original profile reference
    validate account and profile tables
    for every profile:
        validate version is a positive integer
        reject versions newer than this addon
        reject versions without a supported migration path
        determine initialized state if it is not explicitly saved

    load built-in baseline rules
    for every collected profile:
        validate saved rules, AutoCategory fields, debug data, tracked items,
            character-list settings, and account-wide withdrawal settings
        prepare supported tracked-rule migration data when needed
        normalize AutoCategory order into a separate table
        for older supported schemas:
            apply the existing context-inclusion migration
        validate any saved-list backup
        when an older schema requires it:
            copy the backup and prepare its order migration separately

    if the current schema supports candidate preparation:
        for every profile:
            make a shallow candidate with CopyValues()
            overlay prepared rules, order, and setup-state migration data
            for an account-wide profile:
                prepare preferences and documented defaults
                initialize missing trackedItems and trackedRules tables
        for every character profile:
            apply the existing reset, selection, and preference-inheritance rules
        for every initialized candidate:
            find exact custom-name / ordinary-built-in collisions
            if collisions exist:
                copy the candidate rule and order structures
                promote the custom rules and remap their AutoCategory references
        for every saved-list backup:
            use its prepared migration copy if one exists; otherwise make
                a separate copy for collision checking
            if a collision exists:
                convert and validate the prepared backup
            otherwise:
                discard the check copy without publishing it

    only after every profile and required conversion passes:
        assign prepared migration fields to the original profile tables
        assign selected candidate fields to the original profile tables
        set the current schema version and initialized-state flags
        invalidate the runtime rule cache
```

For the current schema version 10, a complete, valid profile does not run a
schema migration. Validation, order normalization, candidate preparation, and
collision detection still run. Normalization can supply missing order contexts
or maps; preference preparation can fill missing documented defaults. A
complete, already-normalized profile should retain the same values.

## Candidate and publish semantics

```text
For each original profile:
    validate the original profile and prepare supported migration data
    build a separate normalized AutoCategory order table
    make a shallow top-level candidate copy with CopyValues()
    overlay the prepared migration data onto the candidate
    before collision conversion, copy the rule/order structures being changed
    use the prepared migration copy of a saved-list backup, or copy it
        separately before checking for collisions

    validate and convert only the candidate values

After all candidates pass:
    assign the prepared field values onto each original profile table
```

This is not a copy of the whole SavedVariables root or file. The code does not
replace the root or replace each original profile table wholesale, and it does
not replay the transformation against the originals. It publishes selected
prepared fields by assignment into the existing profile tables. The shallow
candidate copy holds profile-level fields; separate copies protect nested
tables that normalization or collision repair mutates.

The staging prevents validation or conversion failures in a later profile from
leaving earlier profiles partially converted. This preparation happens before
ESO's next SavedVariables save cycle.

## Collision repair pseudocode

### Resolve a clash

```text
For each collision in an affected profile:
    take the custom group and the built-in group with the same name

    Make sure patterns are the same:
        determine the custom group's complete, effective pattern set
        compare it with the built-in group's default patterns
        additions are custom patterns not in the built-in defaults
        subtractions are built-in defaults not in the custom patterns
        save the additions and subtractions as overrides so the built-in
            group resolves to the same effective pattern set

    Make sure show/notify/hidden settings are the same:
        determine the custom group's effective display values using the
            shared custom-group display defaults
        replace the key in trackedRules from the custom slug to the built-in slug
        set its saved display overrides against the built-in defaults so its
            effective show, notify, isHidden, and other display values stay the same
            # don't copy the old override values directly; the defaults may differ

    Make sure AC settings are the same:
        replace ic:custom-slug with ic:built-in-slug in every context's:
            display and matching lists
            hidden and display-position maps
        apply the same reference changes inside the saved-list backup

        leave name-based values unchanged:
            the promoted group's effective display name, because the name is unchanged
            ac:<assignment name> references for native AC categories
        leave autoCategoryIntegrationEnabled and autoCategorySetupComplete
            unchanged; they are profile-level, not group-keyed
```

Apply the same rule and reference conversion to the saved-list backup when
present. If a collision or conversion is ambiguous or malformed, fail before
publishing any prepared data. Validate all affected profile candidates before
assigning their prepared fields to the originals. This AC-settings step
concerns IC-owned saved data only; it does not authorize reading or changing
AutoCategory's own SavedVariables.

## Worked example: current-schema profile with a name collision

This walkthrough uses a valid, initialized schema-10 account-wide profile. It
shows one supported path through the algorithm, not every migration or
character-profile branch. The example is abbreviated; unrelated SavedVariables
fields are omitted.

### Example: input profile

The loaded account contains a `$AccountWide` profile with these relevant
values:

```lua
profile = {
    version = 10,
    itemListInitialized = true,
    trackedRules = {
        custom_collision = {
            displayName = "Furniture Materials",
            patterns = { "Mundane Rune", "*test item *" },
            autoCategoryEnabled = true,
            display = {
                notifyChat = true,
                notifyHud = true,
                showBackpack = false,
                showBank = true,
                group = false,
                isExpanded = false,
            },
        },
        furniture_materials = {
            displayName = "Old saved data for this built-in",
            addedPatterns = { "stale target pattern" },
        },
    },
    autoCategoryOrder = {
        contexts = {
            backpack = {
                display = { "ic:custom_collision", "ic:furniture_materials" },
                matching = { "ic:custom_collision", "ic:furniture_materials" },
                hidden = {
                    ["ic:custom_collision"] = true,
                    ["ic:furniture_materials"] = false,
                },
                displayPositions = {
                    ["ic:custom_collision"] = 7,
                    ["ic:furniture_materials"] = 9,
                },
            },
            bank = {
                display = { "ic:custom_collision" },
                matching = { "ic:custom_collision" },
                hidden = {},
                -- displayPositions is missing.
            },
            -- Other supported contexts are missing.
        },
    },
    -- trackerOffsetX and trackedItems are missing.
}
```

### Example: validation and version gate

The profile is version 10, so it is supported and no schema migration runs.
All profiles are checked before shallow candidates are created. If any profile
were newer than this addon supports, preparation would stop before publishing
changes to any profile.

### Example: order normalization

Validation accepts the saved order shape. Normalization fills the missing
`bank.displayPositions` map and creates the standard empty order shape for
every other supported context. It preserves the existing `backpack` entries
and their order at this stage:

```lua
backpack.display = { "ic:custom_collision", "ic:furniture_materials" }
backpack.matching = { "ic:custom_collision", "ic:furniture_materials" }
backpack.displayPositions = {
    ["ic:custom_collision"] = 7,
    ["ic:furniture_materials"] = 9,
}

bank.displayPositions = {}
-- Every other missing supported context is added with empty lists and maps.
```

No collision references have been renamed yet. Normalization changes the
structure, not the group identities or list positions.

### Example: candidate and defaults

Once every profile passes boundary validation, `CopyValues()` makes a shallow
candidate for this profile. The normalized order and any supported migration
data are placed on that candidate. Missing account-wide defaults are prepared
there: for example, `trackerOffsetX` becomes its documented default of `50`,
and missing `trackedItems` becomes an empty table.

The original profile still has no `trackerOffsetX` or `trackedItems` at this
point. Before collision conversion mutates rules or order, those nested
structures are copied for the candidate.

### Example: collision conversion

The custom rule's exact display name matches the ordinary built-in
`furniture_materials`. The custom rule's effective patterns are
`Mundane Rune` and `*test item *`; the built-in defaults also include
`Heartwood`, `Regulus`, `Bast`, `Clean Pelt`, `Alchemical Resin`,
`Decorative Wax`, and `Ochre`.

The candidate's `custom_collision` key is promoted to `furniture_materials`.
Its saved pattern overrides preserve the custom rule's effective pattern set:

```lua
trackedRules.custom_collision = nil
trackedRules.furniture_materials = {
    autoCategoryEnabled = true,
    addedPatterns = { "*test item *" },
    removedPatterns = {
        "Alchemical Resin", "Bast", "Clean Pelt", "Decorative Wax",
        "Heartwood", "Ochre", "Regulus",
    },
    -- Effective display settings from the custom rule are preserved.
}
```

The stale saved entry at the built-in key is not merged with the promoted
custom rule. In the `backpack` order, both references collapse to
`ic:furniture_materials`, with the custom reference's position winning. The
custom map values also win over existing built-in values:

```lua
backpack.display = { "ic:furniture_materials" }
backpack.matching = { "ic:furniture_materials" }
backpack.hidden = { ["ic:furniture_materials"] = true }
backpack.displayPositions = { ["ic:furniture_materials"] = 7 }
bank.display = { "ic:furniture_materials" }
```

### Example: backup conversion

If `accountWideListBackup` contains the same collision, it is validated, copied
separately, and converted using the same rule and order logic. The saved backup
is not mutated while the candidate conversion is being prepared; its converted
fields are published only after all profiles and conversions pass.

### Example: publication

After every profile and required conversion succeeds, selected candidate
fields are assigned onto the original profile table. The profile table itself
is not replaced. The resulting profile has the promoted rule, normalized and
remapped order, `trackerOffsetX = 50`, an empty `trackedItems` table, and
version 10. Its converted backup is assigned separately. Unrelated profile
fields remain on the same original table.

## Appendix: Current-schema load with unchanged SavedVariables values

This is the no-collision counterpart to the worked conversion above. It shows
a complete, valid schema-10 load where preparation produces no logical
SavedVariables value changes.

“No changes” describes the resulting saved values, not a check-only code path.
The addon still validates profiles, creates candidates, normalizes order into
a separate table, and publishes selected fields.

### Schema version locations

The [manifest](../../../InventoryCompanion_DEV.txt) declares the SavedVariables
global. [Core/Init.lua](../../../Core/Init.lua) supplies its name and the
current addon schema:

```text
## SavedVariables: InventoryCompanion_SavedVariables
```

```lua
SettingsName = "InventoryCompanion_SavedVariables"
SettingsVersion = 10
```

Each stored account/profile has its own `version` field under the `Default`
branch:

```text
InventoryCompanion_SavedVariables.Default["<account>"]["$AccountWide"].version
InventoryCompanion_SavedVariables.Default["<account>"]["<profile key>"].version
```

For this example, every profile's saved `version` is `10`. The code checks
that it is a valid supported version and whether a migration is needed:

```lua
local version = profile.version
assert(type(version) == "number" and version >= 1 and version < math.huge
    and version % 1 == 0)
assert(version <= this.SettingsVersion)
-- The supported-migration check accepts version == this.SettingsVersion.
```

Because `version == SettingsVersion`, no schema migration runs. Older
supported versions would prepare migration data for their candidates; a newer
version stops initialization before saved data is changed.

### Built-in names and saved-rule locations

The maintained rule definitions are in
[Core/Constants.lua](../../../Core/Constants.lua). For example:

```lua
this.preLoadedRulesets = {
    ["furniture_materials"] = { displayName = "Furniture Materials" },
    ["miscellaneous"] = { displayName = "Miscellaneous", isVirtual = true },
}
```

First, [`ValidateBuiltInVirtualNameCollisions()`](../../../Tracking/ItemDatabase.lua)
checks that an ordinary built-in and a virtual group do not share a display
name. This is a check between addon definitions; it does not inspect
SavedVariables.

Saved rules are checked in every profile's `trackedRules`, including
account-wide and character profiles. An account-wide list backup, when
present, has its own `trackedRules`:

```text
InventoryCompanion_SavedVariables.Default["<account>"]["$AccountWide"].trackedRules
InventoryCompanion_SavedVariables.Default["<account>"]["<profile key>"].trackedRules
InventoryCompanion_SavedVariables.Default["<account>"]["<profile key>"].accountWideListBackup.trackedRules
```

[`FindBuiltInNameCollisions()`](../../../Tracking/ItemDatabase.lua) builds a
name map from non-virtual built-ins. It then checks saved rule keys that are
not already built-in keys, using the saved `displayName` (or the key if there
is no display name):

```lua
if this.preLoadedRulesets[ruleKey] == nil then
    local displayName = saved.displayName or ruleKey
    local targets = builtInsByName[displayName]
    -- An exact name match identifies the ordinary built-in target.
end
```

In this no-change example, every custom rule's name is distinct from every
ordinary built-in name. For example, `custom_workshop` may have the display
name `Workshop Supplies`; it does not match `Furniture Materials`. Existing
rules already keyed by `furniture_materials` are treated as built-in data, not
as custom-name collisions. The same collision check finds none in any
initialized profile or saved-list backup.

### Remaining checks and result

Use one initialized `$AccountWide` profile, optionally with a saved-list
backup. For this example to leave saved values unchanged:

- Every profile, saved rule, debug record, tracked item, AutoCategory field,
  order reference, and present backup passes its boundary validation.
- The schema-10 AutoCategory order already has every supported context and
  all four fields (`display`, `matching`, `hidden`, and `displayPositions`).
  Its references and list order are valid, so normalization copies the same
  values into the normalized order shape.
- All documented preferences are already present and valid, so preference
  preparation adds no defaults or normalizes no values.
- Every initialized profile and any present backup has no exact custom-name /
  ordinary-built-in collision.
- `useCharacterItemList` and the account-wide withdrawal control, when
  present, already have valid values.

The candidate therefore contains the same logical profile values. Publication
still assigns selected fields to the existing profile table and assigns
`version = 10` and the same initialized state. `autoCategoryOrder` is a newly
normalized table, but its saved contents are equivalent to the original.
The runtime rule cache is invalidated as usual.

## SavedVariables persistence

```text
During addon initialization:
    prepare and publish values in memory

When ESO saves on /reloadui or a normal logout:
    ESO serializes the current SavedVariables state to disk
```

Runtime preparation is not conditional on whether addon code changed since the
previous login.

## TODO

- [ ] Convert this document to HTML with expanders, break large methods into
  smaller sections, and link them to the worked example.

## Implementation references

- [Manifest and file load order](../../../InventoryCompanion_DEV.txt)
- [Initialize and OnAddOnLoaded](../../../Core/Init.lua)
- [PrepareSavedVariables and candidate publication](../../../Tracking/ItemDatabase.lua)
- [SavedVariables preparation regression tests](../../../Project/Tests/SavedVariablesTests.lua)
- [Collision-repair feature specification](../FeatureSpecs/AutoCategoryNameCollisionMigration.md)
- [Collision-repair implementation record](../Archive/AutoCategory/BuiltInNameCollisionRepairImplementationPlan.md)
