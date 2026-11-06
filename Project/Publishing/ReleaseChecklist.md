# ESOUI Release Checklist

Use this workflow before every new upload or update. The [release review template](ReleaseReviewTemplate.md) is the authoritative, self-contained set of review checks and evidence requirements.

The template is reusable for any ESO add-on. This checklist supplies InventoryCompanion-specific release steps. The [reviewer reference](ReviewerReference.md) maps test access, coverage, version differences, and review hotspots to speed evidence discovery; verify it against the frozen candidate.

The authoritative publishing documents live in `Project\Publishing\Source Documents`: `ReadMe-Header.bbcode`, `ReadMe-Body.bbcode`, `UserManual.bbcode`, and `Changelog.bbcode`. The manual's schematic source files live in `Project\Publishing\Resources`. Use the author-supplied [ESOUI formatting reference](ESOUIFormatting.md) when editing publishing text.



## Preparation and review sequence
0. **STOP!** Outline what the steps are going to be to the user. Wait for a go!
1. **Prepare the working release folder.** Create `Project\Publishing\Packages\Reviewed\Current release` if it does not exist. If it exists, confirm the prior numbered archive is retained, then empty only this working folder. Create `ReleaseReview.md` in it from `ReleaseReviewTemplate.md`; create the combined `ReadMe.bbcode` from the authoritative header and body, and copy the authoritative `Changelog.bbcode` into the folder.
2. **Diff the baseline and agree on the change summary.**
   - **Baseline diff:** Establish the committed DEV source identity and compare the code with the last approved review.
   - **Draft the report entry:** Use the diff to draft the **Changes reviewed** section. Distinguish what changed from what was merely inspected.
   - **Propose the level of detail:** Present the changed files and methods, relevant behavior or call paths, and a proposed summary. Use a file-and-method list for specific changes, a concise feature-level summary for cohesive broad changes, or an overview with supporting details when both are useful.
   - **Stop for agreement:** Do not assess review standards or run tests yet. Present what changed and agree the entry's scope and wording with the author before continuing. Do not imply that review or tests have been completed.
3. **Review the code against the standards.** After agreeing the change summary, fill in the report header and standards grid: inspect each applicable criterion, trace changed paths and affected callers/integrations, mark whether its area changed, and record the result rationale and evidence. Unchanged areas may rely only on a cited prior PASS where code and behavior remain unchanged.
4. **Run relevant synthetic tests.** After source inspection, run the relevant safe synthetic/offline tests. Record only the pass/fail rate in the report's test-results field; do not use test results as a substitute for standards review.
5. **Complete the documentation review and report.** Review the prepared header, body, and changelog against the report's documentation checks; fill in the version recommendation, summary, and findings.
6. **Present findings and agree next steps.** Present the completed report and pause for discussion. Agree the next version number. If there are problems, change only the authorized issues and perform a focused review of those changes, with relevant synthetic tests; update and present the report again. If there are no unresolved problems, obtain the separate explicit **GO to stage**.
7. **Stage the test installation.** Run `.\Project\Publishing\PackageRelease.ps1 -Action Stage` to copy only the program files and the prepared combined `ReadMe.bbcode` into the release test installation. The script records the candidate identity and advances DEV's patch number. Before changing an existing managed installation, confirm its verified ZIP is retained and get authorization to remove it. Select only the release add-on in the test profile and reload the UI.
8. **Run user testing.** Obtain the separate explicit **GO for UAT**. Run the agreed user-driven unit and in-game checks against the staged installation. Record their actual pass/fail rate and observations; any failure or unexpected behavior returns to the findings/discussion gate.
9. **Finalize documentation and release files.**
   - **Update documents:** After user testing, update and verify the release `ReadMe.bbcode` and `Changelog.bbcode` in `Current release`. Complete the review report with user-test results and final findings.
   - **Prepare the test installation:** Copy the finalized documentation and review report into the test installation.
   - **Create the release ZIP:** Create `InventoryCompanion-v<version>.zip` from the test installation in `Current release`.
   - **Archive and verify:** Copy the ZIP and review/documentation archive into `Project\Publishing\Packages\Reviewed\InventoryCompanion-v<version>`. Verify both ZIP hashes match.
   - **Present for approval:** Present the package for approval before upload or handoff.

## How to carry out the sequence

### Prepare the report and release documents (steps 1, 5, and 9)

- At the start of each new release, ask whether the previous release was published. Use the answer when deciding which changes are still unreleased.
- Use the review template as-is for report structure and checks. Do not add report sections or duplicate its standards in this checklist.
- Build `ReadMe.bbcode` by placing `ReadMe-Header.bbcode` before `ReadMe-Body.bbcode`. Keep the dependency and any applicable AI disclosure in the header. Keep the changelog's newest release first.
- Keep working copies in `Packages\Reviewed\Current release`; preserve existing numbered archive folders.
- Use BBCode for ESOUI publishing text and follow the formatting reference.
- Review the listing header, body, and changelog for accurate current-version, dependency, feature, and change information. Do not include the old manual in the test installation or ZIP; it may remain in `Current release` as a reference.

