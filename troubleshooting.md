# AutoCategory mismatch: what happens

This explains the repeated error for an IC-owned AutoCategory assignment such as
`custom_273124205`, and why it can return after `/reloadui`. The examples are
sanitized fragments, not copies of anyone's live saved variables. The AutoCategory
fragment shows the saved fields IC reads; AutoCategory chooses the outer account
or character profile itself.

## There are two separate saved-data sets

Inventory Companion (IC) saves its tracked groups and its desired AutoCategory
settings in `InventoryCompanion_SavedVariables`. AutoCategory (AC) separately
saves its category assignments and priorities. An AC assignment refers to an IC
group by key; it does not contain the IC group's rules.

For example, IC's current schema-7 account-wide profile can look like this:

```lua
InventoryCompanion_SavedVariables = {
    ["Default"] = {
        ["@Example"] = {
            ["$AccountWide"] = {
                version = 7,
                trackedRules = {
                    ["custom_273124205"] = {
                        displayName = "Cyrodiil Treasure Maps",
                        addedPatterns = { "*Cyrodiil treasure map*" },
                        autoCategoryEnabled = true,
                    },
                },
                autoCategoryIntegrationEnabled = true,
                autoCategorySetupComplete = true,
                autoCategoryOrder = {
                    contexts = {
                        backpack = {
                            display = { "ic:custom_273124205", "ac:New", "ac:Selling" },
                            matching = { "ic:custom_273124205", "ac:New", "ac:Selling" },
                        },
                        -- The real profile also has the other inventory contexts.
                    },
                },
            },
        },
    },
}
```

The character-specific profile is a separate entry under the same account
bucket. IC selects between it and `$AccountWide` using
`character.useCharacterItemList`. AutoCategory independently selects which of
its own saved profiles is active.

The corresponding AC assignment is conceptually:

```lua
-- Fragment of AutoCategory.saved, after AC selected its active saved profile.
bags = {
    [AC_BAG_TYPE_BACKPACK] = {
        rules = {
            {
                name = "New",
                runpriority = 1000,
                showpriority = 1000,
                isHidden = false,
            },
            {
                name = "Cyrodiil Treasure Maps|cFFFFFF|r",
                runpriority = 968,
                showpriority = 968,
                isHidden = false,
                icOwned = true,
                icRuleKey = "custom_273124205",
            },
        },
    },
}
```

`icOwned` marks an assignment IC manages. `icRuleKey` is its stable link back
to the IC group. AC's account/character profile choice and IC's
account-wide/character-specific list choice are independent.

## Login and the mismatch

1. **Both add-ons load their saved data.** AC restores its active bag
   assignments. IC loads its selected tracked-rules profile and builds runtime
   rules from that profile plus its built-in rules. No data should be deleted
   just because the character logged out or back in.

2. **IC prepares definitions and checks AC's assignments.** For each active
   AC assignment marked `icOwned`, IC reads `icRuleKey` and requires that key
   to exist in the current IC runtime rule set. IC builds definitions for all
   ordinary runtime groups; turning AutoCategory participation off by itself
   does not explain an “unavailable IC group” error.

3. **The saved sets disagree.** The error means AC has an IC-owned assignment
   for a key that IC could not find in the runtime rules it was using at that
   moment. The supplied report names `custom_273124205` and the assignment
   `Cyrodiil Treasure Maps`. Possible causes include a group missing from the
   selected IC profile, an AC assignment left over after a group/profile change,
   or IC presenting an incomplete runtime rule set during reconciliation. The
   report alone does not establish which caused the mismatch.

   The error-window locals showed `rules = {}` and `definitions = {}` at the
   failure point. If that is the complete local-table display, IC had no runtime
   rules available to reconcile then—not merely a different display name. That
   is an important clue to investigate; it does not by itself prove why the
   runtime set was empty.

4. **Preflight finds a profile mismatch.** If an assignment's group is missing
   or not enabled for integration in the active IC profile, preflight stops
   before projection. The assignment and IC order remain unchanged, and the
   integration pauses without changing its saved enablement.

