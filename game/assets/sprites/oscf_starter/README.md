# OSCF footballer starter sprites

Original artwork generated with the built-in image-generation tool, then cropped,
scaled and packed by Godot. Prompts are saved beside the source sheets.

## Contents

- `idle.png`, `run.png`, `kick.png`: high-resolution transparent source artwork.
- `idle_64.png`, `run_64.png`, `kick_64.png`: game-size atlases; each cell is 64×64.
- `footballer.tres`: Godot 4 SpriteFrames resource with 15 animations.
- `source_regions.json`: measured source sprite rectangles and preview timing.
- `*_prompt.txt`: the generation prompts.

There are five drawn directions, in column order: N, NE, E, SE, S.
Mirror NE, E and SE horizontally for NW, W and SW. Rows are successive frames.
Idle contains 2 frames per direction; run and kick each contain 5. Total: 60 frames.
The generator returned five running/kicking rows despite the prompts requesting six;
the resource uses the actual five rows.

The packed player is approximately 48 pixels tall with its foot anchor at (32, 58).
Use nearest-neighbour filtering. For a non-centred sprite, use offset (-32, -58).
Idle loops at 2 fps, run at 10 fps, and kick is a non-looping 10 fps animation.
These timings are preview defaults, not calibrated match contact timings.

## Preview

From the game directory:

```sh
godot --path . res://scenes/oscf_sprite_preview.tscn
```

1 = standing; 2 = running; 3 = kicking; Space = pause;
Left/Right = playback speed; Escape = quit.
The preview repeats the kick for inspection; the SpriteFrames resource itself does not loop it.

Load `footballer.tres` into an AnimatedSprite2D to use these RGBA sprites elsewhere.
Animation names follow `idle_n`, `run_ne`, `kick_e`, etc.

## Status and limitations

This is a starter art/animation set, not a complete replacement for the match players.
AI-generated poses need further continuity and gait polish; the run is especially
worth reviewing in motion. Aligning frame bottoms reduces visible drift but is not
an anatomically tracked planted-foot anchor.

The existing match uses palette-indexed textures with a kit/skin/hair shader.
These sprites are ordinary RGBA textures with fixed colours and cannot be put
through that shader unchanged. Conversion to indexed kit slots or a separate
mask-based material is still required for team recolouring.
Goalkeeper actions, tackles, celebrations, other match animations and contact
timing remain outside this starter set. The existing match art is unchanged.

## Repack

Source regions are already measured and included. To rebuild the 64×64 atlases:

```sh
godot --headless --path . -s res://tools/pack_oscf_sprites.gd
```

Refresh/import the generated PNGs in the editor after repacking.
