# AutoCategory profile synchronization fix

**ARCHIVED 2026-11-03.** Historical plan and evidence; current requirements
are in the [master feature document](../../FeatureSpecs/AutoCategoryIntegration.md).

Status: implemented on main, uncommitted. Offline verification passed on
2026-11-03; in-game acceptance remains pending. See implementation evidence
and acceptance steps below.

## Open questions

None currently identified. First-time scope switching and reset behavior
are agreed below. Any implementation discovery requiring a new behavioral
choice must be raised rather than silently assumed.

## Tim's section

There are two different kinds of category in AC:

- **AC's own categories**, such as its native Maps category. IC can change
  their order and will offer Hide/Unhide without deleting their saved
  assignments. Hiding works through matching order, as explained below;
  it does not remove or disable the category in AC's configuration.
- **Categories supplied by IC**, representing participating IC groups. IC
  controls whether these appear in the active AC profile.

For example, character A uses an IC Treasure group and character B does not:

1. On A, IC adds a Treasure category row to AC.
2. Switch to B: IC removes that IC-supplied row from the active AC profile.
3. Switch back to A: IC adds it back using A's IC configuration and saved order.

That removal really does change AC's saved assignments; it is not just hiding
a row on screen. But it must not delete A's source IC group, its item
assignments or its saved integration settings. Nor may it delete a native AC
category or change an inactive profile.

The IC-supplied AC rows are therefore replaceable output, not the only copy
of the configuration. Before treating a row as replaceable, implementation
must establish that its complete intended configuration can be restored.
Any unique AC-side settings must be preserved, not silently lost.

### Effectively hiding AC categories without deleting them

AC uses the first matching category. IC will maintain an internal catch-all
group titled `Other`, using pattern `*`. The user has confirmed this pattern
works in their manual setup. It sits after all wanted categories but before
hidden native AC categories in **matching order**:

1. Wanted IC and native AC categories get first choice.
2. Other catches all remaining items.
3. Native AC categories below it receive no items.

Those later categories remain saved and unchanged apart from intentional
ordering updates. Unhiding moves them back ahead of the catch-all so they can
receive items again. This is effective exclusion from item matching, not
deletion. Display order alone does not achieve it, and whether an empty
heading is shown remains AC's display behavior.

The internal Other helper must not appear as an editable group or ordering
row in IC's UI. Items caught by it are categorized as Other in AC.

In short: **IC may add and remove its own category rows in active AC saved
data. It must not delete native AC categories or source IC configuration as
part of synchronization.** Changes explicitly made by the user in IC, such
as deleting a group, are separate from synchronization.

## Goal and ownership

Allow all four IC/AC account-wide and character-specific combinations.
Synchronize IC-owned assignments into the active AC profile automatically on
login, reload, profile changes and relevant edits. Normal stale assignments
must not pause integration or require manual repair.

- IC owns its group definitions, participation, enablement and saved display
  and matching orders in the selected IC profile.
- AC owns its profile selection and native categories.
- Synchronization projects the selected IC configuration into the active AC
  profile. It does not change IC groups to match AC's loaded assignments.

Neither force matching scopes nor remember a destination that overrides the
user's AC profile selection. Never project into inactive AC profiles or
overwrite an inactive IC profile's configuration.

## Source and destination

| AC mode | IC mode | Groups and order come from | Assignments updated in |
| --- | --- | --- | --- |
| Account-wide | Account-wide | Shared IC profile | Shared AC profile |
| Account-wide | Character | Current character's IC profile | Shared AC profile |
| Character | Account-wide | Shared IC profile | Current character's AC profile |
| Character | Character | Current character's IC profile | Current character's AC profile |

Integration enablement follows the selected IC profile, not exclusively the
account-wide profile. Group identity is its stable key, not its display name.

## Synchronization sequence

1. IC finishes loading the selected profile's groups and saved order.
2. AC finishes selecting and initializing its active profile.
3. Validate readiness, runtime completeness, ownership, collisions and all
   affected contexts before publishing changes.
