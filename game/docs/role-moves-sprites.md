# Role moves: sprite brief

Sprites for the role flavours (plan step 3): the same input gives a different move
depending on the player's line, plus one signature move per line. They complement the 11
Chaos actions in `chaos-actions.md` and don't repeat them: Ghost Step is already the burst
dribble, Stego Sweep the defender's sweep, Rocket Throw and Palm Barrage the keeper's throw
and parries.

Use the body-mechanics column to picture each pose. Public prompts and documentation
should describe the original footballer's motion directly, without external character
or move names.

## The moves

### Shared input: ↓↘→ + Space, one move per line

| # | Line | Our name | What it does in play | Body mechanics | Frames |
|---|---|---|---|---|---|
| 1 | Striker | Power Strike | Fireball shot (exists): new wind-up | Grounded full-body power strike: very low, wide stance, then a full-body strike | 5 |
| 2 | Defender | Bulldozer Clear | Shoulder-first charge, then a huge clearing kick; flattens whoever's in the way | Horizontal body charge / driving shoulder charge: leaning far forward, shoulder first | 6 |
| 3 | Midfielder | Laser Pass | Hard flat pass through a lane | Gather-and-thrust motion, delivered with the foot: side-foot drive, long low follow-through | 5 |
| 4 | Keeper | Cannon Punt | Drop-kick from the hands, far upfield | Crossed-arm sweeping wind-up (arms crossed back), then the release as a volley from the hands | 6 |

### One signature move per line

| # | Line | Our name | What it does in play | Body mechanics | Frames |
|---|---|---|---|---|---|
| 5 | Defender | Grapple Tackle | Wraps up the dribbler, spins once, comes away with the ball | Wrestling waist grab and pivot: ONLY the grab-and-spin, no slam | 8 (2 sheets of 4) |
| 6 | Winger | Stepover Storm | Rapid stepovers; the defender in front freezes for a moment | Rapid alternating leg rhythm: rapid alternating leg flicks, upper body still | 6 |
| 7 | Midfielder | Whirlwind Turn | 360° spin on one leg, shielding the ball, away from pressure | Upright rotating kick: spinning on one leg, arms out (stays on the ground) | 8 (2 sheets of 4) |
| 8 | Keeper | Rising Fist | Leaping one-fist punch save for crosses and lobs | Rising punch / arched aerial kick: explosive vertical leap, one fist high | 7 (sheets of 4 + 3) |

### Effects (one sheet, no character)

| # | Effect | Frames | Notes |
|---|---|---|---|
| 9 | Impact burst (comic star) | 4 | White/yellow, for tackles and clearances |
| 10 | Dust puff | 4 | Light brown, for charges and landings |
| 11 | Yellow card and red card spinning | 4 each | Flat rectangle tumbling, for the referee (step 1) |
| 12 | Whistle shockwave ring | 4 | Expanding ring, slightly squashed (seen from above) |

### Referee (for the Chaos referee steps; replaces EA's referee)

| # | Animation | Frames | Notes |
|---|---|---|---|
| 13 | Idle and run | 2 + 5 | The same sheets as `oscf_starter`, in the referee kit |
| 14 | Whistle blow | 4 | Whistle to the mouth, cheeks puffed, other arm raised |
| 15 | Show card | 4 | Arm straight up, card in hand (draw the card **pure green #00FF00** so we colour it yellow or red in the game) |
| 16 | Point | 3 | Arm straight out to the side (free kick), whistle in the other hand |

## Rules for every sheet (as `oscf_starter`, so they fit the same pipeline)

- **Character:** the same footballer as `oscf_starter`, same face, proportions and kit
  (ivory shirt with red collar, royal-blue shorts, ivory socks, black boots). Keep the kit
  **flat**: few shades, clean colour areas. That lets us turn the colours into team colours
  in the game (the original sprites work that way). Keeper: the same man in a
  **plain bright green** shirt and gloves. Referee: **all black** with a white collar.
- **No ball** in the sprites (the game draws the ball itself), except the keeper's Cannon
  Punt: in its first 2 frames the ball is in his hands (as in the throw-in).
- **Background:** truly transparent, no checkerboard, no floor, no shadows, no text.
- **Directions:** for moves only **3 columns**: NE (rear three quarter), E (right profile),
  SE (front three quarter). The game mirrors them for the other side, and north/south fall back
  to the nearest one. Referee idle/run: all **5 columns** as in `oscf_starter`.
- **Frames:** at most **5 rows** per sheet (generators often return 5 when you ask for 6).
  Longer moves: split into two sheets ("part 1: frames 1-4", "part 2: frames 5-8") with the
  same canvas and scale.
- **Canvas:** 1536 wide, height 256 per row. Character about 180 px tall in a cell, with
  plenty of room at the sides (wide poses like the Whirlwind Turn and Grapple Tackle need it).
- **Camera:** orthographic, 15° above the horizon, the same in every cell and every sheet.
- **Style:** polished late-90s pre-rendered 3D football sprites, crisp outline, NOT
  photorealistic, NOT chibi, no motion blur or speed lines (we do those in the game).
- **Mark the contact frame:** tell me per move which frame the foot/fist meets the ball (or
  the defender reaches the attacker). Save the prompt next to it as `<move>_prompt.txt`.

## Prompt template

Fill in the parts in [brackets]. Example for the Bulldozer Clear:

> Create an ORIGINAL football game sprite sheet on a truly TRANSPARENT background, no
> checkerboard painted into the image. Canvas 1536x1536. Exactly THREE columns and FIVE rows
> of the SAME adult male footballer, 15 separate full-body sprites in an invisible grid of
> equal cells. Use the attached footballer sheet as the EXACT character, kit and rendering
> style. Columns are fixed directions: column 1 rear three quarter (northeast), column 2 right
> profile (east), column 3 front three quarter (southeast). Every row is the next frame of ONE
> move, the same in every column: [row 1: crouched, weight back, shoulders hunched; row 2:
> explodes forward, body almost horizontal, right shoulder leading; row 3: full charge, both
> feet off the ground, shoulder first; row 4: plants the left foot, right leg swings far back;
> row 5: huge kick, right leg high and straight, arms flung wide]. Consistent proportions and
> scale, character about 180 pixels tall, generous margins, no figure crosses a cell
> boundary. Kit with flat colour areas: ivory shirt, red collar, royal-blue shorts, ivory
> socks, black boots. No ball, no text, no logos, no motion trails, no shadows, no floor.
> Slightly elevated orthographic camera, identical in all cells.

For a 6-frame move like this one: make the 6th frame (landing, recovery) a second sheet of 1
row, or leave it out; tell me which.

## Order (the most useful first)

1. Effects (9-12) and referee (13-16): needed for the Chaos referee, which is coming next.
2. Bulldozer Clear, Laser Pass, Cannon Punt, Power Strike (1-4): the shared input.
3. The signature moves (5-8).

Put the files in `game/assets/sprites/oscf_roles/` (sources + prompts). I'll pack them
(64 px cells like `oscf_starter`, wider where needed) and wire them up.
