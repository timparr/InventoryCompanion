# Built-in Group Name Collision Repair

## Goal

When an IC custom group has the exact display name of an ordinary built-in
group, preserve the custom group's effective rule under the built-in slug.
Avoid keeping two IC identities for the same exact name.

## Behavior

1. During `PrepareSavedVariables`, if a built-in group has the same name as a
   virtual group, fail hard before changing saved data or running constructors.
2. Inspect initialized InventoryCompanion saved profiles for exact,
   case-sensitive custom-to-built-in display-name matches.
3. With no match, finish without changing the saved data.
4. For each match, promote the custom rule to the built-in slug. Preserve its
   effective patterns by storing the difference from the built-in pattern
   defaults, and preserve its effective settings.
5. Replace the old slug with the built-in slug in InventoryCompanion's own
   saved display/matching order, hidden/position maps, and saved list backup.
6. If a match is ambiguous or the affected IC data is malformed, stop before
   publishing any profile changes.

## Boundaries

- Only InventoryCompanion's SavedVariables are migrated.
- AutoCategory's profiles, assignments, and templates are not read or changed.
- The migration runs whether AutoCategory is installed, enabled, or absent.
- Built-in/virtual name clashes are fatal; virtual groups are never promoted.
- Keep the existing SavedVariables schema and version.
