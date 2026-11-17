import 'package:dungeondice/dungeondice.dart';
import 'package:test/test.dart';

void main() {
  test('roman numerals', () {
    const expected = {
      1: 'I',
      4: 'IV',
      9: 'IX',
      14: 'XIV',
      18: 'XVIII',
      20: 'XX',
      40: 'XL',
      90: 'XC',
      100: 'C',
      400: 'CD',
      1994: 'MCMXCIV',
      3999: 'MMMCMXCIX',
    };
    expected.forEach((value, numeral) => expect(roman(value), numeral));
    expect(() => roman(0), throwsRangeError);
    expect(() => roman(4000), throwsRangeError);
  });

  test('a number face is centred in the box', () {
    expect(const DieArt(20, FaceStyle.numbers).face(7), [
      '.-------.',
      '|       |',
      '|   7   |',
      '|       |',
      "'-------'",
    ]);
  });

  test('pip faces', () {
    const d6 = DieArt(6, FaceStyle.dots);
    expect(d6.face(1).sublist(1, 4), ['|       |', '|   o   |', '|       |']);
    expect(d6.face(5).sublist(1, 4), ['| o   o |', '|   o   |', '| o   o |']);
    expect(d6.face(6).sublist(1, 4), ['| o   o |', '| o   o |', '| o   o |']);
    for (var value = 1; value <= 6; value++) {
      expect('o'.allMatches(d6.face(value).join()), hasLength(value));
    }
  });

  test('dots style uses Roman numerals above a d6, on every face', () {
    const d20 = DieArt(20, FaceStyle.dots);
    expect(d20.face(3)[2], '|  III  |');
    expect(d20.face(18)[2], '| XVIII |');
  });

  test('every face of a die has the same width', () {
    for (final style in FaceStyle.values) {
      for (final sides in [2, 4, 6, 18, 20, 100, 3999, 4000, 1000000]) {
        final art = DieArt(sides, style);
        for (final value in {1, 2, sides ~/ 2, sides - 1, sides}) {
          if (value < 1) continue;
          for (final line in art.face(value)) {
            expect(line, hasLength(art.width), reason: '$style d$sides $value');
          }
        }
      }
    }
  });

  test('dice past 3999 sides fall back to numbers in dots style', () {
    expect(const DieArt(5000, FaceStyle.dots).face(4321)[2], contains('4321'));
  });

  group('layout', () {
    const d20 = DieArt(20, FaceStyle.numbers);

    test('puts attempts side by side when they fit', () {
      final lines = d20.layout([
        [1, 2],
        [3, 4],
      ], columns: 80)!;
      expect(lines, hasLength(dieHeight));
      expect(lines.first, '.-------. .-------.   .-------. .-------.');
    });

    test('stacks attempts when they do not', () {
      final lines = d20.layout([
        [1, 2],
        [3, 4],
      ], columns: 30)!;
      expect(lines, hasLength(dieHeight * 2));
    });

    test('gives up when one attempt is too wide', () {
      expect(
        d20.layout([
          [1, 2, 3],
        ], columns: 20),
        isNull,
      );
    });
  });
}
