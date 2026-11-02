# AutoCategory integration: spike results

Updated 2026-10-31, incorporating ESO evidence through 23:08 UTC and subsequent
offline follow-up.
**Integration is implemented but not compatibility-certified.** This file
retains dated spike evidence; see the
[implementation report](AutoCategoryImplementationReport.md) for current code
and test status.

This is the authoritative evidence record and reusable dependency-learnings
document. Read the [spec](todo_plan_autocategoryIntegration.md) for requirements
and the [implementation plan](todo_implementation_autocategoryIntegration.md)
for work sequencing. Failed attempts below are historical, not current guidance.
Keep dated command/result evidence here; update the other documents' blockers
and decisions when evidence changes them, rather than duplicating the log.

## Current gate status

PASS means only the explicitly measured case. Offline fixtures, native list
inspection, and user visual confirmation are different kinds of evidence.

| Gate | Current result | Evidence and limits |
| --- | --- | --- |
| Native insertion / first-match precedence | PASS: offline and keyboard Backpack in ESO | Mixed managed/external order, cache rebuild, no-match fallthrough; not a complete public CRUD contract. |
| Inline texture and category identity | PASS: offline and keyboard Backpack in ESO | Decorated lookup/classification/native heading and item; 7 skulls moved into the rendered section, 11 unrelated items retained categories. No items were transferred. Heading collapse clicks were not tested. |
| Many groups above existing categories | PASS sampled empty-colour-prefix candidate in ESO 22:47 | Five run priorities 1005..1001, all show 1000, ordered Zulu through Victor above Maps & Surveys. Appearance, rank replacement and account reload also passed. D4 naming approval is complete; general bounds remain open. |
| Fractional priorities / between-category headings | PASS sampled prefixed crowded order in ESO 22:47 | Unprefixed identical `0914` keys failed at 22:40; rank prefixes restored desired five-heading order with the same crowded fractions. D4 naming approval is complete; general external-order constraints remain open. |
| Pre-registration name collision refusal | PASS: offline and ESO 21:22 | Maps & Surveys detected without registration; definition/identity and both profiles' assignments unchanged. Destructive rename path intentionally not invoked. |
| Plugin startup and persisted assignments | PASS: sampled Backpack in both profiles | Corrected load timing; explicit reload/check 21:21 account and 22:00 character: one assignment plus predefined definition/cache and correct classification. Not reload coverage for every context or original priority retention. |
| All seven contexts | PARTIAL | Six contexts sampled successfully, Bank including subscriber source. Guild Bank explicitly deferred, not passed. See context table. |
| Profile switching / active-only manual projection | PASS manually in both directions | Core switches preserve both assignment lists; projection changes active only. Automatic IC lifecycle hooks are implemented and covered offline; in-game acceptance remains open under Q3. |
| Prefix rank replacement / persistence | PASS sampled ESO 23:01-23:04 | Five-name reversal/full rebuild, one active-only persisted rank change and explicit account reload/check. Both predefined variants intentionally retained; old collapse flags remain. |
| Cleanup / original mode restoration | PASS, ESO 22:05-22:06 and 23:08 | Original account-wide mode restored; 2 earlier tagged assignments and 1 final prefix assignment removed. No other reported changes. DEV code-defined plugin remains. |
| Production dynamic edits / disable / performance | NOT TESTED in ESO | Lifecycle hooks are implemented and covered offline; in-game behavior and Q5 workload/timing acceptance remain open. |

## Open questions, decisions, and deferred coverage

