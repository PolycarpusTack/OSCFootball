# OSCF line-special animation art

Eight original football-character animation sheets, generated using the built-in
image-generation tool. Six poses per move: **48 animation frames**. Sources are
1536×1024 RGBA PNGs with actual transparent backgrounds. Public prompt recipes are saved alongside every source, including the Laser Pass
refinement. These recipes have been revised to describe body mechanics without
external character or move names; they are not verbatim historical generation logs.

## Lineup

| Line | Animation | Design input | Body mechanics | Source |
| --- | --- | --- | --- | --- |
| Striker | Power Strike | ↓↘→ + Space | Low, wide two-arm wind-up, synchronized with a boot strike | [Sheet](power_strike.png) |
| Defender | Bulldozer Clear | ↓↘→ + Space | Horizontal corkscrew body rotation | [Sheet](bulldozer_clear.png) |
| Defender | Grapple Tackle | Signature | Standing waist grab and spin; no slam | [Sheet](grapple_tackle.png) |
| Midfielder | Laser Pass | ↓↘→ + Space | Gather-and-thrust rhythm, with the pass delivered by the foot | [Final sheet](laser_pass_v2.png) |
| Midfielder | Whirlwind Turn | Signature | Airborne turning kick | [Sheet](whirlwind_turn.png) |
| Keeper | Cannon Punt | ↓↘→ + Space | Crossed-arm sweeping wind-up into a punt | [Sheet](cannon_punt.png) |
| Keeper | Rising Fist | Signature | Rising uppercut with an arched airborne follow-through | [Sheet](rising_fist.png) |
| Winger | Stepover Storm | Signature | Rapid alternating leg rhythm translated into rapid low stepovers | [Sheet](stepover_storm.png) |

These are original OSCF footballers in the established white/red/blue outfield kit
and green/black keeper kit. The previously generated OSCF Rising Steal sheet was
used as the character/style reference. No fighting-game sprite files were copied.

Contact markers are in [CONTACT_FRAMES.md](CONTACT_FRAMES.md) and each move's `contact_frame` field in `manifest.json`. They describe the current artwork and
do not enable gameplay hitboxes.

## Godot assets

- `<move>_192.png`: six 192×192 cells in one horizontal RGBA strip.
- `line_actions.tres`: a `SpriteFrames` resource with eight non-looping animations.
- `manifest.json`: measured source rectangles, role/input design notes, root
  adjustment, jump offsets and frame-duration weights.
- `packed_regions.json`: exact packed bounds and scales, for inspection.
- `<move>_prompt.txt`: original generation prompt.
- `laser_pass_v2_prompt.txt`: the final Laser Pass refinement prompt. The initial
  `laser_pass.png` remains as a draft; the resource uses **v2**.

The ready stance is packed `standing_height` (40) pixels tall, the size of the FIFA 96 and Rendered run frames; the shader also recolours its skin and hair per player. Large cells leave safe room for
wide poses and jumps; they do not mean 192-pixel-tall players. For a non-centred
`AnimatedSprite2D`, use offset **(-96, -168)**. Horizontal mirroring uses the same
centred x anchor. The drawings have a right-facing three-quarter base view, with
turning poses where needed. Mirroring supplies left-facing playback, not a full
eight-direction animation set.

Animations run at 10 fps with per-frame duration weights. Most last 0.85 seconds;
Grapple Tackle lasts 0.71 s and Stepover Storm 0.61 s. These are art-review timings,
not gameplay hit windows. Pose continuity, foot planting and role-specific timing
still need final in-match art direction.

## Preview

From the game folder:

```sh
godot --path . res://scenes/oscf_line_actions_preview.tscn
```

All eight animations appear in enlarged and game-size views. Space pauses, R
replays, F mirrors, Left/Right change playback speed and Escape exits. The preview
loops copies of the animations; the saved resource itself remains non-looping.

Rebuild the atlases from the measured source regions:

```sh
godot --headless --path . -s res://tools/pack_oscf_line_actions.gd
godot --headless --path . --editor --quit
```

## In the match

All eight now play in Chaos matches: see "Line moves" and the signature specials in
`docs/chaos-actions.md`. `Anims` loads the `_192.png` strips from `manifest.json` (feet at the
origin, frame durations from the weights). The rest of this section describes the art as
delivered.

## Integration boundary

This delivery is **animation art and a Godot preview**, not a change to live match
controls. The shared ↓↘→ + Space and role-specific signature moves in the table
remain the requested design mapping. The new sheets have not replaced the live
indexed-palette animation library. Use a standard RGBA material; the existing
palette shader is not suitable for these already-coloured textures.

Balls, projectiles and effects are intentionally separate. Grapple Tackle draws
only the actor: a grabbed opponent must be positioned/animated separately by the
game. The grab stays upright and ends with release. Team recolouring, additional
directions, opponent pairing, ball-contact markers and gameplay integration are
separate from these art assets.
