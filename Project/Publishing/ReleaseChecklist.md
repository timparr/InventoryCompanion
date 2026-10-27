# ESOUI Release Checklist

Use this workflow before every new upload or update. The [release review template](ReleaseReviewTemplate.md) is the authoritative, self-contained set of review checks and evidence requirements.

The template is reusable for any ESO add-on. This checklist supplies InventoryCompanion-specific release tooling and author evidence. The [reviewer reference](ReviewerReference.md) maps test access, coverage, version differences, and review hotspots to speed evidence discovery; verify it against the frozen candidate. Do not copy project assumptions into the generic template.

Use the author-supplied [ESOUI formatting reference](ESOUIFormatting.md) when preparing readme, manual, changelog, or listing text for ESOUI's formatted text fields. The root readme and user manual use BBCode in place despite their `.md` filenames; other Markdown documents can be converted separately as needed. Replace the manual's local schematic URLs with hosted URLs before online publication.

## Review baseline

The release-guidance research has been consolidated into the template. Release review assesses the candidate against those recorded requirements; it does not fetch policy pages, search for precedent, or repeat the research. A material question not settled by the baseline requires a documented author-supplied decision before approval. Updating the policy baseline is separate maintenance, not a per-release fetch requirement.

## Before uploading

- AI assistants may perform the source and policy review and prepare `ReleaseReview.md` in the development add-on root, beside `InventoryCompanion_DEV.txt`. Identify the assistant and model when available; do not guess a model that the session does not expose. Name the human author/checker separately. Tim-P has authorized this standing assertion: "The author asserts that, to the best of their knowledge, the submitted files contain no malicious code or stolen material, and that they own the material or have permission to submit it." Reference it in the consolidated declaration as author evidence, not independent AI verification; investigate contradictions and ask one grouped confirmation for remaining facts. In-game results must still be supplied, not inferred.
- Use the template's compact report and AI/TEST/HUMAN assignments, not a completed copy of every reference checkbox. Retain one complete diagnostic report; name relevant cases for changed or risky behavior in the test-evidence summary rather than repeating them across sections.
- Request one `/ictest verbose copy` report from the frozen installation, then keep manual testing to the short transfer check below. Do not routinely request separate quantity-update, settings-toggle, visual, or reload/persistence checks. Additional scenarios or diagnostic runs need a specific relevant change or finding; reuse identified prior human evidence for unchanged behavior when justified.
- Default to ESO Plus enabled and no PTS testing unless the tester or diagnostic evidence says otherwise. Ask the tester to mention only exceptions: ESO Plus was not enabled, or PTS was tested. Record these as reporting defaults when not explicitly confirmed, not independently verified facts. PTS is not required for approval; do not claim PTS compatibility without evidence. Discovery supplies running API/build and enabled dependency integer versions, not newest published versions; compare locally with manifests. For an older frozen suite, record missing diagnostics without changing its bytes solely to add them.
- Retain one complete diagnostic report and reference its cases across review sections. The copyable Lua error window is intentional even on success. Preserve timing-only FAIL results and investigate/repeat outliers; use the frozen suite's limits and document any accepted performance exception rather than imposing new DEV targets retroactively.

## Upload package and listing

- [ ] **Candidate approved:** review and essential test evidence apply to the frozen candidate's version/hash. Complete `ReleaseReview.md` from the generic template, identifying reviewer and human checker. Approval covers those runtime bytes, not a future archive or automatic publication.
- [ ] **Package verified:** finalize with `.\Project\Publishing\PackageRelease.ps1 -Action Finalize -TestResults '<actual results>'`. Confirm successful archive verification and retain the ZIP path and archive SHA-256 separately from the candidate file-set hash. The ZIP contains one `InventoryCompanion` folder with the reviewed manifest/runtime files, staged `readme.md` and `Changelog.md`, plus the completed report.
- [ ] **Ready to upload:** confirm package verification, no unresolved material findings, and the final listing, changelog, release version/type, and required image are ready. Assemble the single release handoff folder described below, open it in Windows Explorer, and give the user a clickable absolute folder link in the completion message, identifying the ZIP and any accepted limitations. Submit through ESOUI Upload & Update as a separate action; neither packaging nor a Git push publishes a release. Monitor private messages after submission.

