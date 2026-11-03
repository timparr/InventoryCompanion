# Copilot instructions

InventoryCompanion is an Elder Scrolls Online (ESO) addon written in Lua 5.1 with XML UI. This checkout is the **DEV** installation (`InventoryCompanion_DEV.txt`); a sibling `InventoryCompanion` folder holds staged/released builds. Both share the same namespace (`InventoryCompanion`) and saved variables (`InventoryCompanion_SavedVariables`).

`AGENTS.md` holds the project rules for every task; the key points are repeated below.

## Build, test, lint

There is no build or linter; the addon runs inside the ESO client.

- **Offline tests** (Lua 5.1 via `lupa`; ESO runs 5.1, so don't use default `lupa`):
  ```powershell
  python -m pip install lupa
  python Project\Tests\Run-RuleTests.py
  python Project\Tests\Run-RuleTests.py --test-filter "<regex>"   # single/matching tests
  python Project\Tests\Run-RuleTests.py --item-editor-only
  python Project\Tests\Run-AutoCategorySpike.py                   # isolated AutoCategory spike
  ```
  `Run-RuleTests.py` first asserts XML structure (control names/anchors in `Tracking\*.xml`), compiles every `.lua` file, then loads addon files and `Project\Tests\*Tests.lua` into stubbed Lua runtimes. Offline tests must never touch live saved variables.
- **In-game tests:** `/ictest [verbose] [veryverbose] [copy]` (also the Debug Key) runs the `Core\Tests.lua` + `Core\RuleTests.lua` diagnostics and performance checks. Other debug commands: `/icclean`, `/icbankitems [1-20]`, `/icactest ...`.
- **Release:** `Project\Publishing\PackageRelease.ps1 -Action Stage|Finalize|Cancel`; follow `Project\Publishing\ReleaseChecklist.md`. `AddOnVersion = major*10000 + minor*100 + patch`; keep manifest `## Version`/`## AddOnVersion` and the runtime version in sync. Update the working changelog (`Project\Publishing\Packages\Reviewed\Current Documentation\Changelog.bbcode`) from the actual changes before recommending a version.

## Architecture

- `InventoryCompanion_DEV.txt` is the manifest and defines **load order** (no `require`): `Core\LoadCheck`/`Development` → `Core\Init`, `Utils`, `Constants`, `ContextMenus`, `Settings`, `Scanning` → `Banking\*` → `Tracking\*` (XML templates before the Lua that uses them) → `Core\Events` → `Core\RuleTests`/`Tests`. All files share one global `InventoryCompanion` table. New files must be added to the manifest in the right position.
- **Core/** – saved-variable init and schema/migration (`Init.lua`), constants, settings (LibAddonMenu-2.0, required), inventory scanning, event registration, in-game tests.
- **Banking/** – automatic bank deposit/withdraw, stack restocking, currency transfers, resource progress bars.
- **Tracking/** – tracked item/group database (`ItemDatabase.lua`), item tracker and currency panels, the multi-tab edit window (`EditPanel*Tab.lua/.xml`, coordinated by `EditPanelTabManager.lua`), and optional **AutoCategory** integration (`AutoCategoryIntegration.lua`, declared via `OptionalDependsOn`).
- For load ordering and AutoCategory integration, start with `Project\DevDocs\Tasks\AutoCategoryIntegration.md`; it links the implementation doc and archived spike/dependency contracts. Consult them before repeating research.
- `generated-eso-api\` (git-ignored) holds LuaLS ESO API stubs for the editor only (`Project\DevDocs\UpdateESOApiLibrary.ps1`); never add them to a manifest.

## Conventions

- **Fail hard, fail fast.** Don't nil-guard, early-return, or add fallbacks for addon-owned functions/state; call them directly so defects throw at the root cause. Guard only at boundaries: ZOS APIs, other addons/libraries, and **saved variables** (users edit them; validate/normalize on load, preserve unrelated data, report malformed values).
- **Saved-variable schema:** bump the schema version whenever older builds can't safely read/preserve new data (even additive fields). Validate every profile and migrate non-destructively before ZOS constructors, and test that older builds reject the newer version without modifying data — DEV and release share saved variables.
- Lua 5.1 only: `xpcall` doesn't forward extra args (wrap in a closure); no `goto`, integer division, or bitwise operators.
- Prioritize in-game tests for rule matching/overrides and safe synthetic inventory-burst performance checks that never mutate live inventory or saved variables.
- Publishing text (readme, manual, changelog, features) uses BBCode with `.bbcode` extensions (`Project\Publishing\ESOUIFormatting.md`); changelog entries use BBCode headings/lists, not Markdown.

## Workflow

- Ask questions conversationally in chat, not via forms/question dialogs.
- Check the current branch before recommending a new branch; don't switch branches without approval.
