# Group pattern exclusions

Status: Completed on 2026-10-30. Implementation and automated checks are
complete, and the final editor controls were approved in game.

## Goal

Allow a group to include items matching its current patterns while excluding
items matching additional patterns. Example: the Treasure Maps group includes
treasure maps generally and excludes maps from Cyrodiil.

## User experience and behavior

- Each pattern row has a visible Include/Exclude control that flips the row's
  role without changing its text.
- A group matches if at least one include pattern matches and no exclude
  pattern matches. A group with no includes matches nothing.
- Exclusions narrow only the results produced by their own group. They do not
  veto another group's match, an individually tracked item, or the item's
  individual tracking settings.
- Excluding an item from a group does not untrack it. It may still appear
  through another matching group, individual tracking, or the existing
  Miscellaneous behavior.
- Empty pattern rows behave the same for Include and Exclude: they are allowed
  and match nothing until text is entered.
- Keep matching against item names, as it works today.
- Do not require users to type a hidden pattern syntax. Explain the behavior in
  the editor and user documentation.

## Compatibility

- Existing patterns remain includes and continue behaving exactly as before.
- Exclusions are additive; no saved-variable version bump or migration is
  needed.
- Saved patterns remain strings in the existing pattern arrays. The editor
  stores the row's Include/Exclude choice in an internal suffix; users see and
  edit only the pattern text and use the visible control to change its role.
- The internal suffix is a reserved, distinctive marker; a legacy pattern
  ending in that exact marker is interpreted as an exclusion. The marker is
  selected to avoid collision with item names, so such a legacy pattern would
  already match no items.
- Do not change group overlap, miscellaneous-group behavior, or tracker display
  policy beyond ensuring excluded items no longer match their owning group.

## Implementation details

See the separate [implementation record](ImplementationPlan_GroupPatternExclusions.md)
for the examined code paths, saved-variable fields, ordered code/test changes,
and in-game verification.