### Single-folder handoff

Immediately after Finalize creates and verifies the ZIP, create `Project\Publishing\Packages\Reviewed\InventoryCompanion-v<version>` as the release's handoff folder. Copy the verified ZIP into it and verify that the copy's SHA-256 matches the finalized archive. Copy the current root readme, user manual, changelog, feature/listing text, upload screenshot, and all images referenced by the manual into the same folder, along with the completed review. These are snapshots of the publishing resources at handoff time; the ZIP retains its separately reviewed, frozen contents. Preserve relative image links. Do not move the working originals, change the verified ZIP, overwrite an earlier release folder, or refresh historical resource snapshots from later DEV files.

For the already approved v1.2.1 candidate, the author explicitly waived adding readme/changelog files inside the ZIP. Finalize its original recorded file set without restaging; include the current documents alongside the ZIP in its versioned handoff folder instead. Future staged candidates include the documents as described below.

Check that all resources and manual image links resolve before marking the handoff ready. Open the assembled versioned handoff folder in Windows Explorer, even if Finalize already opened its ZIP output folder, and provide a persistent clickable link to that versioned folder in the final response so the user can reopen it. Complete this handoff as soon as review approval and ZIP verification are complete, without waiting for another prompt. Do not claim the folder is ready until the ZIP copy has been verified and the resources have actually been gathered there.

## Preparation and review sequence

1. **Preflight and early source review, before freezing.** Check the working tree, intended changes/version, manifest/dependencies, release tooling, and obvious code or packaging blockers. The assistant prepares or updates root-level `Changelog.md` now, before Stage: use a Markdown version heading and concise user-facing bullets based on the actual delta from the last approved release; distinguish unreleased work and do not claim unverified fixes. Keep historical entries and check the readme. Both files must be nonempty; staging copies existing documents rather than inventing release notes. Run relevant safe offline checks. Do not automatically commit edits, switch branches, or overwrite an installation. This early pass reduces restaging; it does not replace review of the final candidate.
2. **Confirm recovery and stage.** Before removing an existing managed release, identify its previous verified ZIP and check it is available as a rollback package; if unavailable, stop and agree a recovery plan. Confirm removal with the user, then cancel/stage through the script, which backs up the last-on-disk saved variables during staging. ESO may remain open; do not reload the UI or change characters until file changes finish. ZIP rollback restores files, not inventory or saved-data changes. Staging records a new identity and increments DEV's build.
3. **Review the frozen candidate.** Verify its identity once and default to a delta review against the last identified approved candidate: inspect the actual diff and affected callers/data flows, carrying forward unchanged source-review evidence with its report/version/hash/date and an applicability rationale. A previous ZIP or test report alone is not an approved source baseline. Use a full source review for a first baseline, unavailable/unverifiable baseline, broad architectural changes, or a specific concern requiring it; record the reason. Use the template's compact report; the detailed criteria and reviewer hotspots are references, not per-release tasks to repeat. Resume recorded review coverage rather than restarting an interrupted pass. Development changes are independent; do not silently patch the candidate. Prepare additional human tests only for specific changes/findings.
4. **Send one testing handoff.** Include candidate version/hash and installation to enable (release only), the exact `/ictest verbose copy` command, and the short transfer check below. The reviewer supplies candidate identity and uses diagnostic metadata rather than asking the tester to reproduce them. Group any remaining author confirmations separately from gameplay testing. Request extra scenarios only for a specific relevant change or finding and explain why. Request Live testing only; record any volunteered PTS testing separately.
5. **Assess results and resolve findings.** Preserve reported failures, limitations, and performance investigations. If runtime bytes must change, fix DEV and stage a replacement candidate with a new identity. Review the delta, rerun affected tests plus a basic load/smoke check, and rerun the available automated suite when safe and inexpensive. Carry forward unaffected human evidence only with its original candidate/date and a reason it remains applicable. Broad changes or unknown impact require broader retesting, not an automatic waiver or an automatic full restart.
6. **Approve, finalize, and hand over.** Complete the three milestones above in order. The reviewer must assess the evidence: the script checks document structure, declared approval, and hashes, not the truth or adequacy of the review. Do not mistake checked boxes or nonempty test text for substantive approval.

