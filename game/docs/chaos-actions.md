# OSCF Chaos actions

Eleven playable prototypes, available only in Chaos Football. Classic keeps its
existing movement, tackling, aerial play and rules. The earlier Elastic Save,
Rubber Boot, Rising Steal and Flying Intercept sheets remain separate art prototypes.

## Controls

| Player | Use selected move | Next move |
| --- | --- | --- |
| Player 1 | E | R |
| Player 2 | Comma | Period |
| Gamepad, either player | Y (top face button) | RB |

Aim with the movement stick/keys. With no direction held, use the controlled
player's facing. The HUD shows the selected move, energy cost and why it cannot
currently be used. Rocket Throw and Palm Barrage command your team's keeper even
when you control an outfielder. The keeper must be free to act. Ordinary shoot,
pass, switch and existing super-shot combinations still work as before.

Use R/Period/RB to cycle the full list. Each team shares its energy and a special
cooldown: the move's total duration plus two seconds. Energy is spent on activation;
an interrupted move or a miss does not refund it. The AI uses the same checks and
costs, only for sides without a human (or both sides in autoplay).

## Moves and counters

Distances below use the game's 18 pitch pixels per metre. Values are initial
playtest settings, not final balance.

| Move | Cost | Gameplay | Counter |
| --- | ---: | --- | --- |
| Ghost Step | 20 | Push the ball loose and burst in the aimed direction for 0.22 s. | Tackle the exposed ball or cover the exit. No invulnerability. |
| Magnet Sole | 25 | Pull a slow loose ball within 1.5 m toward the boot, then take it through normal possession rules. | Fast passes, held balls and balls above ankle height cannot be pulled. |
| Pinball Pass | 40 | A fast ground pass gets one physical rebound off an opponent. | It cannot home in on a receiver or stun; a keeper or teammate can collect it normally. |
| Stego Sweep | 30 | After a 0.25 s tell, sweep a carrier within 1.8 m in front; ball spills loose and the carrier stumbles for 0.4 s. | Dodge or move out of the arc during the tell; the attacker has 0.4 s recovery. |
| Bass Drop | 50 | A 0.45 s stomp wind-up, then a 2 m pulse stuns at most two nearby ball-contesting opponents for 0.45 s. | Move away or dodge; distant/off-ball opponents are unaffected. |
| Phalanx Wall | 40 | You and one free outfield teammate, 0.9–2.7 m apart, plant for 0.8 s and deflect one low ball. | Loft it over, go around, or disrupt either player. The move does not teleport teammates or seize another human's player. |
| Spring Header | 30 | Jump to meet an aerial ball up to 4.6 m high and head it in the chosen direction. | Bait an early jump; contact requires the ball to pass within 1.2 m during the active window. |
| Boomerang Cross | 40 | A lofted cross curves back toward the starting wing after 0.65 s; the return direction is fixed once. | Any touch cancels the curve; it can still go out. It does not track players. |
| Rocket Throw | 35 | A keeper holding the ball winds up for 0.45 s and throws a long, fast aerial outlet. | Read the lane and intercept. No stun or knockback. |
| Palm Barrage | 40 | The keeper rapidly fans his gloves for 0.7 s, parrying incoming balls within a short forward reach. | Shoot outside the reach, behind him, above the window or during recovery. Thunder Strike breaks through. |
| Cyclone Scissor | 40 | An inverted spinning aerial kick replaces a header: a 0.25 s tell, 0.4 s contact window and 0.45 s landing recovery. | Keep the ball outside the 1.2 m reach, bait the spin or exploit the landing. The kick targets the ball and does not add an area stun. |

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
