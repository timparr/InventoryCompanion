# Tracker Group-First: First Branch Debug Key Benchmark

Status: Initial phase-separated observation; branch comparison and feature acceptance pending
Consolidated results: [Tracker Group-First test results](<008 TrackerGroupFirst - Consolidated Test Results.md>)

## Run context

- Captured: 2026-11-21
- Installation: `InventoryCompanion_DEV`, runtime 1.8.2, live ESO, API 101051
- Server/language: EU Megaserver, English
- ESO Plus: enabled; bank: closed
- Active rules: 20; scanned bags: 4
- Branch: `feature/tracker-group-first-clean`; Tim confirmed DEV remained on
  this branch for the run. The captured diagnostic does not record a commit.
- Raw output: [first-branch Debug Key report](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-debug-key.txt)

## Results

- Standard Debug Key diagnostics: **89/89 passed**.
- Existing live bag scan: 100 scans took **339 ms** against the 500 ms limit;
  1,020 occupied entries were found and the bank was closed.
- Existing combined tracker-build probe: **35, 30, and 30 ms** (min/median/max
  **30/30/35 ms**), with four bag reads per sample, 140 snapshot IDs, zero
  differing IDs, and zero display rows.
- New phase-separated benchmark, three runs of 1,000 iterations each:

  | Phase | Run 1 | Run 2 | Run 3 | Min / median / max per operation |
  |---|---:|---:|---:|---:|
  | `GetMasterItemList` | 31,856 ms total | 32,299 ms total | 32,372 ms total | 31.856 / 32.299 / 32.372 ms |
  | Display-list construction | 71 ms total | 92 ms total | 82 ms total | 0.071 / 0.082 / 0.092 ms |
  | Layout-model construction | 4 ms total | 2 ms total | 3 ms total | 0.002 / 0.003 / 0.004 ms |

  The reported last iteration in each run had 140 snapshot IDs but **zero
  display rows, layout rows, or groups**.

## Interpretation and limitations

For this inventory and rule configuration, the measured time was overwhelmingly
in `GetMasterItemList`. The display-list and layout-model timings are for an
empty output list, so they do not establish the cost of building a populated
tracker. The existing combined tracker-build samples are consistent with the
scan taking nearly all the time in this particular run.

The preceding `/ictest` report recorded 341 ms for 100 live bag scans and a
31/34/38 ms combined tracker-build min/median/max. The current report records
339 ms and 30/30/35 ms respectively. These are nearby observations, not a
controlled branch comparison. The main-branch run is still needed; no timing
acceptance limit has been set.
