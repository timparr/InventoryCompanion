# Tracker Group-First: First Branch Visible Rules Benchmark

Status: Populated-list observation; main comparison and feature acceptance pending
Consolidated results: [Tracker Group-First test results](<008 TrackerGroupFirst - Consolidated Test Results.md>)

## Run context

- Captured: 2026-11-21
- Installation: `InventoryCompanion_DEV`, runtime 1.8.2, live ESO, API 101051
- Git branch: `feature/tracker-group-first-clean`
- Server/language: EU Megaserver, English
- ESO Plus: enabled; bank: closed
- Active rules: 20; scanned bags: 4
- Raw output: [visible-rules Debug Key report](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-visible-rules-debug-key.txt)

## Results

- Standard Debug Key diagnostics: **89/89 passed**.
- Existing live bag scan: 100 scans took **305 ms** against the 500 ms limit;
  1,020 occupied entries were found and the bank was closed.
- Existing combined tracker-build probe: **35, 31, and 31 ms** (min/median/max
  **31/31/35 ms**), with four bag reads per sample, 140 snapshot IDs, zero
  differing IDs, and 55 display rows.
- New phase-separated benchmark, three runs of 1,000 iterations each:

  | Phase | Run 1 | Run 2 | Run 3 | Min / median / max per operation |
  |---|---:|---:|---:|---:|
  | `GetMasterItemList` | 32,270 ms total | 31,866 ms total | 31,937 ms total | 31.866 / 31.937 / 32.270 ms |
  | Display-list construction | 852 ms total | 800 ms total | 801 ms total | 0.800 / 0.801 / 0.852 ms |
  | Layout-model construction | 134 ms total | 125 ms total | 132 ms total | 0.125 / 0.132 / 0.134 ms |

  The reported last iteration in each run had 140 snapshot IDs, 55 display
  rows, and three layout rows across three groups.

## Interpretation and limitations

Compared with the first branch's empty-list run, scan time is similar
(32.299 ms median versus 31.937 ms). With 55 rows and three groups, display-list
construction averaged about 0.8 ms and layout-model construction about 0.13 ms
per iteration. These measurements cover building the data models, not UI
rendering.

The report still found zero differing IDs, so it did not exercise duplicate
source rows with different counts. It is also not a main-branch comparison;
the same rules, inventory, and bank state are needed for that run. No
performance acceptance limit has been set.