## Short human transfer check

Use this tester-facing request after obtaining the diagnostic report:

> Please perform a few normal transfers between your bank and bag, involving the craft bag if available, and between your bag and house chests. Use items you intend to move and the game's supported transfer paths; no exhaustive storage-pair or item-type matrix is needed.
>
> Did you encounter any problems? Mention any unavailable storage you could not try. State only if ESO Plus was **not enabled**, or if you **did test on PTS**; otherwise we'll use ESO Plus enabled and no PTS testing as the reporting defaults.

Record the tester's actual response, applying only the ESO Plus/PTS reporting defaults above when omitted; do not infer transfer success or storage coverage from silence. Explicit observations and diagnostic evidence take precedence over defaults. Unavailable craft-bag or house-chest access is a disclosed limitation, not a reason to require a subscription, new storage, or another test profile. Separate settings, rendering, reload/persistence, interruption, or compatibility tests are conditional on a specific source-review finding, relevant change, or reported problem; they are not routine release prerequisites.

## Packaging script

The permanent Git checkout and VS Code workspace live in `live\AddOns\InventoryCompanion_DEV`. The development manifest loads a small development-only bootstrap; staging removes that entry and the `[DEV]` title marker. The remaining runtime files are copied unchanged into the sibling `InventoryCompanion` installation. The global namespace, controls, keybindings, and saved-variable name remain shared.

**Release staging backs up `live\SavedVariables\InventoryCompanion.lua` and `InventoryCompanion_DEV.lua` automatically when present.** ESO names these files after the installation/manifest, not the `InventoryCompanion_SavedVariables` global table declared inside them. The script infers both filenames and the profile directory from the release/development installation paths. It creates separate timestamped copies under the ignored `SavedVariables` folder in the development add-on and verifies their SHA-256 before creating the candidate installation. This is the last-on-disk snapshot, not necessarily the running game's current in-memory settings. Keep those private backups for recovery; they are not included in the release package. If neither source exists, staging warns and continues without a backup; investigate the active profile before treating that as expected. Run `.\Project\Publishing\PackageRelease.ps1 -Action Backup` to make verified backups without restaging or changing versions. If recovery is needed, exit ESO and restore the chosen backup to its corresponding original filename under `live\SavedVariables`; do not overwrite newer data without first preserving it.

Release tests use your real settings and inventory; cancellation does not undo in-game changes. Select exactly one installation through your add-on profiles. Both builds check for an existing namespace before any other add-on files load; if detected, they print a red warning and show an error alert on player activation. This is a reminder, not a loading guard: a double-loaded session may be broken and requires correcting the profile and reloading the UI.

ESO may remain open for Stage, Cancel, and Finalize. Do not reload the UI or change characters during Stage/Cancel because installed files are being changed. Wait for successful completion before selecting the intended installation and reloading; already loaded code does not change just because disk files changed. Finalization uses a temporary copy and leaves the installed candidate untouched. Run from the development root:

```powershell
.\Project\Publishing\PackageRelease.ps1 -Action Stage
```

Staging refuses to overwrite an existing `InventoryCompanion` folder. It creates the release manifest, its runtime files, and root-level `readme.md` and `Changelog.md`, and records all their SHA-256 hashes in ignored `.release-test\state.json`. Missing or whitespace-only release documents stop staging before installation changes. The documents are not manifest entries and are not executed by ESO. Once staged, their bytes are frozen with the candidate; later DEV document edits do not enter its ZIP. It never disables development or changes your add-on profiles. It validates `AddOnVersion = major * 10000 + minor * 100 + build`, copies the current full `major.minor.build` version and integer into the candidate, then increments the DEV build in both manifest fields and runtime metadata. Minor/build components are limited to 0-99 and the integer must fit a positive 32-bit value; an invalid pair or unencodable next build stops staging before installation changes. Numbers are not zero-padded: cut `1.2.3` (`10203`), leaving DEV at `1.2.4` (`10204`). Cancellation does not roll back that build increment.

