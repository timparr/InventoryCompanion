# ESOUI Release Checklist

Use this checklist before every new upload or update. ESOUI's guidance can change. Check for meaningful changes at release time; use the summary below rather than repeatedly loading unchanged full pages into an AI conversation.

## Policy summary and change-check approach

Summary last checked: 2026-10-26. This is a working summary, not a substitute for changed rules or the uploader's certification.

- **Release best practices** (forum thread 10790): disclose AI involvement at the beginning of the description when required; credit borrowed work; describe required dependencies prominently and require their current integer `AddOnVersion` minimums; keep the manifest/API versions current; prefix addon-owned globals, controls, and saved variables; use appropriate event filters and saved-variable scopes.
- **Upload rules** (forum thread 11): provide a ZIP and any requested screenshot, accurate description, and installation help if needed. No nested archives, `wowmatrix.dat`, or unapproved executables. The uploader certifies distribution rights, lawful/ToS-compatible and family-friendly content, no malware, no fees, ads, promotions, nag screens, or trial limits.
- **Prohibited functionality** (forum thread 9865): do not automate combat/movement, start player interactions automatically, bypass game restrictions, send public chat automatically, use unsupported external-file/network access, or misuse group-data channels. Banking must follow a player-opened interaction and supported APIs.
- **Add-on-removal Wiki**: not summarized as verified. Both HTTP retrieval and the integrated browser were blocked by Cloudflare/403 on the last check. Record this limitation; do not treat a failed fetch or challenge page as unchanged policy.

For future automation, retain a local snapshot of the relevant post/article text, excluding navigation, session IDs, avatars, signatures, view counts, and other page chrome. Fetch and normalize the current policy text, then compare locally before sending it to an AI. Identical text needs no model review; meaningful changes need only the changed sections plus enough context. A single agent may review those differences when useful, rather than rereading every full page. Update the summary and baseline only after reviewing changes. A missing baseline requires a full initial review; failed or blocked retrieval requires an explicit unresolved-status report. A matching page hash says only that the captured text is unchanged, not that the add-on complies.

This describes the intended comparison approach; an automated fetch/snapshot/diff checker has not yet been implemented. The current checklist itself remains the reusable summary.

## Official guidance

