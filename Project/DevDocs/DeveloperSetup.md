# Developer Setup

## Development and release installations

Keep the Git checkout and VS Code workspace in `live\AddOns\InventoryCompanion_DEV`, with the matching `InventoryCompanion_DEV.txt` manifest. ESO lists this installation as **InventoryCompanion [DEV]** and prints a DEV reminder when it initializes. `InventoryCompanion.IsDevelopment` is true in this installation; the global namespace and saved-variable name are unchanged.

Versions use `major.minor.build` strings in the manifest and runtime metadata. The manifest also declares integer `AddOnVersion = major * 10000 + minor * 100 + build` (for example, `1.2.1` becomes `10201`). Minor/build components must be 0-99 and the result a positive 32-bit integer. The packaging script validates the pair before staging and updates both manifest fields with the runtime version when advancing DEV. It rejects a stage whose next build would exceed 99; advance to a new minor series before staging in that case. Staging copies the full current version, then increments DEV's build. Successful release finalization advances DEV's minor number and resets its build to zero. Frozen candidates are tested, reviewed, and packaged independently of subsequent DEV edits; candidate hashes, not DEV timestamps, bind approval to the published bytes.

The sibling `InventoryCompanion` folder holds the staged candidate and, after finalization, the tested release for normal gameplay. Follow the [staging, testing, finalization, and cancellation workflow](../Publishing/ReleaseChecklist.md#packaging-script). Your add-on profiles select release or development; the script never disables either. Both installations warn in chat if the namespace already exists when they start loading, then show a persistent, closeable conflict dialog on player activation. This warns about double-loading but does not prevent conflicts; correct the profile and reload the UI. Both installations use the same saved variables; back them up before testing.

For the initial folder rename, exit ESO, close the VS Code window (including its integrated terminals), rename the existing checkout to `InventoryCompanion_DEV` in Explorer, then reopen that folder in VS Code. The `.git` directory and uncommitted changes move with the checkout; no branch change or new clone is needed. If Windows still reports a lock, close other terminals or Explorer windows using the old folder and retry. Do not copy over or delete the checkout to work around a lock.

## ESO API in VS Code

The workspace configures Lua Language Server for Lua 5.1 and loads local ESO API definitions from the ignored `generated-eso-api/luals` directory. These generated files are editor-only and must not be added to either add-on manifest.

The API definitions are generated with the community [ESO-LuaLS-Generator](https://github.com/Hydra9268/ESO-LuaLS-Generator) from [UESP ESO API exports](https://esoapi.uesp.net/current/index.html). For a new development machine:

1. Install the VS Code **Lua** extension (Lua Language Server) and Python 3.12.
2. Clone the generator to `%USERPROFILE%\Documents\ESO-LuaLS-Generator`:

   ```powershell
   git clone https://github.com/Hydra9268/ESO-LuaLS-Generator.git "$env:USERPROFILE\Documents\ESO-LuaLS-Generator"
   ```

3. From the addon root, generate and install the local definitions:

   ```powershell
   .\Project\DevDocs\UpdateESOApiLibrary.ps1
   ```

Reload the VS Code window after initial generation or after updating the API.

To refresh the generator and its bundled UESP exports later:

```powershell
git -C "$env:USERPROFILE\Documents\ESO-LuaLS-Generator" pull --ff-only
.\Project\DevDocs\UpdateESOApiLibrary.ps1
```

## In-Game Diagnostics

ESO may remain open during release staging/cancellation; do not reload the UI or change characters until those file operations finish. Then select release-only and reload before testing. Compare `/ictest verbose copy` installation/runtime version, DEV flag, integer AddOnVersion, and enabled installations with the intended staged candidate; an older loaded release is not acceptable merely because DEV=false. Verify candidate disk hashes separately. Automatic saved-variable backups preserve only the last-on-disk snapshot; exit ESO before restoring one.

- The Debug Key runs the same diagnostic suite as `/ictest verbose copy`.
- `/ictest [verbose] [copy]` runs diagnostic tests and live inventory scans. It does not intentionally modify saved variables.
- Every run reports the UTC Unix timestamp, game build/running API, server/language, DEV/release identity, ESO Plus/bank state, enabled add-ons with integer `AddOnVersion` values, and conditional currency coverage. These are local runtime observations, not proof of the newest published API/dependency version or the candidate hash.
- For a release review, supply one complete `/ictest verbose copy` report from the frozen candidate. Repeat with the other bank state only for specific relevant changes/findings. Request Live testing; PTS is optional and compatibility is not claimed without evidence. `copy` intentionally opens a Lua error window even on success. The listener case checks registration/filter success, feature transitions, shared consumers, duplicate prevention, and debounce behavior. Routine manual testing is limited to a few normal transfers between bank and bag, involving the craft bag if available, and between bag and house chests; ask whether any problems occurred. Ask for environment exceptions only: ESO Plus was not enabled, or PTS was tested. If omitted, record ESO Plus enabled and no PTS testing as reporting defaults; explicit observations and diagnostics take precedence. Note unavailable storage rather than requiring access. Separate settings, visual, and reload/persistence checks require a specific relevant change, finding, or reported problem. See the [short transfer check](../Publishing/ReleaseChecklist.md#short-human-transfer-check).
- Current DEV performance limits are 500 ms for 20 synthetic 100-item scans across 20 rules, 500 ms for 100 live scans, 100 ms for 100 slot-rule matches, and 200 ms for 100 tracked-item slot updates. Review older frozen releases against their embedded limits. Preserve timing-only FAIL results; repeat/investigate outliers and document gameplay impact and any accepted exception rather than treating every threshold breach as an automatic release blocker. Functional failures remain blockers.
- `/icclean` explicitly prunes known diagnostic saved-variable leftovers and updates the currency-name diagnostic history.
- `/icbankitems [1-20]` lists sample standard-bank and ESO Plus subscriber-bank contents while a bank or house chest is open. It is read-only.
