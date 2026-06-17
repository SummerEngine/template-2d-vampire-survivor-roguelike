# Art Bible — Vampire-Survivors-like Roguelike Template

**Locked style: "Don't Starve woodcut" dark-painterly.** Picked 2026-06-16 from a 4-way concept exploration.

## The look in one line
Tim Burton–esque hand-drawn gothic woodcut: scratchy ink linework, muted desaturated palette, heavy blacks, matte paper texture. Grim but characterful, not photoreal.

## Palette
- **Base:** desaturated charcoal, sepia, ash-brown, bone/parchment neutrals.
- **Shadow:** near-black ink, deep and graphic (not soft gradients).
- **Magic / glow accent:** muted teal-cyan (the crystal staff, projectiles, XP gems).
- **Danger accent:** dried blood-red (enemies, hits, danger UI).
- Low overall saturation; color used sparingly as accent, never candy-bright.

## Linework & rendering
- Visible **scratchy hand-drawn ink outlines**, slightly wobbly, varied weight.
- Woodcut/cross-hatch shading for form; flat-ish fills, minimal smooth gradients.
- Matte finish, subtle paper grain. No glossy/plastic highlights, no lens flares.

## Form language
- Elongated, gnarled, slightly exaggerated silhouettes (Burton proportions).
- **Silhouette readability is the top priority** — these are small sprites with a whole horde on screen. Bold, distinct outlines that read at 48–96px.

## Gameplay sprite rules
- **View:** front-facing three-quarter top-down (matches the game's camera).
- Centered, full-body, single character/object, no scenery or ground.
- Generate on a **flat solid neutral-gray background** (NOT "transparent" — the model bakes a fake checkerboard). Key the flat color out to true alpha via `tools` PIL pass.
- Consistent light direction (top, slightly front).

## Cohesion workflow (anti-slop)
- Style anchor = the approved hero sprite. Generate every other asset with the anchor (and/or the menu splash) passed as `referenceImageUrl` so palette, linework, and weight stay matched.
- Name the reference style explicitly in prompts ("Don't Starve, Tim Burton woodcut") — never generic "epic concept art / trending on artstation".
- Review each asset at small scale before shipping; regenerate outliers rather than accepting a near-miss.

## Do / Don't
- DO: heavy ink shadow, muted palette, teal magic + blood-red danger, strong silhouette.
- DON'T: bright saturated cartoon colors, soft airbrush gradients, glossy highlights, photoreal rendering, baked backgrounds/scenery on gameplay sprites.

## Concept reference asset IDs (Summer)
- #2 Don't Starve (CHOSEN): `38ce3e1e-efaa-40bc-90da-983338a6b666`
- #1 Darkest Dungeon: `645a9167-be9c-4c8b-9a9c-df66ea4e754e`
- #3 Gothic gouache: `0cdc1288-df3a-4edf-bb69-bb6783d9bf68`
- #4 Painterly rim-light: `ce8ba97f-4125-412a-9fc8-39503e890e15`