## Why the error used to return after refresh

Previously, the non-destructive failure path kept the stale AC assignment and
left IC's saved order untouched, but reported an error. `/reloadui` cleared the
temporary in-memory fault, AC loaded the same assignment again, and the same
mismatch faulted again. The updated path detects the mismatch before planning:
it restores any archived rows, pauses integration for the current character,
and reports an `unsupported` status instead of repeating the error.

In the earlier failure behavior, IC removed `icOwned` assignments from AC's
active profile while handling the error. That changed AC's saved assignment
tables. On the next load, the offending assignment was gone, so the mismatch
could appear to be fixed. But with those assignments gone, the old cold-start
ordering path could rebuild from AC's remaining native headings and put IC
groups at the end, then save that new order into IC's `autoCategoryOrder`.
Thus the error cleanup could mask the mismatch and the subsequent successful
projection could overwrite the user's saved order.

The current code avoids both data loss and that sequence:

- The failure handler no longer removes IC-owned AC assignments. For this
  profile mismatch, the assignment stays and IC does not write a new order;
  integration pauses for that character without changing its saved enablement.
- A fresh projection starts from IC's saved order when no in-memory projection
  snapshot exists, rather than treating AC's observed order as the user's
  desired order.

This preserves the mismatch for diagnosis without deleting its assignment. The
specific error key has changed between reports
(`custom_262734126` and `custom_273124205`); those are distinct group identities,
so both reports should be treated as evidence rather than assumed to be one
renamed group.

## DEV diagnostics and reproduction

The DEV build records the first **natural** call to `GetRuntimeRules()` and,
when a managed assignment has no matching definition, adds a read-only
diagnostic block to the **See Error** report. The diagnostic does not call
`GetRuntimeRules()` itself, build the cache, or write saved variables. It
reports cache state and rule counts, whether the target exists in the account,
character, active, baseline, and runtime rule sets, which AutoCategory profile
is active, and where that assignment key appears in AutoCategory's account,
character, and active bag lists. It does not include group patterns or dump
saved-variable contents. Caller location is included when the runtime exposes
`debug.getinfo`; ESO may report `caller=unavailable` instead.

To collect it in game:

1. Back up the IC and AutoCategory saved-variable files before testing.
   `/iclistbackup save` backs up IC's account-wide lists, but not AutoCategory's
   assignments.
2. Load the instrumented DEV addon and reproduce the issue using the same
   relog or `/reloadui` that normally triggers it. Do not run a diagnostic
   command that calls `GetRuntimeRules()` first.
3. Do not edit groups, toggle participation, or clear assignments before
   collecting the report.
4. Click **See Error** and copy the complete report. Note whether the trigger
   was relog or `/reloadui`.

## What the IC backup does—and does not—contain

`/iclistbackup save` stores a copy under the IC account-wide profile, roughly:

```lua
accountWideListBackup = {
    formatVersion = 1,
    trackedRules = { ... },
    trackedItems = { ... },
    autoCategoryIntegrationEnabled = true,
    autoCategorySetupComplete = true,
    autoCategoryOrder = { contexts = { ... } },
}
```

`/iclistbackup recover` validates and restores those IC account-wide fields. It
does not back up or restore AutoCategory's own `bags[*].rules` assignments.
Do not use `/iccleanautocategory` as a diagnostic step; that command is
specifically intended to clear integration data.

## Current state in one sentence

AC can load an IC-owned assignment whose `icRuleKey` is missing from, or not
enabled for integration in, the currently active IC profile. IC now retains
the assignment and pauses its integration for that character rather than
changing AC assignments or IC order. The saved integration-enable choice
remains intact and reconciliation retries when the active profile changes.

## Code paths

- [AutoCategoryIntegration.lua](./Tracking/AutoCategoryIntegration.lua): builds
  definitions, pauses on active-profile mismatches without changing saved
  assignments or order, and projects saved order when profiles align.
