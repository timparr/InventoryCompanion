# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-27T21:07:19Z
Reviewer: AI assistant using Copilot SDK in VS Code (GPT-6.1-sol)
Checked by: Tim-P (supplied in-game diagnostic report and confirmed short transfer check)
Add-on: InventoryCompanion
Release version: 1.2.0
Candidate SHA256: CC87B4FDA534EFC1D68FE6F01DAA1AD37BE2568FB070965641BCC80A891D1BF2
Candidate identity method: SHA-256 of sorted candidate-relative path and SHA-256 pairs, joined with LF, as recorded by the packaging script
Report location: ReleaseReview.md in the development checkout
Review status: PENDING

Testing scope: Live only. PTS is not tested or required for approval; PTS compatibility is not claimed.

## Release process

The packaging script staged version 1.2.0 in the sibling `InventoryCompanion` installation on 2026-10-27 at approximately 00:46 UTC. DEV advanced to 1.2.1. On receipt of the diagnostic report, the reviewer recomputed the recorded file-set identity and compared all installed candidate files against the staging records: zero differences. No runtime files were changed during this assessment.

Tim-P supplied the complete diagnostic report below. It identifies the release installation, runtime version 1.2.0, DEV=false, and no enabled development copy. These runtime observations support installation selection; the independent file comparison establishes the currently installed candidate identity.

No saved-variable backup was created at the original staging: the script incorrectly looked for `InventoryCompanion_SavedVariables.lua`, confusing the declared global table with ESO's installation-based disk filename. Tim-P questioned the repeated warning on 2026-10-27; investigation found both `live\SavedVariables\InventoryCompanion.lua` and `InventoryCompanion_DEV.lua`. The files were not actually absent. The tooling now infers and backs up both installation filenames, supports `-Action Backup` without restaging, and passed 147 packaging assertions. Verified private backups of both files were created under the ignored DEV `SavedVariables` folder at 2026-10-27T21:23:03Z; each matched its source SHA256 `E8B9D867A673B8A739FC415E2F378D041B86FD8C91C15C55C97E18C0F808FE7D`. These are last-on-disk snapshots, not proof of current in-memory settings. No live saved-variable file was modified.

The previous report covered version 1.01, not this candidate. Its approval is not carried forward. The earlier report remains in Git history and the previous release package.

## Package and installation

PASS: The installed candidate has 28 files matching the staging records. Its top-level folder and manifest are `InventoryCompanion` and `InventoryCompanion.txt`. No final 1.2.0 release archive has been produced or inspected. After approval, `Project\Publishing\PackageRelease.ps1 -Action Finalize` is responsible for archive entry and byte verification.

UNRESOLVED: Complete candidate source review, final listing/changelog/image checks, applicable author confirmations, and the remaining template requirements have not been completed in this assessment.

## Manifest and dependencies

ISSUE: The frozen manifest has no `## AddOnVersion` directive. The review baseline requires a positive integer; the supplied diagnostic reports InventoryCompanion AddOnVersion=0. Correct the development manifest and version-maintenance tooling, then stage a new identified candidate rather than modifying these frozen files.

PASS: The candidate manifest is UTF-8 without a BOM; its longest line is 106 bytes, below the baseline's 301-byte limit.

PASS: Manifest APIVersion=101051 matches the reported running Live API=101051.

PASS: The manifest requires LibAddonMenu-2.0>=43; the report records enabled AddOnVersion=43. Its outOfDate=true flag is retained below, not treated as an integer dependency-version failure or proof of incompatibility. The attempted local dependency-manifest lookup was unsuccessful; no current published-version or independent local dependency-manifest claim is made.

## Test discovery and coverage

PASS (human-supplied diagnostic evidence): 58/58 named cases passed at Unix timestamp 1793135208, corresponding to 2026-10-27T21:06:48Z. Environment: eso.live.12.1.6.3309674, API 101051, EU Megaserver, English, ESO Plus active, bank closed. The transcript below is the supplied evidence; the reviewer did not execute ESO tests.

The report covers discovery, resource and currency preferences, saved-data pruning and profile import fixtures, matching and overrides, inventory scopes, event-listener transitions and debounce, notification formatting and suppression, and the four performance workloads. Named results are retained below rather than inferred from the suite total.

## Core behavior and correctness

PASS (automated in-game cases reported by Tim-P): Matching, override resolution, display-flag preservation, profile import copying, tracked-item inventory scope, and synthetic scan cases passed. These cases do not establish real settings-editor input, rendered output, transfer execution, or disk persistence.

