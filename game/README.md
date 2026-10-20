# FIFA 96 Bananas (Godot 4.7)

A new football game built on the original FIFA 96 assets. Personal project: the art,
audio and data belong to EA, so don't distribute it with them.

Current state: the 18 clubs of the **Jupiler Pro League** (`data/league.json`): pick player 1's
club and the opponent (AI, or player 2) on the team select screen. 11 a side, 4-4-2, two halves,
in FIFA 96's 3D "Virtual Stadium" (original crowd, advertising boards, nets) seen from a
side-on TV camera; the boards that advertised the original game show OSCF (Old Skool Crazy
Football) instead. Boots with the PTE (Polycarpus Tack Experiments) intro video and its end
card (any key skips), then the OSCF title screen with
the title music, Space to kick off. Left/Right on the title screen picks **Chaos Football**
(energy bars and super-shots, the default) or **Classic Football** (plain FIFA 96 rules:
same players, ball and AI, no energy, combos are just shots). Up/Down picks 1 or 2 players.
Gamepads work on the title screen too (d-pad to choose, A/B/Start to go on). Then team select:
W/S picks player 1's club, ↑/↓ the opponent's, Space goes on, Esc goes back. Then the match
options: ↑/↓ picks a row, ←/→ changes it, Space kicks off, Esc goes back. Mode (Chaos or
Classic, the same setting as on the title screen), half length (2, 3, 5, 10, 20 or 45 real
minutes; the clock always shows 45 match minutes a half), offside, fouls and cards on or
off, and Friendly or Knockout (extra time and penalties when level). The choices are kept for
the next match until the game is closed.

## Run

```
godot --path game              # play (intro, title, match)
godot --path game res://scenes/main.tscn   # straight to the match
godot --editor --path game     # open in the Godot editor
godot --headless --path game -s res://tests/smoke_test.gd                        # match smoke test (Chaos)
godot --headless --path game -s res://tests/classic_test.gd                      # Classic: no energy, no supers
godot --headless --path game -s res://tests/two_player_test.gd                   # 2 players, gamepad stick
godot --headless --path game -s res://tests/teams_test.gd                        # league clubs load, kit clash
godot --headless --path game -s res://tests/ratings_test.gd                      # ratings: pace, finishing, keepers, tackling
godot --headless --path game -s res://tests/controls_test.gd                     # switch, pass lanes and marker, throw-in
godot --headless --path game -s res://tests/air_test.gd                          # headers, volleys, chest, crosses, posts and bar
godot --headless --path game -s res://tests/rules_test.gd                        # cards, sending off, offside, free kicks
godot --headless --path game -s res://tests/pause_test.gd                        # pause menu stops clock, AI and ball
godot --headless --path game -s res://tests/options_test.gd                      # half length, offside / fouls / cards off
godot --headless --path game -s res://tests/knockout_test.gd                     # extra time, golden goal, shoot-out
godot --path game -s res://tests/demo.gd --write-movie demo.avi --fixed-fps 30 -- seed=2   # record the demo reel
godot --path game -s res://tests/supers_demo.gd --write-movie supers.avi --fixed-fps 30 -- seed=2   # super-shot reel
godot --path game -s res://tests/two_player_demo.gd --write-movie 2p.avi --fixed-fps 30 -- seed=7   # 2-player reel (scripted controls)
```

