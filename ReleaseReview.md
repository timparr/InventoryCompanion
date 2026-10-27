# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-27T22:04:15Z
Reviewer: AI assistant using Copilot SDK in VS Code (model identifier not exposed)
Checked by: Tim-P (supplied the v1.2.1 diagnostic, prior transfer observations, and grouped author confirmation)
Add-on: InventoryCompanion
Release version: 1.2.1
Candidate SHA256: F7F3E3B1F06177608871B3FC5A9880D66CDF96F62D4A672C132CB52050E9AC09
Candidate identity method: SHA-256 of sorted candidate-relative Windows-path and file-SHA256 pairs, joined with LF and encoded as UTF-8, as recorded by the staging script
Report location: ReleaseReview.md in the development checkout
Review status: APPROVED
Review format: compact-v1
Review mode: DELTA
Baseline review: ReleaseReview.md approved in commit 8ea56fa213b1001fc43fa1bff4052732f7b1d3b2; version 1.01, candidate SHA256 CD164BA0A316C05BDEA26F505EA245FCCCA8F9AEE77959AD8FBC79A2116D2AB8, reviewed 2026-10-26T15:24:42Z. Its identity reproduces from both `Project/Publishing/Packages/Reviewed/InventoryCompanion-v1.01.zip` (archive SHA256 186D82B785E5C18D9E1DB162DFAC206C12CE98E4FF8CD63175F4BD47562F9721) and `InventoryCompanion-v1.01-rc1.zip` (archive SHA256 79D5FF4F4C333AF090EC774A0923FEEE369F9281234E63D89D4ADB68F1142E08).

Testing scope: Live only. PTS is untested and not required for approval; compatibility is not claimed.

## Review scope

- [x] Candidate identity and staging records match; approved baseline identity is verified against the archived v1.01 release. Runtime report metadata matches the staged 1.2.1 manifest.

PASS: The frozen release installation is `live/AddOns/InventoryCompanion`, staged as version 1.2.1 at 2026-10-27T21:21:39Z. Its 28 files exactly match the staging records; their reproducible file-set identity is the SHA-256 above. Tim-P's 2026-10-27T22:04:07Z diagnostic reports runtime version 1.2.1, DEV=false, AddOnVersion=10201; disk identity was independently recomputed and matches the frozen candidate. No DEV copy is listed as enabled.

PASS: The approved v1.01 source baseline was verified against archived candidate bytes before reuse. No source-review evidence is carried forward from an unapproved report.

## Changes reviewed

- [x] Compared all candidate files with the verified baseline, inspected all four changed files and affected behavior, and recorded applicability limits for unchanged baseline evidence.

PASS: Compared every frozen candidate file with the verified v1.01 archive. Twenty-four files are byte-identical. The four changed candidate-relative files were inspected:

- `InventoryCompanion.txt`: release version is now 1.2.1 and positive `AddOnVersion` is 10201.
- `Core/Init.lua`: runtime version metadata is 1.2.1; the only other difference is removal of a commented-out demo call.
- `Core/LoadCheck.lua`: duplicate-load detection now displays a warning dialog on player activation in addition to the chat warning. It warns but does not prevent loading; no gameplay action or transfer is initiated.
- `Core/Tests.lua`: adds runtime/dependency/currency discovery and report output, checks event-registration/filter success and repeated/shared-listener transitions, and tightens the existing timing limits. These are diagnostic/test changes, not additional inventory actions.

No material defect was found in the reviewed delta. The approved baseline's source assessment remains applicable to the other 24 unchanged files and their call paths. In particular, transfer implementation and protected-call paths are unchanged. The deliberate dual-load warning path was inspected statically; no deliberate double-load test was run.

## Release checks

- [x] Candidate identity, contents, manifest/dependency, listing/assets, author evidence, and final-archive requirements were assessed; unresolved listing and uploader confirmations are recorded below.

PASS: Candidate root and manifest names match. All 28 runtime files are present once at their manifest paths; no executables, nested archives, SavedVariables, generated API definitions, or development-only files are in the candidate. The final archive has not been produced or inspected; `PackageRelease.ps1 -Action Finalize` must verify it after candidate approval.

