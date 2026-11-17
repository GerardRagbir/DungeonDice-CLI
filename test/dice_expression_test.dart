import 'package:dungeondice/dungeondice.dart';
import 'package:test/test.dart';

void main() {
  group('DiceExpression.parse', () {
    const valid = {
      '20': (1, 20),
      'd20': (1, 20),
      '2d20': (2, 20),
      'd18': (1, 18),
      '3d6': (3, 6),
      'D20': (1, 20),
      '2D20': (2, 20),
      ' d20 ': (1, 20),
      '220': (1, 220),
      '1000d1000000': (1000, 1000000),
    };
    valid.forEach((input, expected) {
      test('accepts "$input"', () {
        final expression = DiceExpression.parse(input);
        expect((expression.count, expression.sides), expected);
      });
    });

    const invalid = [
      '',
      'abc',
      'd',
      '2d',
      '0',
      'd0',
      'd1',
      '0d20',
      '-1',
      'd-20',
      '2 20',
      '2d20d4',
      '1.5',
      '1001d6',
      'd1000001',
      '99999999999999999999999',
      '99999999999999999999999d6',
    ];
    for (final input in invalid) {
      test('rejects "$input"', () {
        expect(() => DiceExpression.parse(input), throwsFormatException);
      });
    }
  });

  test('toString omits a count of one', () {
    expect(DiceExpression(1, 20).toString(), 'd20');
    expect(DiceExpression(2, 20).toString(), '2d20');
  });
}