- [ItemDatabase.lua](./Tracking/ItemDatabase.lua): selects the active IC
  profile and builds runtime rules.
- [Init.lua](./Core/Init.lua): schema version and `/iclistbackup` command.

## Assignment preservation and diagnostics

Earlier DEV code archived and removed seven IC-owned AutoCategory assignment
lines. The complete rows, bag contexts, original indices, and timestamps remain
in `accountWide.debug.autoCategoryRemovedLines`. The current code restores those
rows to the active AutoCategory layout once, marks the archive entries as
restored, and refreshes the affected contexts. It does not discard the archive.

For any assignment that references a group missing from, or not enabled for
integration in, the active IC profile, the integration pauses before changing
AutoCategory assignments, definitions, priorities, or IC ordering. It reports
an `unsupported` status rather than an integration error. The selected IC profile's
enablement choice is not changed, and reconciliation retries after a profile
change; a character with the referenced group enabled can use the integration
normally.

The Debug Key report summarizes archived/restored rows and currently ignored
assignments. `/ictest veryverbose copy` includes the archived rows and any
currently ignored rows; `/ictest veryverbose` prints them in chat. This is local
diagnostic data, not remote usage telemetry.

`/iclistbackup` alone does not back up AutoCategory assignments. The recovery
archive preserves the exact rows removed by the earlier DEV behavior. No
additional saved-variable schema bump is planned for the current single DEV
build.

## Account-wide and character-specific profile combinations

IC and AC select their profiles independently. The active IC profile supplies
the groups, participation choices, integration enablement, and saved order.
The active AC profile receives the projected assignments. IC's
`autoCategoryIntegrationEnabled` is read from the selected IC profile; it is
not exclusively account-wide.

| AC mode | IC mode | Groups come from | AC assignments updated in |
| --- | --- | --- | --- |
| Account-wide | Account-wide | Shared IC groups | Shared AC profile |
| Account-wide | Character | Current character's IC groups | Shared AC profile |
| Character | Account-wide | Shared IC groups | Current character's AC profile |
| Character | Character | Current character's IC groups | Current character's AC profile |

When an IC group changes, successful reconciliation projects into whichever
AC profile is active. Inactive AC profiles are not updated. The current
mismatch preflight can block that reconciliation; the table describes its
source and destination, not a guarantee that every update currently succeeds.

## Planned fix: synchronize, do not pause for normal profile changes

The agreed fix is to allow all four profile combinations and synchronize
IC-owned assignments into the active AC profile. The pause described above is
the current protective behavior, not the planned handling of ordinary
character/profile transitions. AC should remain on and working, with neither
its profile selection nor IC's groups changed to accommodate stale assignments.

The synchronization sequence should be:

1. IC finishes loading the selected profile's groups and saved order.
2. AC finishes selecting and initializing its active profile.
3. IC reconciles its owned assignments in that active AC profile: add missing
   assignments, update changed ones, and remove assignments for groups absent
   from or no longer participating in the active IC profile.
4. IC projects the selected IC profile's saved order, and AC rebuilds the
   affected caches and refreshes its lists.

This is the intended handshake: both sides are ready, then IC synchronizes
its portion of the active AC layout. It does not require AC to select a
different profile. AC's native categories must be preserved, and inactive AC
profiles must remain untouched. Synchronization must not overwrite IC's saved
order with a stale AC layout.

Removing an obsolete IC-owned AC assignment does not delete the source IC
group from another character or profile. It removes only that group's
projection from the currently active AC layout.

An unexpectedly empty or incomplete IC runtime is a separate defect, not
evidence that all managed assignments are obsolete. Establish that IC loaded
its selected groups correctly before reconciling; do not turn an initialization
failure into assignment removal. This synchronization behavior remains to be
implemented in place of the current mismatch pause.

### Example: shared AC profile, different character-specific IC groups

Suppose both characters use AC account-wide and IC character-specific lists:

- Character A has `Cyrodiil Treasure Maps` enabled for integration.
- Character B has `Crafting Materials` enabled instead, and does not have A's
  treasure-map group.
- AC also has native categories such as `New` and `Selling`.

On A, synchronization puts A's treasure-map assignment into the shared AC
profile alongside the native categories.

After logging into B, AC initially loads that same shared profile, including
A's assignment. The current code pauses because B's IC groups do not contain
its key. The desired behavior is to remove only that stale IC-owned assignment,
add B's crafting-material assignment, and apply B's saved IC order. AC stays
working, and `New` and `Selling` remain native AC categories.

When A logs in again, synchronization replaces B's managed assignment with A's
treasure-map assignment and applies A's saved IC order. Neither character's IC
groups or saved order were deleted. If AC were character-specific instead,
each character's AC profile would retain its own assignments while inactive
and be reconciled only when it became active.

### Ownership model

- **IC owns:** group definitions, participation choices and saved IC ordering.
- **AC owns:** native categories and its profile selection.
- **Synchronization owns:** projecting the current IC configuration into the
  active AC layout.

Under the planned fix, a stale IC-owned AC assignment is something to reconcile, not
a command to modify IC and not automatically an error. An incompletely
initialized IC runtime remains a genuine defect and must not trigger cleanup.
IC groups are never added, deleted or temporarily disabled merely because AC
loaded different assignments. AC holds the currently applicable layout, not
the authoritative collection of every character's IC groups.

## Planned fix worked examples: all four states

These are independent scenarios showing the agreed behavior, not tests of
the current implementation. Each starts with these example IC profiles:

| IC profile | Groups enabled for AC integration |
| --- | --- |
| Account-wide | Maps, Surveys |
| Character A | Maps, Treasure |
| Character B | Materials |

Maps in the account-wide and character-A profiles need not be the same group
identity; synchronization uses stable group keys, not display names. All
selected IC profiles have integration enabled and their own saved order.
The lists below show managed group membership, not exact heading positions.
Positions come from the selected IC profile's saved ordering, subject to the
integration's supported AC ordering constraints.

AC's shared profile has native categories `New` and `Selling`. For the
character-specific AC examples, A's native category is `Equipment` and B's is
`Crafting`. These native categories are illustrative existing configurations;
synchronization does not create, delete or copy them.

### State 1: AC account-wide / IC account-wide

**Source:** shared IC groups. **Destination:** shared AC assignments.

1. A logs in. IC loads Maps and Surveys. The shared AC profile is synchronized
   to contain native `New`, native `Selling`, and managed Maps and Surveys.
2. A adds Furnishings to account-wide IC and enables it for integration.
   The shared AC profile gains its managed Furnishings assignment.
3. B logs in using the same two account-wide modes. B loads the same IC
   configuration, so AC still has managed Maps, Surveys and Furnishings.
4. B deletes Surveys from account-wide IC. Synchronization removes its managed
   assignment from shared AC. A will also see that deletion on next login,
   because the source IC configuration itself is shared.

Neither character's inactive character-specific IC or AC profile is changed.
Both characters see the same managed groups and saved IC order.

### State 2: AC account-wide / IC character

**Source:** current character's IC groups. **Destination:** shared AC assignments.

1. A logs in. The shared AC profile gets managed Maps and Treasure, alongside
   native `New` and `Selling`.
2. B logs in. IC first finishes loading B's Materials group. Synchronization
   removes A's managed Maps and Treasure assignments from shared AC and adds
   Materials. A's IC groups and saved order are untouched.
3. B adds Furnishings to B's IC profile and enables it for integration.
   Shared AC now has managed Materials and Furnishings.
4. A returns. Synchronization removes B's managed Materials and Furnishings
   assignments and restores Maps and Treasure, using A's saved IC order.
5. B returns. Materials and Furnishings are projected again from B's unchanged
   IC configuration.

Native `New` and `Selling` stay in shared AC throughout. A managed assignment
being absent from shared AC while another character is active does not mean
its IC group was lost. This shared destination must be synchronized on login,
not treated as proof of which IC groups the current character should have.