4. Reconcile IC-owned assignments in the active AC profile: remove obsolete
   assignments, add missing participating groups, and update changed ones.
5. Apply the selected IC profile's saved display and matching orders, then
   rebuild/refresh the affected AC caches and lists without recursive
   reconciliation.

Preserve native AC categories and unrelated data. Removing an IC-owned AC
assignment does not delete its source IC group from another character or
profile. AC holds the currently applicable layout, not the authoritative
collection of every character's IC groups.

Cold startup must use IC's saved order, not overwrite it with a stale AC
layout. A change to AC's selected profile changes the destination, not the
desired IC order. Apply existing supported ordering constraints; do not
silently redefine how manual ordering edits in AC are handled.

## Included/Excluded UI and ordering

Implemented; the following is the agreed behavior. ESO visual acceptance
remains pending.

- Replace the participation checkbox with a clickable, single-line
  `Included` / `Excluded` label. Use the group pattern editor's include/exclude
  presentation: included rows first, then an Excluded divider and excluded
  rows below it, within the same scrollable list. Use green for Included and
  red for Excluded, with excluded row names also red. State text must convey
  the status without relying on colour alone.
- The same interaction applies to both kinds of row: for IC groups it toggles
  participation; for native AC categories it toggles the saved hidden flag.
  These implementation differences must not complicate the user's workflow.
  Tooltips explain the current state, the toggle action and movement between
  sections.
- Inclusion is one shared state, not a separate choice for each list.
  Excluding a row from either Display order or Matching order excludes it
  from both: it moves into the Excluded section in both lists. Including it
  again from either list restores it to the included sections in both, using
  the display-position and matching-priority rules below.
- Store a hidden flag for native AC rows in the selected IC profile's
  integration configuration, following its existing per-context ordering.
  Do not repurpose the source category's AC settings or delete its assignment.
- Treat the flag as a matching-order constraint: wanted categories first,
  internal Other next, hidden native categories last. Preserve saved relative
  orders within those sets. Excluded rows remain accessible below the
  divider so the user can include them again.
- On re-inclusion, use the saved display position as the insertion reference.
  Insert immediately below any row now occupying that position, shifting
  subsequent rows and updating their numbers to make room. If the reference
  is beyond the current list, append. Do not displace or overwrite another row.
- Use the restored display number as the matching-priority insertion
  reference too, not the pre-exclusion matching number or the excluded
  priority behind Other. Apply the same insert-below-occupant and renumber
  rule in the matching list, keeping every included row ahead of Other.
  For example, if the restored display number is 4 and matching position 4
  is occupied, insert below its occupant and shift the following rows.
  This applies to both IC and native AC rows. It is a re-inclusion rule,
  not a general requirement to keep final display and matching numbers equal.
  Do not retain an old matching priority just to restore it later.
- Excluded rows have no ordering controls. Their presentation sort does not
  change the saved display-position reference. Show IC groups first, then
  native AC categories, sorting each set alphabetically by display name.
- Keep the internal helper out of IC's group editor and both ordering lists.
  It is integration machinery, not a user-maintained source group.
- Give the helper a stable owned identity. Its display title is `Other`, but
  that title alone must never identify ownership or cause native AC Other to
  be removed, overwritten or mistaken for our helper. Reuse the existing
  empty colour-markup suffix (`|cFFFFFF|r`) used for managed category names,
  rather than inventing another native-name collision mechanism. Verify AC
  renders the resulting Other heading as intended.
- Apply the selected IC profile's hidden choices to the active AC profile
  in all four scope combinations, without modifying inactive profiles.
- Preserve the hidden choices through reloads and explicit profile copies.
  Validate every saved profile at the loading boundary. Increment the saved
  schema version and provide non-destructive migration and downgrade
  protection before testing new saved fields on normal game data.

## Disable, reset and missing-addon behavior

