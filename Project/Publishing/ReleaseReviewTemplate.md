# ESOUI Release Standards Review

Complete this review for the exact frozen release candidate, not a changing development checkout. Save the completed review as `ReleaseReview.md` in the development root. The timestamp is an audit record, not a freshness gate.

Reviewed (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Reviewer: <AI assistant and model name, if available; do not guess>
Checked by: <human author/checker>
Release version: <manifest version>
Candidate SHA256: <candidate SHA256>
Review status: <PENDING or APPROVED>

Testing scope: Live only. PTS is not tested or required for approval; PTS compatibility is not claimed.

## Review method and evidence

This template is the self-contained result of the release-guidance research, incorporating the upload rules, prohibited-functionality/removal guidance, release and coding best practices, manifest/structure rules, dependency checks, event filters, saved variables, and patch/takeover requirements. Do not fetch guidance pages, search for similar add-ons, or repeat that research as a release-review step. A material policy or permission question that the recorded requirements cannot settle remains `UNRESOLVED`; the author must supply a documented decision before approval.

Each check below has an evidence owner:

- **AI**: source, manifest, archive, or supplied-document inspection. Cite candidate-relative files/symbols and the finding; inspection does not prove runtime behavior.
- **TEST**: human runs `/ictest verbose copy` in ESO against the frozen candidate and supplies the complete report. AI assesses that output; it must not claim to have run ESO. The command intentionally opens a copyable Lua error report even when every test passes; judge the reported results, not the presence of the error window.
- **HUMAN**: author/uploader confirmation or in-game observation that code inspection and synthetic tests cannot establish. Name the person and record actual evidence.

For **every checkbox**, record `PASS`, `ISSUE`, `UNRESOLVED`, or `N/A` with a reason and evidence. A checked box means assessed, not necessarily passed. When a check has multiple owners, provide each owner's evidence. Attach one diagnostic report and reference its named cases in the relevant sections; do not duplicate transcripts or manually repeat synthetic assertions.

The source review covers the complete candidate. Human testing is a focused smoke test plus additional scenarios justified by changes or findings, not an exhaustive matrix on every release. Conditional checks may be assessed as N/A with the reason recorded. Prior human evidence for unchanged behavior may be reused with its candidate identity, date, and an explanation of continued applicability; never relabel it as a fresh run or hide incomplete output. Do not approve with a failed functional test, missing essential evidence, or a material unresolved compliance/safety question. Performance outliers follow the investigation process below rather than automatically blocking release.

## Release process

- [ ] **AI + HUMAN** Record how the intended files were staged and frozen, the candidate installation path, version, SHA-256 identity, and who verified the test installation. Confirm DEV is disabled and the tested bytes match the candidate; subsequent DEV edits do not invalidate an unchanged candidate.

<Actual release process and candidate identity.>

## Mandatory requirements

### Package and installation

- [ ] **AI** Confirm one correctly named top-level add-on folder, a matching manifest basename, and every required runtime file present exactly once. For an existing archive, record filename, format (ZIP or RAR), hash, extraction verification, and comparison of runtime bytes/manifest with the frozen candidate. For this project's stage/finalize workflow, approve the frozen candidate only and record final ZIP verification as delegated to `PackageRelease.ps1 -Action Finalize`; its successful byte/content verification is required before upload. Do not claim a not-yet-produced archive was inspected.
- [ ] **AI** Exclude executables unless a documented ESOUI exception permits them; exclude nested ZIP/RAR archives, `wowmatrix.dat`, hidden/OS/version-control/editor files, SavedVariables, generated API files, backups, and unrelated project files. Under an approved executable/non-addon-file exception, require purpose/file-access disclosure and, for executables, source code and the required VirusTotal report supplied by the uploader.
- [ ] **AI + HUMAN** Confirm any upload-form-required image is JPG, PNG, or GIF, and installation help is included when installation is not straightforward. Human confirms the actual form requirements; AI checks the supplied assets/help.
- [ ] **AI + HUMAN** If this is a compilation, list all included add-ons in the description. If a WTF folder is included, replace personal information with generic information and inspect the submitted copy.

### Listing, rights, and uploader certifications

AI inspects the supplied final listing and materials. Author-only certifications may share one declaration/evidence reference; do not ask a separate question for each checkbox. Tim-P has authorized the following standing assertion to be recorded in reviews: "The author asserts that, to the best of their knowledge, the submitted files contain no malicious code or stolen material, and that they own the material or have permission to submit it." Attribute this to the author, not to independent AI verification; investigate contradictory evidence.

For remaining author-only facts not already supplied, ask one consolidated confirmation covering the applicable certifications below. Do not invent agreement to unconfirmed facts or infer ownership, permission, or distribution terms from the absence of suspicious code. Retain the declaration and any supporting license/permission details as one evidence item.

- [ ] **AI + HUMAN** The description accurately explains the submitted functionality and installation, lists every required dependency at or near the beginning, and uses English where practical. Update details belong in the Changelog, not in place of the description. For console-only releases, state platform support in the name and description.
- [ ] **HUMAN** Reference the author's assertion that the submitted files are free of viruses, trojans, spyware, malware, and worms to their knowledge; include ToS/Add-on Terms conformity in the single consolidated confirmation if not already supplied.
- [ ] **AI + HUMAN** The add-on is free of charge (including elsewhere), has no paid/trial/time limit, and contains no advertisements, promotions, or nag screens. Submitted code, description, credits, and images are neither harmful nor offensive; names/descriptions contain no profanity.
- [ ] **AI + HUMAN** The uploader owns or has submission permission for all material. Credit borrowed code, concepts, assets, and information, including material identified through AI-assisted research; record applicable licenses/permissions. The author confirms they can maintain the resulting code.
- [ ] **AI + HUMAN** If AI generated code the author cannot personally verify as correct, efficient, maintainable, and safe, place AI disclosure at the beginning of the description. Disclosure is optional for ideation-only use when the author wrote and validated the final code. Record which case applies.
- [ ] **HUMAN** For a patch/takeover of another author's add-on, record the license, original-author contact and response, and required permission before proceeding. An unanswered request is not permission; unresolved authorization blocks approval.
- [ ] **HUMAN** Confirm the listing's patch/companion-add-on option matches the author's intent and that the author monitors ESOUI private messages for moderator requests. Confirm the submission meets the upload requirements assessed in this report.

### Supported functionality

AI traces all relevant call paths. Human checks real interaction/restriction behavior in the in-game section; do not mistake synthetic message tests for proof of safe live transfers.

- [ ] **AI** No gameplay actions run before entering the world or during character selection/creation, loading screens, Crown Store use, scrying, or Tales of Tribute. Necessary add-on initialization is distinct from performing gameplay actions.
- [ ] **AI** No player movement, combat actions, skill casts, movement/combat keybind activation, or quickslot use is triggered by the add-on.
- [ ] **AI** The player initiates interactions (including banks, companions, scribing, and scrying); the add-on does not start them. Banking actions use supported protected transfer APIs only within a player-opened interaction.
- [ ] **AI** Public chat is never sent automatically; text may only be prepared for the player to send. Local diagnostic/chat-window output is not public-chat transmission.
- [ ] **AI** No bypass of combat/gameplay restrictions, private/locked API use, or loophole exploits. If a feature's permissibility is unresolved, require a supplied ESOUI/ZOS clarification before approval rather than inventing an exception.
- [ ] **AI** No real-time external-service communication or prohibited group-data exchange through MapPings or other workarounds. Runtime file access uses supported saved-variable APIs only; any external non-real-time client must not modify files held in memory by the running game.
- [ ] **AI** Runtime-loaded code/assets use supported Lua, XML, and DDS formats plus the manifest, stay within `live/AddOns`, and are no more than three subfolder levels below the manifest. Distinguish runtime-loaded assets from permitted archive documentation/images.
- [ ] **AI** No malicious/disruptive behavior or control of another player's actions. No custom sounds/videos, unsupported external 3D objects, prohibited nameplate/restricted-UI changes, or 2D-projection workaround for restricted 3D markers; any markers use supported APIs and respect location restrictions.

### Manifest and dependencies

- [ ] **AI** Use `.txt` for PC-only or `.addon` for console support, not both for the same add-on. The UTF-8 manifest has no BOM. Every line is at most 301 bytes; comment lines must also stay within 1,024 characters (the stricter byte limit still applies).
- [ ] **AI** Require `Title`, positive-integer `AddOnVersion`, `APIVersion` (one or two integer values), and the ESOUI/Minion `Version`. Directives use `## Name: value`; repeated directives are used only where supported. Required dependencies use space-separated `Name>=integer` entries; optional dependencies must not become required.
- [ ] **AI** Resolve every manifest/XML include relative to its containing file, confirm existence and intended load order, and inspect any variable expansion or special-folder usage. Assess platform-specific directives if present.
- [ ] **AI + TEST** Include `Runtime and dependency discovery`, the report's running API and game build, and compare the API with the candidate's `APIVersion`. Record "Live tested; PTS not tested, not required, and no PTS compatibility claim." If an older frozen release lacks discovery, use supplied in-game API/build details and local dependency manifests instead; do not modify it solely to add newer diagnostics. Do not infer a newest published version from local runtime evidence.
- [ ] **AI + TEST** Include installed dependency integer versions from the report and compare each required minimum with the supplied dependency manifest's `AddOnVersion`. An installed version is not proof of the newest published version. Record the tested compatible minimum and rationale; consider raising it for relevant fixes and removing obsolete bundled libraries/LibStub patterns.
- [ ] **AI + HUMAN** For optional dependencies, inspect absence guards and test loading without them. Mark N/A if there are none.

<Results and evidence for each mandatory check.>

## Code quality and automated evidence

Review the complete candidate code, manifest, XML, and relevant configuration, not just changed files. For every TEST check below, reference the named case results in the single attached report. For an older frozen suite, describe missing cases/assertions and assess their risk through source inspection and targeted human checks; newer test coverage is not a retroactive requirement to alter the frozen release. A suite total alone does not establish per-case coverage. Report conditional/unavailable coverage, not just the pass count.

### Initialization, naming, and saved data

- [ ] **AI** Prefer locals and one prefixed add-on global table; prefix necessary saved-variable, control, binding, scene, dialog, and event namespace names. Explain necessary global exceptions and material maintainability concerns.
- [ ] **AI** Initialize saved variables only after the matching `EVENT_ADD_ON_LOADED`, check the add-on name, and unregister completed initialization callbacks. Use supported saved-variable wrappers, appropriate account/character-ID scope, and an intentional NA/EU sharing policy.
- [ ] **AI + TEST** Check data integrity and preservation of unrelated overrides; include `Profile import copies tracked items and rule overrides`, `Baseline and saved-rule override resolution`, `Display-flag writes preserve other overrides`, and `Prune known saved-variable diagnostic keys only`. The pruning test uses fixtures, not a cleanup of the user's data. If schema/scope changes, require migration-specific test evidence as well; these cases alone do not prove migration correctness.

### Rule matching and inventory scope

- [ ] **AI + TEST** Trace empty/invalid data and matching boundaries; include `Case-insensitive substring matching`, `Wildcard matching`, `Literal punctuation and missing names`, `Any-pattern matching`, `Tracked item count respects backpack and craft-bag scope`, and `100-item backpack and craft-bag scan`. Human UI/transfer validation is separate below.

### Events and lifecycle

- [ ] **AI + TEST** Include `Event listener transitions and refresh debounce`: feature-driven registration/unregistration, bag-filter namespaces/values, successful registration/filter application, repeated registry-call stability, shared-consumer retention, and debounced refresh counts/delay. Inspect initialization/permanent listeners and transitions not exercised by that case separately.
- [ ] **AI** For other high-frequency events, assess applicable filters, matching namespace/event IDs, supported parameters, successful filter application, and no repeated filter type for one registration. Distinct values of one filter type require distinct namespaces. Unregister unused listeners to remove filters. Actual game filter delivery requires the human event test below.

### Resources, preferences, and messages

- [ ] **AI + TEST** Include `Progress bar resource model and preferences`, `Currency panel resource preferences`, `Live currency helper API`, `Currency notification preferences and changes`, and `Capacity notification preferences`.
- [ ] **AI + TEST** Include all `Currency messages:` and `Capacity messages:` cases: gains/spending/transfers, burst merging/cancellation, suppression during loading, disabled notifications, exact chat/HUD output, and threshold colours. Identify dynamically unavailable currencies/cap-dependent cases; a conditional return is not proof that its assertions ran.

### Performance and error handling

- [ ] **AI + TEST** Include `Repeated 100-item inventory scan performance`, `100 repeated slot-rule matches`, `100 synthetic tracked-item slot updates`, and `Live read-only scan` measurements and the limits actually embedded in the frozen suite. Current DEV investigation targets are 500 ms for 20 synthetic 100-item scans across 20 rules, 100 ms for 100 slot-rule matches, 200 ms for 100 synthetic tracked-item slot updates, and 500 ms for 100 live scans; do not apply them retroactively as older releases' pass/fail limits. Include occupied-entry count, bank state, and ESO Plus/craft-bag availability. For a timing-only FAIL/outlier, retain the original result, rerun under comparable conditions, compare prior measurements where available, and assess gameplay impact. A justified accepted performance exception may proceed; unexplained material regressions or stalls block approval. Timing uses `GetGameTimeMilliseconds`; no synthetic benchmark may transfer inventory or persist settings.
- [ ] **AI** Trace startup, user actions, repeated events, failure/recovery paths, and API assumptions not already covered above. Assess explicit error handling, repeated scans, allocations, inventory-size scaling, data-heavy API/server-wide cost, and maintainability. Record concrete defects/limitations without claiming the code is bug-free. Use local helper references where beneficial, not at the expense of clarity.

<Per-section evidence references, findings, and uncovered paths.>

## Human in-game testing

Run on the frozen candidate with DEV disabled. Record other enabled add-ons; require a dependency-only isolation run when a failure or suspected interaction warrants it, not automatically for every release. Live is the only required client; explicitly record PTS as untested and out of scope. Back up saved variables before tests that change persistent settings. Use only items and transfers the tester actually intends; no destructive/live-inventory benchmarks. Do not run `/icclean` as part of this review because it intentionally changes saved data.

Baseline human work: one diagnostic run, a real tracked-quantity update, an intended deposit and withdrawal, a relevant display/notification toggle, a visual check, and preference persistence after reload. The checkboxes below record that evidence and identify when additional testing is needed; they are not nine separate mandatory test sessions.

- [ ] **HUMAN + TEST** Record tester, UTC time, Live client, candidate identity, and relevant settings. Attach one complete `/ictest verbose copy` report with available discovery, cases, warnings/failures, totals, and timings, preferably with a player-opened bank. A second bank-open/closed run is needed only for a scanning change, coverage gap, or investigation. Human verifies the installation/hash separately; discovery is not a cryptographic identity check.
- [ ] **HUMAN** Reload and confirm no unexpected Lua errors and persistence of a representative preference. Clean-data, account/character-scope, and old-data migration tests are additional requirements only when affected by changes/findings. Use an isolated, restorable saved-variable fixture; an add-on profile alone does not isolate saved data. Cross-server testing is not routine.
- [ ] **HUMAN** Confirm a representative tracked quantity and relevant editor choice display correctly. Expand to matching overrides, account/character lists, profile import, grouping/expansion, and banking flags only when changed or implicated by a finding. Reuse automated matching evidence rather than manually repeating pattern assertions.
- [ ] **HUMAN** Check readable, correctly placed currency/HUD output and a relevant display/notification toggle. Exercise resource/location selection, empty-balance filtering, ordering, thresholds, positioning, and notification-only combinations when changed or implicated; do not exhaust every combination routinely.
- [ ] **HUMAN** Use a normal inventory change to confirm counts/capacities/notifications update without stale UI or duplicate output, and a real settings toggle to check lifecycle wiring. Expand to craft/subscriber/unrelated bags when filtering or those paths changed or a finding warrants it. Record unavailable bag types; synthetic callbacks do not prove ESO delivery.
- [ ] **HUMAN** Perform an intended deposit and withdrawal; confirm quantities/direction and player-opened interaction gating. Add restocking, stack merging, crafted-item, house-chest, full-bag, unavailable-item, or combat/restriction scenarios when their paths changed or source review raises a concern. Record actual scenarios and outcomes.
- [ ] **HUMAN** Observe panel restoration and absence of spurious notifications during the baseline reload/bank/editor use. Add cutscene/restricted-activity/loading-transition scenarios when affected by changes/findings; prohibited-functionality source review remains required even when those activities are not manually exercised.
- [ ] **HUMAN** Collision testing is required only when loading/warning code changes or a finding warrants it; otherwise reference prior evidence or record why no new run is needed. When required, back up saved variables, temporarily enable DEV and release without transfers, and check the centred persistent warning and Close button, both load orders where practical, then normal loading after disabling one copy. Never use the dual-loaded session for the suite or other functional tests.
- [ ] **HUMAN** Additional compatibility/performance tests are conditional on changes/findings, not a routine matrix. If run, record workload, data size, repetitions, timing method, measurements, acceptance rationale, and whether state can change. Identify carried-forward evidence, accepted limitations, and untested scenarios explicitly.

<Human scenarios, setup limitations, results, and complete diagnostic reports.>

## Review conclusion

<Summarize findings, Live-only testing scope, the author's consolidated declaration, carried-forward evidence, and limitations; list unresolved requirements or follow-up. Approve only when mandatory checks, essential functional evidence, and applicable author confirmations are complete. Explain conditional checks not rerun and any accepted performance/best-practice exceptions. Identify delegated final ZIP verification, which must succeed before upload. PTS being untested is not an approval blocker.>
