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
diagnostic block to the recovery panel's **Show details** report. The diagnostic does not call
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
4. Open IC's AutoCategory recovery panel, click **Show details**, and copy the
   complete report. Note whether the trigger
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

## Planned synchronization fix

The agreed ownership model, all four profile combinations, worked examples,
mode-switch behavior and implementation requirements have moved to
[the master feature document](Project/DevDocs/AutoCategoryIntegration.md#profile-ownership-and-synchronization).
This document retains the mismatch investigation and recovery-work evidence.

## Planned failure recovery and settings UX

Synchronization makes the mismatch pause unnecessary for normal profile
differences; it does not remove failure protection. Bad data or broken
initialization must still stop synchronization safely, preserve data, and
report the cause. Recovery must be accessible from settings even while the
integration is faulted.

The recovery sequence is: automatic synchronization for normal transitions,
targeted repair for identifiable damaged assignments, and a confirmed
last-resort reset when needed. Retry, targeted assignment repair, reset and
diagnostic access are implemented. The normal-profile synchronization fix
remains planned, as detailed under "Failed-state implementation and safe testing."

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

The recovery view lists all identified problematic assignments in a
scrollable area, including inventory context, category name and stable IC
group key, with the total count. No rows are omitted from this list.
The list fills the remaining recovery-panel height and uses 20-point
regular-weight text rather than the small game font.
**Show details** provides the complete mismatch list in a copyable error
report. If no specific rows were identified, explain that instead of showing
an empty list. This preview reads the existing mismatch records; it does not
reconcile assignments or initialize the runtime-rule cache.

The repair confirmation always gives the total number of assignments to
remove. For up to five assignments, it lists all of them. For more than five,
it lists three examples, the remaining count, and says: "To see everything
that will change, cancel and review the scrollable details in the recovery
panel." Confirmation still applies to the complete validated set, not just
the examples shown. The dialog does not expand to list every assignment.

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
| **Repair affected assignments** | Available for an identified active-profile assignment mismatch. Validate the IC runtime, preview the exact affected rows, and require confirmation. Remove only those IC-owned assignments as part of a validated synchronization plan. Keep session-only copies, preserve IC groups, saved order and enablement, and leave inactive profiles untouched. If projection fails, restore the assignment lists. |
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
controls while integration is faulted. Keep the column visible, show its
entries in red with a warning marker, and make clicking any entry open the
same AutoCategory panel in its recovery view. These clicks navigate only,
not change participation or other integration data. Provide explanatory
tooltip text so colour is not the only indication of failure.

Unrelated item editing remains available. Restore the normal column behavior
after successful recovery; after reset, use the normal disabled/awaiting-setup
behavior.

### Separate enablement, write permission and failure visibility

Do not introduce a truthy `"failed"` string into a boolean enablement switch,
and do not clear saved enablement when a failure occurs. Keep an independent
runtime failure state so the UI distinguishes off, healthy and failed:

| State | Integration writes | Item editor AutoCategory column | AutoCategory panel |
| --- | --- | --- | --- |
| Off | Blocked | Hidden | Existing settings access |
| On, healthy | Allowed | Normal controls | Normal editor |
| Failed | Blocked | Red warning entries that open recovery | Available, recovery UI only |

`GetAutoCategoryState()` exposes `configuredEnabled` (the saved boolean
choice), `enabled` (the effective boolean write gate), and `failed` (runtime
recovery state). Settings display the configured choice; normal integration
operations use the effective gate. Failure navigation does not depend on
either the normal editor or writes being enabled. No new saved fields or
schema change are required for these runtime distinctions.

### Failed-state implementation and safe testing

The failed-state UI implements the shared warning, red item-editor entries,
persistent navigation, **More information**, **Retry synchronization**, and
**Show details**, plus confirmed **Repair affected assignments** for identified
assignment mismatches and **Reset integration...** as a last resort.
The normal-profile synchronization fix remains planned work; the current
mismatch preflight is still present.

In the DEV build, enable Debug Mode and a working integration, then use
**IC Settings > AutoCategory Integration > Simulate integration failure
(DEV)**. This injects a runtime failure without editing assignments, IC groups,
saved ordering or saved enablement. Debug Mode also produces its normal error
report. Verify that:

1. Settings retain the checked enable choice but show the warning and
   **More information**.
2. The AutoCategory panel stays accessible through editor navigation and
   replaces editing controls with the same warning and recovery actions.
3. Group entries in the item editor's AutoCategory column turn red and open
   recovery instead of changing participation. Unrelated item editing works.
4. **Show details** reports the simulated failure.
5. **Retry synchronization** validates and synchronizes normally, restores the
   normal editor/column on success, and retains the warning if retry fails.

The simulation itself is read-only with respect to saved data; retry performs
the ordinary projection and may update AC assignments as normal. Use synthetic
offline fixtures first, and back up IC and AC saved variables before in-game
testing. The DEV simulation is unavailable in the release build.

### Real saved-data test: inject an orphan assignment

Back up both IC and AC saved-variable files before this test. Unlike the
runtime-only simulation, this command deliberately changes AC saved data and
the test row can survive logout or `/reloadui` until repaired or removed.
Neither command exists in the release build.

1. Start with a working, enabled integration and note the active IC and AC
   profiles and current order.
2. Run `/icactest inject`. It appends exactly one IC-owned assignment named
   `IC DEV recovery test (missing group)` to the active AC profile's Backpack
   list. Its reserved key, `_ic_dev_recovery_test_missing_group`, deliberately
   has no IC group or category definition. Other contexts and inactive profiles
   are not edited.
3. The command invokes normal projection. The real mismatch preflight detects
   the orphan and displays the recovery UI; it does not call the simulated
   failure function. Verify the settings warning, retained checked enablement,
   accessible recovery panel and red item-editor entries.
4. **Retry synchronization** alone must remain unsuccessful: the row is still
   present in saved data. That is expected, not a successful repair.
5. Click **Repair affected assignments**. The confirmation lists the exact
   affected assignments and contexts. With an otherwise healthy starting
   configuration, it should list only the injected Backpack assignment.
   Canceling must leave the row unchanged.
6. Confirm. Repair must remove the injected row, restore healthy synchronization
   and the normal UI, and preserve the original IC groups, participation,
   ordering, enablement and existing AC assignments. A copy of each removed row
   is retained in runtime `AutoCategoryIntegration.lastRepairBackup` for this
   session only; it is not added to the legacy auto-restoring archive and does
   not require a saved-variable schema change.
7. If repair cannot complete, the normal projection rollback restores the
   assignment lists and the failure remains visible. Incomplete runtime rules,
   changed profiles or changed candidates must not result in blind deletion.

For manual test cleanup, run `/icactest remove` with the same AC profile active.
It removes rows matching the exact reserved names, keys and IC ownership
marker of all test scenarios across that profile's seven supported lists,
then retries if recovery is needed. It does not search or modify inactive
profiles. A repeat cleanup reports zero removed rows.

### Multiple saved-data scenarios for recovery panel and dialog testing

After `/reloadui` to load these commands, choose any scenario:

| Command | Data inserted into the active AC profile | Expected confirmation |
| --- | --- | --- |
| `/icactest inject1` | Three different missing groups in Backpack | All three rows |
| `/icactest inject2` | One missing group assigned once in each of the seven inventory contexts | Three examples and "4 more" |
| `/icactest inject3` | Thirty different missing groups in Backpack | Three examples and "27 more" |
| `/icactest inject4` | Five different missing groups in Backpack | All five rows, testing the exact cutoff |

The recovery panel lists every inserted row in its scrollable area. The item
editor's AutoCategory column enters its warning/navigation-only state; these
orphan AC assignments do not create actual IC groups or item-editor group rows.

Every injection removes **all** reserved test rows from every scenario,
including the original single-row `/icactest inject`, before adding the chosen
scenario. Commands can run in any order, including repeating the same command.
There is no required repair or reload between scenarios. If teardown leaves a
real unrelated mismatch or another failure, the command reports that recovery
is still needed and does not inject new rows over the unresolved failure.
After a last-resort reset, re-enable and finish setup before injecting again.

Only the active AC profile is changed; inactive profiles and real assignments
are preserved. Reserved names and stable keys are validated before teardown.
`/icactest verify` recognizes all four scenarios and the original single-row
test. `/icactest remove` clears all of them from the active profile. The
original `/icactest inject` remains available for the one-row repair/reset
test; it also tears down any previous scenario.

Repair is not yet a general fix for malformed arbitrary data or code defects.
It is a confirmed, active-profile-only repair of identified unavailable or
nonparticipating IC-owned assignments, followed by ordinary synchronization.
Normal profile differences will eventually be handled automatically by the
separately planned synchronization fix instead of requiring this manual step.

### Last-resort reset and setup again

The recovery panel's **Reset integration...** button is for IC's AutoCategory
integration, not a reset of AutoCategory itself. Its scope is the selected IC
profile's integration setup/order and all IC-owned assignments in the active
AC profile's seven supported inventory contexts. The confirmation names the
IC and AC scopes and warns that custom integration ordering will be lost:

1. Show a destructive-action confirmation that identifies every affected
   profile and warns that custom integration ordering will be lost.
2. Remove IC-owned AC assignments within the confirmed scope and reset the
   corresponding IC integration setup/order to its pre-initialization state.
3. Preserve IC groups, participation choices, matching rules, tracked items
   and native AC categories.
4. Leave the affected integration enablement disabled.
5. On re-enable, show the same initial setup dialog used on first activation,
   then rebuild the integration assignments and ordering.

Inactive IC and AC profiles are untouched. Reset does not delete category
definitions supplied by the plugin; while disabled, its predicate does not
match items. Session-only backup copies are retained in
`AutoCategoryIntegration.lastResetBackup`. If reset cannot complete, its
assignment and setup/order changes are rolled back and failure remains visible.
Incompatible AC APIs or unidentified malformed rows can prevent a safe reset;
the button must not claim to fix a code defect.

After a successful reset, the panel remains open in a disabled/awaiting-setup
view with **Enable and set up again** and navigation buttons. Normal editing
and the item editor's AutoCategory column stay inactive. Re-enabling from
either this view or settings opens the original setup dialog. After a reload,
the saved disabled state remains; settings can still re-enable integration.

### Two-pass in-game test and saved-data verification

Back up both saved-variable files first. Stay on the same IC and AC profiles
through both passes so the verification examines the same destination.

**Pass 1: minimal repair**

1. `/reloadui` to load the updated DEV code; start with enabled, working
   integration.
2. `/icactest inject`, then `/reloadui` again. The orphan persists in AC saved
   data, and startup should enter the visible recovery state.
3. Open IC's AutoCategory panel, or settings > **More information**.
4. Choose **Repair affected assignments**, inspect the preview, and confirm.
5. `/icactest verify` should say **item gone** if normal IC-owned assignments
   remain. It must not delete or disable the other participating groups.
6. `/reloadui` and `/icactest verify` again to check the persisted result.

**Pass 2: last-resort reset**

1. `/icactest inject`, then `/reloadui` to return to the real failure state.
2. Choose **Reset integration...**, inspect the profile scopes and ordering-loss
   warning, and confirm.
3. `/icactest verify` should say **everything gone - its lonely in here**.
   This means all IC-owned assignments in the active AC profile are gone,
   not that native AC categories or source IC groups were deleted.
4. `/reloadui` and `/icactest verify` again before re-enabling, to check that
   reset persisted.
5. Re-enable integration in settings (or use **Enable and set up again** before
   reloading) and verify that the original arrangement dialog appears and
   assignments rebuild after confirmation.

`/icactest verify` is DEV-only and read-only. It opens a deliberate, copyable
error-window report, not an integration failure. The report names the active
IC/AC scopes, status, saved enablement and setup state. It scans every row in
the active AC profile's seven supported lists and reports per-context and total
test/IC-owned/native/unavailable counts. Unavailable IC-owned rows are listed
with their names, stable keys and reasons, based on the selected IC saved
profile and loaded baselines without building the lazy runtime-rule cache.

The reserved injected test row has its own result, separate from checking real
unavailable assignments:

- **test item still present:** the reserved test key or name is still found;
  it also reports each affected context.
- **item gone:** no test row remains, but other IC-owned assignments do.
  This does not prove a real mismatch was repaired: the test row may never
  have been injected. Check the unavailable counts and details as well.
- **everything gone - its lonely in here:** no test row or IC-owned assignments
  remain in that active profile.

The command examines loaded saved-variable tables, not files on disk or
inactive profiles. Running it after `/reloadui` checks what was persisted and
loaded again. It does not repair, reset, rebuild caches or change IC ordering.
The last complete report is also retained in runtime
`AutoCategoryIntegration.lastVerificationReport`.

### In-game feedback, 2026-11-02

The user encountered the existing real mismatch on login without injecting
test data. The supplied repair-confirmation screenshot lists
`Cyrodiil Treasure Maps` in all seven inventory contexts. This confirms that
the failure/recovery flow and targeted repair preview were reachable for
real saved assignments, not just the reserved test row.

The user reported that verification ran and reset "also seemed to work."
The original verifier printed to chat and primarily identified the reserved
test row, so this is not yet a captured before/after proof that the real
assignments were removed or that reset persisted after reload. The revised
error-window verifier adds the real unavailable-row checks and copyable
report needed for that evidence. No repeat injection is needed if the real
mismatch is already present.

Subsequent inject1 repair verification reported integration available, saved
enablement and setup complete, zero test rows and zero unavailable assignments,
with 19 IC-owned and 29 native assignments in each of seven contexts
(133 managed, 203 native total). The user then confirmed "all fine" after the
requested persistence check. This verifies the sampled account-wide/account-wide
repair flow, not every profile combination. Repeated group names remain
separate per-context rows in the bounded confirmation; the user found that
legible and did not require grouping them for this pass.

### Report the result, not just the button click

After each action, report the actual outcome: recovered successfully, still
failing with a specific reason, or reset and awaiting re-enable. Do not clear
the warning or present the integration as healthy merely because an action
was clicked. A failed recovery must remain visible and keep diagnostic and
recovery access available.
After successful recovery, restore the normal AutoCategory editing UI. After
a reset, show the disabled/awaiting-setup state rather than a healthy active
editor; re-enabling must still use the initial setup dialog.


Profile setup and copying follow-ups are tracked in
[the master feature document](Project/DevDocs/AutoCategoryIntegration.md#profile-ownership-and-synchronization).