Native categories must become eligible again when integration is disabled
or reset; an active internal catch-all must not keep intercepting their items.
Preserve the selected IC profile's exclusion choices on ordinary disable so
re-enabling can reapply them.

Reset starts the integration arrangement over using the same setup flow as
initial enablement: ask whether IC categories should be near the top or at
the bottom, then rebuild the lists according to that choice. Clear the
selected IC profile's saved integration ordering, native-category exclusion
choices and remembered display positions rather than carrying them into the
fresh arrangement. Preserve source IC groups, item assignments and group
participation choices, native AC categories and inactive profiles.
Pressing Reset must show a warning before proceeding. The confirmation must
explain that the previous arrangement and native AC
exclusions will be replaced. Cancelling the arrangement dialog must not
destructively clear the existing configuration; commit the reset/rebuild
only after the user chooses the new arrangement.

Current code removes IC-owned assignments when integration is turned off
normally, or when its AC plugin initializes with integration disabled. Its
registered IC matching predicate also returns false while effective enablement
is false. The new Other helper must follow that enablement contract, not use
an unconditional AC-side match-all expression that keeps working without IC.

Keep existing deliberate-disable behavior: remove generated rows from the
active AC saved assignment tables and refresh affected caches, without
clearing IC's source configuration, exclusion choices or saved orders.
Re-enabling recreates the generated rows and reapplies that configuration.
This removal is not merely session-cache cleanup; it changes generated AC
saved data while preserving the authoritative IC settings.

When IC is absent and its plugin definitions are not registered, AC skips
saved assignments with missing definitions and continues matching. Its
settings show those assignments with a red `(!)`. This is established by the
absent-definition fixture in the
[dependency investigation](SpikeResults.md);
the evidence is offline, not in-game uninstall certification. A partial
startup failure must still follow the existing failure protection contracts.

For item matching, absent definitions and deliberate disable therefore have
the same effective outcome: our categories and catch-all do not intercept
items, and native categories can receive them again. Keep the last projected
native display and matching priorities, including the low matching priorities
of previously excluded categories. Do not restore an initial snapshot or
set native matching priorities from display numbers on disable/reset.
Overlap may affect which native category wins; accept that limitation.

Explain on deliberate disable: "IC exclusions will stop applying.
AutoCategory keeps the last matching order set by IC; previously excluded
categories may match later than others." No special native-order restoration
mechanism is required.

### Readiness and genuine failures

An unexpectedly empty or incomplete IC runtime is a defect, not evidence that
all managed assignments are obsolete. Establish that IC loaded its selected
groups correctly before deleting assignments. Investigate and fix any
underlying startup/cache-order defect rather than concealing it.

Normal profile differences become synchronization work, not failures.
Malformed data, collisions and broken internal contracts still stop safely,
preserve data and report the cause. Preserve existing write gating, rollback,
diagnostics and recovery access. This fix does not require redesigning the
recovery UI; its history is separate from this plan.

## Worked examples: all four states

Each scenario starts independently with integration enabled and these groups:

| IC profile | Groups participating in AC |
| --- | --- |
| Account-wide | Maps, Surveys |
| Character A | Maps, Treasure |
| Character B | Materials |

Account-wide Maps and A's Maps may have different stable identities.
Membership lists below do not specify exact heading positions; each selected
IC profile also retains its own saved ordering.

Shared AC starts with native New and Selling. In character AC mode, A instead
has native Equipment and B has native Crafting. These are existing categories,
not categories synchronization creates or copies.

### AC account-wide / IC account-wide

1. A logs in: shared AC has New, Selling and managed Maps and Surveys.
2. A adds Furnishings to account-wide IC and enables participation: shared AC
   gains its assignment.
3. B logs in with the same modes: the same shared IC configuration supplies
   Maps, Surveys and Furnishings.
4. B deletes Surveys from account-wide IC: shared AC loses its assignment.
   A sees that deletion on return because the source IC configuration is shared.