## Events and lifecycle

PASS (reported case): Event listener transitions and refresh debounce.

PASS (human-reported normal use): Tim-P confirmed the short transfer check with "everything checks out" on 2026-10-27 and explicitly confirmed ESO Plus enabled. This supplements the diagnostic case with real-use observations, not an instrumented event-delivery trace. Separate settings-input or initialization/reload checks are not routine requirements; request them only for a specific relevant change, source-review finding, or reported problem.

## Performance and queued operations

| Reported workload | Measured | Candidate limit | Result |
|---|---:|---:|---|
| 20 scans of 100 items against 20 rules | 67 ms | 500 ms | PASS |
| 100 slot-rule matches | 1 ms | 100 ms | PASS |
| 100 tracked-item slot updates | 3 ms | 200 ms | PASS |
| 100 read-only live backpack/bank/craft-bag scans | 319 ms | 500 ms | PASS |

The final live scan reported 1,068 occupied entries with the bank closed. Inaccessible bank storage is not claimed as exercised. No timing failures or outliers appear in this supplied run. These timings do not establish sustained-event responsiveness or real transfer-queue behavior.

## Human in-game testing

PASS (human report, 2026-10-27): In response to the short check covering transfers between bank and bag, involving the craft bag if available, and between bag and house chests, Tim-P reported "everything checks out" and "eso plus is enabled". No problems or unavailable storage were reported. No per-transfer quantities or exhaustive storage matrix were supplied or required. ESO Plus is explicitly confirmed and agrees with the diagnostic; no PTS testing was reported, so the author's requested reporting default is no PTS testing. Separate quantity-update, settings-toggle, visual, and reload/persistence checks were not requested or claimed. A second full diagnostic run with an open bank is not automatically required merely because the diagnostic report used a closed bank.

UNRESOLVED: Complete the candidate source review and identify any additional justified human checks before requesting further scenarios. No deliberate collision test, clean-data reset, destructive benchmark, or PTS run is required by this handoff.

## Review conclusion

The diagnostic run succeeded, the installed files matched the frozen 1.2.0 identity when checked, and Tim-P subsequently confirmed successful routine transfer testing with ESO Plus enabled. Approval and final packaging remain withheld for the missing manifest AddOnVersion, incomplete candidate source/template assessment, and remaining listing/author evidence, not for additional routine manual tests.

If only metadata/version fields change in a replacement candidate, retain this report with its original version/hash/date, review the exact delta, and determine affected retests plus a basic load/smoke check. Do not silently relabel this transcript as a run of the replacement candidate.

## Supplied complete diagnostic report

