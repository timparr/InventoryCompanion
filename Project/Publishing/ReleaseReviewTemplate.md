# ESOUI Release Standards Review

Complete this review for the exact frozen release candidate, not a changing development checkout. Save the completed review as `ReleaseReview.md` in the development root. The timestamp is an audit record, not a freshness gate.

Reviewed (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Reviewer: <AI assistant and model name, if available; do not guess>
Checked by: <human author/checker>
Release version: <manifest version>
Candidate SHA256: <candidate SHA256>
Review status: <PENDING or APPROVED>

## Review method and evidence

This template is the self-contained result of the release-guidance research, incorporating the upload rules, prohibited-functionality/removal guidance, release and coding best practices, manifest/structure rules, dependency checks, event filters, saved variables, and patch/takeover requirements. Do not fetch guidance pages, search for similar add-ons, or repeat that research as a release-review step. A material policy or permission question that the recorded requirements cannot settle remains `UNRESOLVED`; the author must supply a documented decision before approval.

Each check below has an evidence owner:

- **AI**: source, manifest, archive, or supplied-document inspection. Cite candidate-relative files/symbols and the finding; inspection does not prove runtime behavior.
- **TEST**: human runs `/ictest verbose copy` in ESO against the frozen candidate and supplies the complete report. AI assesses that output; it must not claim to have run ESO. The command intentionally opens a copyable Lua error report even when every test passes; judge the reported results, not the presence of the error window.
- **HUMAN**: author/uploader confirmation or in-game observation that code inspection and synthetic tests cannot establish. Name the person and record actual evidence.

For **every checkbox**, record `PASS`, `ISSUE`, `UNRESOLVED`, or `N/A` with a reason and evidence. A checked box means assessed, not necessarily passed. When a check has multiple owners, provide each owner's evidence. Reuse an evidence reference rather than repeating the same check in multiple sections. Recommendations may have a justified exception; mandatory requirements and required tests may not be waived without an applicable documented exception. Do not approve with missing results, a failed required test, or a material unresolved question.

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

AI inspects the supplied final listing and materials; the human uploader must personally confirm the certifications below. Do not infer ownership, permission, or distribution terms from the absence of suspicious code.

- [ ] **AI + HUMAN** The description accurately explains the submitted functionality and installation, lists every required dependency at or near the beginning, and uses English where practical. Update details belong in the Changelog, not in place of the description. For console-only releases, state platform support in the name and description.
- [ ] **HUMAN** To the uploader's knowledge, all submitted files are free of viruses, trojans, spyware, malware, and worms, and the files and their use conform to ZeniMax's Terms of Service and Add-on Terms.
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
- [ ] **AI + TEST** Include `Runtime and dependency discovery`, the report's running API and game build, and compare the API with the candidate's `APIVersion`. Identify whether the client is Live or PTS. A run proves compatibility only for that client/API; every additional advertised target needs its own supplied runtime evidence, not an assumption about the latest version.
- [ ] **AI + TEST** Include installed dependency integer versions from the report and compare each required minimum with the supplied dependency manifest's `AddOnVersion`. An installed version is not proof of the newest published version. Record the tested compatible minimum and rationale; consider raising it for relevant fixes and removing obsolete bundled libraries/LibStub patterns.
- [ ] **AI + HUMAN** For optional dependencies, inspect absence guards and test loading without them. Mark N/A if there are none.

<Results and evidence for each mandatory check.>

## Code quality and automated evidence

Review the complete candidate code, manifest, XML, and relevant configuration, not just changed files. For every TEST check below, include the named case results from the same complete report (or reference its evidence ID). A suite total alone is insufficient. Report conditional/unavailable coverage, not just the pass count.

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

- [ ] **AI + TEST** Include `Repeated 100-item inventory scan performance`, `100 repeated slot-rule matches`, `100 synthetic tracked-item slot updates`, and `Live read-only scan` results with measured/limit values: 20 synthetic scans of 100 items across 20 rules <= 500 ms; 100 slot-rule matches <= 100 ms; 100 synthetic tracked-item slot updates <= 200 ms; 100 live read-only scans <= 500 ms. Include occupied-entry count, bank-open state, and ESO Plus/craft-bag availability. Timing uses `GetGameTimeMilliseconds`; synthetic workloads must not transfer inventory or persist settings.
- [ ] **AI** Trace startup, user actions, repeated events, failure/recovery paths, and API assumptions not already covered above. Assess explicit error handling, repeated scans, allocations, inventory-size scaling, data-heavy API/server-wide cost, and maintainability. Record concrete defects/limitations without claiming the code is bug-free. Use local helper references where beneficial, not at the expense of clarity.

<Per-section evidence references, findings, and uncovered paths.>

## Human in-game testing

Run on the frozen candidate with only its intended dependencies first; record other enabled add-ons from discovery output and any subsequent compatibility runs. Back up saved variables before persistence/collision tests. Use only items and transfers the tester actually intends; no destructive/live-inventory benchmarks. Do not run `/icclean` as part of this review because it intentionally changes saved data.

- [ ] **HUMAN + TEST** Record tester, UTC time, client channel (Live/PTS), candidate identity, and relevant settings. Attach the complete `/ictest verbose copy` report, including discovery, every case, warnings/failures, totals, and timings. Run once with bank closed and once with a player-opened bank for live-scan coverage. Discovery reports runtime metadata, not a cryptographic candidate identity; human verifies the installation/hash separately.
- [ ] **HUMAN** On clean install and `/reloadui`, confirm initialization without unexpected Lua errors; settings and intended account/character scopes persist. Where migration changed, test old data using an isolated, restorable saved-variable fixture and verify retained values; an add-on profile alone does not isolate saved data. State unavailable account/server setups.
- [ ] **HUMAN** In the item/group editors, exercise matching and saved overrides, per-character/account lists, profile import, grouping/expansion, visibility, notification and banking flags. Confirm displayed counts and saved choices after reload. Reference automated matching evidence rather than repeating its pattern assertions.
- [ ] **HUMAN** In currency settings and HUDs, exercise resource/location selection, no selected locations, empty-balance filtering, ordering, panel/bar visibility, thresholds/colours, positioning, and notification-only settings. Confirm readable, correctly placed output and persistence; automated formatting tests do not prove rendering.
- [ ] **HUMAN** Verify real inventory-event delivery using intended backpack, craft-bag (if available), bank/subscriber-bank changes, plus an unrelated bag change where accessible. Confirm relevant counts/capacities/notifications update once without stale UI or duplicate output. Toggle consumers on/off through the real settings UI and confirm it wires the lifecycle tested above. State inaccessible bag types; synthetic callback invocation does not prove ESO filtering.
- [ ] **HUMAN** Exercise intended deposits, withdrawals, restocking/stack merging, crafted-item handling, and house-chest behavior where supported, including full bags and unavailable items. Confirm correct quantities/direction, no transfer outside a player-opened bank/chest, and safe restriction/combat handling. Record scenarios and actual outcomes, not a blanket "banking works."
- [ ] **HUMAN** Check reload/loading, cutscene, interaction, editor, and restricted-activity transitions: relevant panels hide/restore correctly, no prohibited gameplay action occurs, and load-time balance reports do not generate spurious notifications.
- [ ] **HUMAN** With saved variables backed up, enable DEV and release only to test the collision warning, without transfers. Confirm a prominent centred dialog after world entry, persistence until dismissal, and a working Close button; test both load orders where possible. Disable one copy and reload; confirm normal operation and no warning. Never use this invalid dual-loaded session for the suite or other functional tests.
- [ ] **HUMAN** Record any compatibility/performance observations beyond the suite, with workload, data size, repetitions, timing method, measurements, and acceptance limits chosen before testing. State whether each check is read-only/synthetic or can change inventory/settings; label untested scenarios explicitly.

<Human scenarios, setup limitations, results, and complete diagnostic reports.>

## Review conclusion

<Summarize material findings and limitations; list each unresolved requirement or follow-up. Approve only when mandatory checks, required tests, and human certifications are complete. Identify any delegated final ZIP verification, which must succeed before upload. Explain any best-practice exceptions and why they are acceptable.>