### State 3: AC character / IC account-wide

**Source:** shared IC groups. **Destination:** current character's AC assignments.

1. A logs in. A's AC profile contains native `Equipment` plus managed Maps and
   Surveys.
2. B logs in. B's AC profile receives managed Maps and Surveys alongside native
   `Crafting`. A's inactive AC profile remains untouched.
3. B deletes Surveys from account-wide IC and adds Furnishings, enabled for
   integration. B's active AC profile becomes native `Crafting` plus managed
   Maps and Furnishings.
4. A's inactive AC profile still stores its earlier Maps and Surveys
   assignments. That is expected: synchronization does not edit inactive
   profiles.
5. A returns. Shared IC now supplies Maps and Furnishings. Synchronization
   removes the stale Surveys assignment from A's active AC profile and adds
   Furnishings. Native `Equipment` remains.

Both characters ultimately get the same shared IC groups and saved IC order,
but keep different native AC configurations. Updates reach an inactive AC
profile only when it becomes active.

### State 4: AC character / IC character

**Source:** current character's IC groups. **Destination:** that character's AC
assignments.

1. A logs in. A's AC profile contains native `Equipment` plus managed Maps and
   Treasure.
2. B logs in. B's AC profile contains native `Crafting` plus managed Materials.
   Neither A's IC profile nor A's inactive AC profile changes.
3. B adds Furnishings to B's IC profile and enables it for integration.
   Only B's active AC profile gains the managed Furnishings assignment.
4. A returns. A still has Maps and Treasure, with A's saved order. B's
   Furnishings change has no effect on A's configuration.

Each character retains its own IC groups, saved IC order and native AC
configuration.

### What happens when either mode changes

The same source-to-destination rule applies without copying IC groups between
profiles or forcing the other addon's mode:

- **IC mode changes:** load the newly selected IC groups and saved order, then
  reconcile them into the AC profile that is already active.
- **AC mode changes:** wait for AC to activate the selected profile, then
  reconcile the current IC groups into that destination. Leave the previously
  active AC profile untouched after the switch.

For example, A starts in state 2 with Maps and Treasure projected into shared
AC. A switches only AC to character mode, entering state 4. A's character AC
profile receives Maps and Treasure alongside its native `Equipment`; shared
AC retains its last stored layout while inactive. A then switches only IC to
account-wide, entering state 3. A's active character AC profile replaces its
managed assignments with account-wide Maps and Surveys. A's character IC
groups remain Maps and Treasure, ready for a later switch back.

In every case, synchronize only after both active profiles and the IC runtime
are ready. A normal profile difference is not a reason to pause integration;
malformed external data or a broken initialization contract must still be
reported rather than mistaken for a valid empty group set.

## Planned failure recovery and settings UX

Synchronization makes the mismatch pause unnecessary for normal profile
differences; it does not remove failure protection. Bad data or broken
initialization must still stop synchronization safely, preserve data, and
report the cause. Recovery must be accessible from settings even while the
integration is faulted.

The recovery sequence is: automatic synchronization for normal transitions,
targeted repair for identifiable damaged assignments, and a confirmed
last-resort reset when needed. These are planned capabilities, not claims
about recovery controls currently implemented.

### How the user knows something needs attention

Show the same persistent warning and failure reason in both **IC Settings >
AutoCategory integration** and IC's **AutoCategory panel**, backed by a
one-time chat warning when a failure occurs. Avoid repeating the chat warning
on every reconciliation attempt.

Example status:

> AutoCategory integration needs attention. Synchronization has stopped to
> protect your data. Your groups and saved order are preserved.

Include the specific failure reason. Distinguish the saved enablement choice
from operational status: a checked enable box must not imply synchronization
is healthy. Do not describe a normal, successfully reconciled profile change
as a failure.

### One recovery surface: the AutoCategory panel

