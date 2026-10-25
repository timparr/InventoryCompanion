# ESOUI Release Checklist

Use this checklist before every new upload or update. ESOUI's guidance can change, so re-read the linked posts at release time and check any linked policy pages that apply.

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

The linked forum guidance and dependency-version explanation were reviewed while preparing this checklist. Automated requests to the ESOUI Wiki's manifest, event-filter, and add-on-removal pages returned HTTP 403; open those and the other linked Wiki references in a browser and confirm the current guidance before release.

## Before uploading

- [ ] Review the current prohibited-functionality rules and confirm the add-on uses only supported ESO APIs. Ask ESOUI staff for clarification before release if a feature might fall into a restricted category.
- [ ] Review inventory-transfer behavior: transfers only run after the player opens the bank/chest interaction, use ESO's protected inventory-transfer APIs, and do not start interactions or automate combat/movement. Similar established add-ons provide precedent for bank withdrawals and deposits; seek ESOUI clarification if the behavior or API path differs or remains uncertain.
- [ ] Keep add-on globals limited to the single `InventoryCompanion` root; prefix saved-variable, UI, binding, scene, and dialog names with the add-on name.
- [ ] Review inventory and other frequently firing event registrations for suitable event filters and avoid unnecessary callbacks.
- [ ] Confirm saved-variable names and scope are appropriate. Character-ID saved variables are already character-specific across servers; decide whether account-wide preferences should be shared across NA/EU.
- [ ] Update the manifest API versions to the current live/PTS versions, with no more than two entries.
- [ ] Verify every non-optional dependency is listed at the beginning of the upload description and uses a current minimum version from that dependency's manifest. InventoryCompanion currently depends on `LibAddonMenu-2.0>=43`; verify the version before release.
- [ ] Make the ESOUI description accurate and informative. The guidance requires an AI disclosure at its beginning when AI-generated code has not been personally verified for correctness, efficiency, maintainability, and safety; it says disclosure is optional when AI was used only for ideation and the author personally wrote and validated the final code. Keep project credits and attributions accurate.
- [ ] Test the release package in-game with the intended files and dependencies. Do not include SavedVariables, generated API files, editor configuration, backups, or development-only documentation.

## Upload package and listing

- [ ] Complete `ReleaseReviewTemplate.md` after the release inputs are final, save it as `ReleaseReview.md`, and complete each confirmation. Packaging is blocked unless the timestamp is within 24 hours and later than the newest release input.
- [ ] Create a ZIP using `.\Project\Publishing\PackageRelease.ps1`. It contains the `InventoryCompanion` folder with the manifest and only manifest-listed runtime files, plus an `InventoryCompanion-ReleaseReview.txt` evidence file at the ZIP root. The review is kept outside the installed add-on folder.
- [ ] Inspect the ZIP before upload. Do not put another ZIP/RAR inside it; do not include executables or `wowmatrix.dat`.
- [ ] Attach a JPG, PNG, or GIF image when required by the upload form. The package script does not create or include a screenshot.
- [ ] Include an installation help file in the ZIP if installation is difficult; this add-on should otherwise install by extracting the folder into `live\AddOns`.
- [ ] Ensure the add-on and its contents are lawful to distribute, free of malware, consistent with ZeniMax's ToS, family-friendly, free of charge, free of ads/promotions/nag screens, and not time-limited.
- [ ] Check ESOUI private messages after submission in case moderators request a change.

## Packaging script

Run from the add-on root:

```powershell
.\Project\Publishing\PackageRelease.ps1
```

By default, the versioned ZIP is written to `Project\Publishing\Packages`. Pass `-OutputDirectory` to choose another destination. Existing packages are not overwritten unless `-Force` is supplied. The script stages only the manifest-listed runtime files, the manifest, and a plain-text copy of the completed review record; the evidence sidecar stays outside the add-on folder, and development docs, backups, generated API files, and other repository files are excluded.
