# ESOUI Release Standards Review

Reviewed (UTC): 2026-10-26T15:24:42Z
Reviewer: AI assistant using Copilot SDK in VS Code (model identifier not exposed in this session)
Checked by: Tim-P
Release version: 1.01
Candidate SHA256: CD164BA0A316C05BDEA26F505EA245FCCCA8F9AEE77959AD8FBC79A2116D2AB8
Review status: APPROVED

## Release process

A copy of the intended release files was extracted into a clean staging installation, staged, and frozen as the review candidate. Its version and SHA-256 identity are recorded above. The review and release tests apply to that frozen copy; the candidate is not changed during review.

Only after the files were frozen were they assessed against ESOUI's mandatory upload rules and prohibited-functionality requirements, together with its release best-practice guidance:

- Mandatory upload rules: https://www.esoui.com/forums/showthread.php?t=11
- Mandatory prohibited-functionality requirements: https://www.esoui.com/forums/showthread.php?t=9865
- Release best practices: https://www.esoui.com/forums/showthread.php?t=10790

## Findings against the guidance

### Prohibited functionality and inventory transfers

The reviewed release does not initiate bank or house-chest interactions, automate combat or movement, or send public chat. Bank transfers are gated on the player having opened the bank (`EVENT_OPEN_BANK` and `IsBankOpen()` checks) and use ESO's protected inventory APIs through `CallSecureProtected`. No unresolved transfer-policy concern was identified in the reviewed code.

The current ESOUI forum guidance on release practices, upload rules, and prohibited functionality was reviewed:

- https://www.esoui.com/forums/showthread.php?t=10790
- https://www.esoui.com/forums/showthread.php?t=11
- https://www.esoui.com/forums/showthread.php?t=9865

The linked add-on-removal Wiki page could not be read because HTTP retrieval and the integrated browser returned 403/Cloudflare. Its current guidance is therefore not claimed as verified.

### Globals, saved variables, UI identifiers, and events

Addon-owned Lua state uses the `InventoryCompanion` namespace. Saved variables use `InventoryCompanion_SavedVariables` with account-wide and character-ID scopes through `ZO_SavedVars`. XML controls, scenes, bindings, dialogs, and events use addon-prefixed identifiers, with child controls deriving names from their parents. Frequently firing inventory slot events are individually filtered to relevant bags, registered conditionally, and paired with debounced UI refreshes.

### API versions and dependencies

The manifest declares API 101051, confirmed by the author's in-game report and the current ESO UI source README (12.1.6, 19 October 2026). No unverified PTS API version is declared. The non-optional dependency `LibAddonMenu-2.0>=43` matches the library's installed `AddOnVersion: 43` and its current public r43 listing.

- https://raw.githubusercontent.com/esoui/esoui/live/README.md
- https://www.esoui.com/downloads/info7-LibAddonMenu.html

### Description, disclosure, credits, licensing, and installation

The upload description begins with the explicit AI disclosure, lists the required dependency immediately afterward, and accurately describes the addon's tracking, currency, and banking behavior. It includes straightforward extraction-based installation instructions. The author confirmed distribution rights, credits, and listing claims. No third-party runtime library or external asset is bundled; the addon references built-in ESO UI resources.

### Release package

The package contains one `InventoryCompanion` folder with the manifest, release runtime files, and a review document. The verified contents exclude SavedVariables, generated API definitions, editor files, executables, nested archives, and development-only documents. The release files match the identified candidate.

## Code quality and testing

The reviewed code follows the addon namespace and saved-variable conventions, filters high-frequency inventory events, and gates transfers on a player-opened bank interaction. The review found no known release-blocking code defect. This is a focused release review, not a guarantee that the addon is bug-free.

Tim-P reported **57/57 in-game tests passed** on the staged release candidate and confirmed that it looked good in game. Reported performance measurements were:

- 20 scans of 100 items against 20 rules: **71 ms / 2,000 ms**
- 100 slot-rule matches: **1 ms / 1,000 ms**
- 100 tracked-item slot updates: **1 ms / 2,000 ms**
- 100 read-only backpack, bank, and craft-bag scans with the bank closed: **305 ms / 1,000 ms**, with 980 occupied entries on the final scan

All reported timings were below their respective limits. The supplied per-case test output was truncated during the Alliance Points currency scenario; the 57/57 result is the author's reported summary, not an independently complete per-case transcript.
