# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-26T02:44:58Z
Reviewer: Copilot SDK assistant (model identifier not exposed in this session)
Checked by: Tim-P
Release version: 1.00
Review status: APPROVED

## Review confirmations

- [x] ESOUI release guidance, upload rules, and linked prohibited-functionality guidance
- [x] House-chest transfers follow a player-opened interaction and supported protected APIs; record relevant precedent or unresolved concerns
- [x] Addon globals, saved-variable names and scope, UI names, and event filters
- [x] Current API versions and every non-optional dependency minimum version
- [x] Upload description, AI disclosure, credits, licensing, and install information
- [x] Release tests and exact ZIP contents

## Notes and references

- Reviewed the current ESOUI upload guidance, upload rules, prohibited-functionality guidance, and addon coding best practices:
  - https://www.esoui.com/forums/showthread.php?t=10790
  - https://www.esoui.com/forums/showthread.php?t=11
  - https://www.esoui.com/forums/showthread.php?t=9865
  - https://www.esoui.com/forums/showthread.php?t=9867
- The manifest declares `LibAddonMenu-2.0>=43`; the ESOUI library listing identifies r43 as the current listed release. The readme puts the AI disclosure first and the non-optional dependency immediately after it.
  - https://www.esoui.com/downloads/info7-175615.html
- Tim-P confirmed `/script d(GetAPIVersion())` returns `101051` on Live; no PTS client is available. The manifest now lists only the confirmed current Live API version, `101051`; the official ESOUI source repository README also identifies API 101051 as current. Recheck and add the PTS API version if a distinct PTS version becomes available.
- Source review: all addon-owned code is rooted under `InventoryCompanion`; saved variables use the addon's prefixed name and `ZO_SavedVars` account-wide/character-ID scopes. Scene, binding, dialog, and event identifiers use the addon prefix. Inventory slot-update listeners are filtered to relevant bags and enabled conditionally.
- Source review: bank transfers are guarded by `IsBankOpen()` and call ESO's `CallSecureProtected("RequestMoveItem", ...)`. House-chest merging is triggered by the bank-open event after the player opens the chest; no code starts bank/chest interactions or automates movement or combat. No unresolved transfer-policy concern was identified in the reviewed code.
- In-game test results provided by Tim-P: 57/57 passed. The run reported 20 x 100-item scans / 20 rules in 50/2000 ms, 100 slot-rule matches in 1/1000 ms, 100 tracked-item slot updates in 1/2000 ms, and 100 live read-only backpack/bank/craft-bag scans (bank closed) in 327/1000 ms, with 998 occupied entries on the final scan. The output reports PASS for the live read-only scan and all listed test cases.
- Tim-P confirmed the distribution-rights, credit/attribution, description, and installation claims for upload. The readme begins with an AI disclosure, lists the required dependency immediately after it, and explains that users should extract the add-on folder into `live\AddOns`.
- The package script validates the archive entry set against the manifest-listed runtime files, manifest, and review sidecar, and rejects unexpected or missing entries. It excludes generated API files, SavedVariables, development docs, and unrelated repository files.
- The manifest-format, event-filter, saved-variable, and add-on-removal Wiki references were attempted in the browser but returned 403/Cloudflare. The API version was confirmed in-game and against the official ESOUI source repository README; source review confirmed the saved-variable and event-filter use. No unresolved release-policy concern was identified.
