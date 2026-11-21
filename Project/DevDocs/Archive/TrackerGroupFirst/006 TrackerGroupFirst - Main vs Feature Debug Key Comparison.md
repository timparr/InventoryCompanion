# Tracker Group-First: Main vs Feature Debug Key Comparison

Status: Initial branch comparison; acceptance pending
Consolidated results: [Tracker Group-First test results](<008 TrackerGroupFirst - Consolidated Test Results.md>)

## Run conditions

Both Debug Key reports were from `InventoryCompanion_DEV` 1.8.2 on ESO live,
API 101051, EU Megaserver, with ESO Plus, 20 active rules, four scanned bags,
and the bank closed. Both reports show 1,020 occupied entries, 140 snapshot
IDs, 55 display rows, and three layout groups.

- Feature run: `feature/tracker-group-first-clean`, with the feature
  implementation in the uncommitted worktree based on `e5bdfeb`.
- Baseline run: `main` at `e5bdfeb`.

The feature worktree was temporarily stashed while DEV ran on main and has
since been restored. The reports do not include source hashes, so this is a
branch/worktree comparison rather than a comparison of two independently
recorded source hashes.

## Phase-separated timings

Each branch ran three runs of 1,000 iterations. Values below are per-operation
min/median/max from the three run averages; the difference is feature median
minus main median.

| Phase | Feature min / median / max | Main min / median / max | Median difference |
|---|---:|---:|---:|
| `GetMasterItemList` | 31.866 / 31.937 / 32.270 ms | 31.462 / 31.579 / 32.115 ms | +0.358 ms |
| Display-list construction | 0.800 / 0.801 / 0.852 ms | 0.472 / 0.478 / 0.504 ms | +0.323 ms |
| Layout-model construction | 0.125 / 0.132 / 0.134 ms | 0.134 / 0.148 / 0.155 ms | -0.016 ms |

Other reported measurements:

- The existing 100-scan live bag-enumeration check took 305 ms on feature and
  321 ms on main. This measures bag enumeration, not `GetMasterItemList`.
- The standard diagnostics passed 89/89 on feature and 88/88 on main; main
  lacks the group-first-specific test.

## Interpretation and limitations

The feature run's median scan time was 0.358 ms higher; its display-list build
was 0.323 ms higher in absolute terms, while layout-model construction was
0.016 ms lower. The same row/group counts were reported on both branches.
These are observed differences from one three-run batch per branch, not an
acceptance decision or evidence to change the implementation.

The feature's existing tracker-build probe reported zero differing IDs; the
main report did not record that metric. Different-count duplicate-source
coverage is therefore not established on both branches. The benchmark excludes
UI rendering and no performance acceptance limit has been set.

- Feature raw report: [feature Debug Key evidence](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-visible-rules-debug-key.txt)
- Main raw report: [main Debug Key evidence](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-main-visible-rules-debug-key.txt)
