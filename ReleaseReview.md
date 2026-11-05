# ESOUI Standards Review

Reviewed (UTC): 2026-11-05T00:39:21Z
Reviewer: AI assistant using Copilot SDK in VS Code
Checked by: PENDING
Add-on: InventoryCompanion
Release version: 1.6.2 (candidate not staged)
Candidate SHA256: NOT STAGED
Candidate identity method: Pending staging; SHA-256 of sorted candidate-relative Windows-path and file-SHA256 pairs, joined with LF and encoded as UTF-8
Report location: ReleaseReview.md in the development checkout
Review status: PENDING
Review format: compact-v1
Review mode: FULL
Baseline review: Project/Publishing/Packages/Reviewed/InventoryCompanion-v1.5.0/ReleaseReview.md; approved version 1.5.0, candidate SHA256 7475DDCCBAA254214C8B33E0E038B82BB055BA5ABBF767B32755C92F4A63FC72, reviewed 2026-10-30T20:02:03Z

Testing scope: Live by default. PTS compatibility is not claimed.

## Review scope

- [x] Record the approved baseline and compare the current release source with it.

PASS: Compared the release files in the verified `InventoryCompanion-v1.5.0.zip` with the current DEV manifest. Three runtime files were added for AutoCategory; the release source changes also include profile/settings, tracking/editor, and banking updates. FULL review is appropriate because the delta adds a broad optional integration and profile model. The prior 1.5.0 report is byte-identical to the historical copy in its versioned handoff folder.

The previously staged 1.6.1 installation was removed after Tim-P authorized replacing it. The 1.5.0 rollback ZIP remains available. No current candidate is staged.

## Changes reviewed

- [x] Review the release source delta, affected callers/data flows, saved-data boundary, and manifest/dependencies.

PASS (AI, source): Reviewed the guild-bank partial deposit/withdrawal path in `Banking/BankTransfers.lua` and its `Core/ContextMenus.lua`, setting, and initialization callers. Permission checks, source-stack revalidation, asynchronous split polling, timeout/error paths, and recovery messages are present. No confirmed source defect was identified in the static review. The implementation conservatively requires a free guild-bank slot for a partial deposit and at least two free backpack slots for a partial withdrawal; confirm these documented limits during the human check and revisit only if they prevent an intended supported case.

PASS (AI, source): Reviewed the AutoCategory adapter's plugin registration and matching bridge, profile lifecycle hooks, assignment preflight/projection/rollback, and the schema-10 migration boundary against `Project/DevDocs/FeatureSpecs/AutoCategoryIntegration.md`. The release manifest declares AutoCategory optional and contains the integration/editor files. The integration remains opt-in.

PASS (AI, offline): `python Project\Tests\Run-RuleTests.py` passed 212/212 isolated tests, including Lua 5.1 syntax and XML checks, schema-10 profile migration, and actual older-build rejection of newer saved data without mutation. `python Project\Tests\Run-AutoCategorySpike.py` passed 31/31 dependency-spike checks. Its output includes an intentionally detected failure of the historical empty-colour-prefix ordering experiment; that superseded approach is not used by the current integer-priority implementation and is explicitly asserted by the spike tests.

LIMITATION: The isolated suites do not exercise the new guild-bank partial-transfer transaction against ESO APIs. No current DEV `/ictest verbose copy` report or human in-game transfer result has been supplied. Those checks remain required before candidate staging.

PASS (AI, offline; repeated 2026-11-05): Re-ran the synthetic suites against DEV before staging: `python Project\Tests\Run-RuleTests.py` passed 212/212, and `python Project\Tests\Run-AutoCategorySpike.py` passed 31/31. The spike output includes its asserted historical empty-colour-prefix ordering limitation; current code uses integer-priority ordering. Per the author's test sequence, repeat synthetic checks after staging and perform the in-game diagnostic and transfer checks on the staged candidate.

## Approved document changes

- [x] Update the authoritative changelog and related feature documentation.

PASS: Consolidated the cumulative unreleased entries under `1.6.2 [unreleased]`. Updated the publishing feature overview, DEV feature overview, and user manual to describe AutoCategory, profile behavior, and both guild-bank partial-transfer directions, including permission, slot, and withdrawal-setting requirements. Removed the duplicated withdrawal copy.

- Approved version: 1.6.2, a feature release in the 1.6 line, based on the cumulative AutoCategory, profile, editor, rule, and banking additions since the approved 1.5.0 release. The canceled 1.6.1 candidate was not reused.
- Discussion status: APPROVED

### Agreement

- Feature documentation: COMPLETE
- Changelog: COMPLETE
- Agreed version: 1.6.2
- Agreement date: 2026-11-05

## Release checks

- [ ] Check the frozen candidate identity and package contents, dependencies, publishing resources, and applicable author confirmations.

PENDING: No candidate has been staged. The updated documents and listing assets still require a final package consistency check.

## Test evidence

- [ ] Record the full relevant DEV test evidence and the brief human in-game checks.

PASS (AI, offline): The isolated test results above apply to the runtime source at DEV commit `7fa8c17caabdd934d5e5569c6014cc796aa87ae3` (version 1.6.2). Only documentation and this review report have changed since those tests. They do not establish guild-bank transfer success or AutoCategory behavior in a running ESO client.

PENDING (TEST/HUMAN): After staging, verify candidate identity and run the current `/ictest verbose copy` report plus the in-game transfer check on the staged candidate, including partial guild-bank deposits and withdrawals. Repeat the synthetic suites against the staged candidate files. Do not approve until these results and the brief candidate load/function smoke check are recorded.

## Findings and decision

- [ ] Summarize findings, limitations, and the candidate decision.

PENDING: No source defect was confirmed in the reviewed delta, and the approved 1.6.2 documentation updates and pre-stage synthetic checks are complete. Candidate verification is still outstanding, particularly because the new guild-bank operations have no direct isolated transaction tests. Do not approve until the staged-candidate checks are complete.
