## 0.2.0

- Requires Dart 3.13 or later.
- New `roll` command: `roll 20`, `roll d20`, `roll 2d20`. Usable as a one-shot
  command or inside the interactive prompt.
- Any die size is accepted (for example `d18`), up to 1,000 dice of up to
  1,000,000 sides.
- Advantage (`-a`, `--adv`, `--advantage`) and disadvantage (`-d`, `--dis`,
  `--disadvantage`).
- Dice are drawn and animated in the terminal, with number faces or dots
  (pips up to a d6, Roman numerals above).
- Colour for advantage (green) and disadvantage (red).
- Saved settings via `roll config` for `faces`, `animate` and `color`, with
  per-roll flags `--faces`, `--[no-]animate` and `--[no-]color`.
- `help`, `--help` and `--version`.
- Fixed: dice could never roll their highest face (a d20 rolled 1 to 19).
- Fixed: crash on end of input (Ctrl-D).
- Input is now case-insensitive and ignores extra whitespace.
- Code moved to `lib/`, tests added under `test/`, unused `mockito` removed.

## 0.1.1

- Interactive prompt with fixed dice: d4, d6, d8, d10, d12, d20, d100.
