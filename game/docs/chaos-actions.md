# OSCF Chaos actions

Eleven playable prototypes, available only in Chaos Football. Classic keeps its
existing movement, tackling, aerial play and rules. The earlier Elastic Save,
Rubber Boot, Rising Steal and Flying Intercept sheets remain separate art prototypes.

## Controls

Hold the special button and press shoot, pass or switch; special on its own does the
referee's move. There is nothing to select or cycle.

| Player | Special |
| --- | --- |
| Player 1 | E |
| Player 2 | Comma |
| Gamepad, either player | Y (top face button) |

| Special + | Does, the first that suits the play (`ChaosActions.BUTTON_MOVES`) |
| --- | --- |
| shoot | line move (with the ball), Rising Fist / Palm Barrage (a ball coming at your keeper), Cyclone Scissor, Grapple Tackle, Stego Sweep, Magnet Sole, Bass Drop |
| pass | Rocket Throw (keeper holding it), Boomerang Cross (a cross on), Pinball Pass, Spring Header, Phalanx Wall |
| switch | Stepover Storm (a man in front), Whirlwind Turn (midfielders), Ghost Step, Dive |
| (alone) | Captain, Bribe |

Aim with the movement stick/keys. With no direction held, use the controlled
player's facing. The HUD shows what each button would do now, with its cost, lit
when ready. Keeper moves command your team's keeper even when you control an
outfielder. The keeper must be free to act. Ordinary shoot, pass, switch and the
super-shot motions still work as before when special isn't held.

The energy bar fills in four segments of 25 and every move costs whole segments.
Each team shares its energy and a special
cooldown: the move's total duration plus two seconds. Energy is spent on activation;
an interrupted move or a miss does not refund it. The AI uses the same checks and
costs, only for sides without a human (or both sides in autoplay).

## Moves and counters

Distances below use the game's 18 pitch pixels per metre. Values are initial
playtest settings, not final balance.

| Move | Cost | Gameplay | Counter |
| --- | ---: | --- | --- |
| Ghost Step | 25 | Push the ball loose and burst in the aimed direction for 0.22 s. | Tackle the exposed ball or cover the exit. No invulnerability. |
| Magnet Sole | 25 | Pull a slow loose ball within 1.5 m toward the boot, then take it through normal possession rules. | Fast passes, held balls and balls above ankle height cannot be pulled. |
| Pinball Pass | 50 | A fast ground pass gets one physical rebound off an opponent. | It cannot home in on a receiver or stun; a keeper or teammate can collect it normally. |
| Stego Sweep | 50 | After a 0.25 s tell, sweep a carrier within 1.8 m in front; ball spills loose and the carrier stumbles for 0.4 s. | Dodge or move out of the arc during the tell; the attacker has 0.4 s recovery. |
| Bass Drop | 50 | A 0.45 s stomp wind-up, then a 2 m pulse stuns at most two nearby ball-contesting opponents for 0.45 s. | Move away or dodge; distant/off-ball opponents are unaffected. |
| Phalanx Wall | 50 | You and one free outfield teammate, 0.9–2.7 m apart, plant for 0.8 s and deflect one low ball. | Loft it over, go around, or disrupt either player. The move does not teleport teammates or seize another human's player. |
| Spring Header | 50 | Jump to meet an aerial ball up to 4.6 m high and head it in the chosen direction. | Bait an early jump; contact requires the ball to pass within 1.2 m during the active window. |
| Boomerang Cross | 50 | A lofted cross curves back toward the starting wing after 0.65 s; the return direction is fixed once. | Any touch cancels the curve; it can still go out. It does not track players. |
| Rocket Throw | 50 | A keeper holding the ball winds up for 0.45 s and throws a long, fast aerial outlet. | Read the lane and intercept. No stun or knockback. |
| Palm Barrage | 50 | The keeper rapidly fans his gloves for 0.7 s, parrying incoming balls within a short forward reach. | Shoot outside the reach, behind him, above the window or during recovery. Thunder Strike breaks through. |
| Cyclone Scissor | 50 | An inverted spinning aerial kick replaces a header: a 0.25 s tell, 0.4 s contact window and 0.45 s landing recovery. | Keep the ball outside the 1.2 m reach, bait the spin or exploit the landing. The kick targets the ball and does not add an area stun. |
| Grapple Tackle | 50 | Defenders only. Wraps up a carrier within 1.9 m: he is held for 0.6 s and the defender comes away with the ball. | Keep away from him, or dodge; stun immunity applies. The referee judges it like any Chaos rough stuff. |
| Stepover Storm | 25 | Midfielders and strikers with the ball. The opponent right in front (2.5 m) stands frozen for 1 s; the ball stays at the feet. | Stand off: nobody in front, nothing to freeze. Immunity applies. |
| Whirlwind Turn | 50 | Midfielders with the ball. A 0.45 s spin along the aim; opponents within 1.8 m can't get a foot in meanwhile. | Wait out the spin and the 0.3 s recovery, or cover where he's turning to. |
| Rising Fist | 50 | The keeper, in his box: a leaping punch clears a loose ball 0.7–5.5 m high within 3.5 m, upfield. | Keep it low, or out of his reach. Thunder Strike breaks through. |

