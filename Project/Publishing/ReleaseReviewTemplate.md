# ESOUI Release Standards Review

Use this template for any ESO add-on, regardless of its features, test framework, or release tooling. Complete the review for an identified, frozen release candidate, not a changing development checkout. Record where the completed report is saved. The timestamp is an audit record, not a freshness gate.

Reviewed (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Reviewer: <AI assistant and model name, if available; do not guess>
Checked by: <human author/checker>
Add-on: <add-on name>
Release version: <manifest version>
Candidate SHA256: <candidate SHA256>
Candidate identity method: <archive hash or deterministic file-set hash; describe how to reproduce>
Report location: <completed report location>
Review status: <PENDING or APPROVED>

Testing scope: Live by default. Record PTS as untested unless the tester reports PTS testing; record any such evidence separately. PTS is not required for approval; compatibility is not claimed without evidence.

## Review method and evidence

This template is the self-contained result of the release-guidance research, incorporating the upload rules, prohibited-functionality/removal guidance, release and coding best practices, manifest/structure rules, dependency checks, event filters, saved variables, and patch/takeover requirements. Do not fetch guidance pages, search for similar add-ons, or repeat that research as a release-review step. A material policy or permission question that the recorded requirements cannot settle remains `UNRESOLVED`; the author must supply a documented decision before approval.

Each check below has an evidence owner:

- **AI**: source, manifest, archive, or supplied-document inspection. Cite candidate-relative files/symbols and the finding; inspection does not prove runtime behavior.
- **TEST**: discover the add-on's existing unit, integration, diagnostic, and performance tests and their supported invocation. AI may execute suitable offline tests; a human runs tests requiring ESO. Record who ran each test, the environment, command/workload, candidate identity, and actual output. Never assume a particular command/framework or claim an in-game run without supplied results.
- **HUMAN**: author/uploader confirmation or in-game observation that code inspection and synthetic tests cannot establish. Name the person and record actual evidence.

For **every checkbox**, record `PASS`, `ISSUE`, `UNRESOLVED`, or `N/A` with a reason and evidence. A checked box means assessed, not necessarily passed. When a check has multiple owners, provide each applicable owner's evidence. Mark absent features N/A; do not require an add-on to implement features just to satisfy this template. Attach test output once and reference the relevant cases in each section rather than duplicating transcripts or manually repeating automated assertions.

The source review covers the complete candidate. Keep routine human testing to a short representative normal-use check, using the project's documented minimum when available. Additional scenarios require a specific relevant change, source-review finding, or reported problem, not an exhaustive matrix on every release. Missing automated tests are a coverage limitation to assess, not an automatic requirement to build a new suite, alter the frozen candidate, or add manual checks for every gap.

Use a project-supplied reviewer reference, if available, to locate test commands, coverage, and known risk areas quickly. Verify it against the candidate; it is navigation/context, not proof of compliance or a replacement for reviewing the code.

Prior human evidence for unchanged behavior may be reused with its candidate identity, date, and an explanation of continued applicability; never relabel it as a fresh run or hide incomplete output. Do not approve with a failed functional test, missing essential evidence, or a material unresolved compliance/safety question. Performance outliers follow the investigation process below rather than automatically blocking release.

If candidate bytes change, assign a new identity, review the changes and their impact, and repeat affected tests plus a basic load/smoke check. Reuse unaffected human evidence only with explicit provenance and an applicability rationale; broaden testing when impact is widespread or uncertain. Approval of a candidate, verification of its final archive, and readiness to publish are separate milestones. Structural checks on a report cannot establish that its evidence is adequate or its conclusions are true.

## Release process

- [ ] **AI + HUMAN** Record how the intended files were staged and frozen, the candidate installation path, version, reproducible SHA-256 identity, and who verified the test installation. Confirm that no other development/release copy of the same add-on is loaded and the tested bytes match the candidate; subsequent development edits do not invalidate an unchanged candidate.

<Actual release process and candidate identity.>

## Mandatory requirements

### Package and installation

- [ ] **AI** Confirm the intended top-level add-on folder(s), matching manifest basenames, and every required runtime file present exactly once at its intended path. For an existing archive, record filename, format (ZIP or RAR), hash, extraction verification, and comparison with the frozen candidate. If the release workflow produces the archive after candidate approval, identify the tool/person responsible for final content/byte verification and require its success before upload. Do not claim a not-yet-produced archive was inspected.
- [ ] **AI** Exclude executables unless a documented ESOUI exception permits them; exclude nested ZIP/RAR archives, `wowmatrix.dat`, hidden/OS/version-control/editor files, SavedVariables, generated API files, backups, and unrelated project files. Under an approved executable/non-addon-file exception, require purpose/file-access disclosure and, for executables, source code and the required VirusTotal report supplied by the uploader.
- [ ] **AI + HUMAN** Confirm any upload-form-required image is JPG, PNG, or GIF, and installation help is included when installation is not straightforward. Human confirms the actual form requirements; AI checks the supplied assets/help.
- [ ] **AI + HUMAN** If this is a compilation, list all included add-ons in the description. If a WTF folder is included, replace personal information with generic information and inspect the submitted copy.

### Listing, rights, and uploader certifications

AI inspects the supplied final listing and materials. Use one consolidated author declaration for the applicable certifications below, reusing an existing explicit assertion when available. Ask one grouped confirmation only for facts not already supplied; do not ask a separate question per checkbox. Attribute the declaration to the named author/uploader, not independent AI verification. Do not invent agreement, infer permission from unobjectionable code, or ignore contradictory evidence. Retain the declaration and supporting license/permission details as one evidence item.

- [ ] **AI + HUMAN** The description accurately explains the submitted functionality and installation, lists every required dependency at or near the beginning, and uses English where practical. Update details belong in the Changelog, not in place of the description. For console-only releases, state platform support in the name and description.
- [ ] **HUMAN** Reference the author's assertion that the submitted files are free of viruses, trojans, spyware, malware, and worms to their knowledge; include ToS/Add-on Terms conformity in the single consolidated confirmation if not already supplied.
- [ ] **AI + HUMAN** The add-on is free of charge (including elsewhere), has no paid/trial/time limit, and contains no advertisements, promotions, or nag screens. Submitted code, description, credits, and images are neither harmful nor offensive; names/descriptions contain no profanity.
- [ ] **AI + HUMAN** The uploader owns or has submission permission for all material. Credit borrowed code, concepts, assets, and information, including material identified through AI-assisted research; record applicable licenses/permissions. The author confirms they can maintain the resulting code.
- [ ] **AI + HUMAN** If AI generated code the author cannot personally verify as correct, efficient, maintainable, and safe, place AI disclosure at the beginning of the description. Disclosure is optional for ideation-only use when the author wrote and validated the final code. Record which case applies.
- [ ] **HUMAN** For a patch/takeover of another author's add-on, record the license, original-author contact and response, and required permission before proceeding. An unanswered request is not permission; unresolved authorization blocks approval.
- [ ] **HUMAN** Confirm the listing's patch/companion-add-on option matches the author's intent and that the author monitors ESOUI private messages for moderator requests. Confirm the submission meets the upload requirements assessed in this report.

### Supported functionality

AI traces relevant call paths for the functionality actually implemented. Human checks applicable real interaction/restriction behavior in the in-game section; synthetic tests alone do not prove live action safety.

- [ ] **AI** No gameplay actions run before entering the world or during character selection/creation, loading screens, Crown Store use, scrying, or Tales of Tribute. Necessary add-on initialization is distinct from performing gameplay actions.
- [ ] **AI** No player movement, combat actions, skill casts, movement/combat keybind activation, or quickslot use is triggered by the add-on.
- [ ] **AI** The player initiates interactions; the add-on does not start them. Any actions performed within an interaction use supported APIs, including the required protected-call mechanism, and stop when the interaction or permission is no longer valid.
- [ ] **AI** Public chat is never sent automatically; text may only be prepared for the player to send. Local diagnostic/chat-window output is not public-chat transmission.
- [ ] **AI** No bypass of combat/gameplay restrictions, private/locked API use, or loophole exploits. If a feature's permissibility is unresolved, require a supplied ESOUI/ZOS clarification before approval rather than inventing an exception.
- [ ] **AI** No real-time external-service communication or prohibited group-data exchange through MapPings or other workarounds. Runtime file access uses supported saved-variable APIs only; any external non-real-time client must not modify files held in memory by the running game.
- [ ] **AI** Runtime-loaded code/assets use supported Lua, XML, and DDS formats plus the manifest, stay within `live/AddOns`, and are no more than three subfolder levels below the manifest. Distinguish runtime-loaded assets from permitted archive documentation/images.
- [ ] **AI** No malicious/disruptive behavior or control of another player's actions. No custom sounds/videos, unsupported external 3D objects, prohibited nameplate/restricted-UI changes, or 2D-projection workaround for restricted 3D markers; any markers use supported APIs and respect location restrictions.

### Manifest and dependencies

- [ ] **AI** Use `.txt` for PC-only or `.addon` for console support, not both for the same add-on. The UTF-8 manifest has no BOM. Every line is at most 301 bytes; comment lines must also stay within 1,024 characters (the stricter byte limit still applies).
- [ ] **AI** Require `Title`, positive-integer `AddOnVersion`, `APIVersion` (one or two integer values), and the ESOUI/Minion `Version`. Directives use `## Name: value`; repeated directives are used only where supported. Required dependencies use space-separated `Name>=integer` entries; optional dependencies must not become required.
- [ ] **AI** Resolve every manifest/XML include relative to its containing file, confirm existence and intended load order, and inspect any variable expansion or special-folder usage. Assess platform-specific directives if present.
- [ ] **AI + TEST** Determine whether existing diagnostics report the running API/game build; otherwise use supplied in-game details. Compare the observed Live API with the candidate's `APIVersion` and record the actual tested scope. PTS is untested and not required for approval; do not claim PTS compatibility. Do not alter a frozen candidate just to add discovery or infer newest published versions from local evidence.
- [ ] **AI + TEST** Determine how dependency versions are reported, using diagnostics or supplied local manifests. Compare installed integer `AddOnVersion` values with required minimums. An installed version is not proof of the newest published version. Record tested versions and minimum-version rationale; consider relevant fixes and obsolete bundled libraries/LibStub patterns. Mark N/A if there are no dependencies.
- [ ] **AI + HUMAN** For optional dependencies, inspect absence guards and test loading without them. Mark N/A if there are none.

<Results and evidence for each mandatory check.>

## Code quality and automated evidence

Review the complete candidate code, manifest, XML, and relevant configuration, not just changed files. Discover the implemented behavior first, then map existing tests to the checks below. Reference actual case names/results, not assumed test names or a suite total alone. Record absent, skipped, conditional, mocked-only, or unavailable coverage and explain how remaining risks are assessed.

### Test discovery and coverage

- [ ] **AI + TEST** Identify available test entry points, setup requirements, isolation/cleanup behavior, and whether execution is offline, in-game, synthetic, read-only, or state-changing. Assess whether it is safe to run each test before doing so; do not run destructive benchmarks on live data. Include results of applicable safe tests and state explicitly when no suite exists.
- [ ] **AI** Map tests to core behavior, persistence, lifecycle, error/recovery paths, and performance. Distinguish testing the real implementation from testing mocks or mirrored expectations. Explain significant gaps and the targeted inspection/human evidence used instead; recommend new tests only where justified by risk, not merely to satisfy a fixed checklist.

### Initialization, naming, and saved data

- [ ] **AI** Prefer locals and one prefixed add-on global table; prefix necessary saved-variable, control, binding, scene, dialog, and event namespace names. Explain necessary global exceptions and material maintainability concerns.
- [ ] **AI** Initialize saved variables only after the matching `EVENT_ADD_ON_LOADED`, check the add-on name, and unregister completed initialization callbacks. Use supported saved-variable wrappers, appropriate account/character-ID scope, and an intentional NA/EU sharing policy.
- [ ] **AI + TEST** Determine which tests cover defaults, persistence, scope isolation, malformed/older data, and preservation of unrelated user settings. Review migrations/import/export/cleanup only if implemented or changed; require evidence for material migration risks without mutating live saved data. Reference applicable test results and document gaps.

### Core behavior and correctness

- [ ] **AI + TEST** Identify the add-on's main responsibilities and expected outcomes from its code and supplied documentation. Trace representative normal, empty, invalid, boundary, repeated, and interrupted operations as applicable. Determine which existing tests exercise these paths and include their results; record untested paths and material defects.
- [ ] **AI** Review assumptions about API availability, permissions, optional features, state validity, and operation ordering. Check explicit failure handling, recovery, and user-data integrity. Record concrete limitations and maintainability concerns without claiming the code is bug-free.

### Events and lifecycle

- [ ] **AI + TEST** Inventory event listeners, hooks, periodic updates, and delayed callbacks. Assess their lifecycle, shared consumers, duplicate prevention, cancellation/cleanup, and stale-state or re-entrant behavior as applicable. Determine which existing tests cover enabling/disabling features, repeated initialization, and pending work; include their results and coverage gaps. Always-on registrations may be justified by their purpose and cost.
- [ ] **AI + TEST** For frequently firing events, review applicable filters, matching namespace/event IDs, supported parameters, and successful application. Avoid duplicate filter types on one registration; use distinct namespaces where distinct values require them. Assess debounce/coalescing/throttling or other mitigation without assuming every listener needs it. Include relevant test results and distinguish synthetic invocation from real game delivery.

### User interface and configuration

- [ ] **AI + TEST** Where present, inspect settings, controls, commands, and other user entry points for valid defaults, bounds, state changes, and consistency with documented behavior. Determine which existing tests cover them and reference results. Mark UI/configuration checks N/A for add-ons that do not provide them.
- [ ] **AI + TEST** Where present, review formatting/localization, messages, notification frequency, visibility/restoration, and separation of local output from public communication. Include relevant existing test results; distinguish data/format assertions from rendering, usability, and actual input handling that require human observation.

### Performance and queued operations

- [ ] **AI + TEST** Determine what performance tests or monitoring exist and whether their workloads represent the add-on's likely costs. Inspect potentially expensive routines: high-frequency callbacks, repeated/bulk work, allocations, polling, data-heavy APIs, and queued/retried operations. Assess scaling, per-frame work, queue bounds, retry limits, ordering, cancellation, and backlog recovery where applicable. Reference lifecycle findings rather than repeating them.
- [ ] **AI + TEST** Assess how identified costs are mitigated through filtering, debounce, coalescing, caching, batching, bounded work, or other appropriate design, and how well existing tests exercise those mitigations. It is acceptable to cite a specific code comment as the author's assertion that monitoring or a mitigation is unnecessary, impractical, or would compromise behavior. Record its location and rationale as attributed evidence, not measured proof; accept it when consistent with the code and risk. Do not demand instrumentation or debounce for every routine, and do not let an assertion override contradictory behavior or material risk.
- [ ] **AI + TEST** For available measurements, record workload/data size, repetitions, timing method, environment, measured values, and the limits used by the frozen suite or agreed before testing; do not impose universal millisecond targets. Preserve timing-only FAIL/outlier results, repeat under comparable conditions where useful, compare prior measurements, and assess gameplay impact. Document accepted exceptions and missing measurements; unexplained material regressions or stalls block approval. Do not mutate live data to obtain benchmarks.

<Per-section evidence references, findings, and uncovered paths.>

## Human in-game testing

Use a short representative normal-use check based on the add-on's responsibilities and any project-specific minimum. Ask whether problems occurred and use exception-only environment reporting where the project defines defaults. Label unconfirmed defaults as reporting assumptions, not verified observations; explicit reports and diagnostics take precedence. Record unavailable features without requiring the tester to acquire access. Prefer existing diagnostic metadata and reviewer-side candidate verification to repeated questions. There is no prescribed feature list, test command, number of test runs, or benchmark workload. Record other enabled add-ons from available diagnostics; require dependency-only isolation only for a failure or suspected interaction. Live is the only required client; default to no PTS testing unless reported and record any PTS evidence separately.

- [ ] **HUMAN + TEST** Record tester, UTC time, Live client/API/build, candidate identity, dependencies, and relevant settings. Supply available test output once, including cases, warnings/failures, totals, timings, and conditional coverage. Obtain missing metadata through suitable in-game observation; runtime discovery does not establish the candidate's cryptographic identity.
- [ ] **HUMAN** Perform representative normal use of the main feature(s), including a real event-driven or queued path if present. Record actions, expected/observed outcomes, errors, stale state, or duplicated effects. Choose safe actions the tester intends; do not create destructive/live-state benchmarks or assume features absent from the add-on.
- [ ] **HUMAN** Require separate UI/output, settings/command-input, or reload/persistence checks only for a specific relevant change, source-review finding, or reported problem. Otherwise record that these were not separately exercised, with the risk-based rationale; do not treat them as routine prerequisites or claim automated logic/format checks prove rendering or input wiring. Mark absent features N/A.
- [ ] **HUMAN** Add edge, interruption/recovery, migration, restriction, pending-work cancellation, or compatibility scenarios only where changes/findings warrant them. Use backed-up, restorable fixtures for risky persistence tests; add-on profiles alone do not isolate saved data. Do not routinely require clean-data, cross-server, alternate-load-order, or deliberate dual-installation tests.
- [ ] **HUMAN** Record additional performance/compatibility observations if justified, their method and state-changing potential, and any untested scenarios, carried-forward evidence, or accepted limitations. Unavailable features/environments are disclosed, not invented as tested; PTS remains optional and unclaimed.

<Human scenarios, setup limitations, results, and complete diagnostic reports.>

## Review conclusion

<Summarize findings, Live-only testing scope, the author's consolidated declaration, carried-forward evidence, and limitations; list unresolved requirements or follow-up. Approve only when mandatory checks, essential functional evidence, and applicable author confirmations are complete. Explain conditional checks not rerun and any accepted performance/best-practice exceptions. Identify delegated final ZIP verification, which must succeed before upload. PTS being untested is not an approval blocker.>
