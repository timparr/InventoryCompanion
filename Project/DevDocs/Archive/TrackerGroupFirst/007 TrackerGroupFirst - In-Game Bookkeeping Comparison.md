# Tracker Group-First: In-Game Bookkeeping Comparison

Status: Historical measurement; bookkeeping retained; performance acceptance pending
Consolidated results: [Tracker Group-First test results](<008 TrackerGroupFirst - Consolidated Test Results.md>)

## Run conditions

- Captured: 2026-11-21
- Rules: 20; scanned bags: 4; bank closed
- Output: 140 snapshot IDs in the last scan
- The diagnostic report does not include a source hash, game/server details,
  or occupied-entry count.

The test ran three batches of 1,000 matched scan pairs. Each pair performed one
scan with the group snapshot/count bookkeeping and one without it; their order
alternated. The timer covered only `GetMasterItemList`, not display-list
construction or rendering.

The no-group-count path retains shared item and rule-index data and uses the
pre-feature list-based rule-index deduplication. Therefore, the comparison
measures the net scan change, including both group bookkeeping and the
set-based rule-index deduplication; it does not isolate group-record cost
alone. The production scan continues to build the group snapshot.

## Results

| Run | With bookkeeping (ms/scan) | Without bookkeeping (ms/scan) | Paired difference (ms/scan) |
|---|---:|---:|---:|
| 1 | 32.100 | 31.503 | +0.597 |
| 2 | 31.630 | 31.381 | +0.249 |
| 3 | 31.639 | 30.978 | +0.661 |
| Min / median / max | 31.630 / 31.639 / 32.100 | 30.978 / 31.381 / 31.503 | 0.249 / 0.597 / 0.661 |

The median paired increase was **0.597 ms per scan**, about **1.9%** of the
median no-bookkeeping scan time. The raw report's final `0.258 ms` is the
difference between the two independent medians, not the median of the
paired per-run differences. The benchmark summary was corrected afterward to
report the paired median; the raw output is preserved unchanged.

This is one three-run batch. The run-to-run paired difference varied from
0.249 to 0.661 ms/scan. Tim chose to keep group-count bookkeeping after
reviewing this result. The measurement does not set a performance limit or
establish feature acceptance. Different-count duplicate-source coverage and
the feature's in-game display acceptance remain pending.

- Raw report: [bookkeeping A/B Debug Key evidence](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-bookkeeping-ab.txt)
- Prior branch comparison: [main vs feature Debug Key comparison](<006 TrackerGroupFirst - Main vs Feature Debug Key Comparison.md>)