Both characters use the same managed groups and saved IC order. Inactive
character-specific IC and AC profiles are untouched.

### AC account-wide / IC character

1. A logs in: shared AC has native New and Selling, plus managed Maps and
   Treasure.
2. B logs in: after B's IC profile is ready, synchronization removes A's
   managed assignments and adds Materials. A's IC configuration is untouched.
3. B adds participating Furnishings: shared AC has Materials and Furnishings.
4. A returns: synchronization replaces B's managed assignments with Maps and
   Treasure, applying A's saved IC order.
5. B returns: Materials and Furnishings are projected again using B's order.

Native New and Selling remain throughout. Neither character's source IC
groups or saved order were deleted. A shared AC layout is expected to contain
another character's stale managed assignments when first loaded.

### AC character / IC account-wide

1. A logs in: A's AC has native Equipment plus managed Maps and Surveys.
2. B logs in: B's AC receives Maps and Surveys alongside native Crafting.
   A's inactive AC profile is untouched.
3. B deletes Surveys from shared IC and adds participating Furnishings: B's AC
   now has Maps and Furnishings.
4. A's inactive AC still stores its earlier assignments. This is expected.
5. A returns: synchronization replaces stale Surveys with Furnishings in A's
   now-active AC profile. Equipment remains.

The shared IC groups and order apply to both characters, but their native AC
configurations remain different. Updates reach an inactive AC profile only
when it becomes active.

### AC character / IC character

1. A logs in: A's AC has Equipment plus managed Maps and Treasure.
2. B logs in: B's AC has Crafting plus managed Materials. A's profiles do not
   change.
3. B adds participating Furnishings: only B's active AC profile gains it.
4. A returns: A still has Maps and Treasure with A's saved order.

Each character retains its own IC groups, order and native AC configuration.

## Switching modes

- Switch IC scope: load the newly selected IC configuration, then project it
  into the already-active AC profile.
- Switch AC scope: wait for AC to activate the destination, then project the
  unchanged selected IC configuration there. Leave the old destination alone.

Example: A starts with character IC Maps and Treasure projected into shared
AC. Switching only AC to character mode projects those same groups/order into
A's AC alongside Equipment. Shared AC retains its last layout while inactive.
Switching only IC to account-wide then replaces managed assignments in A's AC
with shared Maps and Surveys. A's character IC groups remain ready for a later
switch back.

### Native Maps ordering acceptance example

Initially native `ac:Maps` is at the bottom in every IC and AC profile:

| Action | Expected Maps position |
| --- | --- |
| Log in as A using account-wide IC and AC | Bottom |
| Move Maps to the top in IC's UI | Top; saved in account-wide IC and projected into shared AC |
| Log in as B using character IC, keeping shared AC | Bottom; B's saved IC order applies |
| Return to A using account-wide IC | Top; A's shared IC order was not overwritten |
| Switch only AC to A's character profile | Top; IC's selected order has not changed |

Thus account-wide IC can retain top and character IC can retain bottom.
Switching AC scope does not change the position specified by active IC;
switching IC scope applies the order saved in the newly selected IC profile.

## Profile setup and copying

### First-time scope switching

When switching to an IC destination profile that has not yet been initialized,
copy the complete configuration from the currently selected source profile:

- Account-wide to character for the first time: initialize that character's
  configuration from account-wide.
- Character to account-wide when no initialized account-wide configuration
  exists: initialize account-wide from the character making that first
  switch. This includes the case where integration was enabled while all
  characters were using character-specific configurations.

Copy the entire system: group definitions and item assignments, participation,
integration enablement/setup, display and matching orders/priorities,
notification and show preferences, native AC exclusions and remembered
display-position references. Copy by value so later edits do not affect the
source profile. Preserve unrelated saved data and all other profiles.
After selection, project the destination IC configuration into active AC
using the normal synchronization rules.

