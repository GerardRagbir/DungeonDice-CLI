import 'dart:math';

import 'package:dungeondice/dungeondice.dart';
import 'package:test/test.dart';

void main() {
  test('every face from 1 to the maximum can be rolled', () {
    final roller = Roller(Random(1));
    for (final sides in [4, 6, 8, 10, 12, 18, 20, 100]) {
      final seen = <int>{};
      for (var i = 0; i < sides * 200; i++) {
        seen.addAll(roller.roll(DiceExpression(1, sides)).attempts.single);
      }
      expect(seen, {for (var face = 1; face <= sides; face++) face});
    }
  });

  test('rolls the requested number of dice and sums them', () {
    final result = Roller(Random(2)).roll(DiceExpression(5, 6));
    final dice = result.attempts.single;
    expect(dice, hasLength(5));
    expect(result.total, dice.reduce((a, b) => a + b));
  });

  test('advantage keeps the higher of two attempts', () {
    final roller = Roller(Random(3));
    for (var i = 0; i < 200; i++) {
      final result = roller.roll(
        DiceExpression(2, 20),
        mode: RollMode.advantage,
      );
      expect(result.attempts, hasLength(2));
      expect(result.total, result.attemptTotals.reduce(max));
    }
  });

  test('disadvantage keeps the lower of two attempts', () {
    final roller = Roller(Random(4));
    for (var i = 0; i < 200; i++) {
      final result = roller.roll(
        DiceExpression(2, 20),
        mode: RollMode.disadvantage,
      );
      expect(result.attempts, hasLength(2));
      expect(result.total, result.attemptTotals.reduce(min));
    }
  });

  group('describe', () {
    final d20 = DiceExpression(1, 20);
    final twoD20 = DiceExpression(2, 20);

    test('single die', () {
      expect(
        RollResult(d20, RollMode.normal, [
          [14],
        ]).describe(),
        'd20: 14',
      );
    });

    test('several dice', () {
      expect(
        RollResult(twoD20, RollMode.normal, [
          [14, 7],
        ]).describe(),
        '2d20: [14, 7] = 21',
      );
    });

    test('single die with disadvantage', () {
      expect(
        RollResult(d20, RollMode.disadvantage, [
          [14],
          [7],
        ]).describe(),
        'd20 (disadvantage): [14, 7] -> 7',
      );
    });

    test('several dice with advantage', () {
      expect(
        RollResult(twoD20, RollMode.advantage, [
          [14, 7],
          [3, 9],
        ]).describe(),
        '2d20 (advantage): [14, 7] = 21, [3, 9] = 12 -> 21',
      );
    });
  });
}
