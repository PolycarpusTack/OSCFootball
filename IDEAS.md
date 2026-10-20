# Ideas from FIFA 97 and FIFA: Road to World Cup 98

Collected 2026-10-20 from the two games' data (menu and string tables, file names; nothing
run) plus general knowledge. **V** = verified in the data, **A** = assumed. These are design
ideas only: no EA asset goes into the game (see ROADMAP's guiding rule). Sizes as in ROADMAP:
S = an evening, M = a few sessions, L = a project of its own.

## Indoor mode (the favourite)

What the originals did:

- **Teams:** FIFA 98 indoor is 4 outfield players and a keeper ("Must use a 4 player
  formation", V). FIFA 97 had it too, 5 outfield players, with its own formations
  (2-1-2, 1-2-2, 2-0-3, 3-0-2, 2-2-1, V).
- **Arena:** a closed box with boards on all four sides (wall meshes only in the indoor
  arena, V), roughly 1/7 of the outdoor area, about 33 × 42 m (A). Day only, no fly-in (V).
- **Rules:** the ball plays off the boards: no throw-ins, corners or offside (A). Fouls and
  cards stay (A). Players walk off to the side for substitutions (V).
- **Choice:** Indoor / Outdoor in friendlies, leagues and tournaments; FIFA 97 also had a
  surface choice (artificial, wood, turf, grass) and pitch size (V).
- **"Invisible walls" cheat:** boards around an outdoor match (V, both games).

For OSCF, as **3.4 Indoor mode (M)**:

1. Match option "Indoor" (1.2's options screen): a smaller pitch with boards.
2. Boards: the ball bounces off them (the posts and bar already rebound; same idea), and
   players are kept inside.
3. Rules off: no throw-ins, corners, goal kicks or offside; the keeper still restarts after
   a save. Fouls, cards and penalties stay.
4. A 4+1 (or 5+1) formation, picked from the squad; rolling substitutions with 2.1.
5. Own arena art: boards with our sponsors (we already make boards), a hall floor or
   artificial turf, a low crowd. S–M on top.
6. Chaos indoors is a natural fit: rebounds off the boards suit the Pinball Pass and the
   Boomerang Cross; a Chaos "wall pass" special could use them on purpose.

Also: **Invisible walls** as a Chaos modifier for outdoor matches (S).

## Modes and structure

| Idea | Seen in | Fits | Size |
|---|---|---|---|
| Two-legged ties: aggregate, away goals | FIFA 98 World Cup qualifying (V) | 3.1 cup option | M |
| Cup creator: groups, games per opponent, how many go through, how ties are settled (extra time + penalties / extra time / penalties) | FIFA 98 (V) | 3.1 + 1.3 | M |
| Suspensions after 7 / 11 / 15 yellows, injuries carried over | FIFA 98 (V) | 3.2 season | S |
| Penalty shoot-out as its own mode | FIFA 98 (V) | 1.3 | S |
| Training: "score before the defence clears it", "save it", corners, free kicks, keepers on/off; timed challenges with best times | both (V) | 5.2 practice | M |

## Mechanics and options

| Idea | Seen in | Fits | Size |
|---|---|---|---|
| Assists: AI-assisted passes, lobs, headers; automatic crosses; shot aim by stick or CPU | FIFA 98 (V) | 5.4 settings | S |
| Catch-up logic (help for the side behind) | FIFA 98 (V) | Chaos: more energy for the losing side | S |
| Skill levels: amateur / professional / world class | FIFA 98 (V) | AI difficulty | S |
| Named tactics: offside trap, flood the box, double team, overlap, wing-back charge, through-ball runs, man marking, attack / pass / shot bias | FIFA 98 (V) | 2.3 strategy presets | M |
| Referee strictness slider | FIFA 98 (V) | C.4: the Chaos referee's temper | S |
| "Exaggerated" ball physics | FIFA 98 (V) | Chaos modifier | S |
| Cheats: dive, hot potato, big heads, crazy ball, silly moves (98); giant players, metallic men, laser ball, curve ball, crazy bounce, super goalie (97) | both (V) | a Chaos **modifiers** menu: each is one toggle | S each |

## Presentation

| Idea | Seen in | Fits | Size |
|---|---|---|---|
| Weather (sun, rain, snow, sleet), day / night, pitch condition (dry, damp, drenched) and pitch wear | both (V) | 5.3; a wet pitch slows and skids the ball (A) | M |
| Stadium card: capacity, year built, record attendance | FIFA 98 (V) | 5.3, before kick-off | S |
| Captions: hat-trick, equaliser, milestone goal, clean sheet; score flash | FIFA 98 (V) | 1.4 / 4.4 | S |
| Radar toggle, auto replay, saved highlights | both (V) | 5.1 / 5.4 | S |
| About 40 general chants plus club chants, rotated | FIFA 98 (V) | 4.2, recorded our own | S |
| Commentary split into team-name lines and event lines | FIFA 98 (V) | 4.4: record the club names apart from the calls | S |

## A 3D version (OSCF 3D)

Don't use EA's models or motion: FIFA 97/98's are 3D, but they're EA's, and decoding them is
a project of its own. The path that builds on what exists:

1. **Own 3D player, made once** (Blender): one stylised low-poly body (about 1-3k triangles,
   the late-90s look), a standard humanoid rig, the kit as flat material slots so any club
   colours apply. Keeper and referee from the same body. Licence-clear animation sources:
   hand-keyed in Blender, a free animation library whose terms allow games (check them
   first), or your own video motion capture.
2. **Use it for the 2D game first: pre-rendered sprites**, as FIFA 96 itself did. A Blender
   script renders every animation in 5 (or 8) directions with flat kit colours, straight into
   the sheet format `AnimLibrary` reads, ready for the kit shader. This replaces the 42 FIFA 96
   animations (section A of the replacement list) and gives the role moves team colours
   (C.6) and every direction.
3. **Then OSCF 3D as a second view on the same match.** The match is simulated in pitch
   coordinates with the ball's height, and drawn through one projection
   (`stadium.to_screen()`, called from `Match._process`). A 3D view replaces that drawing
   layer; rules, AI, Chaos and the referee stay. Prototype: a 3D pitch with 22 capsules driven by
   the existing match, then the models, then animation blending and the ball meeting the
   foot (the hard part).

Steps 1-2 are L together but pay off in 2D right away; step 3 is L on its own.
