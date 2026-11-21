# Tracker Group-First: First Branch `/ictest` Results

Status: Initial observation; feature acceptance pending
Consolidated results: [Tracker Group-First test results](<008 TrackerGroupFirst - Consolidated Test Results.md>)

## Run context

- Captured: 2026-11-21
- Installation: `InventoryCompanion_DEV`, runtime 1.8.2, live ESO, API 101051
- Server/language: EU Megaserver, English
- ESO Plus: enabled; bank: closed
- Branch: `feature/tracker-group-first-clean`; Tim confirmed DEV remained on
  this branch for the run. The captured diagnostic does not record a commit.
- Raw output: [first-branch `/ictest copy` report](../../../Tests/Evidence/1.8.2-20261121-tracker-group-first-first-branch-ictest.txt)

## Results

- `/ictest`: **89/89 passed**.
- Read-only live bag scan: 100 scans took **341 ms** against the existing
  500 ms limit; the final scan contained 1,020 occupied entries.
- Existing real tracker-build probe: **34, 38, and 31 ms** (min/median/max
  **31/34/38 ms**), with four bag reads per sample, 140 snapshot IDs, zero
  differing IDs, and zero display rows. Its acceptance limit remains pending.
- Other reported diagnostics were within their displayed limits, including
  synthetic scan, slot-rule match, tracked-item update, AutoCategory
  classification, preflight, and rule-rebuild timings.
- This earlier `/ictest copy` report contains no phase-separated timings.
  The subsequent Debug Key benchmark is summarized in the
  [phase benchmark results](<004 TrackerGroupFirst - First Branch Debug Key Benchmark.md>).

## Comparison and limitations

The earlier 1.8.2 exploratory run recorded 327 ms for 100 live bag scans and
tracker-build samples of 34/29/29 ms (median 29 ms). This run is 14 ms higher
for bag scans and 5 ms higher for the three-sample tracker-build median.
These small samples are observational, not a controlled comparison or evidence
for a code change; the tracker probe also produced no display rows.

The branch-specific isolated phase timings are recorded separately; this
earlier report remains observational and does not by itself establish a
performance regression or acceptance.