PASS: Candidate manifest is UTF-8 without a BOM; longest line is 106 bytes. `APIVersion` is 101051; `AddOnVersion` is the positive integer 10201, consistent with version 1.2.1. Required dependency is `LibAddonMenu-2.0>=43`. The 2026-10-27 diagnostic reports enabled LibAddonMenu-2.0 AddOnVersion 43; its outOfDate flag is retained and is not treated as an integer minimum-version failure or incompatibility evidence. A local dependency manifest was not found, so no newest-published-version claim is made. PTS is not claimed.

PASS: `Test-PackageRelease.ps1` passed 185 isolated packaging assertions after adding staged-document coverage, including root-level document copies, their frozen hashes, missing/empty inputs, tamper rejection, and archive byte verification. No live installation or saved variables were modified. The existing 28-file candidate remains unchanged and does not gain documents from this tooling update.

PASS (HUMAN): On 2026-10-27, Tim-P confirmed the grouped remaining author statements: conformity with ESOUI terms; no paid/trial/time limits, ads, promotions, or nag screens; non-harmful/non-offensive submitted materials with appropriate rights and credits; accurate listing claims; monitoring ESOUI private messages; and patch/companion intent. This records author assertions, not independent AI verification. The standing ownership/no-malicious-material assertion and v1.01 rights/credit confirmations are also retained.

PASS (source materials found): The workspace contains [Features.md](./Features.md) and [UserManual.md](./UserManual.md) as product-description and installation references, plus [COMPLETED.md](./Project/DevDocs/COMPLETED.md), an internal record explicitly intended as source material for user-facing release notes. The AI disclosure and dependency line are present in `readme.md`; that file is not a candidate runtime file.

PASS (HUMAN): Tim-P subsequently confirmed that the existing documentation is suitable for their use in preparing the upload. No separate listing rewrite is required by this review. A root-level `Changelog.md` has now been drafted from the verified v1.01-to-v1.2.1 delta.

PASS (author-approved packaging exception, 2026-10-27): Tim-P explicitly chose not to add the readme/changelog inside this release's ZIP. Finalize the original approved 28-file candidate without restaging, and provide current publishing documents alongside the ZIP in its versioned handoff folder. Future staging includes both documents. No candidate files or staging records were changed for this exception.

PASS (asset located): `InventoryCompanion CurrencyConfig.png` is beside the root user documentation in the development checkout. It is a 642 x 531 PNG showing the currency settings UI, with SHA256 `99C8C8AAF6AC054878AEECC7F4B64FE2DD37E2A3A4E353D4AAC2A95E03E69D5D`. It is not part of the frozen runtime candidate. The existing local shortcut under `Project/Publishing/Packages/Reviewed` now resolves to this moved file. The visible capture is cropped at the top and bottom; confirm it meets the upload form's image requirement and intended presentation before upload.

## Test evidence

- [x] Reviewed the complete v1.2.1 diagnostic supplied by Tim-P, with runtime metadata consistent with the identified frozen installation, and prior short transfer evidence with provenance.

PASS (human-supplied diagnostic evidence): Tim-P supplied the complete `/ictest verbose copy` report below for InventoryCompanion 1.2.1. It reports 58/58 named cases passed on Live at 2026-10-27T22:04:07Z, game `eso.live.12.1.6.3309674`, API 101051, EU Megaserver, English, ESO Plus active, bank closed. The enabled add-on list reports InventoryCompanion AddOnVersion=10201 and LibAddonMenu-2.0 AddOnVersion=43. Runtime metadata is consistent with the candidate; candidate disk identity is independently verified above.

PASS: All four reported workloads are within the candidate limits: 20 x 100-item scans against 20 rules, 65/500 ms; 100 slot-rule matches, 0/100 ms; 100 synthetic tracked-item slot updates, 1/200 ms; 100 live read-only backpack/bank/craft-bag scans, 324/500 ms. The final scan reported 1,072 occupied entries with the bank closed. Inaccessible bank storage is not claimed as exercised. Conditional currency coverage for Alliance Points, Transmute Crystals (including capped-colour assertions), and Trade Bars was available and included.

PASS (human evidence applicable to unchanged transfer paths): On 2026-10-27, Tim-P reported “everything checks out” for the short bank/bag/craft-bag/house-chest transfer check and explicitly confirmed ESO Plus enabled. This observation was reported on v1.2.0, not relabeled as a v1.2.1 run. It remains applicable to the transfer implementation because the reviewed transfer code is byte-identical to the approved v1.01 baseline. No PTS testing was reported; use no PTS testing as the reporting default. No extra transfer matrix is indicated by the reviewed delta.