1. After staging finishes, select **InventoryCompanion**, not **InventoryCompanion [DEV]**, in your release-test profile and reload the UI (or start ESO if closed). Keep your development profile selecting only **InventoryCompanion [DEV]**.
2. Run `/ictest verbose copy` after reloading. The reviewer compares the reported installation, runtime version, DEV=false, and integer AddOnVersion with the staged manifest, checks that no DEV copy is enabled, and independently verifies disk hashes. Diagnostics report identity; they do not automatically know the intended candidate version or prove disk identity. Do not accept an older still-loaded release merely because DEV=false. Follow the frozen review and short transfer check above; record actual results, never infer success from staging.
3. Finish and approve `ReleaseReview.md` using the candidate's version and SHA-256 identity; delegate final ZIP verification to finalization. DEV work may continue independently. Replacement candidates follow the impact-based retesting rules above. Obtain the identity with:

   ```powershell
   $state = Get-Content .\Project\Publishing\.release-test\state.json -Raw | ConvertFrom-Json
   $identity = (@($state.Candidate | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object) -join "`n")
   $sha = [System.Security.Cryptography.SHA256]::Create()
   try {
       [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))).Replace("-", "")
   } finally { $sha.Dispose() }
   ```
4. Finalize:

   ```powershell
   .\Project\Publishing\PackageRelease.ps1 -Action Finalize -TestResults 'Actual in-game results and manual checks'
   ```

Package after approval while the candidate remains unchanged; elapsed time alone does not invalidate it. Finalization verifies candidate hashes, the review's identity, declared approval and supplied test text, and packages a temporary copy with the review document added. Every archive entry, including the staged readme and changelog, is checked for its expected path and SHA-256 hash. No DEV runtime or document files are release inputs at finalization. Older candidates retain their recorded file set: upgrading the packaging script does not add documents to an already frozen candidate. Follow the agreed replacement-candidate process to add them; never silently patch its files or state. The installed candidate remains untouched. The completed review is saved back to the checkout and completion state prevents accidental re-finalization. DEV then advances its second number and resets its build: releasing `1.2.3` advances DEV to `1.3.0`, unless DEV has already moved to a different release series. The legacy `1.01` label is retained for that older candidate.

Finalization prints the verified ZIP path, archive SHA-256, and candidate file-set SHA-256 before post-package bookkeeping. If completion-state recording or DEV version housekeeping fails, the error explicitly identifies the already verified package and required recovery; it does not mean ZIP verification failed. Do not blindly retry Finalize or overwrite that ZIP. Repair completion state if needed, or DEV manifest/runtime versions together (normally the next minor with build zero for the released series), then confirm bookkeeping before the next stage. An accepted package remains independently verified, but disclose the housekeeping failure in the handoff.

By default, the ZIP is written to `Project\Publishing\Packages`. Use `-OutputDirectory` to choose another destination and `-Force` to replace an existing package. Successful finalization opens the output folder in Windows Explorer. Failed finalization retains the candidate for inspection/retry. Packaging never automatically approves a review.

To abandon a test, or explicitly remove the script-owned installed release before staging the next version, run Cancel without reloading or changing characters during removal. If not immediately staging a replacement, select DEV only after cancellation finishes, then reload the UI:

```powershell
.\Project\Publishing\PackageRelease.ps1 -Action Cancel
```

Cancellation removes the managed release installation, not its ZIP or any development files. Do not manually move or replace the candidate or state file. If cleanup is interrupted, retry `-Action Cancel`. An interruption before staging records its state may require manually inspecting/removing the partial candidate; the script will not overwrite it.

Safe packaging regression tests run entirely in a temporary fixture, without changing the live installation or saved variables:

```powershell
.\Project\Publishing\Test-PackageRelease.ps1
```