Do not overwrite an already initialized destination or repeat the copy on
later switches. Switching to an existing profile restores its own saved
configuration. If the destination already has source groups/settings but
only its integration arrangement is uninitialized, preserve those existing
groups/settings; distinguish that case from a wholly uninitialized profile
and apply the existing initial integration setup flow.

The user can choose Reset afterward to rebuild the integration arrangement
with IC near the top or at the bottom, with the warning described above.

### Explicit profile copying

When explicitly copying an IC profile from another character or account-wide,
include its integration settings consistently with the copied groups,
including exclusions and saved ordering/restoration references. Inspect the
current copy semantics and validate the resulting references. First-time
initialization and explicit copying must use compatible complete-copy
semantics rather than leaving integration settings behind.

## Implementation and validation

Read [AGENTS.md](../../../../AGENTS.md) and the existing
[dependency contracts](SpikeResults.md),
including its linked specification and implementation plan. Follow the
existing integration lifecycle and helpers; no need to replay the separate
recovery-work history.

Stay on main. Implement and verify, but do not commit until asked.

Use the existing Lua 5.1 runner and synthetic fixtures. Cover:

- All four combinations, with distinct identities and saved orders.
- A to B to A with shared AC and character-specific IC.
- Both mode switches and the native Maps ordering example.
- Additions, deletions, participation changes, renames and profile copies.
- Native categories, unrelated data and inactive profiles preserved.
- Included/Excluded labels, colours, section movement and tooltips for both
  IC and native AC rows; internal Other absent from IC's editor lists.
- Re-inclusion restores display position but initializes matching priority
  from the restored display number, not the pre-exclusion matching number.
- Cold startup, relog-equivalent and reload-equivalent lifecycle behavior.
- Incomplete runtime and malformed data still stop safely.
- Failed projection rolls back without saving a proposed order.
- Existing recovery features continue working for genuine failures.

Existing DEV orphan scenarios may become automatic synchronization cases.
Adapt tests deliberately: do not keep treating a normal orphan as a failure
merely to exercise recovery, and do not weaken actual failure coverage.

Do not mutate live saved variables or inventory in automated validation.
Update this document with implementation status and concise in-game
acceptance steps, distinguishing offline evidence from in-game confirmation.

### Implementation evidence (2026-11-03)

- Automatic reconciliation replaces stale IC-owned rows in the active AC
  profile, rather than pausing on normal profile/participation differences.
  Complete baseline and saved-group runtime membership is checked first.
  All contexts are preflighted; failed publication restores assignments and
  template storage without saving the proposed order or participation change.
- Selected IC orders remain authoritative at startup and on either mode
  switch. Native references unavailable in a different AC destination remain
  dormant in IC's saved arrangement, without appearing as rows there. An
  observed native deletion in the same source/destination still removes its
  ordering reference.
- IC-owned assignment settings are copied by stable identity into
  `icAssignmentTemplates` on each active AC bag before replacement/removal.
  Returning groups reuse the complete saved assignment, changing only owned
  identity/name and projected priorities. Native assignments and inactive
  profiles are not used as replacement output. Historical recovery archives
  are preserved, not replayed into an unverified destination.
- Schema **8** adds per-context native `hidden` choices and excluded-row
  `displayPositions`, plus the profile `itemListInitialized` marker.
  Migration validates all profiles before ZOS constructors and retains
  malformed integration data under the existing failure-isolation contract.
  Actual schema-4, -5, -6 and -7 builds reject synthetic schema-8 data without
  constructors or mutation, including inactive characters and other accounts.
- First-time scope switching and explicit profile copying share complete,
  by-value copy semantics. Existing destination configuration is retained;
  group/item preferences, participation and integration arrangements travel
  together. Restoring an account-wide list backup also marks it initialized.
- Both lists have clickable green Included/red Excluded labels, red excluded
  names, one Excluded divider, sorted nonorderable excluded rows and state/action
  tooltips. Native exclusion puts the stable, predicate-gated Other helper
  before hidden native matches. The helper is absent from IC's group/editor
  lists and does not claim an undecorated native Other category.
