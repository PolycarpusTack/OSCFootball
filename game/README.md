# FIFA 96 Bananas (Godot 4.7)

A new football game built on the original FIFA 96 assets. Personal project: the art,
audio and data belong to EA, so don't distribute it with them.

Current state: the 18 clubs of the **Jupiler Pro League** (`data/league.json`): pick player 1's
club and the opponent (AI, or player 2) on the team select screen. 11 a side, 4-4-2, two halves,
in FIFA 96's 3D "Virtual Stadium" (stands filled with the two clubs' own supporters, the home
fans on the long side and the far end and the away fans behind the left goal; advertising boards, nets) seen from a
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

## Chaos special actions

Chaos now includes eleven additional playable action prototypes: Ghost Step, Magnet Sole,
Pinball Pass, Stego Sweep, Bass Drop, Phalanx Wall, Spring Header, Boomerang Cross,
Rocket Throw, **Palm Barrage** (rapid keeper parries) and **Cyclone Scissor**
(an inverted spinning aerial kick). Three more deal with the referee: **Dive**, **Captain** and
**Bribe** (see The Chaos referee). Each line has a signature special too: **Grapple Tackle**
(defender), **Stepover Storm** (midfielder or striker), **Whirlwind Turn** (midfielder) and
**Rising Fist** (keeper).

**Line moves:** ↓↘→ then shoot, with the ball, does a different move on each line: a
striker's **Fireball**, a defender's **Bulldozer Clear** (charges, flattening whoever's in the
way, then hoofs it upfield; 40 energy), a midfielder's **Laser Pass** (flat, fast, straight to
the man; 30) and the keeper's **Cannon Punt** (from the hands, far upfield, once the box is
clear; 30). The role moves play our own art (`brand/sprites/line_actions`), recoloured to
each team's kit.

**P1: E to use, R to cycle. P2: comma to use, period to cycle. Gamepad: Y / RB.**
R cycles only the moves your player's line can do (plus the keeper's and the captain's).
The HUD shows the selected one between its neighbours, white when ready and grey when not,
and what it still needs. Along the bottom, each player's **prompts** show what his player can
do right now (with the ball, without it, a ball in the air, a keeper holding it) in the
buttons of the keyboard or gamepad he's using, Chaos costs grey when the bar is short; in
front, the directions he's just entered (F2 hides them), or what a combo he couldn't afford
needs ("LASER PASS: NEED 30"). Ticks on the energy bar mark the cost of his ↓↘→ move
(orange) and his selected special (cyan). **Esc → MOVES**, or **M / Y on the title screen**, lists every move: its input in the keyboard's or
the gamepad's buttons, its cost and what it does, your line's moves first, with the
animation looping beside it. Keeper moves command your keeper
while you control an outfielder. Classic mode has none of these powers.
See [controls, counters, costs and art](docs/chaos-actions.md) for details.

## Run