PASS (carried-forward, with limits): The approved v1.01 report records 57/57 in-game cases and successful normal use. Its pasted per-case output was truncated and its timings used older limits; this is historical evidence only. The previous v1.2.0 diagnostic is superseded by the candidate-specific v1.2.1 run and is not used as evidence for this candidate.

## Findings and decision

- [x] No material source defect was identified in the delta. The original identified candidate is approved, with the author's explicit exception to supply publishing documents outside this ZIP. Final ZIP verification and upload readiness are separate milestones.

PASS: The identified 1.2.1 candidate is approved. The approved v1.01 baseline is verified, all delta paths were reviewed, required author declarations are recorded, and the candidate-specific Live diagnostic passed. No material source finding remains.

PASS (handoff authorization): Tim-P requested final packaging of this unchanged candidate and a versioned folder containing the ZIP and current publishing resources. Verify the archive through Finalize and verify its handoff copy before declaring completion. Tim-P accepts the existing documentation and image for upload preparation; the actual upload form remains a separate author action. The BBCode manual's local schematic URLs need hosted URLs for online publication. No extra manual UI, persistence, or deliberate collision scenario is required absent a specific finding.

## Supplied complete v1.2.1 diagnostic report

```text
[InventoryCompanion tests] 58/58 passed; 20 x 100-item scans / 20 rules: 65/500 ms; 100 slot-rule matches: 0/100 ms; 100 tracked-item slot updates: 1/200 ms; 100 live backpack/bank/craft-bag scans (bank closed): 324/500 ms, 1072 occupied entries
[InventoryCompanion tests] INFO Environment: timestamp=1793138647 (Unix UTC); game=eso.live.12.1.6.3309674; API=101051; server=EU Megaserver; language=en
[InventoryCompanion tests] INFO Installation: InventoryCompanion; runtime version=1.2.1; DEV=false; ESO Plus=true; bank=closed
[InventoryCompanion tests] INFO Enabled add-on: AddonSelector; AddOnVersion=302030; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: InventoryCompanion; AddOnVersion=10201; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: LibScrollableMenu; AddOnVersion=20407; state=2; outOfDate=false
[InventoryCompanion tests] INFO Enabled add-on: VotansKeybinder; AddOnVersion=0; state=2; outOfDate=true
[InventoryCompanion tests] INFO Enabled add-on: LibAddonMenu-2.0; AddOnVersion=43; state=2; outOfDate=true
[InventoryCompanion tests] INFO Conditional currency coverage: Alliance Points; ID=2; available=true
[InventoryCompanion tests] INFO Conditional currency coverage: Transmute Crystals; ID=5; available=true
[InventoryCompanion tests] INFO Transmute Crystals capped-colour assertions enabled=true
[InventoryCompanion tests] INFO Conditional currency coverage: Trade Bars; ID=9; available=true
[InventoryCompanion tests] INFO Human evidence still required: Live/PTS channel, candidate SHA256/installation verification, manifest API/minimum-version comparison, UI/event delivery, transfers, persistence and collision checks.
[InventoryCompanion tests] INFO Safety: live scans are read-only; synthetic tests temporarily replace runtime state and restore it; no inventory transfers or intentional saved-variable writes.
[InventoryCompanion tests] PASS Runtime and dependency discovery
[InventoryCompanion tests] PASS Live read-only scan: 100 scans, 1072 occupied entries on final scan, bank closed
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

## Staged release test confirmation

Staged (UTC): 10/27/2026 21:21:39
Confirmed (UTC): 2026-10-27T22:27:04.8514657Z

Tim-P supplied candidate-specific Live diagnostic at 2026-10-27T22:04:07Z: 58/58 passed; synthetic scans 65/500 ms, slot-rule matches 0/100 ms, tracked-item updates 1/200 ms, live scans 324/500 ms with 1072 entries and bank closed. Runtime 1.2.1, DEV=false, AddOnVersion=10201; disk candidate identity verified. Prior normal transfer evidence carried forward for unchanged paths with provenance in the review. Author confirmations recorded. Author explicitly waived readme/changelog inclusion inside this ZIP; current publishing resources supplied alongside it.