- Re-inclusion saves/restores the display insertion reference and derives
  matching insertion from the restored display number, not an old priority.
  Reset warns, then asks for the starting arrangement; neither cancellation
  writes anything. Successful reset clears exclusions/restoration references
  while preserving source groups, items and participation. Normal disable
  removes generated rows, preserves the last native priorities and saved IC
  choices, and reports the agreed explanation.
- DEV recovery injections now use genuinely malformed priorities. Ordinary
  stale owned assignments are covered as successful synchronization cases;
  incomplete runtime, malformed state, collisions, rollback, Retry, Repair,
  Reset and owner cleanup retain failure/recovery coverage. Explicit saved-data
  cleanup also removes owned AC assignment-template storage.

Offline commands and results:

- `python Project\Tests\Run-RuleTests.py`: **192/192 passed**, including Lua
  5.1 syntax checks, all four scope combinations, A/B/A shared-destination
  replacement, both mode switches/Maps ordering, lifecycle edits/copies,
  exclusion/re-inclusion UI callbacks, cold/deferred startup, schema safety,
  rollback and recovery.
- The same runner's synthetic inventory-style burst covers **100 updates,
  128 groups and seven contexts**: seven refreshes, zero cache rebuilds,
  measured **6 ms CPU** in the final run. This is a mocked-boundary observation,
  not an ESO timing limit or compatibility certification.
- `python Project\Tests\Run-AutoCategorySpike.py`: **31/31 passed** against
  installed AC 4.5.2 modules. Its historical top-slot FAIL diagnostics are
  expected assertions of the earlier unsupported placement mechanism, not
  failing tests. Missing definitions/predicates still fall through.
- `git diff --check`: passed.

No live inventory or normal saved-variable files were read or changed by
these automated tests. No commit was created.

### In-game acceptance still required

Back up IC and AC saved variables before testing schema 8. DEV and release
share IC saved variables; schema-7 and older guarded builds will refuse the
upgraded data. Do not remove the downgrade guard to switch builds.

1. With participating groups on A and different groups on B, exercise all
   four scope combinations. In shared AC/character IC, perform A/B/A, reload
   on each character, and confirm only the selected source's generated rows
   exist; native categories and inactive configurations remain intact.
2. Move native Maps to the top in account-wide IC and leave it at the bottom
   in character IC. Switch IC modes, then AC modes: the selected IC order
   must follow the destination. Also switch through an AC profile without
   Maps and confirm its saved IC position survives the return.
3. Exclude/re-include an IC group and a native category from each list.
   Verify green/red single-line labels, red names, the divider, alphabetical
   excluded sections, tooltips, no excluded movement controls and movement
   between both lists. Verify the documented insert-below-occupant numbering
   and matching priority derived from the restored display number.
4. Verify AC displays the decorated helper title as **Other**, classifies
   remaining items there, and gives excluded native categories no matches.
   Confirm an existing native Other remains separate and saved. Check each
   supported inventory context; Guild Bank remains unconfirmed until tested.
5. Add, rename, delete and change participation; copy a profile and try both
   first-time scope switches. Confirm settings copy once by value, already
   initialized profiles retain their own setup, and AC-side assignment
   options survive a group disappearing and returning.
6. Disable and re-enable integration. Verify the explanation, native matching
   eligibility, preserved IC choices/last native priorities, and recreated
   helper/categories. Verify an IC-absent session separately: offline
   missing-definition evidence is not uninstall certification.
7. Cancel Reset's warning and its arrangement dialog independently; neither
   may alter the configuration. Then confirm a top/bottom reset and verify
   exclusions/remembered positions are cleared but source data and inactive
   profiles remain. Exercise recovery only with deliberate malformed DEV
   fixtures, not a normal stale assignment.

These are pending manual checks, not reported in-game confirmations.
