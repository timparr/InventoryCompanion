# AutoCategory integration implementation report

## Status

Implemented on `feature/autocategory-integration`. Focused automated tests pass,
but post-implementation ESO acceptance and compatibility certification remain
incomplete. The integration is opt-in and disabled by default. No normal saved
variables or live inventory were used.

## Delivered

- Added schema-v4 saved-state validation and migration for integration
  enablement, participation, heading visibility and sparse placement overrides.
  Added mutations for presets, per-context placements, first participation,
  resets and rank rebalancing.
- Added `Tracking/AutoCategoryIntegration.lua` as the native AutoCategory
  adapter. It projects only managed definitions and assignments to the active
  AutoCategory profile, reuses IC's runtime rule matching, and hooks profile and
  rule lifecycle changes.
- Added the settings enablement/status entry, the Edit Items participation
  checkbox, and the Edit Groups AutoCategory view with context selection,
  heading visibility, filters, reset and movement controls.
- Added focused adapter tests and wired them into the existing rule-test
  runner. Added schema migration and downgrade-protection coverage using
  synthetic saved-variable fixtures.
- Updated the user manual and synchronized the spec, implementation plan,
  spike-status record and historical review with the current D4 and
  implementation status.

## Verification

| Check | Result |
| --- | --- |
| `python Project\Tests\Run-RuleTests.py` | PASS: 107/107 isolated addon tests; runner reports Lua 5.1 syntax checked. |
| Synthetic schema safety | PASS: migration preserves fixture data; schema-v4 saved data is rejected unchanged by the actual schema-v3 sources at `HEAD`, before constructors. |
| Normal saved data / live inventory | Not used. |
| ESO in-game acceptance | Not run after implementation. |
| Standalone spike testing | Not reopened or repeated. |

## Differences from the implementation plan

- Context moves persist only the moved group's context placement override;
  they do not swap a neighboring group's order. This avoids introducing an
  unrelated override and follows the spec's group-specific context semantics.
- Master combines differently ordered heading lists by heading occurrence and
  a cycle-checked ordering model, rather than assuming one global native
  sequence. Inconsistent/unrepresentable layouts remain acceptance risks; this
  does not claim to solve arbitrary external priority or run/show mismatches.
- The runtime uses the spike-proven built-in plus texture. The final texture
  identity/tint and DEV-versus-release category identity choice remain open
  under D2; no new asset was introduced.
- Only the DEV manifest in this Git repository was wired. The release manifest
  is outside this repository and was not modified; confirm its scope and update
  it before a release package can load the integration.

## Decisions and remaining acceptance

- **D4 is approved.** Production rank-bearing empty colour prefixes are
  authorized, including the accepted renamed-heading expansion behavior and
  retained old per-name collapse flags.
- **Q1/Q2:** verify both winning classification and visible heading order in
  ESO for top, crowded, heading-anchored and arbitrary-label placements,
  including external run/show mismatches and finite rank/priority bounds.
  Unsupported cases must fail visibly rather than silently changing external
  entries or falling back to alphabetical order.
- **Q3:** exercise profile switches, edits/renames/deletes, cache invalidation,
  reclassification, refresh and disable against the actual AutoCategory
  runtime. Offline lifecycle tests are not in-game acceptance.
- **Guild Bank and the seven-context matrix:** verify all required keyboard
  contexts, including subscriber Bank and Guild Bank's BulkMode path. Guild
  Bank remains untested. Do not infer gamepad, other crafting tabs, or merchant
  buy/buyback support.
- **Q5:** agree a synthetic workload and numerical timing limits, then measure
  matcher/scan/compile/projection/refresh counts and off/on edit-burst timing.
  Use synthetic data only; do not mutate live inventory or saved variables.
- **D2 and pre-shipping:** settle final asset identity/tint and release
  category-name identity, then complete the documented DEV spike teardown and
  confirm the release manifest. D1 remains conditional if the unchanged
  classification/order contract cannot pass.

Until these gates pass, do not claim compatibility certification or release
readiness. The schema-v4 downgrade test has passed on synthetic data; continue
to avoid normal saved data until the remaining safety checks and in-game
acceptance are complete.