- [Before you release or update an addon: rules and best practice](https://www.esoui.com/forums/showthread.php?t=10790)
- [ESOUI upload rules](https://www.esoui.com/forums/showthread.php?t=11)
- [What addons must not do](https://www.esoui.com/forums/showthread.php?t=9865)
- [Add-on coding best practices](https://www.esoui.com/forums/showthread.php?t=9867)
- [Dependency version checks](https://www.esoui.com/forums/showthread.php?t=11595)
- [ESOUI add-on manifest format](https://wiki.esoui.com/Addon_manifest_%28.txt%29_format)
- [Event filters](https://wiki.esoui.com/AddFilterForEvent)
- [Saved variables](https://wiki.esoui.com/Storing_data_and_accessing_files)
- [API versions](https://wiki.esoui.com/APIVersion)
- [Add-ons that can get removed](https://wiki.esoui.com/How_to_get_your_AddOn_removed)
- [ESOUI Developer FAQ: Git and SVN publishing](https://www.esoui.com/forums/faq.php?faq=developer)

The linked forum guidance and dependency-version explanation were reviewed while preparing this checklist. Automated requests to the ESOUI Wiki's manifest, event-filter, and add-on-removal pages returned HTTP 403; open those and the other linked Wiki references in a browser and confirm the current guidance before release.

## Before uploading

- AI assistants may perform the source and policy review and prepare `ReleaseReview.md` in the development add-on root, beside `InventoryCompanion_DEV.txt`. Identify the assistant and model when available; do not guess a model that the session does not expose. Name the human author/checker separately. The human must verify author-only claims (including rights, credits, listing details, and test results); do not approve the review until those checks and in-game testing are complete.
- Ask the author to run the in-game tests against the intended release files and dependencies. Record the results in `ReleaseReview.md`; for the synthetic/read-only suite, `/ictest verbose copy` prints the summary and test cases. Never claim an in-game test was run without its result.
- [ ] Review the current prohibited-functionality rules and confirm the add-on uses only supported ESO APIs. Ask ESOUI staff for clarification before release if a feature might fall into a restricted category.
- [ ] Review inventory-transfer behavior: transfers only run after the player opens the bank/chest interaction, use ESO's protected inventory-transfer APIs, and do not start interactions or automate combat/movement. Similar established add-ons provide precedent for bank withdrawals and deposits; seek ESOUI clarification if the behavior or API path differs or remains uncertain.
- [ ] Keep add-on globals limited to the single `InventoryCompanion` root; prefix saved-variable, UI, binding, scene, and dialog names with the add-on name.
- [ ] Review inventory and other frequently firing event registrations for suitable event filters and avoid unnecessary callbacks.
- [ ] Confirm saved-variable names and scope are appropriate. Character-ID saved variables are already character-specific across servers; decide whether account-wide preferences should be shared across NA/EU.
- [ ] Update the manifest API versions to the current live/PTS versions, with no more than two entries.
- [ ] Verify every non-optional dependency is listed at the beginning of the upload description and uses a current minimum version from that dependency's manifest. InventoryCompanion currently depends on `LibAddonMenu-2.0>=43`; verify the version before release.
- [ ] Make the ESOUI description accurate and informative. The guidance requires an AI disclosure at its beginning when AI-generated code has not been personally verified for correctness, efficiency, maintainability, and safety; it says disclosure is optional when AI was used only for ideation and the author personally wrote and validated the final code. Keep project credits and attributions accurate.
- [ ] Test the release package in-game with the intended files and dependencies. Do not include SavedVariables, generated API files, editor configuration, backups, or development-only documentation.
- [ ] Next release: test the DEV/release collision warning with both installations enabled (back up shared saved variables first; do not perform inventory transfers in this invalid session). Confirm a prominent, centred dialog appears after entering the game, remains until dismissed, and closes with its Close button. Test both load orders where possible. Then disable one copy and reload: confirm normal loading without the warning. Record actual results in `ReleaseReview.md`.

## Upload package and listing

- [ ] Freeze a candidate using the workflow below, then test and review that installation, not the changing DEV checkout. Complete `ReleaseReviewTemplate.md`, save it as `ReleaseReview.md` in the development root, and complete each confirmation. Identify the reviewer and human checker, the candidate version, and its SHA-256 identity. The timestamp is an audit record only; neither DEV timestamps nor DEV changes invalidate a frozen candidate.
- [ ] Finalize using `.\Project\Publishing\PackageRelease.ps1 -Action Finalize -TestResults '<actual results>'`. The ZIP has one top-level `InventoryCompanion` folder containing the manifest, `ReleaseReview.md`, and only release-manifest-listed runtime files. Runtime bytes and manifest must match the staged candidate. Extracting the ZIP into `live\AddOns` installs the add-on without moving files.
- [ ] Choose the ESOUI publishing route: upload the ZIP through Upload & Update, or investigate ESOUI-hosted Git/SVN repositories. The Developer FAQ documents SVN's explicit release flow: select "Make Zip", enter the File Version/release type and listing text, generate and inspect the ZIP, then choose "Push Zip Live". It says an unassociated repository can prompt to select an existing listing or create one, so a separate manual first upload may not be necessary; verify the current site flow before relying on that. The FAQ describes Git repository setup and pushing, but does not establish that a Git push alone publishes an ESOUI release.
- [ ] Inspect the ZIP before upload. Do not put another ZIP/RAR inside it; do not include executables or `wowmatrix.dat`.
- [ ] Attach a JPG, PNG, or GIF image when required by the upload form. The package script does not create or include a screenshot.
- [ ] Include an installation help file in the ZIP if installation is difficult; this add-on should otherwise install by extracting the folder into `live\AddOns`.
- [ ] Ensure the add-on and its contents are lawful to distribute, free of malware, consistent with ZeniMax's ToS, family-friendly, free of charge, free of ads/promotions/nag screens, and not time-limited.
- [ ] Check ESOUI private messages after submission in case moderators request a change.

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
3. Review the frozen candidate against the policy, source, author, and listing checks above. Finish and approve `ReleaseReview.md` using the candidate's version and SHA-256 identity. DEV work may continue independently. If the candidate itself changes, cancel and stage/test/review a new cut. Obtain its identity with:

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
