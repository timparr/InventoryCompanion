# HUD layout and visibility - archived work

Status: D10.1, D10.2, and integrated D10.3 abandoned, 2026-11-15;
standalone currency-grid and scene-layout work released in 1.7.2

Tim did not like the proposed HUD behavior and does not expect the positioning,
bar-visibility, or HUD-editor-dependent work to proceed. The standalone
currency-columns proposal is resumed as an active draft, separate from that
work. This archive preserves historical proposals, decisions, and review
notes; earlier approvals and agreements do not authorize implementation.

## Archived documents

- [Shared HUD layout and visibility spec](HUDLayoutAndVisibility.md)
- [D10.1 HUD positioning plan](HUDPositioningImplementationPlan.md)
- [D10.2 vanishing progress bars plan](VanishingProgressBarsImplementationPlan.md)
- [D10.3 integrated currency columns plan](CurrencyGridColumnsImplementationPlan.md)

The standalone proposal was later expanded to cover scene-aware panel layouts
and released in 1.7.2. See the [current feature spec](../../FeatureSpecs/CurrencyGridColumnsFeatureSpec.md)
and the archived [implementation and UAT record](../CurrencyGridAndSceneLayouts/CurrencyGridColumnsPostImplementationBugFixes.md).
The older integrated D10.3 plan remains historical.

## Historical implementation notes

These notes are historical context, not approved requirements:

- If a variable slider maximum is not supported, use a number/text input with
  no maximum instead.
- For temporary panel movement around the settings window, use the same
  mechanism as the current tracking-panel move behavior.
- Extra credit: allow each panel to have separately stored positions for each
  mode or scene (for example, bank-scene and settings-panel positions), then
  restore that panel's position when switching back to the scene.

The resumed standalone plan still requires current spec review and approval,
plan review and approval, and explicit GO to code. Any other future variant
needs a fresh discussion. The per-mode position idea in particular needs its
own behavior, persistence, and compatibility decisions before it can become
scope.
