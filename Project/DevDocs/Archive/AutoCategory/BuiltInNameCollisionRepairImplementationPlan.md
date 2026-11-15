# Built-in Group Name Collision Repair — Implementation Plan

**ARCHIVED 2026-11-15.** Historical plan, not current work instructions. Use
the current [feature specification](../../FeatureSpecs/AutoCategoryNameCollisionMigration.md).

## Flow

Method-like names in the pseudocode, such as `ValidateSavedVariablesFile()`
and `NormalizeAutoCategoryOrders()`, label conceptual processes so their
responsibilities are clear. They are not an implementation requirement to add
or refactor Lua methods; the steps may remain within the existing
`PrepareSavedVariables()` flow and its helpers.

### `Initialize()`

Keep `PrepareSavedVariables()` before any SavedVariables constructors or
AutoCategory registration:

```text
Initialize()
    PrepareSavedVariables()                 # first
    register ESO keybind names               # existing
    load SavedVariables and validate the selected profiles
    AutoCategoryIntegration.Initialize()    # only after preparation
        RegisterPlugin() with prepared definitions
    initialize remaining modules
```

AutoCategory's display and priority lists are reconciled later, after its
initialization. They must only receive definitions built from prepared IC data.

### `PrepareSavedVariables()`

```text
PrepareSavedVariables()
    fail hard if a built-in group has the same name as a virtual group  # new

    ValidateSavedVariablesFile()                 # validation process
    NormalizeAutoCategoryOrders()                # normalization process

    for each initialized temporary profile copy and each saved-list backup:
        find exact custom-name / built-in-name collisions                # new
        for each collision:
            resolve it using the steps below

    validate all temporary profile copies
    publish their prepared IC data only after all copies pass
```

### Process: `ValidateSavedVariablesFile()`

```text
For every saved account and profile:

    Validate data
        validate the SavedVariables root and profile structure
        validate saved rules, items, profile settings, AutoCategory data,
            and any saved-list backup

    Check version
        reject unsupported or newer versions before preparing any copies
        create a temporary in-memory copy of each profile to be prepared
        create a temporary backup copy only if migration or collision repair
            needs to change it
        if the version is older than the current version:
            run only the already-supported schema migration on its copy
        if the version is already current (version 10):
            do not run a schema-version migration
            continue preparing the copy

    Fill documented missing profile defaults on the copy where needed

    keep the loaded SavedVariables unchanged while validating and preparing
    the copies; return the copies without publishing them
```

For a complete, already-normalized version-10 profile, this preparation leaves
its existing values unchanged. It can still fill missing defaults.

### Process: `NormalizeAutoCategoryOrders()`

See Appendix 1 for before-and-after examples of these order-shape changes.

```text
For every temporary profile copy whose AutoCategory order passed validation:
    if autoCategoryOrder is absent:
        create an empty order for every supported context, with empty display,
            matching, hidden, and displayPositions fields
    otherwise:
        copy each saved context's display, matching, hidden, and
            displayPositions entries as-is
        fill a missing hidden or displayPositions map with an empty map
        add each missing supported context with all four fields empty
    reject unknown contexts or malformed context tables
    preserve existing references and order; do not sort, deduplicate, rename,
        or otherwise repair references in this process
    validate reference syntax, list density, duplicates, and known references
        separately; do not silently fix invalid data
    for versions below 9, apply the existing context-inclusion migration
        after normalization

For each legacy saved-list backup being migrated:
    normalize its order using the same rules
    apply the existing context-inclusion migration after normalization
```

For a complete, already-normalized version-10 profile, normalization preserves
its existing order values. Collision repair below runs on the temporary copies
after normalization and before publication.

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
publishing any prepared data. Validate all affected temporary profile copies
before publishing them together. This AC-settings step concerns IC-owned saved
data only; it does not authorize reading or changing AutoCategory's own
SavedVariables.

## Code touchpoints

- `Tracking/ItemDatabase.lua`: detect exact collisions and convert only the
  affected IC profile copies inside the existing `PrepareSavedVariables`
  flow. Fail on built-in/virtual name clashes. Update `trackedRules`,
  `autoCategoryOrder`, and IC's saved list backup.
