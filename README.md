# Dungeon Dice

A dice-rolling CLI for Dungeons & Dragons and other tabletop games, written in Dart.

Created by Gerard Ragbir.

## Usage

```
roll 20         one d20
roll d20        one d20
roll 2d20       two d20, with each die and the total
roll d18        any die size works
roll d20 2d6    several rolls at once
```

In a terminal the dice are drawn and tumble for a moment before settling:

```
$ roll 2d20
.-------. .-------.
|       | |       |
|  18   | |   8   |
|       | |       |
'-------' '-------'
2d20: [18, 8] = 26
```

When the output is piped or redirected, or the dice are too many to fit the terminal width, only the last line is printed.

### Advantage and disadvantage

| Flag | Effect |
| --- | --- |
| `-a`, `--adv`, `--advantage` | Roll twice and keep the higher total |
| `-d`, `--dis`, `--disadvantage` | Roll twice and keep the lower total |

```
$ roll d20 --dis
.-------.   .-------.
|       |   |       |
|  12   |   |  19   |
|       |   |       |
'-------'   '-------'
d20 (disadvantage): [12, 19] -> 12
```

The kept roll is green for advantage and red for disadvantage, and the discarded roll is dimmed.

With more than one die, the whole roll is made twice and the totals are compared. Using both flags together cancels out to a normal roll.

Other flags: `-h` / `--help` and `--version`.

### Settings

| Setting | Values | Default | Effect |
| --- | --- | --- | --- |
| `faces` | `numbers`, `dots` | `numbers` | What the drawn dice show |
| `animate` | `on`, `off` | `on` | `off` prints only the result line |
| `color` | `on`, `off` | `on` | Colour for advantage and disadvantage |

```
roll config                  show the settings and where they are stored
roll config faces dots
roll config animate off
```

With `faces dots`, dice with up to six sides show pips and larger dice show Roman numerals:

```
$ roll 2d6                   $ roll d20
.-------. .-------.          .-------.
| o   o | | o     |          |       |
|   o   | |   o   |          |  XIV  |
| o   o | |     o |          |       |
'-------' '-------'          '-------'
2d6: [5, 3] = 8              d20: 14
```

Each setting can be overridden for one roll with `--faces dots`, `--animate` / `--no-animate` and `--color` / `--no-color`. The `NO_COLOR` environment variable is respected.

Settings are saved to `~/.config/dungeondice/config.json` (`%APPDATA%\dungeondice\config.json` on Windows). Set `DUNGEONDICE_CONFIG` to use a different file.

### Interactive prompt

Run with no arguments to get a prompt. It takes the same commands, and the word `roll` is optional:

```
$ roll
Welcome to Dungeon Dice 0.2.0. Type a roll such as "roll 2d20", "help", or "quit".
> 2d6
2d6: [4, 3] = 7
> d20 -a
d20 (advantage): [8, 17] -> 17
> quit
```

`q`, `quit`, `exit` or Ctrl-D leaves the prompt.

### Limits

A roll can have up to 1,000 dice, and a die can have from 2 to 1,000,000 sides.

## Install

Requires [Dart](https://dart.dev/get-dart) 3.13 or later.

Run from a clone without installing:

```
dart pub get
dart run bin/dungeondice.dart 2d20 --dis
```

Install the `roll` command (and `dungeondice`, which is the same program) on your PATH:

```
dart pub global activate --source path .
```

Or build a standalone executable:

```
dart compile exe bin/dungeondice.dart -o roll
```

## Development

```
dart analyze
dart test
```

The code is in `lib/src/`: `dice_expression.dart` parses the dice notation, `roller.dart` does the rolling, `die_art.dart` draws the dice, `settings.dart` loads and saves the config, and `cli.dart` handles flags, the animation and the prompt.
