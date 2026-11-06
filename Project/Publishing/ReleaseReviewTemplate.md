
# ESOUI Release Standards Review

Use this template for any ESO add-on, regardless of its features, test framework, or release tooling. The report layout and review standards are together here: the standards are listed in the checks table. The release checklist defines the process. The timestamp is an audit record, not a freshness gate.

##Review for release of Add-On-Name
Status: [Not Approved]
Reviewed (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Reviewer: <AI assistant and model name, if available; do not guess>
Add-on: <add-on name>
Reviewed source: <DEV commit or source identity>
Baseline review: <approved report location, source/candidate version and identity, review date; NONE for a full review without a baseline>
Review mode: <DELTA or FULL>
Release version: <agreed major.minor.patch version>
Candidate SHA256: <filled after staging>
Report location: Project\Publishing\Current release\ReleaseReview.md
Review status: <COMPLETE - findings present / COMPLETE - no findings / INCOMPLETE>

Set Status to `[Approved to Test]` only when there are no failed or unresolved checks and every remaining Pending item requires test deployment to assess. Otherwise leave it `[Not Approved]`. After test deployment, set Status to `[Approved for Release]` only when all checks pass, no findings remain unresolved, and no Pending items remain. Neither status substitutes for the separate GO to stage or GO for UAT.



### Review scope

- [ ] Record the reviewed DEV source identity and comparison baseline. Use DELTA for routine reviews with an identifiable approved baseline; explain FULL for a first baseline, unavailable/unverifiable baseline, broad architectural changes, or a specific concern requiring complete inspection. A previous ZIP or test report alone is not an approved source-review baseline.

### Checks performed and results

Complete one row for every applicable criterion. Enter `Yes` or `No` in Changed. Enter `PASS`, `FAIL`, `PENDING`, `UNRESOLVED`, or `N/A` in Result, with concise rationale and evidence. Use `PENDING` for a review-form criterion not yet assessable because required evidence is outstanding; do not infer a result or mark unperformed tests `FAIL`. In the Pending items subsection, list only review-form criteria whose result is `PENDING`, not tests or metrics as standalone items. Tests, metrics, and process steps/approvals may be mentioned only as missing evidence explaining why a criterion is pending. Use `FAIL` only when an assessed criterion actually failed. A `No` may pass by a cited prior review only when the relevant files and behavior are unchanged. A `Yes` requires assessment of the current source/materials; tests alone are not a pass. Preserve the template's prefilled results, especially author certifications; only populate blank fields unless an existing result is explicitly authorized for revision.

| Check | Changed | Result |
|---|---|---|
| **Package and installation:** Confirm the intended top-level add-on folder(s), matching manifest basenames, and every required runtime file present exactly once at its intended path. For an existing archive, record filename, format (ZIP or RAR), hash, extraction verification, and comparison with the frozen candidate. If the release workflow produces the archive after candidate approval, identify the tool/person responsible for final content/byte verification and require its success before upload. Do not claim a not-yet-produced archive was inspected. |  |  |
| **Package and installation:** Exclude executables unless a documented ESOUI exception permits them; exclude nested ZIP/RAR archives, `wowmatrix.dat`, hidden/OS/version-control/editor files, SavedVariables, generated API files, backups, and unrelated project files. Under an approved executable/non-addon-file exception, require purpose/file-access disclosure and, for executables, source code and the required VirusTotal report supplied by the uploader. |  |  |
| **Package and installation:** Required upload files are the ReadMe, Changelog, and ZIP file. Verify that each final artifact is present and correct. |  |  |
| **Package and installation:** If this is a compilation, list all included add-ons in the description. If a WTF folder is included, replace personal information with generic information and inspect the submitted copy. |  |  |
| **Listing, rights, and uploader certifications:** The listing prominently identifies the current release version, and the description accurately explains the submitted functionality and installation, lists every required dependency at or near the beginning, and uses English where practical. Update details belong in the Changelog, not in place of the description. For console-only releases, state platform support in the name and description. |  | See documentation review |
| **Listing, rights, and uploader certifications:** Record the author's assertion that the submitted files are free of viruses, trojans, spyware, malware, and worms to their knowledge; include ToS/Add-on Terms conformity in the single consolidated confirmation if not already supplied. |  | Certified by @Tim-P |
| **Listing, rights, and uploader certifications:** The add-on is free of charge (including elsewhere), has no paid/trial/time limit, and contains no advertisements, promotions, or nag screens. Submitted code, description, credits, and images are neither harmful nor offensive; names/descriptions contain no profanity. |  | Certified by @Tim-P |
| **Listing, rights, and uploader certifications:** The uploader owns or has submission permission for all material. Credit borrowed code, concepts, assets, and information, including material identified through AI-assisted research; record applicable licenses/permissions. The author confirms they can maintain the resulting code. |  | Certified by @Tim-P |
| **Listing, rights, and uploader certifications:** If AI generated code the author cannot personally verify as correct, efficient, maintainable, and safe, place AI disclosure at the beginning of the description. Disclosure is optional for ideation-only use when the author wrote and validated the final code. Record which case applies. |  | See documentation review |
| **Listing, rights, and uploader certifications:** For a patch/takeover of another author's add-on, record the license, original-author contact and response, and required permission before proceeding. An unanswered request is not permission; unresolved authorization blocks approval. |  | Certified by @Tim-P |
| **Listing, rights, and uploader certifications:** Confirm the listing's patch/companion-add-on option matches the author's intent and that the author monitors ESOUI private messages for moderator requests. Confirm the submission meets the upload requirements assessed in this report. |  | Certified by @Tim-P |
| **Supported functionality:** No gameplay actions run before entering the world or during character selection/creation, loading screens, Crown Store use, scrying, or Tales of Tribute. Necessary add-on initialization is distinct from performing gameplay actions. |  |  |
| **Supported functionality:** No player movement, combat actions, skill casts, movement/combat keybind activation, or quickslot use is triggered by the add-on. |  |  |
| **Supported functionality:** The player initiates interactions; the add-on does not start them. Any actions performed within an interaction use supported APIs, including the required protected-call mechanism, and stop when the interaction or permission is no longer valid. |  |  |
| **Supported functionality:** Public chat is never sent automatically; text may only be prepared for the player to send. Local diagnostic/chat-window output is not public-chat transmission. |  |  |
| **Supported functionality:** No bypass of combat/gameplay restrictions, private/locked API use, or loophole exploits. If a feature's permissibility is unresolved, require a supplied ESOUI/ZOS clarification before approval rather than inventing an exception. |  |  |
| **Supported functionality:** No real-time external-service communication or prohibited group-data exchange through MapPings or other workarounds. Runtime file access uses supported saved-variable APIs only; any external non-real-time client must not modify files held in memory by the running game. |  |  |
| **Supported functionality:** Runtime-loaded code/assets use supported Lua, XML, and DDS formats plus the manifest, stay within `live/AddOns`, and are no more than three subfolder levels below the manifest. Distinguish runtime-loaded assets from permitted archive documentation/images. |  |  |
| **Supported functionality:** No malicious/disruptive behavior or control of another player's actions. No custom sounds/videos, unsupported external 3D objects, prohibited nameplate/restricted-UI changes, or 2D-projection workaround for restricted 3D markers; any markers use supported APIs and respect location restrictions. |  |  |
| **Manifest and dependencies:** Use `.txt` for PC-only or `.addon` for console support, not both for the same add-on. The UTF-8 manifest has no BOM. Every line is at most 301 bytes; comment lines must also stay within 1,024 characters (the stricter byte limit still applies). |  |  |
| **Manifest and dependencies:** Require `Title`, positive-integer `AddOnVersion`, `APIVersion` (one or two integer values), and the ESOUI/Minion `Version`. Directives use `## Name: value`; repeated directives are used only where supported. Required dependencies use space-separated `Name>=integer` entries; optional dependencies must not become required. |  |  |
| **Manifest and dependencies:** Resolve every manifest/XML include relative to its containing file, confirm existence and intended load order, and inspect any variable expansion or special-folder usage. Assess platform-specific directives if present. |  |  |
| **Manifest and dependencies:** Check the manifest's `APIVersion` and dependency declarations against available source/local evidence. Record any runtime API or installed-dependency version comparison for the later in-game/release test phase; do not claim a runtime version was observed without evidence or infer newest published versions from local files. |  |  |
| **Manifest and dependencies:** Check dependency minimums and relevant fixes or obsolete bundled-library/LibStub patterns from available evidence. Mark N/A if there are no dependencies. |  |  |
| **Manifest and dependencies:** For optional dependencies, inspect absence guards. Record optional-dependency load testing as later supporting evidence when needed; mark N/A if there are no optional dependencies. |  |  |
| **Test discovery and coverage:** Identify existing test coverage relevant to changed or specifically risky behavior, and distinguish real implementation coverage from mocks or mirrored expectations. Tests are supplementary evidence; do not require execution of unrelated tests or a new suite just to satisfy this checklist. |  |  |
| **Test discovery and coverage:** Note significant gaps or environmental limits that affect the review, and explain what source/integration paths were inspected instead. Recommend new tests only where justified by risk, not merely to satisfy a fixed checklist. |  |  |
| **Initialization, naming, and saved data:** Prefer locals and one prefixed add-on global table; prefix necessary saved-variable, control, binding, scene, dialog, and event namespace names. Explain necessary global exceptions and material maintainability concerns. |  |  |
| **Initialization, naming, and saved data:** Initialize saved variables only after the matching `EVENT_ADD_ON_LOADED`, check the add-on name, and unregister completed initialization callbacks. Use supported saved-variable wrappers, appropriate account/character-ID scope, and an intentional NA/EU sharing policy. |  |  |
| **Initialization, naming, and saved data:** Review defaults, persistence, scope isolation, malformed/older data, and preservation of unrelated user settings where changed or otherwise in scope. Review migrations/import/export/cleanup only if implemented or changed. Cite prior or relevant test evidence when available; assess material migration risks without mutating live saved data. |  |  |
| **Core behavior and correctness:** Identify the add-on's main responsibilities and expected outcomes from its code and supplied documentation. Trace representative normal, empty, invalid, boundary, repeated, and interrupted operations as applicable. Inspect changed paths and callers; cite relevant prior or current test evidence only as supporting context, and record material defects or limitations. |  |  |
| **Core behavior and correctness:** Review assumptions about API availability, permissions, optional features, state validity, and operation ordering. Check explicit failure handling, recovery, and user-data integrity. Record concrete limitations and maintainability concerns without claiming the code is bug-free. |  |  |
| **Events and lifecycle:** Inventory relevant event listeners, hooks, periodic updates, and delayed callbacks. Assess their lifecycle, shared consumers, duplicate prevention, cancellation/cleanup, and stale-state or re-entrant behavior as applicable. For changed paths, inspect registrations and teardown directly; cite existing tests as supporting evidence and note relevant gaps. Always-on registrations may be justified by their purpose and cost. |  |  |
| **Events and lifecycle:** For frequently firing events, review applicable filters, matching namespace/event IDs, supported parameters, and successful application. Avoid duplicate filter types on one registration; use distinct namespaces where distinct values require them. Assess debounce/coalescing/throttling or other mitigation without assuming every listener needs it. Distinguish code inspection and synthetic invocation from actual game event delivery. |  |  |
| **User interface and configuration:** Where present, inspect settings, controls, commands, and other user entry points for valid defaults, bounds, state changes, and consistency with documented behavior. Cite relevant existing tests as supporting evidence. Mark UI/configuration checks N/A for add-ons that do not provide them. |  |  |
| **User interface and configuration:** Where present, review formatting/localization, messages, notification frequency, visibility/restoration, and separation of local output from public communication. Distinguish code/data inspection from rendering, usability, and actual input handling that require later human observation. |  |  |
| **Performance and queued operations:** Inspect potentially expensive routines affected by changes or presenting a specific risk: high-frequency callbacks, repeated/bulk work, allocations, polling, data-heavy APIs, and queued/retried operations. Assess scaling, per-frame work, queue bounds, retry limits, ordering, cancellation, and backlog recovery where applicable. Reference lifecycle findings rather than repeating them. |  |  |
| **Performance and queued operations:** Assess how identified costs are mitigated through filtering, debounce, coalescing, caching, batching, bounded work, or other appropriate design. Existing measurements may support the assessment but are not required for every routine. Do not demand instrumentation or debounce without a concrete risk. |  |  |
| **Performance and queued operations:** For relevant existing measurements, record workload/data size, repetitions, timing method, environment, measured values, and the limits used; do not impose universal millisecond targets. Preserve timing-only failures/outliers and assess gameplay impact when material. Do not mutate live data to obtain benchmarks. |  |  |

### Test results

- <x>/<y> synthetic tests passed, or PENDING until run
- <x>/<y> user driven unit tests passed, or PENDING until run
- In-game UAT: PENDING until performed; then record only actual results and observations

### Summary

<Brief overall review status; keep findings and pending actions in the adjacent sections.>

### Findings

- <Finding and evidence, or "No findings identified in the assessed scope.">

### Pending items

- <List only review-form criteria whose result is PENDING, and state that each requires test deployment. Tests and metrics may appear only as missing evidence for a criterion, not as standalone items. Use "- None." when no review criteria are pending.>

### Documentation review

| Document | Check | Result |
|---|---|---|
| `Project/Publishing/Source Documents/ReadMe-Header.bbcode` | Does the listing header prominently identify the current release version and required dependency (name and minimum version), and include the required AI disclosure when applicable? |  |
| `Project/Publishing/Source Documents/ReadMe-Body.bbcode` | Is the feature overview accurate and up to date with the current implemented add-on? |  |
| `Project/Publishing/Source Documents/Changelog.bbcode` | Does the changelog accurately cover all cumulative unreleased changes, with the newest version first? |  |

### Version recommendation

<Recommend the next major.minor.patch version and briefly explain why, based on the cumulative changes. Mark PENDING until the author agrees the version; a recommendation is not agreement or authorization to change metadata.>

### Changes reviewed

- List the examined `.lua` and `.xml` files and the names of methods changed. Include relevant callers/data flows examined; use an appendix if the list is long. Do not list non-Lua/XML files in this section.
(verbatim): No other code changes were present and so they were not rechecked.