### Compare and review the source (steps 2–3)

- Establish the committed DEV source identity and use the last approved source review as the comparison baseline. Use the reviewer reference to locate relevant tests and code paths, then verify those against the actual candidate/source.
- Step 2 is a discussion gate: present the proposed **Changes reviewed** entry and wait for agreement before starting the standards review.
- In the standards review, assess each applicable template check against the actual changed code and publishing materials. Cite prior review evidence only for areas whose code and behavior have not changed.

### Run tests and discuss findings (steps 4–6 and 8)

- Run only relevant safe synthetic/offline tests after the source review. The repository's rule suite is `python Project\Tests\Run-RuleTests.py`; focused options and additional test commands are documented in the project's development instructions.
- Before UAT, run `.\Project\Publishing\PackageRelease.ps1 -Action Backup` to make and verify a timestamped backup of the existing ESO SavedVariables files. Stage already makes a backup, but this separate backup is taken immediately before user testing. The script stores private copies under the DEV add-on's `SavedVariables` folder; do not include them in the release. These are on-disk snapshots, not unsaved in-memory settings. If no source files are found, the script warns; resolve that before proceeding with UAT.
- Run UAT only after the separate GO. The in-game diagnostic command is `/ictest [verbose] [veryverbose] [copy]`; perform the agreed feature and transfer checks against the staged installation. Use the tester prompt below for the normal transfer check; expand testing only when the source review, a reported issue, or test evidence calls for it.
- Record only the synthetic pass/fail rate where the sequence specifies it. Record actual UAT results and observations; do not infer test success or coverage.
- Retain the complete diagnostic output as test evidence and report actual results in the template's existing test-evidence area. Do not add report sections for diagnostics or tester details.
- Present findings and wait at the discussion gate. Make only changes the author authorizes, then review and test those changes before presenting the updated report.

#### UAT transfer prompt

After obtaining the diagnostic report, ask the tester:

> Please perform a few normal transfers between your bank and bag, involving the craft bag if available, and between your bag and house chests. Use items you intend to move and the game's supported transfer paths; no exhaustive storage-pair or item-type matrix is needed.
>
> Did you encounter any problems? Mention any unavailable storage you could not try. State only if ESO Plus was **not enabled**, or if you **did test on PTS**; otherwise we'll use ESO Plus enabled and no PTS testing as the reporting defaults.

Record the tester's actual response. Do not infer transfer success or storage coverage from silence. An unavailable craft bag or house chest is a disclosed limitation, not a reason to require a subscription, new storage, or another test profile. The ESO Plus and PTS defaults are reporting assumptions, not verified facts; do not claim PTS compatibility without evidence. Test settings, rendering, persistence, interruption, or compatibility when a relevant change, finding, or reported problem makes them applicable.

### Agree version and stage the candidate (steps 5–7)

- Base the version recommendation on the cumulative changes since the last author-confirmed release, including changes carried forward from cancelled or superseded candidates. As a guide, patches are for fixes/maintenance, minors for backward-compatible features, and majors for incompatible changes.
- Draft user-facing feature and changelog wording from the cumulative changes. Lead the changelog with user impact and add relevant technical detail. Agree wording and version with the author rather than choosing a version to justify prewritten notes.
- Mark numbered but unpublished changelog entries `[unreleased]`. A review, approval, or ZIP does not prove publication; do not remove the marker until publication is confirmed.
- After upload, ask whether publication is confirmed. Once confirmed, remove the marker from the working changelog; do not change frozen packages or historical archives.
- Agree the release wording and version before changing version metadata. Keep the manifest's `Version` and `AddOnVersion` consistent with the runtime version in `Core\Init.lua`.
- Stage only after the separate GO. Run the Stage command from the development checkout and follow the sequence's scope: only program files and the prepared combined README go into the test installation.
- Before testing, select the release installation rather than the DEV installation, reload the UI, and verify the candidate's version and identity. Although the add-ons have different names, both manifests declare the same `SavedVariables` global, `InventoryCompanion_SavedVariables`, and both builds initialize `ZO_SavedVars` with that name. They therefore use the same saved-variable data. Preserve the current data before UAT and do not restore an older copy over newer data.

### Complete and verify the package (step 9)

- After UAT, update the combined README and changelog, then put the finalized documents and review report into the test installation as specified in the sequence.
- Run `.\Project\Publishing\PackageRelease.ps1 -Action Finalize` after the report records actual UAT results and has no unresolved findings. It copies the finalized README, changelog, and review into the test installation, verifies the candidate files, creates the ZIP in `Current release`, and copies the ZIP plus those documents into the versioned `Reviewed` folder. It refuses to overwrite an existing archive or versioned folder.
- Verify the ZIP and copied archive hashes before presenting the package. Finalize does not upload or confirm publication; do not replace historical versioned archives.
- Once the author confirms they are satisfied with the completed documents, continue through the remaining sequence while preserving its separate GO gates and package-approval step. After package approval, perform the ESOUI upload. Upload alone does not confirm publication; ask the author whether publication is confirmed before removing the working changelog marker.