| Key | Action |
|---|---|
| Left / Right on the title screen | Chaos or Classic Football |
| Up / Down on the title screen | 1 player (vs the AI) or 2 players (Brugge vs Anderlecht) |
| WASD / arrows | move (you control the Brugge player nearest the ball, ringed in yellow; the ring empties as he tires) |
| Space | with the ball: shoot on release, hold for power (aims at goal when you face it). Without: slide tackle |
| ↓ ↘ → then Space | **Fireball** (50 energy): flat rocket, bowls over anyone in the way |
| ← → then Space | **Banana Shot** (50): bends hard toward the far post |
| hold Space 0.8 s, full bar | **Thunder Strike** (100): bicycle kick, slow-mo, lightning ball that nobody can hold |
| Up/Down while taking a penalty | choose the corner |
| (with the ball) | an arrow on the grass shows where a shot would go; holding Space stretches it and turns it orange with power, Thunder Strike light blue when one is ready |
| X or K | pass to the best teammate in the direction you're pushing (the one a triangle marks over his head; a pass lane with an opponent in it counts against a teammate) |
| Q with the ball | **dodge**: a hop that slides and tackles miss for its first 0.25-0.45 s (reactions). Time it as the tackle comes in; in Chaos a dodged slide flashes DODGE! and earns 10 energy |
| **skill moves**: a motion, then Q, with the ball (directions relative to the goal you attack, as for the supers) | double-tap a direction: **nutmeg**, through the legs of the opponent in front and on (dribbling against his defensiveAwareness; fails: he has it). ↓↑ or ↑↓: **rainbow flick** over everyone's head to land 5 m on (nobody can touch it on the way up; ballControl, or it drops short). →←: **backheel** to the teammate behind. The ball goes where he faces; opponents beside him can still nick it before the touch. In Chaos, beating a man with a nutmeg or rainbow flashes and earns 10 energy |
| double-tap a direction, then Space, without the ball | **Body Check** (Chaos, 20 energy): a shoulder charge along that direction; hit the dribbler and strength against his strength and balance decides who goes down (10-90%) |
| Q | switch to the teammate nearest the ball (kept for a second before the automatic switching takes over again) |
| Space / X as a ball in the air comes to you | head or volley it: Space at goal (aim with the stick), X to a teammate. Pressing nothing, your player does what the AI would (see Rules) |
| X from out wide in the last third | to a teammate in (or running into) the box: a cross, at head height |
| X / Space at a throw-in, corner or goal kick | take it (aim with the stick; a throw-in always goes into the field) |
| Space / X at a free kick | Space: shoot (aim with the stick, freeKickAccuracy), X: pass |
| Space at full time | back to the title screen |
| Esc (gamepad Start) | pause: the clock, the AI and the ball stop. ↑/↓ and Space/Enter pick Resume, Restart match or Quit to title; Esc again resumes |
| F1 | animation viewer |
| **2 players** | P1 (Brugge, yellow ring): WASD, Space shoot, X pass. P2 (Anderlecht, cyan ring): arrows, Enter shoot, Right Shift pass, Right Ctrl switch. P1 switches with Q |
| **Gamepad** | left stick or d-pad: move, B: shoot (hold for power) / slide, A: pass, X or LB: switch. Alone: any pad is player 1's. Two players: one pad goes to player 2 (player 1 keeps the keyboard), two pads are player 1's and player 2's in connection order. Plugging in or out rebinds |
| F3 | debug overlay: each player's AI decision (chase, defend, support, dribble, pass, shoot, keeper states), BUSY while an animation locks them, touch cooldown; ball holder and last touch; frame rate, match state, clock, ball height/speed, energy |

## Layout

```
scripts/main.gd           Match: teams, possession, tackles, fouls, penalties, restarts, halves, control switching, goals, kick-offs, sound, HUD
scripts/stadium.gd        3D pitch, boards, stands and goals from the original textures; TV camera; pitch-to-screen projection
scripts/title.gd          boot sequence: PTE intro video and end card, title screen, title music
scripts/team_select.gd    pick both clubs from the league table
scripts/ai.gd             AI decisions: hold formation (shifts with the ball), chase, dribble, pass, shoot, goalkeeping
scripts/team.gd           Team: name, kits, 4-4-2 formation, pitch-side helpers; clubs from data/league.json, change kit on a clash
scripts/footballer.gd     a player's body: movement, animation, carrying the ball, kick/pass/shoot/slide
scripts/ball.gd           ball with height, bounce, friction, holder (dribbler); super-shot flight and trails
scripts/supers.gd         super-shot table (cost, animation, speed, colour) and energy rewards
scripts/combo_input.gd    fighting-game input buffer; directions relative to the goal you attack
scripts/human.gd          one person at the controls: team, controlled player, shot/combo state; keyboard and gamepad bindings
scripts/kit.gdshader      recolours kit parts of the original palette-indexed sprites
scripts/anim_library.gd   autoload "Anims": all player animations, frame lookup by facing (8 dirs)
scripts/pitch.gd          grass from the original texture, markings to real dimensions (18 px/m), baked into the 3D pitch's texture
scripts/anim_viewer.gd    browse the 81 animations
scripts/debug_overlay.gd  F3 overlay: AI decisions (Footballer.ai_state), ball ownership, match state, frame rate
brand/                    our own art, in git: intro.ogv + intro_end.png (PTE intro), title.png (title and team select), title_music.ogg (title loop), ball/ (the ball's 8 roll frames), board_*.png (pitch-side boards)
data/league.json          the 18 Jupiler Pro League clubs: name, 3-letter code, standings, kit colours
data/squads.json          squads and EA ratings, built by tools/build_ea_assets.py (see below)
```

