import 'dart:io' as io show sleep;
import 'dart:io' hide sleep;
import 'dart:math';

import 'package:args/args.dart';

import 'ansi.dart';
import 'dice_expression.dart';
import 'die_art.dart';
import 'roller.dart';
import 'settings.dart';
import 'version.dart';

const Set<String> quitCommands = {'q', 'quit', 'exit'};

/// Exit code for a command the user got wrong (BSD `EX_USAGE`).
const int usageError = 64;

/// The command-line front end. With arguments it rolls once; with none it
/// opens an interactive prompt. Both paths share [execute].
class Cli {
  /// Tumbling frames shown before a roll settles.
  static const int _frames = 10;

  final Roller _roller;
  final StringSink _out;
  final StringSink _err;
  final String? Function() _readLine;
  final bool _ansi;
  final int Function() _columns;
  final void Function(Duration) _sleep;
  final bool _noColor;
  final SettingsStore _store;

  /// Faces shown while tumbling. Kept apart from the roller's generator so
  /// the animation never changes what a seeded roller produces.
  final Random _tumble = Random();

  /// [ansi] says whether the output is a terminal that understands escape
  /// codes; animation and colour need it. It defaults to what stdout reports,
  /// or to false when [out] is supplied.
  Cli({
    Roller? roller,
    StringSink? out,
    StringSink? err,
    String? Function()? readLine,
    bool? ansi,
    int Function()? columns,
    void Function(Duration)? sleep,
    Map<String, String>? environment,
    SettingsStore? settings,
  }) : _roller = roller ?? Roller(),
       _out = out ?? stdout,
       _err = err ?? stderr,
       _readLine = readLine ?? stdin.readLineSync,
       _ansi =
           ansi ??
           (out == null && stdout.hasTerminal && stdout.supportsAnsiEscapes),
       _columns =
           columns ?? (() => stdout.hasTerminal ? stdout.terminalColumns : 80),
       _sleep = sleep ?? io.sleep,
       _noColor = (environment ?? Platform.environment)['NO_COLOR'] != null,
       _store =
           settings ??
           SettingsStore.fromEnvironment(environment ?? Platform.environment);

