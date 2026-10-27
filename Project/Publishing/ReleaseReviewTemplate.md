# ESOUI Release Standards Review

Complete this review for the exact frozen release candidate described below, not for a changing development checkout. Save the completed review as `ReleaseReview.md` in the development root. Treat the timestamp as an audit record, not a freshness gate. Do not approve while a mandatory requirement, required test, or material compliance question remains unresolved.

Reviewed (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Reviewer: <AI assistant and model name, if available; do not guess>
Checked by: <human author/checker>
Release version: <manifest version>
Candidate SHA256: <candidate identity>
Review status: <PENDING or APPROVED>

## Release process

Describe how the intended release files were copied, extracted into a clean staging installation, staged, and frozen before review. State the staging location or other identifying details as appropriate. Confirm that the version and candidate hash above identify those frozen files, and that review findings and test results below apply to this candidate. Do not describe the changing development checkout as the reviewed release.

-- Example --
## Release process

A copy of the intended release files was extracted into a clean staging installation, staged, and frozen as the review candidate. Its version and SHA-256 identity are recorded above. The review and release tests apply to that frozen copy; the candidate is not changed during review.

Only after the files were frozen were they assessed against ESOUI's mandatory upload rules and prohibited-functionality requirements, together with its release best-practice guidance:

- Mandatory upload rules: https://www.esoui.com/forums/showthread.php?t=11
- Mandatory prohibited-functionality requirements: https://www.esoui.com/forums/showthread.php?t=9865
- Release best practices: https://www.esoui.com/forums/showthread.php?t=10790
-- /Example --

<Record the actual release process and candidate identity.>

## Guidance reviewed

After freezing the candidate, check the current applicable guidance below. Record the date checked and whether each source was accessible/current. A failed or blocked fetch is unresolved, not evidence that the guidance is unchanged. Check conditional sources when applicable (for example, patch/takeover guidance only when modifying another author's add-on).

- Mandatory upload rules: [ESOUI upload rules](https://www.esoui.com/forums/showthread.php?t=11)
- Prohibited functionality: [What AddOns must not do](https://www.esoui.com/forums/showthread.php?t=9865); [add-on removal guidance](https://wiki.esoui.com/How_to_get_your_AddOn_removed)
- Release practices and AI disclosure: [ESOUI release rules and best practices](https://www.esoui.com/forums/showthread.php?t=10790)
- Code conventions: [ESOUI add-on coding best practices](https://www.esoui.com/forums/showthread.php?t=9867)
- Manifest and folder structure: [manifest format](https://wiki.esoui.com/Addon_manifest_%28.txt%29_format); [add-on structure](https://wiki.esoui.com/Addon_Structure)
- Runtime conventions: [event filters](https://wiki.esoui.com/AddFilterForEvent); [saved variables](https://wiki.esoui.com/Storing_data_and_accessing_files)
- API and dependency versions: [API versions](https://wiki.esoui.com/APIVersion); [dependency version checks](https://www.esoui.com/forums/showthread.php?t=11595)
- Conditional patch/takeover guidance: [original-author contact and add-on patch rules](https://www.esoui.com/forums/showthread.php?p=44591#post44591)
- Add-on licensing reference: [ZeniMax Add-on Terms](https://account.elderscrollsonline.com/add-on-terms)

<For each applicable source, record: checked date; current/access status; review result or limitation. Include any staff clarification relied on.>

## Findings against the guidance

For each applicable check, record the result and brief evidence in the report: `PASS`, `ISSUE`, `UNRESOLVED`, or `N/A` with a reason. A checked box means the check was completed, not automatically that it passed. Do not approve with an unresolved mandatory check or material compliance question.

### Mandatory Guidance

#### Upload and package requirements

Source: [ESOUI upload rules](https://www.esoui.com/forums/showthread.php?t=11).

- [ ] Provide the add-on as a ZIP or RAR archive; include a JPG, PNG, or GIF image when required by the upload form.
- [ ] Include a help file in the archive if the add-on is difficult to install.
- [ ] Ensure the description is informative and accurately describes the submitted files and functionality.
- [ ] Exclude executables unless the upload falls within an ESOUI-approved exception.
- [ ] Exclude `wowmatrix.dat`.
- [ ] Do not place additional ZIP or RAR archives inside the submitted archive.
- [ ] Remove hidden files and folders from the archive, including operating-system and version-control metadata.
- [ ] If this is a compilation, list the included add-ons in the description and exclude executables.
- [ ] If a WTF folder is included, replace all personal information with generic information.

#### Uploader certifications

The human author/uploader must confirm these statements; the reviewer should not infer them from code inspection alone.

- [ ] To the best of the uploader's knowledge, the files are free of viruses, trojans, spyware, malware, and worms.
- [ ] The uploader confirms that the submitted files and their use conform to ZeniMax's current Terms of Service.
- [ ] The add-on is free of charge and is not available elsewhere for a fee.
- [ ] The uploader owns the copyright to all submitted material or has permission to submit it.
- [ ] The add-on and its contents are not harmful or offensive.
- [ ] The add-on is free of advertisements, promotions, and nag screens.
- [ ] The add-on has no time limit and is not paid or trial software.
- [ ] The description accurately reflects the submitted files and their contents.
- [ ] The upload complies with the ESOUI upload rules above.

#### Functionality, AI disclosure, and dependencies

- Sources: [What AddOns must not do](https://www.esoui.com/forums/showthread.php?t=9865) and [Add-ons that can get removed](https://wiki.esoui.com/How_to_get_your_AddOn_removed). The checks below incorporate the supplied removal-guidance text; verify its current version when preparing a release review.

- [ ] Confirm the add-on does not act before entering the game world or during character selection, character creation, loading screens, Crown Store use, scrying, or Tales of Tribute.
- [ ] Confirm the add-on does not trigger player movement, combat actions, skill casts, movement/combat keybinds, or quickslot item use.
- [ ] Confirm the add-on does not start player interactions (such as banks, companions, scribing, or scrying); the player must initiate the interaction.
- [ ] Confirm the add-on does not directly send public chat messages; it may only prepare text for the player to send.
- [ ] Confirm the add-on does not bypass or alter game restrictions, including restrictions that apply during combat.
- [ ] Confirm the add-on does not perform real-time communication with external websites or services, or exchange group data through MapPings or another prohibited workaround.
- [ ] Confirm the add-on does not directly read or write files while running; in-game saved variables are accessed through supported APIs. If an external client uses saved variables for non-real-time exchange, confirm it does not modify files that the running game has in memory.
- [ ] Confirm the add-on does not bundle unsupported external files; code and assets use supported Lua, XML, and DDS formats (in addition to the required manifest), do not load files outside `live/AddOns`, and do not load files more than three subfolder levels below its add-on manifest.
- [ ] Confirm the add-on does not perform malicious actions, annoy or disrupt other players, or take control of another player's actions.
- [ ] Confirm it does not use private/locked APIs or exploit loopholes to bypass API or gameplay restrictions.
- [ ] If the add-on draws 3D markers, confirm it uses supported APIs and does not use 2D projection or another workaround to evade restrictions in dungeons or other restricted locations.
- [ ] Confirm the add-on does not play custom sounds or videos, introduce unsupported external 3D objects, or make prohibited changes to nameplates or other restricted game UI.
- [ ] If functionality may fall into a prohibited category or relies on an unsupported API, do not approve release until ESOUI staff and, where appropriate, ZeniMax Online Studios have clarified it.
- [ ] If AI generated code that the author cannot personally verify as correct, efficient, maintainable, and safe, disclose AI use at the beginning of the add-on description. If AI was used only for ideation and the author wrote and validated the final code, disclosure is optional.
- [ ] List every non-optional dependency clearly at or near the beginning of the add-on description so users know what is required to run the add-on.
- [ ] If this release patches or takes over another author's add-on, check its license and contact the original author first; wait for a response and obtain permission where required before proceeding. Follow [ESOUI's patch/takeover process](https://www.esoui.com/forums/showthread.php?p=44591#post44591).
- [ ] If an executable or other non-addon file is included under an ESOUI-approved exception, describe its purpose and file access in the listing. For executables, provide source code and a VirusTotal report as required by the guidance.

#### Manifest validity and structure

- Source: [ESOUI add-on manifest format](https://wiki.esoui.com/Addon_manifest_%28.txt%29_format). These checks reflect the supplied guidance excerpt; verify current details when preparing a release review.

- [ ] Use a `.txt` manifest for PC-only add-ons and a `.addon` manifest only when the add-on is intended to run on console.
- [ ] Do not ship both `.txt` and `.addon` manifests for the same add-on. Verify that the add-on folder and manifest naming follow the rules for the chosen platform and extension.
- [ ] Encode the manifest as UTF-8 without a byte-order mark (BOM).
- [ ] Ensure every manifest line is no longer than 301 bytes; split long directive values across repeated directives where supported.
- [ ] Include valid `Title`, positive-integer `AddOnVersion`, and `APIVersion` directives; include the ESOUI/Minion `Version` directive when publishing there.
- [ ] Verify `APIVersion` against current Live and, where applicable, PTS API versions; use no more than two API values.
- [ ] Use the required `## ` directive prefix and a space after each directive colon; check directive names and values against the manifest guidance.
- [ ] Keep manifest comment lines within the documented 1,024-character limit.
- [ ] Verify all listed files and paths exist, are relative to the manifest, and appear in the intended load order; check any variable expansion or special-folder usage.
- [ ] Confirm the release archive's folder structure and manifest filename meet ESOUI's add-on structure rules.

### Best-practice guidance

- These are recommendations in the guidance; assess applicability and record material risks or reasons a recommendation does not apply.
- Source: [ESOUI release rules and best practices](https://www.esoui.com/forums/showthread.php?t=10790), [add-on coding best practices](https://www.esoui.com/forums/showthread.php?t=9867), and [dependency version guidance](https://www.esoui.com/forums/showthread.php?t=11595).

- [ ] Review code, description, credits, and images for problematic or inappropriate content that could result in the listing being put on hold.
- [ ] Credit code, concepts, assets, and information derived from other add-ons, developers, and external sources, including sources identified through AI-assisted research; verify applicable licenses and get permission before copying another add-on's code.
- [ ] When AI was used, review its sources where practical and confirm the author can maintain the resulting code.
- [ ] Describe the add-on and its dependencies clearly; use English where practical.
- [ ] Put update details in the listing's Changelog rather than replacing the main description with release notes.
- [ ] Ensure the author monitors ESOUI private messages for moderator requests.
- [ ] Search ESOUI for existing add-ons with similar functionality and consider relevant prior solutions and user expectations.
- [ ] Prefer documented ESO APIs; if a needed API is unavailable, ask ESOUI for guidance rather than using an unsupported workaround.
- [ ] For updates, consider cleaning up obsolete bundled libraries or LibStub patterns where applicable.
- [ ] If console-only, make platform support clear in the add-on name and description; keep names and descriptions free of profanity.
- [ ] Check that the listing's option to allow patches or companion add-ons matches the author's intent.
- [ ] Consider the server-wide performance impact of data-heavy APIs and optimize usage for the possibility of many users running the add-on.

#### Dependency and manifest practices

- Sources: [manifest format](https://wiki.esoui.com/Addon_manifest_%28.txt%29_format), [dependency version checks](https://www.esoui.com/forums/showthread.php?t=11595), and [API versions](https://wiki.esoui.com/APIVersion). If the Wiki pages cannot be accessed, record that limitation and verify against another current source where possible.

- [ ] For non-optional dependencies, use a `>=` version check based on the dependency's current manifest `AddOnVersion`; use the correct manifest syntax and space-separate multiple dependencies.
- [ ] Consider updating minimum dependency versions when newer releases resolve relevant issues, after testing compatibility.
- [ ] Review the applicable manifest documentation for directive syntax and load-order behavior, especially when using platform-specific or optional dependencies.
- [ ] Confirm optional dependencies are treated as optional and do not prevent the add-on from loading when absent.

#### Namespace, saved variables, and event efficiency

- Sources: [event filters](https://wiki.esoui.com/AddFilterForEvent) and [saved variables](https://wiki.esoui.com/Storing_data_and_accessing_files).

- [ ] Keep variables local where possible; limit necessary globals to one clearly prefixed add-on table, with local references in Lua files where appropriate.
- [ ] Give saved variables unique add-on-prefixed names and access them only through supported APIs after they become available at `EVENT_ADD_ON_LOADED`.
- [ ] In `EVENT_ADD_ON_LOADED` handlers, check the event's add-on name and avoid unnecessary repeat callbacks when initialization is complete.
- [ ] Choose account-wide and character-specific saved-variable scopes to match the data; prefer character-ID scopes over character-name scopes and decide whether account-wide data should be server-specific.
- [ ] If changing saved-variable structure or scope, preserve existing user data with a tested migration where needed.
- [ ] Do not assume saved-variable globals exist before `EVENT_ADD_ON_LOADED`; initialize and access saved data through the supported wrapper/API.
- [ ] For frequently firing combat, effect, and inventory events, use applicable `AddFilterForEvent` filters to prevent irrelevant callbacks from reaching Lua.
- [ ] Confirm each filter uses the same event namespace and event ID as its registration, uses supported filter types and matching parameters, and does not repeat a filter type for the same namespace/event pair.
- [ ] Check that `AddFilterForEvent` reports successful application; treat a failed filter as unresolved rather than assuming it is active.
- [ ] Register events only while their functionality is needed and unregister them when disabled or no longer needed; unregistering is also required to remove applied filters.
- [ ] Where the same event needs multiple registrations with the same filter type but different values, use distinct unique event namespaces and manage each registration's lifecycle.
- [ ] Consider local references for frequently used globals and helpers where this improves clarity or performance without reducing maintainability.

### Release package

- [ ] Record the archive filename and format and verify the submitted archive can be opened and extracted.
- [ ] Verify the archive has the expected top-level add-on folder and contains the manifest and all required runtime files exactly once.
- [ ] Compare the archive contents with the frozen candidate and confirm each packaged runtime file matches the reviewed candidate.
- [ ] Confirm there are no missing, unexpected, duplicate, or hidden entries; no nested archives, `wowmatrix.dat`, SavedVariables, editor/version-control files, generated API files, backups, or unrelated project files.
- [ ] Confirm any requested image and any necessary installation help are present and in the required format.

<Record package identity, verification method, and findings.>

## Overall code quality

Summarize the release code's correctness, maintainability, and performance-relevant design. Identify material defects or limitations found; distinguish reviewed evidence from guarantees. Do not claim the release is bug-free.

- [ ] Review the complete release code and relevant manifest/XML/configuration, not just changed files.
- [ ] Trace startup, event-driven behavior, user actions, and relevant state transitions; check invalid or missing data, repeated events, and boundary cases for the add-on's core features.
- [ ] Check API calls and assumptions against the supported API; assess failure handling, saved-data integrity, and migration behavior where applicable.
- [ ] Assess event registration and unregistration, callback frequency, repeated scans, allocations, and work that scales with inventory size; identify avoidable performance costs.
- [ ] Assess whether the implementation remains understandable and maintainable, including the need for local state, comments, and separation of responsibilities.
- [ ] State material findings, limitations, and areas not inspected; do not treat absence of a discovered defect as proof of being bug-free.

<Overall assessment and any issues>

## User testing and performance

Record who tested the frozen candidate, when, the tested setup and dependency versions, and the actual results. Do not claim tests were run without reported results; disclose incomplete output or untested scenarios.

- [ ] Confirm testing was performed on the identified frozen candidate with its intended dependencies; record game/API version and relevant settings.
- [ ] Record test coverage, passed/failed counts, failures, and any untested or blocked scenarios. Include relevant functional/user-facing behavior, not only automated or synthetic checks.
- [ ] Record whether other add-ons were disabled during isolation testing; note any known interactions or compatibility testing.
- [ ] For performance tests, record workload, data size, repetitions, timing method, measured results, and acceptance limits.
- [ ] State whether each performance test is synthetic/read-only or can affect live inventory, saved variables, or other persistent state; do not run destructive benchmarks on live data.
- [ ] Compare actual measurements with the stated limits and report regressions or missing evidence explicitly.
- [ ] Where practical, test representative normal, edge, and recovery scenarios (including reload/reinitialization and saved-data behavior) and note any setup limitations.

<User-test results and evidence>

<Performance measurements, workloads, and limits>

## Review conclusion

Summarize whether the frozen release meets the mandatory rules and applicable best practices. List unresolved requirements or required follow-up. Approve only when required checks and human confirmations are complete.

<Conclusion and approval rationale>