- `Core/Init.lua`: keep `PrepareSavedVariables()` as the first operation in
  `Initialize()`, before SavedVariables constructors and
  `AutoCategoryIntegration.Initialize()`.
- `Tracking/AutoCategoryIntegration.lua`: remove the collision-specific scan,
  assignment/template rekey, and preflight from plugin registration. Preserve
  unrelated normal integration behavior.
- `Core/Constants.lua`: keep the built-in group enabled; distinguish built-in
  and virtual groups for the hard-failure check and collision detection.

The migration reads and writes only InventoryCompanion's SavedVariables. It
does not inspect or modify AutoCategory profiles, assignments, or templates,
and does not depend on AutoCategory being installed. No new SavedVariables
fields or schema-version change are needed.

## Appendix 1: AutoCategory order normalization examples

These examples show only the shape normalization of IC-owned
`autoCategoryOrder`. Assume the shown contexts are supported and the existing
order passed validation.

### No saved order

Before:

```lua
autoCategoryOrder = nil
```

After:

```lua
autoCategoryOrder = {
    contexts = {
        backpack = {
            display = {}, matching = {}, hidden = {}, displayPositions = {},
        },
        bank = {
            display = {}, matching = {}, hidden = {}, displayPositions = {},
        },
        -- Every other supported context gets the same empty structure.
    },
}
```

### Existing order with a missing map and context

Before:

```lua
autoCategoryOrder = {
    contexts = {
        backpack = {
            display = { "ic:custom_242230065", "ac:ExampleCategory" },
            matching = { "ac:ExampleCategory", "ic:custom_242230065" },
            hidden = { ["ic:custom_242230065"] = true },
            -- displayPositions is absent.
        },
        -- bank is absent.
    },
}
```

After:

```lua
autoCategoryOrder = {
    contexts = {
        backpack = {
            display = { "ic:custom_242230065", "ac:ExampleCategory" },
            matching = { "ac:ExampleCategory", "ic:custom_242230065" },
            hidden = { ["ic:custom_242230065"] = true },
            displayPositions = {},
        },
        bank = {
            display = {}, matching = {}, hidden = {}, displayPositions = {},
        },
        -- Every other missing supported context is added too.
    },
}
```

Existing references and their order are preserved. Normalization does not
change `ic:custom_242230065`; the separate collision-repair process does that.

## Implementation record

- Implemented collision detection and repair in the existing
  `PrepareSavedVariables()` flow. The repair promotes exact-name IC custom
  groups to ordinary built-ins, preserves effective IC group data, and updates
  IC-owned order references and saved-list backups only. No schema change or
  AutoCategory-owned data migration was added.
- When both custom and built-in references occur in an order list, the custom
  reference's position wins regardless of input order. For keyed maps, a
  custom value wins when present; otherwise the existing built-in value is
  preserved.
- Offline validation: `python Project\Tests\Run-RuleTests.py` passed 220/220
  tests, including Lua 5.1 syntax and XML structure checks. The focused
  order-position/map-preservation regression passed 1/1. An independent
  follow-up review of the final map-preservation change found no significant
  issues.
- In-game validation on 2026-11-15: after restoring the built-in and renaming
  the custom group to the exact built-in name, the UI reload completed. The
  group remained at the top of the craft bag, and its test-pattern behavior
  remained until reset. Reset to defaults showed the built-in's full material
  list, and a subsequent UI reload persisted that reset.
- The persisted SavedVariables file uses `furniture_materials` in place of
  `custom_242230065`, and its AutoCategory order references use the built-in
  slug. The final `furniture_materials` override has no test-pattern
  additions/removals. Pre- and post-reset snapshots were preserved.
- Temporarily commenting out the built-in caused startup validation to reject
  an existing `ic:furniture_materials` order reference before migration; the
  built-in was restored before the successful in-game test.
- Committed as `6d3e4e9` on 2026-11-15; not pushed or released.
