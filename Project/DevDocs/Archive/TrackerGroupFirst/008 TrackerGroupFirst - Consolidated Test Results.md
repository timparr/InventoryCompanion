# Tracker Group-First: Consolidated Test Results

Status: Closeout requested; bookkeeping retained; remaining behavior and performance checks pending
Captured: 2026-11-21

This is the single summary of the tracker feature's offline, in-game, and
performance testing. The earlier numbered result documents remain as detailed
run notes; raw diagnostic reports are linked below.

## Quick scan: measured `GetMasterItemList` times

Sorted by median time per scan. This is a quick ranking across separate runs,
not a controlled ranking across all five entries.

| Rank | Scan variant | Median (ms/scan) | Difference vs. fastest | Context |
|---:|---|---:|---:|---|
| 1 | A/B, no group-count bookkeeping | 31.381 | — | Same-session comparison; diagnostic-only path |
| 2 | Main branch | 31.579 | +0.198 | Three runs of 1,000 scans |
| 3 | A/B, group-count bookkeeping enabled | 31.639 | +0.258* | Same-session comparison |
| 4 | Feature branch, visible rules | 31.937 | +0.556 | 55 display rows, three groups |
| 5 | Feature branch, earlier empty-list run | 32.299 | +0.918 | No display rows; not useful for display-building costs |

`*` The +0.258 value is the difference between the two independent A/B mode
medians. The paired per-run median increase is **+0.597 ms/scan**, which is the
better estimate from that paired test. The no-bookkeeping mode is not a
production option; it omits group records and counts.

The sorted ranking is descriptive only. The branch runs and the A/B run were
separate sessions; do not treat small differences between those entries as
causal.

## Same-session A/B: bookkeeping on versus off

Each run performed 1,000 matched scan pairs, alternating which variant ran
first. Each mode therefore has 3,000 measured scans total.

| Run | With bookkeeping (ms/scan) | Without bookkeeping (ms/scan) | Paired difference (ms/scan) | Extra time per 1,000 scans |
|---:|---:|---:|---:|---:|
| 1 | 32.100 | 31.503 | +0.597 | +597 ms |
| 2 | 31.630 | 31.381 | +0.249 | +249 ms |
| 3 | 31.639 | 30.978 | +0.661 | +661 ms |
| Min / median / max | 31.630 / 31.639 / 32.100 | 30.978 / 31.381 / 31.503 | 0.249 / 0.597 / 0.661 | — |

The median paired increase is **0.597 ms per scan**, about **1.9%** of the
median no-bookkeeping scan time. The no-bookkeeping path retains shared item
records and the rule index, using the old list-based index deduplication. The
comparison therefore measures the net effect of group-count bookkeeping plus
the feature's set-based index deduplication; it does not isolate group-record
cost alone. Production scanning still builds the group snapshot.

The raw A/B report's completion line said `0.258 ms`, subtracting independent
medians. The benchmark was corrected afterward to report the median paired
difference. The three per-run values above are unchanged and sufficient to
recalculate the paired result.

## Main versus feature: populated tracker phases

Both reports used 20 active rules, four bags, a closed bank, 1,020 occupied
entries, 140 snapshot IDs, 55 display rows, and three groups. The branch reports
do not include source hashes.

| Phase | Feature min / median / max | Main min / median / max | Feature minus main |
|---|---:|---:|---:|
| `GetMasterItemList` (ms/scan) | 31.866 / 31.937 / 32.270 | 31.462 / 31.579 / 32.115 | +0.358 ms/scan |
| Display-list build (ms/build) | 0.800 / 0.801 / 0.852 | 0.472 / 0.478 / 0.504 | +0.323 ms/build |
| Layout-model build (ms/build) | 0.125 / 0.132 / 0.134 | 0.134 / 0.148 / 0.155 | -0.016 ms/build |
| Sum of phase medians (ms/rebuild) | 32.870 | 32.205 | +0.665 ms/rebuild |

The phase sum excludes UI rendering. The scans were three-run batches, not a
single paired A/B test; the observed differences do not by themselves establish
a regression or acceptance.

## Other in-game tracker measurements

### Live bag enumeration

This is the existing 100-scan `Scanning.GetBagContents` check, not
`GetMasterItemList`.

| Run | Total for 100 scans | Per scan |
|---|---:|---:|
| Earlier exploratory run | 327 ms | 3.27 ms |
| First `/ictest` probe | 341 ms | 3.41 ms |
| First Debug Key run | 339 ms | 3.39 ms |
| Feature visible-rules run | 305 ms | 3.05 ms |
| Main visible-rules run | 321 ms | 3.21 ms |

The existing limit was 500 ms per 100 scans. These are separate observations,
not measurements of group-count bookkeeping.

### Earlier combined tracker-build probes

These are older three-sample probes, not the phase-separated benchmark above.
Empty-list runs do not measure display-list construction for populated rows.

| Run | Tracker-build samples (ms) | Min / median / max | Last output |
|---|---|---|---|
| Earlier exploratory run | 34, 29, 29 | 29 / 29 / 34 | No visible output reported |
| First `/ictest` probe | 34, 38, 31 | 31 / 34 / 38 | 0 display rows |
| First Debug Key run | 35, 30, 30 | 30 / 30 / 35 | 0 display rows |
| Feature visible-rules run | 35, 31, 31 | 31 / 31 / 35 | 55 rows, 3 groups |

## Test status and limitations

- Offline Lua 5.1 suite: feature **278/278**; main **272/272**.
- In-game standard diagnostics: feature **89/89**; main **88/88**. The extra
  feature test is the group-first scan test.
- Feature visible-rules run reported zero differing IDs. Main did not report
  that metric. Different-count duplicate-source coverage is still unproven.
- The same-session A/B is one three-run batch. Tim chose to keep group-count
  bookkeeping. No numeric performance limit was set, and the remaining in-game
  behavior checks are not claimed as passed.
- Display behavior, differing-source rows, and other feature acceptance checks
  remain pending. These timings do not include rendering.

## Raw reports and detailed notes

- A/B raw report: [bookkeeping comparison](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-bookkeeping-ab.txt)
- Feature populated-list raw report: [visible-rules Debug Key](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-visible-rules-debug-key.txt)
- Main populated-list raw report: [main Debug Key](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-main-visible-rules-debug-key.txt)
- Earlier feature reports: [initial `/ictest`](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-ictest.txt), [empty-list Debug Key](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-debug-key.txt), [initial probe](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-initial-probe.txt)
- Detailed notes: [first `/ictest`](<003 TrackerGroupFirst - First Branch In-Game Results.md>), [empty-list benchmark](<004 TrackerGroupFirst - First Branch Debug Key Benchmark.md>), [populated-list benchmark](<005 TrackerGroupFirst - First Branch Visible Rules Benchmark.md>), [branch comparison](<006 TrackerGroupFirst - Main vs Feature Debug Key Comparison.md>), [A/B comparison](<007 TrackerGroupFirst - In-Game Bookkeeping Comparison.md>)
