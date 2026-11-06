# Prompt: design the Inventory Companion category icon

**Historical prompt.** Retained for design context, not current work instructions.
Use the [master feature specification](../../../FeatureSpecs/AutoCategoryIntegration.md)
for delivered behavior.

You are designing a small icon for **Inventory Companion**, an addon for The
Elder Scrolls Online (ESO). Your deliverable is **SVG source code as copyable
text**. Do not generate raster images as the deliverable; I will render, convert,
and review the SVGs myself.

## What the icon represents

Inventory Companion lets players define named **groups** of items using simple
name patterns (for example "Plunder" matches every item with "plunder skull" in
its name). It tracks those groups in a compact HUD panel and notifies the player
on pickup.

The icon marks **"this inventory category comes from Inventory Companion"**. It
appears inline, immediately before the group name, in inventory section
headings drawn by another addon:

    [icon] Plunder        [icon] Cyrodiil Maps        Container        New

Most headings on screen are not ours, so the icon is how a player recognises at
a glance which headings Inventory Companion created. Avoid people or faces:
"companion" is also an in-game term for NPC followers and would be misread.

## Concept

The concept is entirely up to you. Interpret what the addon does (grouping,
labelling, and tracking items by name pattern) however you think works best as
an icon. It should feel at home in a fantasy RPG interface.

## Variants (same base design)

1. **Main**: the icon itself.
2. **Include rule**: the main icon marked to mean "included / added".
3. **Exclude rule**: the main icon marked to mean "excluded / removed".

How you mark the variants is up to you, but they must be distinguishable by
shape, not colour alone.

## Hard constraints

- Displayed at **16–20 px** high inline with 18 px text, so it must read
  clearly at that size.
- `viewBox="0 0 64 64"`, transparent background, `width="64" height="64"`.
- **Pure white only** (`#FFFFFF`) for all fills and strokes. The addon tints the
  icon in game by multiplying it with a colour (gold, blue, or red), so no other
  colours, greys, gradients, filters, opacity tricks, or shadows. Use
  `fill-rule="evenodd"` or separate paths for cut-outs (any holes or interior
  detail must be genuinely transparent, not drawn in a dark colour).
- Plain SVG 1.1: only `svg`, `g`, `path`, `rect`, `circle`, `ellipse`, `line`,
  `polyline`, `polygon`. No `text`, `image`, `mask`, `clipPath`, `filter`,
  `use`, CSS, or external references.

## Required output format (important)

Reply with exactly **three fenced code blocks marked as `text`** (not `svg`,
`xml`, or `html`), so the chat shows them as copyable plain text instead of
rendering them:

````
```text
<svg xmlns="http://www.w3.org/2000/svg" ...> ... </svg>
```
````

- Block 1: main. Block 2: include. Block 3: exclude.
- Each block contains one complete, standalone SVG document and nothing else.
- Put a one-line heading above each block: `CategoryIcon.svg`,
  `CategoryIconInclude.svg`, `CategoryIconExclude.svg`.
- Do not attach files, generate images, or render previews in place of the code
  blocks. After the three blocks, add at most three short sentences describing
  the design.