## How it's drawn

The match is simulated in 2D, in pitch pixels (18 px per metre) with a height for the
ball, as before. `Stadium` builds the ground and stadium in 3D (metres) and follows the
ball with a camera placed like FIFA 96's default TV view. Each frame the match projects every
player and the ball through that camera (`Stadium.to_screen`) and draws the original
sprites there, scaled for distance and sorted by depth, the way FIFA 96 put its sprites
into its 3D stadium. Camera height and distance are `CAM_OFFSET` / `CAM_FOV` in `stadium.gd`.

## Clubs

`data/league.json` lists the clubs in table order with their points (Sporza standings, fetched
2026-10-20 after 8 matches) and kit colours. The kit colours are from general knowledge of
each club's home kit, not checked against this season's (ASSUMED): edit the hex values to fix
one. When the two shirts look alike, the away side wears a plain white or dark change kit
(not the club's real away kit). Keeper kits are just contrasting colours.

## Kits

Sprites keep FIFA 96's palette indices. `kit.gdshader` recolours five slots (shirt,
shirt second colour, shorts, socks, boots); kit colours are set per club in
`data/league.json`. The index-to-slot mapping is in `tools/build_godot_assets.py`
(`KIT_SLOTS`), found by where each index appears on the body.

## Squads, ratings, crests and portraits

From EA SPORTS FC 27's public ratings site (1A Pro League: 502 players), for personal use
only and kept out of git:

```
tools/.venv/bin/python -I tools/fetch_ea_ratings.py downloads/ea_fc27   # 6 league pages, 18 crests, ~500 photos; slow on purpose
tools/.venv/bin/python -I tools/build_ea_assets.py downloads/ea_fc27 game
```

