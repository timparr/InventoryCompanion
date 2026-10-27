# ESOUI Release Checklist

Use this workflow before every new upload or update. The [release review template](ReleaseReviewTemplate.md) is the authoritative, self-contained set of review checks and evidence requirements.

## Review baseline

The release-guidance research has been consolidated into the template. Release review assesses the candidate against those recorded requirements; it does not fetch policy pages, search for precedent, or repeat the research. A material question not settled by the baseline requires a documented author-supplied decision before approval. Updating the policy baseline is separate maintenance, not a per-release fetch requirement.

## Before uploading

- AI assistants may perform the source and policy review and prepare `ReleaseReview.md` in the development add-on root, beside `InventoryCompanion_DEV.txt`. Identify the assistant and model when available; do not guess a model that the session does not expose. Name the human author/checker separately. Attribute author-only claims to the template's consolidated declaration, not AI verification; ask at most one grouped confirmation for remaining facts. In-game results must still be supplied, not inferred.
- Follow the template's AI/TEST/HUMAN assignments rather than maintaining a second policy checklist here. Include the named unit-test results in their relevant sections, not only a suite total.
- Request one `/ictest verbose copy` report from the frozen installation, preferably with a bank open, plus a focused quantity-update, transfer, settings-toggle, visual, and reload/persistence smoke test. A second scan run, isolation profile, collision test, migration fixture, or broader edge-case matrix is needed only for relevant changes/findings. Reuse identified prior human evidence for unchanged behavior when justified.
- Record Live-only scope: PTS is untested, not required for approval, and no PTS compatibility claim is made. Discovery supplies running API/build and enabled dependency integer versions, not newest published versions; compare locally with manifests. For an older frozen suite, record missing diagnostics without changing its bytes solely to add them.
- Retain one complete diagnostic report and reference its cases across review sections. The copyable Lua error window is intentional even on success. Preserve timing-only FAIL results and investigate/repeat outliers; use the frozen suite's limits and document any accepted performance exception rather than imposing new DEV targets retroactively.

## Upload package and listing

- [ ] Freeze a candidate using the workflow below, then test and review that installation, not the changing DEV checkout. Complete `ReleaseReviewTemplate.md`, save it as `ReleaseReview.md` in the development root, and complete each confirmation. Identify the reviewer and human checker, the candidate version, and its SHA-256 identity. The timestamp is an audit record only; neither DEV timestamps nor DEV changes invalidate a frozen candidate.
- [ ] Finalize using `.\Project\Publishing\PackageRelease.ps1 -Action Finalize -TestResults '<actual results>'`. The ZIP has one top-level `InventoryCompanion` folder containing the manifest, `ReleaseReview.md`, and only release-manifest-listed runtime files. Runtime bytes and manifest must match the staged candidate. Extracting the ZIP into `live\AddOns` installs the add-on without moving files.
- [ ] Submit the verified ZIP through ESOUI Upload & Update with the listing, release type, changelog, and required image assessed in the review. The script does not create a screenshot or publish the release. A Git push alone is not evidence of publication. Monitor private messages after submission.

## Packaging script

The permanent Git checkout and VS Code workspace live in `live\AddOns\InventoryCompanion_DEV`. The development manifest loads a small development-only bootstrap; staging removes that entry and the `[DEV]` title marker. The remaining runtime files are copied unchanged into the sibling `InventoryCompanion` installation. The global namespace, controls, keybindings, and saved-variable name remain shared.

**Back up `live\SavedVariables\InventoryCompanion_SavedVariables.lua` before testing.** Release tests use your real settings and inventory; cancellation does not undo in-game changes. Select exactly one installation through your add-on profiles. Both builds check for an existing namespace before any other add-on files load; if detected, they print a red warning and show an error alert on player activation. This is a reminder, not a loading guard: a double-loaded session may be broken and requires correcting the profile and reloading the UI.

Exit ESO completely before staging or cancelling (both change the installed files). Finalization uses a temporary copy, leaves the installed candidate untouched, and can run while ESO is open. Run from the development root:

```powershell
.\Project\Publishing\PackageRelease.ps1 -Action Stage
```

Staging refuses to overwrite an existing `InventoryCompanion` folder. It creates only the release manifest and its runtime files and records SHA-256 hashes in ignored `.release-test\state.json`. It never disables development or changes your add-on profiles. It copies the current full `major.minor.build` version into the candidate, then increments the DEV build in both its manifest and runtime metadata. Numbers are not zero-padded: cut `1.2.3`, leaving DEV at `1.2.4`. Cancellation does not roll back that build increment.

1. Start ESO and select **InventoryCompanion**, not **InventoryCompanion [DEV]**, in your release-test profile. Keep your development profile selecting only **InventoryCompanion [DEV]**.
2. Test the candidate, including `/ictest verbose copy`, rule matching and overrides, and relevant banking/tracking UI checks. Record actual results; never infer success from staging.
3. Complete the template's policy, source, author, listing, automated, and human checks. Finish and approve `ReleaseReview.md` using the candidate's version and SHA-256 identity; delegate final ZIP byte/content verification to finalization if the archive does not yet exist. DEV work may continue independently. If the candidate itself changes, cancel and stage/test/review a new cut. Obtain its identity with:

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

Package immediately after approval. Finalization verifies candidate hashes and the review's candidate identity, validates approval and explicit test results, and packages a temporary copy with the review document added. Every archive entry is checked for its expected path and SHA-256 hash. No DEV runtime files are used as release inputs. The installed candidate remains untouched for normal gameplay. On success, the completed review is saved back to the checkout and the state file prevents accidental re-finalization. DEV advances its second number and resets its build: releasing `1.2.3` advances DEV to `1.3.0`, unless DEV has already moved to a different release series. The legacy, already-tested `1.01` candidate keeps that label; subsequent cuts include the build component.

By default, the ZIP is written to `Project\Publishing\Packages`. Use `-OutputDirectory` to choose another destination and `-Force` to replace an existing package. Successful finalization opens the output folder in Windows Explorer. Failed finalization retains the candidate for inspection/retry. Packaging never automatically approves a review.

To abandon a test, or explicitly remove the script-owned installed release before staging the next version:

```powershell
.\Project\Publishing\PackageRelease.ps1 -Action Cancel
```

Cancellation removes the managed release installation, not its ZIP or any development files. Do not manually move or replace the candidate or state file. If cleanup is interrupted, retry `-Action Cancel`. An interruption before staging records its state may require manually inspecting/removing the partial candidate; the script will not overwrite it.

Safe packaging regression tests run entirely in a temporary fixture, without changing the live installation or saved variables:

```powershell
.\Project\Publishing\Test-PackageRelease.ps1
```
