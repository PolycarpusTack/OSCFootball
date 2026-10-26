# Polish slices (after EPIC G), 2026-10-26

Feature work is paused (the user's decision, 2026-10-26). Two slices of polish follow, each
planned before it's built. Slice 2 gets its own plan when slice 1 is done.

## Slice 1 — Menus, fonts, commentary

> **Status 2026-10-26: DONE** (awaiting the user's review). P-1 … P-4 are in. Deviations (AS-P1 failed:
> two pixel fonts) and the retro: `state/phase-P1.md`.

Decided by the user:
- free fonts may be downloaded;
- a stylised pixel font for the Pixel edition ("think Minecraft");
- a stylised regular font for the 3D edition ("think RTWC98");
- commentary stays text for now, with many more lines:
  - serious ones: regular football commentary;
  - Chaos ones: over the top and ridiculous, the crowd's behaviour, players' weird behaviour.

| Story | AC |
|---|---|
| **P-1** Fonts | AC1: Pixel uses Pixelify Sans (OFL, `game/fonts/`); Rendered, which stands in for the 3D edition until it exists, uses Exo 2 Italic (OFL). AC2: the font follows the PLAYERS option at once, everywhere (`ThemeDB.fallback_font`, set by `UiText.apply_font`). AC3: each font's OFL licence ships next to it. AC4: no screen's text overflows in either font (screenshots of every screen) |
| **P-2** Menu audit and fixes | AC1: a screenshot of every menu screen in both fonts, with a list of what's wrong (overflow, alignment, inconsistent sizes or colours, missing hints). AC2: those fixed; the list and the before / after go in the phase note |
| **P-3** Commentary, serious | AC1: the main keys (goals, shots, saves, fouls, cards, corners, half and full time) have at least 6 serious lines each. AC2: new "lull" lines in quiet open play (possession, tempo, the shape) |
| **P-4** Commentary, Chaos | AC1: each key can carry a `chaos` pool, used only in Chaos mode on top of the serious lines. AC2: lull lines in Chaos about the crowd and odd player behaviour. AC3: Classic mode never shows a Chaos line (`commentary_test`) |

Order: P-1, P-2 (the audit needs both fonts in), P-3, P-4.

Assumptions:
- AS-P1: Pixelify Sans stays readable down to the smallest text in use (13 px). If not, the
  pixel font is for headings only, and small text keeps a plainer face. Checked in P-1's
  screenshots.
- AS-P2: one weight per font is enough. Pixelify 700 and Exo 2 800 are a start.

## Slice 2 — The match engine for Pixel and 3D (to be planned)

Notes for the plan:
- The hardware is Intel UHD integrated graphics and 15 GB of RAM, so the target is Godot's
  Compatibility renderer.
- Free public-domain (CC0) models may be used, as they are or for reference.
- There's no Mixamo; CMU mocap is a candidate for locomotion.
