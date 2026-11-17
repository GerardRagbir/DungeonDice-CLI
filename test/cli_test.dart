import 'dart:io';
import 'dart:math';

import 'package:dungeondice/dungeondice.dart';
import 'package:test/test.dart';

void main() {
  late StringBuffer out;
  late StringBuffer err;

  late Directory temp;
  late File configFile;
  late List<Duration> sleeps;

  Cli cli({
    List<String> input = const [],
    bool ansi = false,
    int columns = 80,
    Map<String, String> environment = const {},
  }) {
    final lines = input.iterator;
    return Cli(
      roller: Roller(Random(7)),
      out: out,
      err: err,
      readLine: () => lines.moveNext() ? lines.current : null,
      ansi: ansi,
      columns: () => columns,
      sleep: sleeps.add,
      environment: environment,
      settings: SettingsStore(configFile),
    );
  }

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    sleeps = [];
    temp = Directory.systemTemp.createTempSync('dungeondice_test');
    configFile = File('${temp.path}/nested/config.json');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('one-shot', () {
    for (final args in [
      ['20'],
      ['d20'],
      ['roll', '20'],
      ['roll', 'd20'],
      ['ROLL', 'D20'],
    ]) {
      test('$args rolls one d20', () {
        expect(cli().run(args), 0);
        expect(out.toString(), matches(RegExp(r'^d20: \d+\n$')));
      });
    }

    test('roll 2d20 rolls two dice', () {
      expect(cli().run(['roll', '2d20']), 0);
      expect(out.toString(), matches(RegExp(r'^2d20: \[\d+, \d+\] = \d+\n$')));
    });

    test('accepts any die size', () {
      expect(cli().run(['roll', 'd18']), 0);
      expect(out.toString(), startsWith('d18: '));
    });

    for (final flag in ['-d', '--dis', '--disadvantage']) {
      test('$flag rolls with disadvantage, before or after the dice', () {
        expect(cli().run(['roll', 'd20', flag]), 0);
        expect(cli().run([flag, 'roll', 'd20']), 0);
        final lines = out.toString().trim().split('\n');
        expect(lines, hasLength(2));
        expect(lines, everyElement(startsWith('d20 (disadvantage): [')));
      });
    }

    for (final flag in ['-a', '--adv', '--advantage']) {
      test('$flag rolls with advantage', () {
        expect(cli().run(['roll', 'd20', flag]), 0);
        expect(out.toString(), startsWith('d20 (advantage): ['));
      });
    }

    test('advantage and disadvantage cancel out', () {
      expect(cli().run(['d20', '-a', '-d']), 0);
      final lines = out.toString().trim().split('\n');
      expect(lines.first, contains('cancel out'));
      expect(lines.last, matches(RegExp(r'^d20: \d+$')));
    });

    test('rolls several expressions', () {
      expect(cli().run(['roll', 'd20', '2d6']), 0);
      expect(out.toString().trim().split('\n'), hasLength(2));
    });

    for (final args in [
      ['roll'],
      ['roll', 'banana'],
      ['roll', 'd0'],
      ['roll', '-1'],
      ['roll', 'd20', '--nope'],
      ['roll', 'd20', 'banana'],
    ]) {
      test('$args fails without rolling', () {
        expect(cli().run(args), usageError);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNotEmpty);
      });
    }

    for (final args in [
      ['--help'],
      ['-h'],
      ['help'],
    ]) {
      test('$args prints usage', () {
        expect(cli().run(args), 0);
        expect(out.toString(), contains('Usage: roll'));
        expect(out.toString(), contains('--disadvantage'));
      });
    }

    test('--version matches pubspec.yaml', () {
      expect(cli().run(['--version']), 0);
      expect(out.toString().trim(), 'Dungeon Dice $version');
      expect(
        File('pubspec.yaml').readAsLinesSync(),
        contains('version: $version'),
      );
    });
  });

  group('prompt', () {
    test('rolls each line until quit', () {
      final code = cli(
        input: ['roll 2d20 --dis', 'd18', '', '  20  ', 'quit', 'd4'],
      ).run([]);
      expect(code, 0);
      final text = out.toString();
      expect(text, contains('Welcome to Dungeon Dice $version'));
      expect(text, contains('2d20 (disadvantage): '));
      expect(text, contains('d18: '));
      expect(text, contains('d20: '));
      expect(text, isNot(contains('d4: ')));
    });

    for (final quit in ['q', 'quit', 'exit', 'QUIT']) {
      test('"$quit" exits', () {
        expect(cli(input: [quit, 'd4']).run([]), 0);
        expect(out.toString(), isNot(contains('d4: ')));
      });
    }

    test('end of input exits cleanly', () {
      expect(cli(input: ['d6']).run([]), 0);
      expect(out.toString(), contains('d6: '));
    });

    test('help works and a bad line does not end the session', () {
      expect(cli(input: ['help', 'banana', 'd6']).run([]), 0);
      expect(out.toString(), contains('Usage: roll'));
      expect(err.toString(), contains('"banana" is not a dice expression'));
      expect(out.toString(), contains('d6: '));
    });
  });

  const green = '\x1b[1;32m';
  const red = '\x1b[1;31m';
  const dim = '\x1b[2m';
  const cursorUp = '\x1b[6A';

  /// What is left on screen: the text after the last cursor-up, without
  /// escape codes.
  String finalFrame() => out
      .toString()
      .split(cursorUp)
      .last
      .replaceAll(RegExp(r'\x1b\[[0-9;]*[A-Za-z]|\r'), '');

  group('animation', () {
    test('tumbles, then settles on the rolled value', () {
      expect(cli(ansi: true).run(['d20']), 0);
      // Ten tumbling frames, each overwritten by the next.
      expect(sleeps, hasLength(10));
      expect(cursorUp.allMatches(out.toString()), hasLength(10));
      expect(out.toString(), contains('Rolling d20...'));

      final lines = finalFrame().trimRight().split('\n');
      expect(lines, hasLength(6));
      expect(lines.first, '.-------.');
      final value = RegExp(r'^d20: (\d+)$').firstMatch(lines.last)!.group(1)!;
      expect(lines[2], matches(RegExp('^\\| +$value +\\|\$')));
    });

    test('draws one die per die rolled', () {
      expect(cli(ansi: true).run(['3d6']), 0);
      expect(finalFrame().split('\n').first, '.-------. .-------. .-------.');
    });

    test('dots style draws pips on a d6', () {
      expect(cli(ansi: true).run(['d6', '--faces', 'dots']), 0);
      final frame = finalFrame();
      expect(frame, contains('o'));
      expect(frame.split('\n')[2], isNot(contains(RegExp(r'\d'))));
    });

    test('dots style draws Roman numerals on a d20', () {
      expect(cli(ansi: true).run(['d20', '--faces', 'dots']), 0);
      expect(finalFrame().split('\n')[2], matches(RegExp(r'^\| +[IVX]+ +\|$')));
    });

    test('advantage colours the kept die and dims the other', () {
      expect(cli(ansi: true).run(['d20', '-a']), 0);
      final settled = out.toString().split(cursorUp).last;
      expect(settled, contains(green));
      expect(settled, contains(dim));
      expect(settled, isNot(contains(red)));
    });

    for (final off in [
      ['--no-animate'],
      <String>[],
    ]) {
      final where = off.isEmpty ? 'config' : 'flag';
      test('can be turned off by $where', () {
        if (off.isEmpty) cli().run(['config', 'animate', 'off']);
        out.clear();
        expect(cli(ansi: true).run(['d20', ...off]), 0);
        expect(sleeps, isEmpty);
        expect(out.toString(), matches(RegExp(r'^d20: \d+\n$')));
      });
    }

    test('is skipped when the output is not a terminal', () {
      expect(cli().run(['d20', '--animate', '--color', '-a']), 0);
      expect(sleeps, isEmpty);
      expect(out.toString(), isNot(contains('\x1b')));
    });

    test('falls back to the result line when the dice do not fit', () {
      expect(cli(ansi: true, columns: 40).run(['8d6']), 0);
      expect(sleeps, isEmpty);
      expect(out.toString(), startsWith('8d6: ['));
    });

    test('stacks the two attempts when they do not fit side by side', () {
      expect(cli(ansi: true, columns: 40).run(['3d6', '-d']), 0);
      // Two rows of dice and the result line.
      expect(out.toString(), contains('\x1b[11A'));
    });
  });

  group('colour', () {
    test('advantage is green and disadvantage is red', () {
      expect(cli(ansi: true).run(['d20', '-a', '--no-animate']), 0);
      expect(out.toString(), contains(green));
      out.clear();
      expect(cli(ansi: true).run(['d20', '-d', '--no-animate']), 0);
      expect(out.toString(), contains(red));
    });

    test('a normal roll has no colour', () {
      expect(cli(ansi: true).run(['2d20', '--no-animate']), 0);
      expect(out.toString(), isNot(contains('\x1b')));
    });

    test('--no-color, --no-colour, NO_COLOR and config turn it off', () {
      const args = ['d20', '-a', '--no-animate'];
      expect(cli(ansi: true).run([...args, '--no-color']), 0);
      expect(cli(ansi: true).run([...args, '--no-colour']), 0);
      expect(cli(ansi: true, environment: {'NO_COLOR': '1'}).run(args), 0);
      cli().run(['config', 'colour', 'off']);
      expect(cli(ansi: true).run(args), 0);
      expect(out.toString(), isNot(contains('\x1b')));
    });

    test('--color overrides NO_COLOR', () {
      final code = cli(
        ansi: true,
        environment: {'NO_COLOR': '1'},
      ).run(['d20', '-a', '--no-animate', '--color']);
      expect(code, 0);
      expect(out.toString(), contains(green));
    });
  });

  group('config', () {
    test('shows the defaults', () {
      expect(cli().run(['config']), 0);
      expect(out.toString(), contains(RegExp(r'faces +numbers')));
      expect(out.toString(), contains(RegExp(r'animate +on')));
      expect(out.toString(), contains(RegExp(r'color +on')));
      expect(out.toString(), contains(configFile.path));
    });

    test('saves a setting that later rolls use', () {
      expect(cli().run(['roll', 'config', 'faces', 'dots']), 0);
      expect(configFile.readAsStringSync(), contains('"faces": "dots"'));
      out.clear();
      expect(cli(ansi: true).run(['d6']), 0);
      expect(finalFrame(), contains('o'));
    });

    test('a flag overrides the saved setting', () {
      cli().run(['config', 'faces', 'dots']);
      out.clear();
      expect(cli(ansi: true).run(['d6', '--faces', 'numbers']), 0);
      expect(finalFrame(), isNot(contains('o')));
    });

    test('works from the prompt', () {
      expect(cli(input: ['config animate off', 'config']).run([]), 0);
      expect(out.toString(), contains(RegExp(r'animate +off')));
    });

    for (final args in [
      ['config', 'faces', 'stars'],
      ['config', 'animate', 'maybe'],
      ['config', 'speed', 'fast'],
      ['config', 'faces'],
      ['d20', '--faces', 'stars'],
    ]) {
      test('$args is rejected', () {
        expect(cli().run(args), usageError);
        expect(configFile.existsSync(), isFalse);
      });
    }

    test('a broken config file gives a warning and the defaults', () {
      configFile
        ..createSync(recursive: true)
        ..writeAsStringSync('{"faces": 3');
      expect(cli().run(['d20']), 0);
      expect(err.toString(), contains('Using default settings'));
      expect(out.toString(), startsWith('d20: '));
    });
  });
}