## Line moves (special + shoot, or ↓→ + shoot)

The same input, with the ball, does a different move on each line (`scripts/line_moves.gd`).
Like the super-shots, the bar is spent only once the foot meets the ball: robbed in the
0.35 s wind-up, it costs nothing. The AI uses them too (not the striker's, which it fires
as a shot), and its keeper throws to a free teammate before he punts.

| Line | Move | Cost | Gameplay | Counter |
| --- | --- | ---: | --- | --- |
| Striker | Fireball (Power Strike wind-up) | 50 | The existing Fireball, now wound up with the Power Strike art. | As before. |
| Defender | Bulldozer Clear | 50 | Charges with the ball, flattening the opponents he runs into (once each, judged by the referee), then clears it high upfield, never back toward his own goal. | Dodge the charge; take the ball in the wind-up. |
| Midfielder | Laser Pass | 50 | A flat 760 px/s pass with no aim error to the best teammate along the aim. | Stand in the lane. |
| Keeper | Cannon Punt | 50 | A drop-kick from the hands, far upfield, once he may release it. | Read where it lands. |

New stuns grant 1.5 seconds of immunity after recovery, preventing repeated
stun-locks. Opponents can still win possession. Stoppages cancel actions, flight
effects and locks. Dispossession before a kick/throw's contact prevents release;
a knockdown interrupts the move. Ball contact checks use the last movement segment
to catch balls that travel past the player between physics ticks.

## Art and presentation

Concept boards live in `assets/concepts/chaos_moves/`:

- `01-possession.png`: Ghost Step, Magnet Sole, Pinball Pass.
- `02-duels.png`: Stego Sweep, Bass Drop, Phalanx Wall.
- `03-aerial.png`: Spring Header, Boomerang Cross, Rocket Throw.
- `04-barrage-cyclone.png`: Palm Barrage and Cyclone Scissor.

Each board has a matching generation prompt. The boards are concept illustrations,
not sprite atlases. Live actions currently combine the existing directional,
kit-coloured player sprites with procedural effects: glove afterimages, motion
trails, charge arcs, a short wall, shock rings and an inverted rotating volley.
Spring Header adds cosmetic jump height; hit windows use explicit ball heights.
Custom drawn animation sheets and final tuning can replace these prototype visuals.

The project's existing ignore rules exclude `assets/`; these local concept files
must be included separately when sharing the project, just like the other assets.

The line moves and the four signature specials are drawn like the rest of the match, so a
special doesn't swap the player for a different-looking one. In the Rendered view they're
Blender animations (`tools/blender/footballer.py`, all five drawn directions); in the Pixel
view each plays the nearest FIFA 96 animation (`Anims.PIXEL_LINE_MOVES`: Power Strike the
shot, Bulldozer Clear the diving header, Grapple Tackle the push, Laser Pass the kick,
Whirlwind Turn the rainbow flick, Cannon Punt the volley, Rising Fist the keeper's punch,
Stepover Storm the dummy). Either way a move lasts as long as its drawn art in
`brand/sprites/line_actions` (`manifest.json`), which its timing is tuned to; that art itself
is no longer shown in a match.

Hits show in the effects sheet (`Effects`, art in `assets/sprites/oscf_roles/effects`): an
impact burst when a super, line move, body check, Grapple or Bulldozer connects; dust when a
player slides or is knocked down; an orange shock ring and dust for the Bass Drop and Stego
Stomp; the card spinning over a booked player; a ring when the referee blows, and a large one
for the whistle stun.

## Implementation and validation

`ChaosActions` owns the move catalog, activation, wind-up/contact/recovery, team
cooldowns, AI selection, HUD and projected effects. `Match` ticks it before normal
possession checks. `Footballer` has a temporary movement lock and cosmetic pose
fields. `Ball.touch_revision` invalidates flight effects on a kick, catch or reset.
No new custom `Ball.power` values are introduced, so Fireball/Banana/Thunder retain
their existing path.

From the game directory:

```sh
godot --headless --path . -s res://tests/chaos_actions_test.gd
```

The test checks every action plus energy, cooldown, misses, aerial reach, stun
immunity, lofted wall counters, one rebound, touch cancellation, interruption,
stoppage cleanup, Classic isolation, both players' input and AI ownership.
The existing smoke test already failed its keeper-clearance scenario before this
change; this work does not alter that underlying rule.