```text
[InventoryCompanion tests] 58/58 passed; 20 x 100-item scans / 20 rules: 67/500 ms; 100 slot-rule matches: 1/100 ms; 100 tracked-item slot updates: 3/200 ms; 100 live backpack/bank/craft-bag scans (bank closed): 319/500 ms, 1068 occupied entries
[InventoryCompanion tests] INFO Environment: timestamp=1793135208 (Unix UTC); game=eso.live.12.1.6.3309674; API=101051; server=EU Megaserver; language=en
[InventoryCompanion tests] INFO Installation: InventoryCompanion; runtime version=1.2.0; DEV=false; ESO Plus=true; bank=closed
[InventoryCompanion tests] INFO Enabled add-on: AddonSelector; AddOnVersion=302030; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: InventoryCompanion; AddOnVersion=0; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: LibScrollableMenu; AddOnVersion=20407; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: LibAddonMenu-2.0; AddOnVersion=43; state=2; outOfDate=true
[InventoryCompanion tests] INFO Conditional currency coverage: Alliance Points; ID=2; available=true
[InventoryCompanion tests] INFO Conditional currency coverage: Transmute Crystals; ID=5; available=true
[InventoryCompanion tests] INFO Transmute Crystals capped-colour assertions enabled=true
[InventoryCompanion tests] INFO Conditional currency coverage: Trade Bars; ID=9; available=true
[InventoryCompanion tests] INFO Human evidence still required: Live/PTS channel, candidate SHA256/installation verification, manifest API/minimum-version comparison, UI/event delivery, transfers, persistence and collision checks.
[InventoryCompanion tests] INFO Safety: live scans are read-only; synthetic tests temporarily replace runtime state and restore it; no inventory transfers or intentional saved-variable writes.
[InventoryCompanion tests] PASS Runtime and dependency discovery
[InventoryCompanion tests] PASS Live read-only scan: 100 scans, 1068 occupied entries on final scan, bank closed
[InventoryCompanion tests] PASS Progress bar resource model and preferences
[InventoryCompanion tests] PASS Currency notification preferences and changes
[InventoryCompanion tests] PASS Prune known saved-variable diagnostic keys only
[InventoryCompanion tests] PASS Currency panel resource preferences
[InventoryCompanion tests] PASS Live currency helper API
[InventoryCompanion tests] PASS Profile import copies tracked items and rule overrides
[InventoryCompanion tests] PASS Tracked item count respects backpack and craft-bag scope
[InventoryCompanion tests] PASS Case-insensitive substring matching
[InventoryCompanion tests] PASS Wildcard matching
[InventoryCompanion tests] PASS Literal punctuation and missing names
[InventoryCompanion tests] PASS Any-pattern matching
[InventoryCompanion tests] PASS Baseline and saved-rule override resolution
[InventoryCompanion tests] PASS Display-flag writes preserve other overrides
[InventoryCompanion tests] PASS 100-item backpack and craft-bag scan
[InventoryCompanion tests] PASS Repeated 100-item inventory scan performance
[InventoryCompanion tests] PASS 100 repeated slot-rule matches
[InventoryCompanion tests] PASS 100 synthetic tracked-item slot updates
[InventoryCompanion tests] PASS Event listener transitions and refresh debounce
[InventoryCompanion tests] PASS Currency messages: capped balance colours follow the progress bar thresholds
[InventoryCompanion tests] PASS Currency messages: Picking up 10 gold
[InventoryCompanion tests] PASS Currency messages: Picking up three 10-gold piles in quick succession merges
[InventoryCompanion tests] PASS Currency messages: Picking up three 10-gold piles with quiet periods between
[InventoryCompanion tests] PASS Currency messages: Withdrawing 10 gold (bank event first)
[InventoryCompanion tests] PASS Currency messages: Withdrawing 10 gold (bag event first)
[InventoryCompanion tests] PASS Currency messages: Depositing 10 gold
[InventoryCompanion tests] PASS Currency messages: Withdrawing a large amount
[InventoryCompanion tests] PASS Currency messages: Depositing a large amount
[InventoryCompanion tests] PASS Currency messages: Spending a large amount
[InventoryCompanion tests] PASS Currency messages: Spending a small amount
[InventoryCompanion tests] PASS Currency messages: Login balance report is silent
[InventoryCompanion tests] PASS Currency messages: Withdrawing then depositing the same amount in one window sends nothing
[InventoryCompanion tests] PASS Currency messages: Pickup and withdrawal in one window show consistent balances
[InventoryCompanion tests] PASS Currency messages: Alliance Points gained
[InventoryCompanion tests] PASS Currency messages: Alliance Points spent
[InventoryCompanion tests] PASS Currency messages: Alliance Points withdrawn from the bank
[InventoryCompanion tests] PASS Currency messages: Alliance Points deposited in the bank
[InventoryCompanion tests] PASS Currency messages: Transmute Crystals gained
[InventoryCompanion tests] PASS Currency messages: Transmute Crystals spent
[InventoryCompanion tests] PASS Currency messages: Trade Bars gained
[InventoryCompanion tests] PASS Currency messages: Trade Bars spent
[InventoryCompanion tests] PASS Capacity messages: bag space used by looting
[InventoryCompanion tests] PASS Capacity messages: bag space freed by selling
[InventoryCompanion tests] PASS Capacity messages: bag changes that cancel out
[InventoryCompanion tests] PASS Capacity messages: bag space crossing the warning and danger thresholds
[InventoryCompanion tests] PASS Capacity messages: bank to bag move
[InventoryCompanion tests] PASS Capacity messages: bag to bank move
[InventoryCompanion tests] PASS Capacity messages: moving a stack of 10 counts all items
[InventoryCompanion tests] PASS Capacity messages: stack merged into an existing stack still reports the move
[InventoryCompanion tests] PASS Capacity messages: bank change away from the bank is silent
[InventoryCompanion tests] PASS Capacity messages: opposite changes without a bank visit are bag-only
[InventoryCompanion tests] PASS Capacity messages: transfer plus a pickup
[InventoryCompanion tests] PASS Capacity messages: bag-only notification during a withdrawal
[InventoryCompanion tests] PASS Capacity messages: disabled notifications stay silent
[InventoryCompanion tests] PASS Capacity messages: load-screen reports stay silent
[InventoryCompanion tests] PASS Capacity messages: balance colours follow the progress bar thresholds
[InventoryCompanion tests] PASS Capacity notification preferences
```
