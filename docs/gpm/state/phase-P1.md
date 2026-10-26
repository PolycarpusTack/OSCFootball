# Phase summary: polish slice 1 (menus, fonts, commentary), 2026-10-26

Branch `feature/A-cup`, on top of EPICs A to G. Nothing has been committed yet.

## What was built

| Story | Files | Test |
|---|---|---|
| P-1 Fonts | `game/fonts/` (NEW; `README.md` lists sources, licences and changes). `ui_text.gd`: `apply_font()` sets the default theme's font and a "Heading" Label variation; `label()` makes 28 px and up a heading. Called at the title, the match options' PLAYERS row and the pause menu's | `rendered_test`: a Label already on screen changes font with the option |
| P-2 Menu audit | A screenshot of all 17 screens in both fonts. Fixes: `UiText.hint()` for every key-hint line (12 screens); the full-time hint says where SPACE goes (title, cup or table); the bracket's heading names the cup | screenshots; the suite |
| P-3 Serious commentary | `commentary_lines.gd`: at least 6 serious lines for the main moments; `lull` lines | `commentary_test` |
| P-4 Chaos commentary | `chaos` pools, added in Chaos mode only; the silly lines moved there from the serious pools; 22 Chaos lull lines (the crowd, the players' odd ways). `commentary.gd`: `_lull()` after `LULL` (14 s) of open play with nothing said | `commentary_test`: Classic 0 Chaos lines in 1,500 picks, Chaos about 600 |

## The fonts

| Edition | Body | Headings |
|---|---|---|
| Pixel | Jersey 10, unitsPerEm 1400 → 1085 so its capitals match Exo 2's at the same size; renamed "OSCF Jersey" | Pixelify Sans, weight 500 |
| Rendered (and the 3D edition) | Exo 2 Italic, weight 800 | the same |

All three are OFL 1.1, from the Google Fonts repository; none declares a Reserved Font Name.

## Deviations from the plan (for your review)

- **AS-P1 failed, so the Pixel edition uses two fonts.** Pixelify Sans, the most
  Minecraft-like, isn't readable below about 20 px: C reads as O, B as 8, 2 as 8. It's kept
  for the headings; Jersey 10, also a pixel font, does the rest. I tried DotGothic16 (too
  thin) and Silkscreen (too wide) too.
- **Jersey 10 is modified** (scaled, renamed), as the OFL allows; the change is in
  `fonts/README.md`.
- **The font follows the PLAYERS option** (Pixel or Rendered), since the 3D edition doesn't
  exist yet. When it does, it will use the Rendered font.
- **The anim viewer (F1) and the in-match control prompts keep their own hint style.** One is
  a developer's tool; the other is boxed keys, a different design.
- **Full time showed 0% / 100% possession** in a 40-second autoplay. It's counted from the
  last touch, and one side kept it, so this probably isn't a bug. Out of scope; noted only.

## Retro

- **Full suite: 43 of 43 pass.**
- **Rework:**
  - My first font switch set `ThemeDB.fallback_font`, which Labels don't read; they read the
    default theme's font and cache it. The first test passed anyway, because it read back the
    setting it had written. It now checks a Label that's on screen.
  - The audit script had its own leftovers: a season screen it opened through
    `simulate_mine`, and a black first frame for the title. Neither is in the game.
  - The lull test read the queue, but `tick()` puts a lone line straight up.
- **TD:** none new. `UiText.hint()` replaced 12 hand-made hint strings.