```
godot --path game              # play (intro, title, match)
godot --path game res://scenes/main.tscn   # straight to the match
godot --editor --path game     # open in the Godot editor
godot --headless --path game -s res://tests/smoke_test.gd                        # match smoke test (Chaos)
godot --headless --path game -s res://tests/chaos_actions_test.gd                # 11 actions, counters, input and Classic isolation
godot --headless --path game -s res://tests/role_moves_test.gd                   # line moves (↓↘→ per line) and the four signature specials
godot --headless --path game -s res://tests/move_list_test.gd                    # pause-menu move list, special picker by line
godot --headless --path game -s res://tests/control_hints_test.gd                # bottom prompts per situation, input trail, cost ticks
godot --headless --path game -s res://tests/classic_test.gd                      # Classic: no energy, no supers
godot --headless --path game -s res://tests/two_player_test.gd                   # 2 players, gamepad stick
godot --headless --path game -s res://tests/teams_test.gd                        # league clubs load, kit clash
godot --headless --path game -s res://tests/ratings_test.gd                      # ratings: pace, finishing, keepers, tackling
godot --headless --path game -s res://tests/engine_test.gd                       # AI: shooting range, decisions, meeting passes, press, cover
godot --headless --path game -s res://tests/controls_test.gd                     # switch, pass lanes and marker, throw-in
godot --headless --path game -s res://tests/air_test.gd                          # headers, volleys, chest, crosses, posts and bar
godot --headless --path game -s res://tests/rules_test.gd                        # cards, sending off, offside, free kicks
godot --headless --path game -s res://tests/referee_art_test.gd                  # the referee's own sprites, yellow and red card
godot --headless --path game -s res://tests/pause_test.gd                        # pause menu stops clock, AI and ball
godot --headless --path game -s res://tests/options_test.gd                      # half length, offside / fouls / cards off
godot --headless --path game -s res://tests/knockout_test.gd                     # extra time, golden goal, shoot-out
godot --headless --path game -s res://tests/stats_test.gd                        # match stats, Man of the Match, full-time screen
godot --headless --path game -s res://tests/referee_test.gd                      # Chaos referee: view cone, discipline meter, mood, "Sorry, ref!", dive, captain, whistle stun, bribe
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
| ↓ ↘ → then Space | the line move: a striker's **Fireball** (50 energy): flat rocket, bowls over anyone in the way. Defender: Bulldozer Clear, midfielder: Laser Pass, keeper: Cannon Punt (see Chaos special actions) |
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
| Space at full time | back to the title screen (the full-time screen shows possession, goals, shots, saves, fouls, cards, offsides and corners for each side, and the Man of the Match) |
| Esc (gamepad Start) | pause: the clock, the AI and the ball stop. ↑/↓ and Space/Enter pick Resume, Moves (every move, see Chaos special actions), Restart match or Quit to title; Esc again resumes |
| F1 | animation viewer |
| F2 | hide / show the input trail in front of the prompts |
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
scripts/control_hints.gd  the prompts along the bottom of a match, input trail, cost ticks on the energy bar
scripts/line_moves.gd     Chaos line moves: ↓↘→ per line (Bulldozer Clear, Laser Pass, Cannon Punt)
scripts/combo_input.gd    fighting-game input buffer; directions relative to the goal you attack
scripts/human.gd          one person at the controls: team, controlled player, shot/combo state; keyboard and gamepad bindings
scripts/kit.gdshader      recolours kit parts of the original palette-indexed sprites
scripts/anim_library.gd   autoload "Anims": all player animations, frame lookup by facing (8 dirs)
scripts/pitch.gd          grass from the original texture, markings to real dimensions (18 px/m), baked into the 3D pitch's texture
scripts/anim_viewer.gd    browse the 81 animations
scripts/debug_overlay.gd  F3 overlay: AI decisions (Footballer.ai_state), ball ownership, match state, frame rate
brand/                    our own art, in git: intro.ogv + intro_end.png (PTE intro), title.png (title and team select), title_music.ogg (title loop), ball/ (the ball's 8 roll frames), board_*.png (pitch-side boards), crowds/ (each club's supporters, <SHORT>.png; manifest.json)
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
| seeing a pass (AI and the pass button's pick) | vision | sees mates up to 400 → 560 px away, 45° → 75° either side of the pass button's aim; a cut-off lane counts against a mate 150 → 350; leads a runner 0.15 s → 0.65 s of his run |
| switching play, through balls (AI) | vision | out to a free winger 3% → 13% of decisions; a forward with room ahead gets the ball played 6 m into that space 0% → 30% of decisions |
| bending it | curve | long shots, free-kick shots, crosses and corners leave 0 → 0.3 rad off line and curl in on target: a keeper reading the ball's line dives late or the wrong way |
| shooting from distance (AI) | curve | shoots from 18 m, up to 25 m at 95 (never less); from beyond 20 m goes for the corner furthest from the keeper 0% → 100% of shots |
| weaker foot | weak_foot, preferred_foot | kicking more than 20° across the body: shot / pass / cross error x1.6 (1 star) → x1.0 (5 stars, or no squad) |
| skill moves | skill_moves | nutmeg and backheel need 2 stars, rainbow 3 (no squad: 3); without them the switch button dodges. AI tries them x stars / 3 as often |
| holding a shot | gkHandling | a hard shot he gets to is spilled loose 40% → 0% (67.5 and up hold everything) |
| narrowing the angle (AI keeper) | gkPositioning | stands 8 → 28 px off his line; comes for a loose ball 120 → 200 px from goal |
| waiting on the offside line (AI) | positioning | 0.9 m → 0.1 m behind it |
| who goes for the ball (AI chaser, human auto-switch) | sprintSpeed, acceleration, agility, reactions, fatigue | the quickest there, not the nearest: 0.3 s → 0.1 s to set off, then the run-up and top speed |
| first touch | ballControl, reactions | a ball faster than 360 → 240 px/s may run 2-4 m off him: up to 50% → 0% of the time |
| marking (AI) | defensiveAwareness | 2.5 m → 0.5 m goal-side; reads the run 0.3 s behind it → 0.3 s ahead |
| cutting off a pass (AI, off the ball) | interceptions | steps from his spot toward the lane to the nearest attacker: not at all → half way, at most 4 m |
| dribbling round a man (AI) | dribbling | bends 0.2 → 0.9 rad away from an opponent in the way, more the closer he is |

The ranges are judgement calls, not FIFA 96's or EA's formulas. `tests/ratings_test.gd`
checks each against an elite and a poor player.

## Rebuilding the assets

From the repository root, with `FIFA96.ISO` there. Needs Python 3.12, `7z` and `ffmpeg`.

```
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
7z x FIFA96.ISO -oextracted                                                 # the CD's files
tools/.venv/bin/python -I tools/extract_all.py extracted decoded             # everything to PNG/WAV/MP4/TSV/CSV, ~10 min
tools/.venv/bin/python -I tools/build_godot_assets.py extracted decoded game # what the game loads, into game/assets
```

Then the squads (see "Squads, ratings, crests and portraits"): `fetch_ea_ratings.py`, then `build_ea_assets.py`. Each
step exits non-zero if anything failed or is missing (`decoded/errors.txt` lists extraction
errors). `build_ea_assets.py` draws the club boards with DejaVu Sans Bold; set `OSCF_FONT` to
another bold TTF where that isn't installed.

Older builds also copied the FIFA 96 music cues and the 1995 database into the project. Nothing
loads them, and Godot imported the CSVs as translations that shipped in every build. If they
are still there: `rm -r game/assets/audio/music game/data/*.csv* game/data/*.translation`.

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

`brand/crowds/` comes from the 18 generated 2048×512 club crowds (six rows of fans, seamless
left/right), each scaled to 1024×256 and named by the club's short code:
`convert club-brugge-2048x512.png -filter Lanczos -resize 1024x256! -strip brand/crowds/BRU.png`.

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
- Cards (Classic): a foul from behind is booked 45% of the time and is a straight red 10%;
  other fouls 12% yellow. Aggression scales both (0.7x → 1.3x). A second yellow is a red: the
  player leaves the pitch for the rest of the match. In Chaos the yellows come from the
  discipline meter instead (see The Chaos referee); straight reds stay.
- Offside: a player in the opponents' half, nearer their goal line than the ball and than the
  second-last defender when a teammate kicks it (a pass, a cross, a shot, a header), is
  offside if he plays that ball, also after it comes back off the woodwork: a free kick to
  the defenders where he is. Not judged on restarts. The AI's attackers wait level with the
  offside line, and the AI doesn't pass to a teammate standing offside.
- With fouls off in the match options a slide never takes the man (no free kicks or penalties
  from fouls); with cards off fouls are never booked; with offside off nobody is offside.
- Match stats (`match_stats.gd`) are counted from the match's events: a shot is a shot,
  header or volley at goal or a super-shot from within 40 m (kicks marked as shots from
  farther out are punts and blind passes). Possession is the time on the ball (or since the
  last touch) in open play. Shoot-out kicks don't count. Man of the Match: 4 points a goal,
  2 a save, 1 a shot; level, the winners' man.
- The referee (in black) follows play about 12 m from the ball, points to free kicks,
  shows the cards and blows the whistle. He is our own art (`assets/sprites/oscf_roles`,
  packed by `tools/pack_oscf_referee.gd`), not FIFA 96's; the card is keyed green in the
  sheets and drawn yellow or red by `scripts/referee_card.gdshader`. A booking also spins the
  card over the player, and his whistle sends out a ring (`scripts/effects.gd`, from the
  same folder's effects sheet; the tool packs that too).
- Keepers catch shots within reach and dive (original low/high dive animations) for shots
  heading past them. A keeper holding the ball in his box (AI or human) can't play it until
  opponents are 9.15 m away, which they walk to, or after six seconds.
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

## The Chaos referee (Chaos Football only)

**View cone:** the referee looks toward the ball, turning to it at about 140° a second, and
sees 50° either side of where he looks, up to 40 m (a faint wedge on the grass), and
anything within 6 m of him. A foul he doesn't see goes unpunished: REF DIDN'T SEE IT!, the
victim goes down, play on.

**Discipline meter:** every player has one (your player's is the bar under his portrait).
What the referee sees fills it: a foul from behind 45, another foul 30, a body check 20, a
Chaos stun (Stego Sweep, Bass Drop) 20. Full, he's booked and it starts again: twice full is
a red. It cools by 1.5 a second of play. A body check is never a foul, but the referee
remembers it.

**His mood:** two bars over his head, one per side (home on top, in the sides' colours).
Every offence he sees makes him angrier with that side (half of what it adds to the meter),
and the angrier he is, the faster the meters of that side fill: up to double when furious.
It cools by 1 a second of play.

**"Sorry, ref!":** press special (E; player 2 comma; pad Y) just after a foul of yours has
been called, while SORRY? shows over his head (half a second). He takes back half of what
it added to the meter and to his mood, and a booking it earned becomes a warning (the meter
left at 80). Pressed at a stoppage with nothing to be sorry for, it's dissent: +20 mood
with your side. Only for fouls, which stop play; the AI never says sorry.

**The dive** (Chaos action DIVE, 10 energy, with an opponent within 2.5 m): your player
throws himself down and the ball rolls free. If the referee doesn't see it, nothing comes of it.
If he does, he may fall for it: a foul on you by the nearest opponent (a penalty in the box;
the opponent's meter fills as for any foul). The odds are 50% for an average diver with a calm
referee, more for a high composure rating, down to a fifth of that when he's furious with your
side. If he sees through it: a yellow for diving, +20 mood, a free kick the other way.

**The captain** (Chaos action CAPTAIN, 30 energy): your side's captain, the outfield player
with the highest composure rating (a C over his head), has a word with the referee from
within 25 m: his mood with your side drops by 40. Only when he's angry with you at all.

**The whistle stun:** when his mood with a side is full, he fumes for 1.2 seconds, for all to
see (a pulsing ring around him and !! next to his mood bars, THE REF IS FUMING!), then blows
his top: that side's players within 20 m of him are stunned for 1.2 seconds, a stunned
dribbler drops the ball, and his mood with the side falls to 50. Get away from him while he
fumes, dodge, or send the captain: talked down in time, he doesn't blow.

**The bribe** (Chaos action BRIBE, a full bar, within 10 m of the referee): for 30 seconds
of play he leans your way: he's no longer angry with you, your offences don't fill any
meter, your fouls are play on and he falls for every dive. A gold coin ringed in your colour
by his mood bars shows it, to both sides. One time in three the linesman saw it: two
seconds later he flags it, the bribe is off, the other side gets a penalty and the referee
is furious with you (so a whistle stun follows).

The AI dives too, with the ball in the attacking half, when the referee sees it and is calm
enough to fall for it at least 35% of the time; it sends its captain once his mood with it
reaches 30, or when he's fuming. It never says sorry and never bribes.

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

- No defensive wall at free kicks, no advantage rule. The AI defenders don't play an offside
  trap.
- No player-vs-player collision; the net doesn't stop the ball. Sprites are
  always drawn over the 3D scene, so a post never hides a player.
- Sound effects are matched to their use by their spectra, not by ear (`SFX` in `main.gd`:
  kicks, bounce, whistles, crowd "ooh" and roar). No commentary yet: the speech banks
  are decoded but which phrase is which isn't known.
- Match length, camera framing and the AI's shot accuracy are guesses, not FIFA 96's values.
- Frame timing assumes a 30 ticks/s clock (`TICKS_PER_SECOND` in `anim_library.gd`).
# OSCFootball