IDs match the [spec's open-question register](todo_plan_autocategoryIntegration.md#open-questions-and-decisions).

- **Q1 - POST-IMPLEMENTATION ACCEPTANCE:** verify safe top-heading mapping without changing external
  entries for the final general contract. Sampled prefix top placement, appearance,
  rank replacement and account reload passed ESO; 128-group scale passed offline.
  Arbitrary external priority/name bounds still need a compatibility decision.
  Mirroring above 1000 is not a solution. Negative bottom classification was
  tested offline only, not a negative top-placement alternative.
- **Q2 - POST-IMPLEMENTATION ACCEPTANCE:** prefixed crowded managed order and
  reversal passed in the sampled ESO case; distinct unprefixed fractions fail.
  External run/show mismatch and finite floating-point gaps remain demonstrated limits.
  Decide supported behavior without silently changing external entries/spec.
- **Q3 - IMPLEMENTED; IN-GAME ACCEPTANCE OPEN:** profile switching, refresh/cache
  invalidation, dynamic definitions/renames/deletes and disable hooks are
  covered by the adapter and offline tests; in-game behavior is not certified.
- **Q4 - SYNTHETIC SAFETY CHECKS PASS:** schema migration and pre-feature
  downgrade rejection are covered by the focused runner against the actual
  pre-feature sources at `HEAD`. No normal saved data has been loaded.
- **Q5 - OPEN decision/measurement:** agree synthetic workload and numerical
  timing limits, then measure the real integration.
- **D1 - CONDITIONAL author decision:** if Q1/Q2 cannot satisfy the spec safely,
  present evidence and alternatives before changing ordering semantics or
  taking over AutoCategory classification/rendering.
- **D2 - OPEN author decision:** final heading texture path and DEV/release
  identity policy, exact gold tint. Built-in plus texture is the proven probe
  asset, not the final IC asset.
- **D3 - OPEN, outside the initial heading requirement:** include/exclude badge
  placement, badge colours, and optional colour settings. These do not block
  using a plain category icon.
- **D4 - APPROVED author decision (2026-11-01):** rank-bearing empty colour
  prefixes are approved for production category names. The author accepts that
  reorders change names, restart collapse state and leave old per-name flags.
  This approval does not close Q1/Q2 or claim general placement compatibility.
- **Deferred / not certified:** Guild Bank (author deferred at 21:53 and
  22:16), gamepad, other crafting tabs/professions/universal deconstruction,
  merchant buy/buyback. Sampled merchant Sell is supplementary, not an eighth
  required context. Collapse interaction and reloads outside Backpack remain
  untested; the completed feature still needs its acceptance matrix.

## Reproduction and safety

- Installed dependency inspected: AutoCategory **4.5.2**, AddOnVersion **134**.
  Recheck contracts if its version/source changes.
- Offline probe module: [AutoCategorySpikeRuntime.lua](../../Tests/AutoCategorySpikeRuntime.lua).
  Offline fixture: [AutoCategorySpikeTests.lua](../../Tests/AutoCategorySpikeTests.lua).
  Run `python Project\Tests\Run-AutoCategorySpike.py` using the existing
  [runner](../../Tests/Run-AutoCategorySpike.py).
- Latest recorded offline result: **31/31 passed** on 2026-10-31 after the
  22:54 follow-up, including scale/bounds, runtime reorder and persistent prefix
  cycle/check/cleanup preparation. Earlier 28/28 preceded the 22:19 ESO test.
  Actual installed classifier/cache/settings modules execute against synthetic
  saves and mocked ESO/library/event/list boundaries. This is not full real
  startup execution, ESO formatting, or real inventory rendering.
- Earlier suite milestones: 15/15 initial insertion; 16/16 proxy isolation;
  17/17 absent definitions; 21/21 expanded priority/ownership/settings checks;
  26/26 command expansion; 27/27 unavailable-context/load-event regressions;
  28/28 core profile-switch and subsequent context/order regressions.
  Expected top-order FAIL diagnostics can occur inside a passing suite because
  the tests assert that the probe exposes that limitation.
- Synthetic tests never use live inventory or either addon's real saved data.
  Installed AutoCategory source is read-only; source fingerprints were checked
  by the runner. No integration, item transfers, or source patches were made.
- Classification/render probes substitute isolated rule/profile/cache state,
  restore original references synchronously even on failure, then leave only a
  temporary native list preview. Normal redraw is scheduled after 20 seconds
  (ordinary refresh may end it earlier). Do not click temporary headings or
  edit settings during the preview.
- One early proxy-isolation defect did write a temporary IC group; it was
  reported and repaired. See failures below. Do not describe the entire spike
  history as having made zero IC saved-variable writes.
- Only lifecycle probes were authorized to persist uniquely tagged AutoCategory
  assignments in both profiles. Projection writes only active; switch commands
  explicitly authorize AutoCategory's normal legacy normalization/cache work.
  Inactive comparisons cover bag assignments, not every legacy profile field.
- Ownership token: `InventoryCompanion-DEV-AutoCategory-Gate-20261031`.
  Cleanup matches both exact name and `icAutoCategoryGate` token, not labels.
  Gate name includes `|t18:18:EsoUI/Art/Buttons/plus_up.dds|t` followed by
  `InventoryCompanion DEV Gate Reload`. Production `icOwned` is separate.
- Reports use ESO's copyable diagnostic window, headed `DIAGNOSTIC REPORT` /
  `not a test failure`. NOT AVAILABLE is not a pass.

### Commands and walkthrough

Use explicit slash commands one at a time; wait for the user's report and
record it before proceeding. Use short placeholders such as `<item>`.
Reload only to load changed code or explicitly test persistence.

| Command | Purpose / precondition |
| --- | --- |
| `/icacspike <item>` | Existing isolated classification/precedence/cache probe; reads a Backpack item. |
| `/icacspike render <item>` | Group-wide native preview with keyboard Backpack open; default search plunder skull. |
| `/icacspike order <item>` | Five exact bag/slot groups plus retained anchor; needs at least six matching visible Backpack rows in one baseline category, not a stack of six units. |
| `/icacspike order2 <item>` | Same six-row prerequisite; unprefixed crowded order failed in ESO, top candidate unavailable. |
| `/icacspike ordertop <item>` | Top-only visible-heading sample; names external show >=996. ESO identified Maps & Surveys 1000 as blocker; candidate unavailable. |
| `/icacspike orderprefix <item>` | Empty colour-rank prefixes; top show 1000 tie then crowded fractions. Sampled ESO order and visual appearance passed. |
| `/icacspike orderreorder <item>` | Same six-row fixture, then reverse five ranks, replace only temporary definitions/assignments and rebuild full caches; measure stale-name removal, exact count, heading order and isolated collapse consequences. Offline validated; ESO pending. |
| `/icacspike prefix cycle <item>` | Persist one uniquely tagged active-profile assignment, classify rank 1 then rename/classify rank 2; compare inactive and other active assignments. Offline validated; ESO pending. Uses the existing lifecycle-write authorization. |
| `/icacspike prefix check <item>` | After explicit reload, read-only check of rank 2 assignment, both code-predefined rank variants, cache/compile and classification. Offline validated; ESO pending. Cleanup removes both exact rank-name variants with the token. |
| `/icacspike collision` | Refuse an existing Backpack category before registration; preserve definitions and both assignment profiles. |
| `/icacspike context <context> <item>` | Open keyboard context, one visible row; native classification/heading/item inspection. |
| `/icacspike context subscriber-bank` | With Bank open, select any available subscriber-source row by bag ID; ESO+ has no separate page. |
| `/icacspike profile baseline` | Read-only in-memory snapshots of both assignment profiles; reload loses them. |
| `/icacspike profile switch account` / `character` | Core mode/cache switch; close AutoCategory settings. Compare both assignment profiles, add no assignment. |
| `/icacspike profile project <item>` | Add/reuse one tagged active-profile assignment; compare inactive to same-session baseline. Backpack may be closed. |
| `/icacspike profile check <item>` | After explicit `/reloadui`, check one assignment, predefined definition/cache and classification without projecting. |
| `/icacspike cleanup` | Remove exact tagged entries in both profiles; `/icaccleanup` alias. Does not restore profile mode or remove code-defined plugin. |

Context names: `backpack`, `bank`, `subscriber-bank`, `guild-bank`, `house-bank`,
`crafting-station`, `craft-bag`, `furniture-vault`.

**Post-test housekeeping:** the temporary Debug override is removed from the
workspace after Test 7/7; offline checks verify the spike preserves the normal
handler from [Core/Init.lua](../../../Core/Init.lua), which calls
`this.RunTests("verbose copy")`. ESO must reload to pick up that change; normal
Debug dispatch is not yet reverified in game. Stale profile report advice was
replaced by explicit commands. The manifest-loaded probe/slash commands and
three code-defined predefines remain DEV-only for reuse; this is not full
teardown. Pre-shipping removal/relocation is required by the spec/plan.

## Dated ESO results

All dates below are **2026-10-31**, times UTC where supplied. Missing exact
arguments/times are identified rather than invented.

### Native insertion, markup, and group-wide matching

- Initial `/icacspike` passed three mixed orders: managed A / baseline
  Container / managed B, external first, and managed B first; full cache rebuild
  retained precedence. Uses the actual baseline rather than hardcoded spelling.
  Two test entries initially reused one real group; not two production groups.
- Early visual run put everything under Spike because the selected user's
  deliberate Test group used `*`. Restricting to one link then rendered only
  Dremora Plunder Skull, Public & Sweeper; six other skulls stayed Container.
  Those were fixture scopes, not evidence of group-wide matching.
- Corrected `/icacspike render` constructs a synthetic `*plunder skull*` group
  through the real create/update/compile/matcher path in detached IC profiles.
  After the reported proxy repair, **PASS** native keyboard Backpack:
  all **7 matching skulls** under inline-texture Spike B; **11 other items**
  kept their categories. User confirmed icon/section and normal redraw.
  Exact time not recorded. Collapse-control clicks were intentionally excluded.
- Offline markup checks include name lookup, expression compilation, classifier
  tuple, alphabetical tie-break, settings display and collapse-key lookup.
  This does not prove interactive collapse usability or the unconverted IC icon.

### Startup, collision, profiles, reload, and cleanup

**2026-10-31 23:08:05 UTC, ESO Test 7/7**, `/icacspike cleanup`:
**PASS** removed exactly **1** exact-token assignment across account/character
profiles. Report states no other AutoCategory entries, definitions, collapse
state, IC saved variables or items changed. The latest persisted prefix entry
is cleaned; original account-wide mode remains restored. All seven follow-up
steps are finished. No further saved test entries were reported.
Code-defined predefines remain until runtime unloading/reload; exact cleanup
does not remove definitions or collapse flags. Pending items are supported-
contract/naming decisions, deferred coverage and production acceptance, not
unfinished repetitions of these sampled tests.

**2026-10-31 23:04:28 UTC, ESO Test 6/7**, explicit `/reloadui` then
`/icacspike prefix check ancestor silk`: **PASS** one persisted account-wide
rank-2 assignment, both predefined rank variants compiled after startup,
native cache present and correct `ancestor silk hat^n` classification under
the exact rank-2 name. No stale rank-1 assignment or duplicates.
Check was read-only; other active and all inactive assignments unchanged during
this command. Inactive comparison does **not** cover the reload interval
because the session baseline was lost. This closes sampled prefixed assignment/
definition/cache startup persistence, not automatic production reprojection or
all-profile/context reload coverage. One tagged account entry awaits Test 7/7.

**2026-10-31 23:02:23 UTC, ESO Test 5/7**,
`/icacspike prefix cycle ancestor silk`: **PASS** account-wide active-only
rank 1 -> rank 2 assignment rename; exactly one tagged assignment retained,
no stale rank 1 assignment or duplicates. Other active assignments and all
inactive character assignments unchanged. Native classification of
`ancestor silk hat^n` returned the exact rank-2 prefixed Gate Prefix Reload name.
Both code-defined rank variants intentionally remain available; this does not
prove removal of every old definition or dynamic production registration.
One temporary account assignment remains for explicit reload Test 6/7;
cleanup Test 7/7 is still required. No IC saves or items changed.

| Time | Command / supplied report | Result and implication |
| --- | --- | --- |
| Before 21:14, time not recorded | Debug Key baseline after startup correction | PASS registration preflight before AutoCategory initialization; account active, character inactive; read-only baselines. Establishes corrected event handoff. |
| 21:14 | Debug Key `profile baseline` | PASS account active; captures both assignment baselines only. |
| 21:14:43 | Debug Key full profile switch | FAIL in external `CatSet.clearRuleCheckStatus`; mode/cache switch already happened, comparisons not reached. Core-only alternative below supersedes it. |
| 21:16 | Debug Key baseline | PASS character active after partial switch; not proof of assignment preservation. |
| 21:16:30 | Debug Key core `profile switch account` | PASS character to account; both complete assignment lists unchanged, no entry added. |
| 21:17 (repeated 21:18) | Debug Key `profile project plunder skull` | PASS reuse of one account entry at run/show 1000; correct classification, inactive character equals baseline. Earlier priority origin unexplained; no priority-retention claim. |
| 21:18-21:18:48 | Requested reload/check, supplied projection reports | NOT reload evidence. Workspace key pointed at check but runtime/report mismatch unexplained. |
| 21:19:52 | Explicit `/icacspike profile check plunder skull` | PASS current account assignment/definition/cache/classification; immediate preceding reload not independently confirmed. |
| 21:21 | Explicit `/reloadui`, then `/icacspike profile check plunder skull` | PASS account Backpack reload: exactly one tagged assignment plus definition/cache and correct classification. |
| 21:22 | Debug Key `/icacspike collision` | PASS existing Maps & Surveys detected in runtime list before registration; registration not called, existing identity/definition and both assignment profiles unchanged. |
| 21:57:54 | `/icacspike profile baseline` | PASS account active, both profiles captured read-only for reverse test. |
| 21:58:35 | `/icacspike profile switch character` | PASS account to character, both assignment lists unchanged, no added entry. |
| 21:59:28 | `/icacspike profile project plunder skull` | PASS one new character entry at 1001.5, correct decorated classification, inactive account unchanged. Fractional classification only, not formatter/order. |
| 22:00:37 | Explicit `/reloadui`, then `/icacspike profile check plunder skull` | PASS character Backpack reload: exactly one assignment, predefined definition/cache, correct classification. Original 1001.5 retention and headings not checked. |
| 22:05:13 | `/icacspike profile switch account` | PASS original account mode restored; both assignment profiles unchanged. |
| 22:06 | `/icacspike cleanup` | PASS exactly 2 exact-token assignments removed across both profiles; report says other entries, definitions, collapse state, IC saves and items unchanged. |

Manual active-only projection and both core switches are proven for these
sessions. These commands do not implement or establish automatic IC reprojection.
Bank/subscriber reloads, uninstall in ESO, many production definitions and
repeated arbitrary edit cycles still need implementation acceptance.

### Context classification and native rendering

All successful context probes restore runtime synchronously, schedule normal
redraw after 20 seconds and use temporary run priority 1001. They check exact
decorated heading/item identity, not intended top placement or persistence.

| Time | Context / command | Observed item, bag / AC context | Result / limits |
| --- | --- | --- | --- |
| Earlier, time not recorded | Backpack `/icacspike render` | 7 matching skulls; bag 1 / context 1 | PASS group-wide rendering, 11 unrelated rows retained. |
| 21:33 | `/icacspike context bank map` | Glenmoril Wyrd Treasure Map row | FAIL stale Maps & Surveys classification; no test header. Corrected timestamp invalidation, not a claimed pass. |
| 21:41 | `/icacspike context bank map` | Glenmoril Wyrd Treasure Map: Eastmarch; 2 / 2 | PASS after correction; baseline Maps & Surveys. |
| 21:42 | `/icacspike context subscriber-bank map` | No matching subscriber row | NOT AVAILABLE, not absence of ESO+ support. |
| 21:46 | Supplied order report while Bank open | Backpack unavailable | Wrong probe; no subscriber evidence or writes. |
| 21:47 | `/icacspike context subscriber-bank` | Escapist's Poison IX; 6 / 2 | PASS auto-selected subscriber row; baseline Poison. |
| 21:52 | `/icacspike context craft-bag ancestor silk` | Ancestor Silk (`Ancestor Silk^ns`); 5 / 4 | PASS; baseline Clothing. |
| 21:53, reaffirmed 22:16 | Guild Bank | No probe run; AC context 3 | DEFERRED by author to later DEV testing; not passed. |
| 21:54 | `/icacspike context house-bank <item>` | Betnikh Treasure Map I; 10 / 6 | PASS; baseline Maps & Surveys. Exact search not supplied; not all chests. |
| 21:57 | `/icacspike context furniture-vault <item>` | Alinor Tapestry, Alinor Dusk; 18 / 7 | PASS; baseline Furnishing. Exact search not supplied. |
| 22:10 | `/icacspike context crafting-station <item>` | ruby ash bow (`ruby ash bow^n`); 1 / 5 | PASS smithing-framework deconstruction; baseline Low Level. Exact search/profession not supplied; not every tab/profession. |
| 22:13:34 | Merchant Sell exploratory `/icacspike context backpack <item>` | Glenmoril Wyrd Treasure Map: Alik'r; 1 / 1 | PASS Backpack surface, baseline Maps & Surveys; report alone did not identify a separate Sell list. |
| 22:15 | Merchant Sell visual retry | Exact retry argument/report not supplied | User confirmed temporary category at end of Sell. Together with prior diagnostic supports sampled keyboard Sell rendering, not buy/buyback or desired heading order. |

### Heading order and fractional formatter

- **23:01:22 ESO, Test 4/7**, `/icacspike orderreorder ancestor silk`:
  **PASS prefix rank reorder/full-cache rebuild**. Five desired headings
  reversed to Victor > Whiskey > Xray > Yankee > Zulu between Container and
  Low Level, with corresponding ranks 1..5. All five item classifications
  passed after replacement/full rebuild; checks found exactly five reordered
  assignments and no stale names outside the retained middle Xray identity.
  Initial prefixed top and crowded phases passed again. Isolated collapse
  consequence measured: old Zulu flag retained true, renamed Zulu false.
  Original runtime restored; normal redraw 20s, no saved writes or item movement.
  This answers runtime rank-name replacement/cache behavior in ESO, not
  persisted prefix startup or automatic production reprojection.
  Next Test 5/7 persists one exact-tagged rank change in active profile only;
  Test 6/7 verifies explicit reload, Test 7/7 removes it.
- **22:54 onwards, remaining spike checks prepared offline; 31/31 PASS** with
  `python Project\Tests\Run-AutoCategorySpike.py`:
  - **Scale:** 128 managed definitions, distinct fractional run priorities in
    (100,100.129), shared show 100.25, reverse-numbered visible labels and
    fixed-width colour ranks. Actual native classification/cache across all
    seven synthetic contexts preserves all 128 identities/priorities; synthetic
    native string keys sort by rank. Copied saved assignments plus actual
    `RulesW:CompileAll()`/full cache rebuild preserve classification/data.
    This is not 128 actual ESO headings or a real reload.
  - **Rank boundaries:** hexadecimal 255->256, 65535->65536 sort correctly in
    the fixture; six digits encode at most 0xffffff. No unlimited capacity
    claim. Adjacent floating-point priorities near 1 cannot contain five
    strictly interior ranks; prefixes cannot create numeric precision.
  - **Placement boundaries:** two external run-90 ties both precede run-89.5
    managed rule; empty external list and negative last-slot -10.25 classify
    natively, show key 1010 offline. External run/show mismatch failure from
    earlier fixtures remains: prefixes order managed ties, not external rows.
    No negative-bottom ESO heading certification.
  - **Runtime reordering:** `orderreorder` reverses five rank prefixes, removes
    stale temporary definitions/compiled rules/assignments, registers replacements,
    rebuilds complete native caches and measures actual list rows. Synthetic
    fixture passes exact five assignments and reverse label order; old Zulu
    collapse flag remains true, new Zulu name is expanded. All real assignment/
    collapse state restored; **ESO Test 4/7 pending**.
  - **Persisted prefix lifecycle:** `prefix cycle` and `prefix check` use two
    code-defined rank variants added to the existing gate plugin (now three
    predefines including the original reload gate). Only one exact-tagged
    active-profile assignment persists; rank 1->2 and repeat cycle have no
    duplicate/stale assignment or priority drift. Both rank definitions remain
    intentionally available for inactive-profile references. Inactive and
    other active assignments compare unchanged. Read-only recompilation/check
    and cleanup pass; an untagged same-name inactive entry survives cleanup.
    Preflight covers all three names before registration. **ESO Tests 5/7
    cycle, 6/7 explicit reload/check, 7/7 cleanup pending**.
  - A fixture initially called a nonexistent `compileRules`; offline failed,
    corrected to the inspected `RulesW:CompileAll` and passed. No failed
    candidate build was sent to ESO.
  These bounded checks establish supported mechanisms and known limits, not a
  universal placement algorithm or production hooks. Q1/Q2 require an explicit
  supported-contract decision; D4 prefix adoption follows lifecycle evidence.
- **22:47:26 ESO, Test 3/3**, `/icacspike orderprefix ancestor silk`:
  **PASS top classification AND actual native heading order**:
  Zulu > Yankee > Xray > Whiskey > Victor > Maps & Surveys > remaining external
  headings. Full names carry empty `|c000001|r` through `|c000005|r` before
  the icon. Run values 1005,1004,1003,1002,1001; all show priorities 1000.
  **PASS crowded classification AND native order** between Container and
  Low Level with the same five fractions as 22:40 and identical `0914` keys.
  Immediate classification gap (85,90); visible Container anchor 95.
  Both phases separately passed five item classifications; runtime restored
  and normal redraw scheduled after 20s, no saved writes or item movement.
  Initial visual check was not confirmed: author asked where to look; raw
  markup in the diagnostic is intentional identity output, not a visual defect.
  Top ordering differs from the offline plain-name-tie fixture, which failed;
  retain both results. Do not infer a universal cross-runtime string comparator
  contract from the synthetic list. This establishes a working sampled ESO
  alternative, not production naming approval or reorder/reload/collapse safety.
- **22:51:40 ESO visual follow-up**, rerun of
  `/icacspike orderprefix ancestor silk` (exact rerun diagnostic not supplied):
  author confirmed the temporary headings "look fine" / "look ok".
  **PASS sampled visual prefix invisibility / no reported tint artefacts**.
  Alignment was hard to assess in the huge expanded Low Level list and remains
  **unverified**, not failed. The source category must be expanded because this
  probe selects six visible item rows; collapsed rows are unavailable to its
  fixture discovery. Temporary names have no existing collapse flags, so their
  sections initially open. No heading-collapse interaction was tested.
  Test 3/3's sampled top/crowded order and visual prefix gates are answered.
  General placement bounds, production rank-name lifecycle/approval and
  alignment/collapse interaction are not established by this visual result.
- **22:44:07 ESO, Test 2/2**, `/icacspike ordertop ancestor silk`:
  **NOT AVAILABLE**; **Maps & Surveys = show priority 1000, visible heading**.
  No top phase executed and no claimed PASS. Existing entries/items/saves not
  changed. Therefore the five whole show slots 1000..996 cannot satisfy this
  user's current top requirement unchanged. This is a candidate boundary,
  not proof every possible top mapping fails.
- **After 22:44, author suggested invisible prefix; offline preparation:**
  `/icacspike orderprefix <item>` uses empty colour spans `|c000001|r` through
  `|c000005|r` before icon/label, resetting colour before visible content.
  Actual classifier/cache and synthetic native-list fixture pass ordered
  crowded headings despite reverse-alphabetical visible labels.
  Top show 1000 ties with a plain-name external heading at 1000 and **fails
  top placement offline**; prefix rank does not by itself put our categories
  before that external name. ESO/visual invisibility not tested yet.
  Full suite **28/28 passed** after fixing a probe branch-placement defect
  detected by offline execution (nil priorities, never sent to ESO).
  Saved assignments unchanged; prefix changes full category-name identity on
  reorder, with possible collapse residue, collision/reload implications.
  Candidate is not approved production naming. **Test 3/3 pending** to verify
  the author's alternative; the total grows because top candidates remain
  unavailable and this new alternative needs explicit evidence.
- **22:40:36 ESO, Test 1/1**, `/icacspike order2 ancestor silk`:
  top candidate **NOT AVAILABLE**, existing show priority >=996; that version
  did not identify the entry or whether it had a visible heading. No top PASS.
  All five items **PASS classification** with run/show
  `85.416666666667 > 85.333333333333 > 85.25 > 85.166666666667 > 85.083333333333`
  inside immediate gap (85,90), visible Container anchor 95.
  All five `%04d` display keys were **`0914`**, formatter sample also `0914`.
  Desired Zulu > Yankee > Xray > Whiskey > Victor instead rendered
  **Container > Victor > Whiskey > Xray > Yankee > Zulu > Low Level**:
  **FAIL crowded saved heading order**, confirming alphabetical ties in ESO.
  Other reported headings retained order; runtime restored, normal redraw 20s,
  no saved writes or item movement. Fractions are not a general display-order
  solution; retain Q2/D1 until a safe alternative or author revision is decided.
- **After 22:40 offline follow-up**, 28/28 passed:
  `/icacspike ordertop <item>` now identifies each external high show priority,
  tests only top placement of the currently visible headings and ends with that
  preview (no repeated crowded phase). Visible external show >=996 remains
  explicitly unavailable; invisible high entries remain unchanged and are
  reported as outside this sampled heading bound. Fixture covers both cases,
  saved-state preservation and no crowded rerun. This can establish a sampled
  separate run/show alternative, but cannot certify top placement if currently
  invisible categories gain headings later. **ESO Test 2/2 pending**; total
  increased because Test 1's top phase could not execute.
- **22:36 onwards, offline preparation; ESO NOT YET RUN:**
  `python Project\Tests\Run-AutoCategorySpike.py` passed **28/28** after adding
  `/icacspike order2 <item>` to the existing native-list fixture.
  Five run priorities above the highest external run priority, with separate
  show values `1000,999,998,997,996`, put reverse-alphabetical labels
  `Zulu > Yankee > Xray > Whiskey > Victor` above existing headings offline.
  Candidate explicitly reports NOT AVAILABLE if any external show priority
  is >=996. This is a bounded five-slot alternative, not arbitrary top capacity.
  Crowded run/show fractions in a sub-unit part of the immediate gap still
  classified all five items but produced five identical integer display keys
  (`0899` in the fixture) and **FAIL** desired native heading order.
  Separate classifier PASS is reported so heading failure cannot be concealed.
  Additional fixture with external run 200/show 50 above baseline run/show 100
  exposed between-heading failure; allocation by run order alone is insufficient.
  Saved assignments compared unchanged after the new probe. High-show-priority
  rejection is also covered. These use synthetic native lists and the actual
  classifier/cache, not ESO rendering; verify `order2` in ESO next.
- **21:28**, `/icacspike order ancestor silk`: five selected rows from Low
  Level each classified under its own temporary heading. Run/show
  `1005 > 1004 > 1003 > 1002 > 1001` produced headings after Others in order
  `Order 5 > Order 4 > Order 3 > Order 2 > Order 1`: **FAIL top placement and
  sequence**. Preview's normal return was intentional.
  Fractional phase **NOT RUN**: baseline 85, immediate higher priority 90
  had no visible heading. No external entries edited to force a fixture.
- **22:16 offline correction**, 28/28 passed: still allocate strictly inside
  the immediate numerical classification gap, but use the nearest *visible*
  higher category for the rendering anchor. Fixture baseline 100, invisible
  immediate anchor 105, visible anchor 200; five fractions inside (100,105).
  This supersedes requiring the immediate numeric anchor to be visible; it
  does not skip intermediate assignments in priority calculation.
- **22:19**, `/icacspike order ancestor silk`: top phase repeats the same
  failure. Fractional phase **PASS classification and actual native heading
  order**:
  `Container > Order 1 > Order 2 > Order 3 > Order 4 > Order 5 > Low Level`.
  Run/show values:
  `89.166666666667 > 88.333333333333 > 87.5 > 86.666666666667 > 85.833333333333`.
  Immediate gap `90 > 85`; visible higher Container priority **95**.
  ESO fractional `%04d` sample **`0910`**. Other native category headings
  retained relative order. Five selected rows plus at least one baseline row.
  Runtime restored, normal redraw scheduled, no saved writes.
- This passes the five-group sample, **not arbitrary density or label order**:
  `%04d` truncation can give different fractions identical integer keys, then
  alphabetical category names decide order. Probe labels Order 1-5 already
  agree with their desired alphabetical order. Formatter success alone is not
  heading-order evidence.

## Failed approaches and supported alternatives

| Failure / date | Root cause / consequence | Supported alternative / limit |
| --- | --- | --- |
| Initial absent-addon assertion, 2026-10-31 | Optional dependency absence reached assertion. | Slash boundary now opens copyable unavailable/incompatible diagnostics; offline no-probe/no-write checks. |
| Raw closed-Backpack error from wrong Debug Key, 2026-10-31 | Key still ran render instead of baseline. | Copyable NOT AVAILABLE for closed Backpack/gamepad; use explicit commands. |
| Startup `acctSaved bag assignments are unavailable`, 2026-10-31 | DEV had `OptionalDependsOn: None`; same dependency-event listener incorrectly assumed it ran after AutoCategory's own listener. Incorrectly labelled collision. | Declare optional dependency and register on IC's own load event after dependency event completes; readiness and genuine collision distinguished. Offline event-before-bags regression and ESO baseline PASS. |
| IC `ic_acspike_group` saved-data leak / second press "Rule already exists", 2026-10-31 | Deep copy preserved ZO_SavedVars write-through proxy metatable, so synthetic group wrote live data. | Detach raw table behind `__index = current`, without proxy metatable. Reported repair removed leaked account group (character clean); repaired ESO render passed. One-off repair code/test removed; proxy regression remains. Restoring old copy reproduced 3 offline failures. |
| Full settings profile switch, 21:14:43 | External CatSet nil-global defect after mode/cache switch, before comparisons. | Core mode setter plus actual `UpdateCurrentSavedVars`, no settings-only calls, settings closed. Both directions PASS; legacy non-assignment fields not compared. No source patch/global workaround. |
| Debug Key/check mismatch, 21:18-21:19 | Exact runtime mismatch unexplained despite workspace dispatch/manifest inspection. | Explicit slash check and explicit reload/check establish independent evidence. No inferred reload pass from wrong report. |
| Bank preview stale row, 21:33 | Native row classification uses hash/timestamp; `RefreshList(..., true)` is not forced reclassification. | Invalidate only selected transient `AC_lastUpdateTime`; offline other-row timestamp preserved, ESO retry PASS. Production-wide invalidation still Q3. |
| "Subscriber page" / name search, 21:42 | ESO+ shares Bank UI; no subscriber row matched map. | Select by subscriber bag ID with no name; offline fixture and ESO 21:47 PASS. |
| Crafting refresh preflight, before 22:10 | Crafting `RefreshList` ignores true. | False for preview and delayed restoration; ordinary inventories true. Offline argument checks and ESO 22:10 PASS. |
| >1000 top show priorities, 21:28 and 22:19 | Negative formatted keys gave bottom placement and reversed sequence. | No proven top alternative. Mirroring above 1000 only addresses reversal, not bottom placement. Negative priorities not tested. |
| Immediate visible fractional anchor requirement, 21:28 | Available items did not generate the priority-90 heading. | Numeric gap unchanged, nearest visible higher rendering anchor; offline correction and ESO 22:19 PASS. |

## Dependency contracts and source trail

These are inspected contracts for the recorded AutoCategory release, not a
promise of a complete dynamic public API.

### Lifecycle and definitions

- ESO event identity is directory/manifest identity, not localized title.
  AutoCategory filters `"AutoCategory"`; IC filters `InventoryCompanion.Name`.
  DEV now declares `## OptionalDependsOn: AutoCategory`; release integration
  is not wired. Optional dependency preserves IC use when AC is absent.
- Register at IC's own `EVENT_ADD_ON_LOADED`, after AutoCategory's load handler
  has established `acctSaved`, `charSaved`, `acctRules`, before player activation.
  Do not rely on ordering of two handlers for the same dependency event.
- Player activation: load plugin predefines; combine saved definitions; select
  active profile via `UpdateCurrentSavedVars`; call plugin initializers; build
  caches/menu/classes; set `Inited = true`.
- `RegisterPlugin(name, init, predefined)` stores a plugin and marks predefines
  `pred=1`; it does not immediately initialize or assign categories. Late
  registration does not rerun initialization. Provide a real predicate via
  `AddRuleFunc(name, func)` before evaluation; omission installs an always-false
  dummy. Definitions without the function become damaged for that session.
- Plugin predefined definitions are supplied by code each session; persisted
  bag assignments are separate. Do not write IC definitions to `AutoCatRules`.
- Absent-definition fixture: actual classifier skips missing definitions and
  falls through; settings show red `(!)` with missing-category tooltip.
  Offline only, not uninstall certification in ESO. Integration off while IC
  loaded should keep definitions available with a deliberately disabled
  predicate, and remove owned active-profile assignments.

### Ownership, collision, priority, and refresh

- Assignment shape: `saved.bags[acBagType].rules` entries have `name`,
  `runpriority`, `showpriority`, `isHidden`. Higher run priority wins; equal
  priorities sort by name. Matcher sets current bag/slot/link and returns the
  native category tuple. External rule errors are caught/marked damaged by AC.
- Production `icOwned = true` survived actual cache/settings and Export-to-all-
  bags `SF.deepCopy` paths in all seven synthetic lists, with fractional
  priorities. This is offline ownership-preservation evidence, not permission
  to export user data during tests.
- Same-name/different-expression `addTableRules` can rename incoming rules via
  `GetUsableRuleName` and redirect existing assignments via `renameBagRule`.
  Preflight definitions (runtime/default/plugin/account/character) and both
  profiles' assignments before registration/projection; skip/report unowned
  conflicts. Label resemblance never establishes ownership.
- Keyboard/gamepad show key from source:
  `string.format("%04d%s", 1000 - showpriority, categoryName)`.
  No general run/show equality guarantee. Alphabetical integer-key ties remain.
- `RulesW:AddRule`, `cache.AddRule`, `cacheInitBag`, `cacheBagInitialize` and
  `cacheInitialize` affect distinct layers. `cache.AddRule` has nil-success /
  error-string-failure convention. Do not invent a complete public CRUD API.
- `RefreshList(inventoryType, even_if_hidden)` is narrower than
  `RefreshCurrentList`. True does not force cached keyboard rows to reclassify;
  crafting requires false. Production refresh and coalescing still need tests.
- Account checkbox sets `charSaved.accountWide`, calls
  `UpdateCurrentSavedVars`, clears BagSet/CatSet and refreshes settings.
  Core routine rebuilds caches and may remove legacy profile fields.
  `settings/CategorySettings.lua:40` defines `clearRuleCheckStatus` before
  `local ruleCheckStatus`, reading a nil global; do not patch installed source
  or create that global. Core-only probe is not a replacement settings UI.
- Collapse flags live under category names and are not pruned on AC renames.
  Decorated renames start expanded and leave old flags; document, do not edit.

Read-only installed sources:
[Plugin_API.lua](../../../../AutoCategory/Plugin_API.lua),
[AutoCategory.lua](../../../../AutoCategory/AutoCategory.lua),
[AutoCategory_API.lua](../../../../AutoCategory/AutoCategory_API.lua),
[AC_Classes.lua](../../../../AutoCategory/AC_Classes.lua),
[Hooks_Keyboard.lua](../../../../AutoCategory/Hooks_Keyboard.lua),
[AddonMenu.lua](../../../../AutoCategory/AddonMenu.lua),
[BagSet.lua](../../../../AutoCategory/settings/BagSet.lua),
[CategorySettings.lua](../../../../AutoCategory/settings/CategorySettings.lua),
and [DressingRoom plugin prior art](../../../../AutoCategory/plugins/DressingRoom2018_Plugin.lua).
Bank maps bag 2 and subscriber bag 6 to AC context 2; Guild uses a separate
assignment list and has a BulkMode bypass. Merchant source inspection found
shared inventory sorting, not a distinct merchant hook. Neither finding
substitutes for missing in-game evidence.