The AutoCategory panel must remain accessible while integration is faulted.
Replace its normal editing UI with the warning, specific failure reason and
resolution options. Keep the top menu navigation buttons enabled so the user
can enter and leave the panel. Apart from navigation, only recovery actions
are enabled; normal group, ordering and other editing controls must not remain
interactive behind the failure view.

The settings section shows the same warning but has just one recovery-related
button: **More information**, which opens IC's AutoCategory panel directly in
its failure/recovery view. Do not duplicate the recovery controls in settings.
Opening the panel must not require a healthy integration or trigger normal
editor initialization that depends on successful synchronization.

Keep the following actions and short explanations beside the warning in the
AutoCategory panel:

| Action | Purpose and limits |
| --- | --- |
| **Retry synchronization** | Retry without resetting saved configuration. Clear the failure state only after validation and synchronization succeed. |
| **Repair affected assignments** | Offer only when a specific, safe data repair can be identified. Show the proposed changes, preserve a recovery copy, and remove or rebuild only the damaged IC-owned assignments. Preserve IC groups, saved order, enablement and native AC categories, then retry synchronization. |
| **Reset integration...** | Destructive last resort: discard the explicitly identified integration setup/order and IC-owned AC assignments, leaving integration disabled for setup again. Require confirmation. |
| **Show details** | Display diagnostic information for understanding or reporting an unresolved failure. |

A group missing from the current IC profile does not prove an assignment in
an inactive AC profile is corrupt. Targeted repair must not remove valid
inactive-profile assignments on that basis. The earlier recovery evidence
described seven assignment rows across inventory contexts, not necessarily
one row per account/character profile.

Removing assignments is not a valid repair for an incomplete IC runtime or a
code defect. Explain when targeted repair is unavailable instead of offering
it as a generic cure.

The chat warning must direct the user to IC's AutoCategory panel, also
reachable through **IC Settings > AutoCategory integration > More
information**. Settings, panel navigation, diagnostics and applicable recovery
actions must remain usable while integration is faulted. Both warning surfaces
must reflect the same failure state and recovery result.

### Item edit panel during a failure

The item edit panel must not present AutoCategory entries as healthy, editable
controls while integration is faulted. Two presentation alternatives remain:

- Hide the AutoCategory column for the duration of the failure; recovery stays
  accessible through settings and the AutoCategory panel.
- Keep the column visible, show its entries in red, and make clicking any entry
  open the same AutoCategory panel in its recovery view. These clicks must
  navigate only, not change participation or other integration data. Provide
  explanatory tooltip text so colour is not the only indication of failure.

The presentation choice is not yet settled. Neither alternative disables
unrelated item editing. Restore the normal column behavior after successful
recovery; after reset, use the normal disabled/awaiting-setup behavior.

### Last-resort reset and setup again

The reset is for IC's AutoCategory integration, not a reset of AutoCategory
itself:

1. Show a destructive-action confirmation that identifies every affected
   profile and warns that custom integration ordering will be lost.
2. Remove IC-owned AC assignments within the confirmed scope and reset the
   corresponding IC integration setup/order to its pre-initialization state.
3. Preserve IC groups, participation choices, matching rules, tracked items
   and native AC categories.
4. Leave the affected integration enablement disabled.
5. On re-enable, show the same initial setup dialog used on first activation,
   then rebuild the integration assignments and ordering.

The precise reset scope across IC and AC profiles must be defined before
implementation; a generic reset button must not silently clear every profile.
This explicit reset is distinct from normal synchronization, which writes
only the active AC profile.

### Report the result, not just the button click

After each action, report the actual outcome: recovered successfully, still
failing with a specific reason, or reset and awaiting re-enable. Do not clear
the warning or present the integration as healthy merely because an action
was clicked. A failed recovery must remain visible and keep diagnostic and
recovery access available.
After successful recovery, restore the normal AutoCategory editing UI. After
a reset, show the disabled/awaiting-setup state rather than a healthy active
editor; re-enabling must still use the initial setup dialog.
