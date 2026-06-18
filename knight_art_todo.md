# Knight art pass — handoff spec

The Knight character (mechanics, character-select screen, Flaming Arrows upgrades)
is **already built and committed**. Only the custom art is missing — the Knight
currently uses a placeholder (the Mage/rogue sprite). This doc is the exact spec to
generate the real art and wire it in. **Use parallel agents** for generation.

## Visual identity (use this SAME description in every generation for coherence)
> A stout armored knight-rogue: heavyset chibi humanoid (big head, stocky body) in
> dark steel plate armor over a deep-blue tunic and hood, worn leather straps, a
> short cape, gauntlets and armored boots, hood shadowing a determined face, small
> daggers sheathed at the belt. Cute top-down action-roguelike style, bold thick
> black outline, clean cel shading, vibrant slightly-desaturated palette. Full body,
> centered, plain solid pure white background, no shadow, no text, single character.

## Frames to produce (2-frame walk per direction; mirrors the existing player set)
Animation names MUST match the player's so `player.gd` works unchanged: `walk_down`,
`walk_up`, `walk_right`, `idle` (left is `flip_h` of right).

- `assets/knight_down_0.png`, `assets/knight_down_1.png`  — FRONT view, walking (stride A / stride B)
- `assets/knight_up_0.png`,   `assets/knight_up_1.png`    — BACK view, walking
- `assets/knight_right_0.png`, `assets/knight_right_1.png` — SIDE view facing RIGHT, walking
- idle = reuse `knight_down_0.png`
- `assets/flame_arrow.png` — OPTIONAL polish: a small flaming arrow projectile (orange/yellow flames, thick outline, white bg). The Knight's "Flaming Arrows" just turns on the **standard arrows weapon** (no separate weapon); this texture is only a cosmetic swap if you want those arrows to look flaming.

## Pipeline
1. Generate `knight_down_0` first (text→image, style "none", white bg). QA with Read. Note its cloudinary `fileUrl`.
2. Spawn agents in parallel:
   - FRONT-alt: img2img from down_0 → `knight_down_1` (swap stride).
   - BACK: gen `knight_up_0` (text + the down_0 URL as `referenceImageUrl`, "same character from behind"), then img2img → `knight_up_1`.
   - SIDE: gen `knight_right_0` (ref down_0, "same character side view facing right"), then img2img → `knight_right_1`.
   - FX: gen `flame_arrow` (small flaming arrow, pointing right).
3. Key every sprite with the existing tool, fixed canvas so frames register:
   `powershell -NoProfile -ExecutionPolicy Bypass -File tools/key_sprite.ps1 -src "<tempPng>" -out "assets/knight_<x>.png" -canvas 900`
   (flame_arrow can use a smaller canvas, e.g. 256, and tighter crop.)
4. QA each with Read; regenerate any that drift from the description.

## Wiring after art lands
1. **`resources/knight_frames.tres`** — currently reuses `player_*.png` as a placeholder.
   Replace the ext_resources so: walk_down=[knight_down_0,knight_down_1],
   walk_up=[knight_up_0,knight_up_1], walk_right=[knight_right_0,knight_right_1],
   idle=[knight_down_0]. Set each anim `speed` ~6 (2-frame cycle).
2. **(Optional) Flaming arrow look** — there is NO separate flaming weapon. "Flaming
   Arrows" enables the standard `arrows` weapon (`random_missile.tres`). If you want
   the Knight's arrows to look flaming, generate `assets/flame_arrow.png` and apply it
   as the projectile texture on the arrows weapon the Knight gets (e.g. in
   `main._apply_upgrade("flaming")` after `add_weapon("arrows")`). Skip entirely if not wanted.
3. **`scripts/run_state.gd`** — knight `portrait` is already `res://assets/knight_down_0.png`;
   tune knight `sprite_scale` (currently 0.2) if the knight reads too big/small next to enemies.
4. Trigger an import scan, then `summer_get_script_errors` on the touched scripts and
   open `main.tscn` to confirm it loads clean.

## Verify
Boot the game → main menu → Play → Character Select → pick Knight. Confirm the new
directional sprites animate, 150 HP / slower / 2 saws + homing orb, and that the
"Flaming Arrows" card appears on level-up and ignites fire arrows that use the new sprite.