  static final ArgParser _parser = ArgParser()
    ..addFlag(
      'advantage',
      abbr: 'a',
      aliases: ['adv'],
      negatable: false,
      help: 'Roll twice and keep the higher total. Also --adv.',
    )
    ..addFlag(
      'disadvantage',
      abbr: 'd',
      aliases: ['dis'],
      negatable: false,
      help: 'Roll twice and keep the lower total. Also --dis.',
    )
    ..addOption(
      'faces',
      allowed: ['numbers', 'dots'],
      help: 'What the animated dice show, for this roll.',
    )
    ..addFlag('animate', help: 'Draw and tumble the dice, for this roll.')
    ..addFlag(
      'color',
      aliases: ['colour'],
      help: 'Colour advantage and disadvantage results, for this roll.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
    ..addFlag('version', negatable: false, help: 'Show the version.');

  static String get usage =>
      '''
Usage: roll <dice> [more dice] [flags]

Dice can be any size:
  roll 20       one d20
  roll d20      one d20
  roll 2d20     two d20
  roll d18      one d18

Flags:
${_parser.usage}

Settings (saved, and used when the matching flag is not given):
  roll config                         show the settings
  roll config faces <numbers|dots>    dots: pips up to a d6, Roman numerals above
  roll config animate <on|off>        off prints just the result line
  roll config color <on|off>

Run with no arguments for an interactive prompt. There, type the same
commands (the word "roll" is optional), "help", or "quit".''';

  /// Returns the process exit code.
  int run(List<String> args) => args.isEmpty ? _repl() : execute(args);

  /// Runs one command, for example `['roll', '2d20', '--dis']`.
  int execute(List<String> tokens) {
    final ArgResults results;
    try {
      results = _parser.parse(tokens);
    } on FormatException catch (e) {
      return _fail(e.message);
    }

    var rest = results.rest;
    if (rest.isNotEmpty && rest.first.toLowerCase() == 'roll') {
      rest = rest.sublist(1);
    }
    final command = rest.isEmpty ? null : rest.first.toLowerCase();

    if (results.flag('help') || (rest.length == 1 && command == 'help')) {
      _out.writeln(usage);
      return 0;
    }
    if (results.flag('version')) {
      _out.writeln('Dungeon Dice $version');
      return 0;
    }

    final (saved, warning) = _store.load();
    if (warning != null) _err.writeln(warning);

    if (command == 'config') return _config(rest.sublist(1), saved);
    if (rest.isEmpty) return _fail('Nothing to roll. Try: roll d20');

    // Parse everything before rolling so a bad expression rolls nothing.
    final List<DiceExpression> expressions;
    try {
      expressions = [for (final text in rest) DiceExpression.parse(text)];
    } on FormatException catch (e) {
      return _fail(e.message);
    }

    final advantage = results.flag('advantage');
    final disadvantage = results.flag('disadvantage');
    final RollMode mode;
    if (advantage && disadvantage) {
      mode = RollMode.normal;
      _out.writeln('Advantage and disadvantage cancel out: rolling normally.');
    } else if (advantage) {
      mode = RollMode.advantage;
    } else if (disadvantage) {
      mode = RollMode.disadvantage;
    } else {
      mode = RollMode.normal;
    }

    // A flag wins over NO_COLOR, which wins over the saved setting.
    final wantColor = results.wasParsed('color')
        ? results.flag('color')
        : saved.color && !_noColor;
    final wantAnimation = results.wasParsed('animate')
        ? results.flag('animate')
        : saved.animate;
    final faces = switch (results.option('faces')) {
      'numbers' => FaceStyle.numbers,
      'dots' => FaceStyle.dots,
      _ => saved.faces,
    };

    for (final expression in expressions) {
      _show(
        _roller.roll(expression, mode: mode),
        faces: faces,
        animate: _ansi && wantAnimation,
        ansi: Ansi(_ansi && wantColor),
      );
    }
    return 0;
  }

  /// Prints [result]: tumbling dice that settle on the roll when [animate] is
  /// set and the dice fit the terminal, otherwise just the result line.
  void _show(
    RollResult result, {
    required FaceStyle faces,
    required bool animate,
    required Ansi ansi,
  }) {
    String kept(String text) => switch (result.mode) {
      RollMode.advantage => ansi.green(text),
      RollMode.disadvantage => ansi.red(text),
      RollMode.normal => text,
    };
    final summary = result.describe(paint: kept);

    final art = DieArt(result.expression.sides, faces);
    final columns = _columns();
    final settled = animate
        ? art.layout(
            result.attempts,
            columns: columns,
            paint: result.mode == RollMode.normal
                ? null
                : (attempt, text) => attempt == result.keptAttempt
                      ? kept(text)
                      : ansi.dim(text),
          )
        : null;
    if (settled == null) {
      _out.writeln(summary);
      return;
    }

    for (var frame = 0; frame < _frames; frame++) {
      final tumbling = [
        for (final attempt in result.attempts)
          [for (final _ in attempt) _tumble.nextInt(art.sides) + 1],
      ];
      _draw([
        ...art.layout(tumbling, columns: columns)!,
        'Rolling ${result.expression}...',
      ], overwrite: frame > 0);
      // Each frame lingers a little longer, so the dice appear to slow down.
      _sleep(Duration(milliseconds: 30 + frame * 7));
    }
    _draw([...settled, summary], overwrite: true);
  }

  /// Writes [lines], first moving back up over the previous frame when
  /// [overwrite] is set. Every frame of one roll has the same line count.
  void _draw(List<String> lines, {required bool overwrite}) {
    if (overwrite) _out.write('\x1b[${lines.length}A');
    for (final line in lines) {
      _out.write('\r\x1b[2K$line\n');
    }
  }

  int _config(List<String> words, Settings saved) {
    if (words.isEmpty) {
      _out.writeln('faces    ${saved.faces.name}');
      _out.writeln('animate  ${saved.animate ? 'on' : 'off'}');
      _out.writeln('color    ${saved.color ? 'on' : 'off'}');
      _out.writeln('file     ${_store.file?.path ?? '(none)'}');
      return 0;
    }
    if (words.length != 2) {
      return _fail('Usage: roll config <faces|animate|color> <value>');
    }
    final key = words[0].toLowerCase();
    final value = words[1].toLowerCase();
    bool? toggle() => switch (value) {
      'on' || 'true' || 'yes' => true,
      'off' || 'false' || 'no' => false,
      _ => null,
    };

    final Settings updated;
    switch (key) {
      case 'faces':
        final faces = FaceStyle.values.asNameMap()[value];
        if (faces == null) return _fail('faces must be "numbers" or "dots".');
        updated = saved.copyWith(faces: faces);
      case 'animate' || 'color' || 'colour':
        final on = toggle();
        if (on == null) return _fail('$key must be "on" or "off".');
        updated = key == 'animate'
            ? saved.copyWith(animate: on)
            : saved.copyWith(color: on);
      default:
        return _fail('Unknown setting "$key". Use faces, animate or color.');
    }

    try {
      _store.save(updated);
    } on FileSystemException catch (e) {
      _err.writeln('Could not save settings: ${e.message}.');
      return 1;
    }
    _out.writeln('${key == 'colour' ? 'color' : key} set to $value.');
    return 0;
  }

  int _fail(String message) {
    _err.writeln(message);
    _err.writeln('Type "help" or use --help for usage.');
    return usageError;
  }

  int _repl() {
    _out.writeln(
      'Welcome to Dungeon Dice $version. '
      'Type a roll such as "roll 2d20", "help", or "quit".',
    );
    while (true) {
      _out.write('> ');
      final line = _readLine();
      if (line == null) {
        // End of input (Ctrl-D or a closed pipe).
        _out.writeln();
        return 0;
      }
      final tokens = line
          .trim()
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList();
      if (tokens.isEmpty) continue;
      if (tokens.length == 1 &&
          quitCommands.contains(tokens.first.toLowerCase())) {
        return 0;
      }
      execute(tokens);
    }
  }
}
