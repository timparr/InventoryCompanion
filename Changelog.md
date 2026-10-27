# Inventory Companion Changelog

Historical coverage is limited to versions verified in local release archives: v1.00 and v1.01. No local package or review establishes intervening v1.1.x or v1.2.0 changes, so they are not attributed here.

## 1.00

- Initial release with crafted-item bank transfers, house-chest stack merging, item and group tracking, and currency and inventory-capacity panels.

## 1.01

- Distinguished development and release installations and warned players when both copies are enabled.

## 1.2.1 (approved candidate; not yet published)

Changes since the reviewed 1.01 release:

- Added a prominent warning dialog when both the development and release copies are enabled. Disable one copy and reload the UI before continuing.
- Added ESO's integer add-on version metadata for dependency and version reporting.
- Expanded diagnostics to report the running game, installation, enabled add-ons, and available currency-test coverage.
- Strengthened event-listener regression checks and tightened performance-test limits.

Bank transfers, item tracking, currency notifications, settings, and saved-data behavior are unchanged from the reviewed 1.01 release.

## Unreleased

- Updated release tooling to include the readme and this changelog beside the manifest in staged installations and release ZIPs. This is packaging work, not an add-on feature.