`build_ea_assets.py` writes `data/squads.json`: per club, the best 4-4-2 picked greedily
by position and overall rating (GK, RB, CB, CB, LB, RM, CM, CM, LM, ST, ST), then the subs,
each with all ~35 EA ratings. Shirt numbers aren't on EA's pages: numbers go by formation
slot. It also writes `assets/clubs/<SHORT>.png` (crest, on the scoreboard and team select),
`<SHORT>_board.png` (a pitch-side board: every third board shows one of the two clubs) and
`assets/portraits/<id>.png` (the photo pixelated to 40x40, 16 colours, shown above the
controlled player's name). EA has no photo for about half the players, mostly squad
players: they get `unknown.png`, a silhouette. From each photo it also samples a skin
colour (cheeks) and hair colour (crown) that `kit.gdshader` applies to the sprite's skin
and hair palette ramps (indices 219-227 and 215-218); players without a photo keep FIFA
96's own colours. A cap or headband in the photo gives the wrong hair colour. The ratings are loaded into
`Footballer.stats` and change play (see "Ratings in play").

## Ratings in play

`Footballer.skill(stat, lo, hi)` maps a rating onto a range: 40 or less gives `lo`, 95 or
more `hi`, and a player without ratings is halfway (the behaviour before ratings).

| Play | Ratings | 40 → 95 |
|---|---|---|
| top speed, acceleration | sprintSpeed, acceleration | 0.86-1.14x, 0.75-1.25x |
| shot accuracy | finishing (longShots beyond 20 m, penalties at a penalty) | up to 55 px off → 6 px |
| shot speed | shotPower | 0.88-1.12x |
| pass accuracy | shortPassing, longPassing (gkKicking for keepers) | up to 40 px off → 4 px |
| winning the ball | standingTackle vs the holder's ballControl | steal rate 0.5-1.5x / 1.4-0.6x |
| slide tackles | slidingTackle | 55-100% success, one try per slide |
| keeper reach | gkReflexes standing, gkDiving diving | 0.8-1.2x |
| how high a player heads | jumping | 42-54 px (2.3-3.0 m) |
| header / volley at goal | headingAccuracy, volleys | up to 50 px off → 8 px |
| cross accuracy | crossing | up to 50 px off → 6 px |
| aim with an opponent within 3 m | composure | shot / pass / cross error up to 1.8x → 1.1x |
| AI decisions on the ball | reactions | every 0.35 s → 0.15 s |
| dodge (safe part of the hop) | reactions | 0.25 s → 0.45 s; AI dribblers dodge a slide 10% → 45% of the time |
| cutting out the other side's passes | interceptions | reach 0.8x → 1.6x |
| close control | dribbling | ball 16 px → 8 px ahead of the feet; top speed with the ball 0.9x → 1.0x |
| turning and getting going | agility | acceleration 0.85x → 1.15x (on top of acceleration) |
| shoulder to shoulder | strength | steal rate x0.8 → 1.2 (against the holder's); wins a header both go up for; Body Check odds |
| skill moves | dribbling vs defensiveAwareness, ballControl | nutmeg through 21% → 90% (even: 50%); rainbow clean 50% → 100%; AI dribblers with a man right in front try one 5% → 30% of decisions |
| going to ground, getting booked | aggression | AI chaser on the dribbler slides 0.2% → 1.2% of frames; card odds 0.7x → 1.3x |
| free kicks | freeKickAccuracy | up to 55 px off → 6 px |
| getting tired | stamina | fatigue per second running 0.012 → 0.0045 (see Rules) |
| staying on your feet | balance | a slid-in dribbler stays up 0% → 50% of the time; harder to body check (0.9x → 1.1x) |

The ranges are judgement calls, not FIFA 96's or EA's formulas. `tests/ratings_test.gd`
checks each against an elite and a poor player.

## Rebuilding the assets

```
tools/.venv/bin/python -I tools/build_godot_assets.py extracted decoded game
```

`brand/` is made from the full-size originals (kept out of git) with ffmpeg:

```
ffmpeg -i pte-intro-three-mascots.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 brand/intro.ogv
ffmpeg -i pte-end-card-three-mascots.png -vf scale=1280:720:flags=lanczos brand/intro_end.png
ffmpeg -i OSCF_full.jpeg -vf scale=512:64:flags=lanczos brand/board_oscf_full.png
ffmpeg -i OSCF_shor.jpeg -vf scale=512:64:flags=lanczos brand/board_oscf.png
ffmpeg -i OSCF_newpanel.jpeg -vf scale=512:64:flags=lanczos brand/board_oscf_long.png
ffmpeg -i OSCF_PTE_banner.jpeg -vf scale=512:64:flags=lanczos brand/board_pte.png
ffmpeg -i OSCF_FullScreen.jpeg -vf scale=1280:-2:flags=lanczos brand/title.png
```

`brand/ball/` comes from `ball_1.png` (cut out, 8 frames turned in 45° steps):

```
tools/.venv/bin/python -I tools/build_brand_ball.py game/ball_1.png game/brand/ball
```

`brand/title_music.ogg` is "Stadium Breakbeat" (made with Suno) cut to loop: the file ends on
a kick at 121.374 s and `title.gd` loops back to the matching kick 160 beats earlier (52.722 s),
skipping the song's ending; 20 ms of the jump target is crossfaded into the last 20 ms. The
cut was made with a short numpy script (onset search at 139.8 BPM), then:

```
ffmpeg -i title_loop.wav -c:a libvorbis -q:a 6 brand/title_music.ogg
```

## Rules as implemented

- Two halves of `half_seconds` (the match options' half length, 3 minutes of play by default;
  the clock shows match minutes). Ends change
  at half time; at full time the winners celebrate. A friendly can end level.
- Knockout (match options): level after 90 minutes, two halves of extra time (15 match minutes
  each, ends changing), golden goal: the first goal ends the match. Still level, a penalty
  shoot-out: five each, home first, strikers first and the keeper last, then sudden death; it
  stops as soon as one side can't catch up. Each side shoots at the goal it attacked last
  (the ends alternate), and the AI keeper guesses a side as for any penalty.
- Ball over a touchline: throw-in to the other side, thrown from the hands (the ball
  stays hidden in them until the release) and always into the field. Over a goal line: corner if the
  defenders touched it last, otherwise a goal kick (taken by the keeper). Opponents stay
  9.15 m back until it's taken, and out of the penalty area at a goal kick; the AI takes
  it after a short pause.
- A ball in the air: up to head height (34 px plus 8-20 px for jumping) an outfield player
  meets it. Within 20 m of the opponents' goal he heads or volleys it at goal; within 30 m
  of his own he clears it upfield and wide; elsewhere he heads it on to a teammate, or
  chests it down when it's low. Players run to where a ball in the air comes down.
- Crosses: from out wide in the last third (35 m) to a teammate in or running into the box,
  coming down at head height. The AI's wingers go down the line and cross; the forwards
  attack the near and far post, the far-side winger the penalty spot. Central players
  sometimes switch play out to a free winger in the opponents' half.
- Posts and crossbar: off the outside of a post or the front of the bar the ball comes back
  out; off the inside of a post it goes in; off the underside of the bar down and in half
  the time; off the top it loops over.
- Tackling: standing next to the dribbler with your feet on the ball wins it at a rate set by
  standingTackle and strength against his ballControl and strength. A slide (Space without the
  ball; AI chasers on the dribbler slide too, more often the more aggressive they are) wins it
  outright if slidingTackle comes off. A missed slide takes the man 40% of the time, and one
  from behind always does: a foul. A foul in the box gives a penalty (keeper guesses a side
  and dives); elsewhere a free kick where it happened. Within 30 m of goal the AI shoots it
  (freeKickAccuracy); you choose: Space shoots (aim with the stick), X passes.
- Cards: a foul from behind is booked 45% of the time and is a straight red 10%; other fouls
  12% yellow. Aggression scales both (0.7x → 1.3x). A second yellow is a red: the player
  leaves the pitch for the rest of the match. A body check (Chaos) is never a foul.
- Offside: a player in the opponents' half, nearer their goal line than the ball and than the
  second-last defender when a teammate passes or crosses it, is offside if he plays it: a
  free kick to the defenders where he is. Not judged on restarts.
- With fouls off in the match options a slide never takes the man (no free kicks or penalties
  from fouls); with cards off fouls are never booked; with offside off nobody is offside.
- The referee (in black) follows play about 12 m from the ball, points to free kicks and
  shows the cards.
- Keepers catch shots within reach and dive (original low/high dive animations) for shots
  heading past them.
- `tests/demo.gd` stages three situations (Brugge attack, Anderlecht attack, foul in the box)
  and lets the AI play them out; `seed=2` gives a save, a goal and a scored penalty.

## Stamina

Each player has a fatigue level, 0 (fresh) to 1 (spent). It builds while he runs
(`Footballer.TIRING`, by the stamina rating), and every time he goes down (+0.1).
It eases off while he walks or stands, and halves at half time. Spent, he has lost 15% of his
top speed and 20% of his acceleration. The ring around your player empties as he tires: a
quarter is left when he's spent. Over a match the players who chase the ball most end up
near 1, and the rest around 0.3.

**Dizzy** (Chaos Football only): a player knocked down (slid, body checked, bowled over by a
fireball, fouled) at 0.6 fatigue or more gets up seeing stars: DIZZY!, 2.5 s at half speed,
and he can't touch the ball. Expect a few a match.

## Energy and super-shots (Chaos Football only)

`Match.chaos` (a static var, set by the title screen) switches them off for Classic:
`Team.gain` adds nothing, `Match.try_super` refuses, and the energy bars aren't drawn.
Each team has a bar (top left, 0-100; the tick marks 50). It fills from completed passes
(+6), tackles (+10), saves (+15), being fouled (+20), conceding (+25) and dribbling
(+2.5/s). Combo directions are relative to the goal you attack, so ↓↘→ works on both
wings; ↑↗→ is accepted too. The AI spends its bar on shots inside shooting range, and a chaser stronger than the dribbler
sometimes spends 20 on a Body Check.
`tests/supers_demo.gd` stages one of each (`seed=2`: three goals, `supers_demo.mp4`).

## Known simplifications

- No defensive wall at free kicks, no advantage rule; the AI is never told about offside
  (its forwards hold their positions, so it's rarely caught).
- No player-vs-player collision; the net doesn't stop the ball. Sprites are
  always drawn over the 3D scene, so a post never hides a player.
- Sound effects are matched to their use by their spectra, not by ear (`SFX` in `main.gd`:
  kicks, bounce, whistles, crowd "ooh" and roar). No commentary yet: the speech banks
  are decoded but which phrase is which isn't known.
- Match length, camera framing and the AI's shot accuracy are guesses, not FIFA 96's values.
- Frame timing assumes a 30 ticks/s clock (`TICKS_PER_SECOND` in `anim_library.gd`).
# OSCFootball
