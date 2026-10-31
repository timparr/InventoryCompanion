# Prompt: continue AutoCategory integration gate testing

You are picking up the AutoCategory integration for **Inventory Companion (IC)**,
an Elder Scrolls Online addon. The design is decided; your job is to close the
remaining **stage 1 gates** with evidence, so live runtime work can start.
Do not start runtime/editor implementation (stages 2–5).

## Read first (the source of truth)

1. [AGENTS.md](../../../AGENTS.md): project rules.
2. [todo_plan_autocategoryIntegration.md](todo_plan_autocategoryIntegration.md):
   the feature spec. Especially "Saved-data compatibility" (ownership, display
   order, category names, IC icon, collisions) and "Technical decisions still
   gated".
3. [todo_implementation_autocategoryIntegration.md](todo_implementation_autocategoryIntegration.md):
   the staged plan. Stage 1 "Remaining spike tasks and exit gate" lists the
   gates; stage 2 "Ownership and projection contract" defines what the gates
   must prove.

If anything in this prompt disagrees with those docs, the docs win. Record new
findings and decisions in both docs as you go (dated), the way earlier entries
are written.

## Project rules that matter here

- **Fail fast** in IC's own code; guard only at external boundaries (ZOS APIs,
  AutoCategory, saved data).
- Stay on `main`. Ask before creating or switching branches.
- Tests must **never** mutate live inventory or saved variables. AutoCategory's
  installed source (sibling folder `..\AutoCategory`) is read-only.
- The user cannot paste chat output from the game. In-game diagnostics must
  report through ESO's copyable error window (see `/icacspike`'s
  `DIAGNOSTIC REPORT` pattern in `Core/AutoCategorySpike.lua`).
- Discuss conversationally during planning; use structured question forms only
  for quick, specific decisions mid-implementation.
- Commit each documented step with the `Co-authored-by: Copilot` trailer.

## Current state

- Gate 1 (absent definitions are harmless) **passed** offline.
- Offline suite: `python Project\Tests\Run-AutoCategorySpike.py` (17/17),
  using AutoCategory's real installed modules via
  [AutoCategorySpikeTests.lua](../../Tests/AutoCategorySpikeTests.lua).
- Rule suite: `python Project\Tests\Run-RuleTests.py` (99/99).
- DEV probe `/icacspike` and `/icacspike render` in
  [Core/AutoCategorySpike.lua](../../../Core/AutoCategorySpike.lua); the DEV
  Debug Key is temporarily overridden to run the render probe (revert when the
  probe phase ends).
- IC icon designed: sources in [Project/Art/CategoryIcon/v5](../../Art/CategoryIcon/v5/).
  No `.dds` exists yet.

## Your tasks, in order

1. **Gate 2, offline** (extend `AutoCategorySpikeTests.lua`, real modules):
   - Fractional and above-1000 run/show priorities sort and classify as
     computed, and survive AutoCategory's saved data and settings window.
   - `string.format("%04d", fraction)`: AutoCategory's sort key. ESO's Lua
     may truncate; standard Lua 5.3+ errors. The offline runner is Lua 5.1-like,
     so this likely needs an in-game check too; say which you proved where. If
     it errors in game, the spec's fallback is whole numbers with renumbering.
   - `icOwned = true` survives cache rebuild, "Export to all bags"
     (`SF.deepCopy`) and the settings window paths.
   - A same-name collision is skipped before registration, and AutoCategory
     renames nothing (`addTableRules` → `GetUsableRuleName` → `renameBagRule`).
   - An inline texture (`|t18:18:<path>|t Name`) in a category name is safe for
     lookup, compile, sort tie-break, collapse state, settings dropdown and
     keyboard header. If not, record the `· Inventory Companion` fallback.
2. **Icon textures:** convert the v5 SVGs to 64×64 DXT5 `.dds` with alpha,
   white artwork, and verify the alpha. No converter is set up; propose one
   (ask before installing tools). Keep the source SVGs. Decide the final
   in-addon path with the user: it becomes part of category names and must
   never change after release.
3. **Gates 3–5, in game** (design DEV-only probes first, agree them with the
   user, keep them reversible):
   - Plugin registration plus projected entries survive `/reloadui` and
     classify in Backpack and Bank, including subscriber bank. This needs
     entries deliberately left in AutoCategory's saved data; get explicit user
     agreement and provide cleanup.
   - Each of the seven contexts (Backpack, Bank, Guild Bank, House Bank,
     Crafting Station, Craft Bag, Furniture Vault) classifies through its list.
   - Trace AutoCategory's account/character profile switch path and prove
     reprojection into the newly active profile without touching the other.
   - Visual trial of the inline icon in headings (built-in ESO texture until
     ours exists; new textures need a full game restart).
4. Update both docs with results, then report which gates passed, which failed,
   and anything the user must decide.

## Open decisions to raise with the user (do not decide alone)

- Badge colouring for include/exclude marks: A (coloured bag, white badge),
  B (gold bag, coloured badge) or C (coloured bag, gold badge). See the spec.
- Where include/exclude marks appear in IC's own UI.
- Exact gold tint (placeholder `#FFD700`) and whether colours become a setting.
- Final texture path and the DEV/release path difference.
