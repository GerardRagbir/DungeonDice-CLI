import 'dart:math';

import 'dice_expression.dart';

enum RollMode { normal, advantage, disadvantage }

/// The outcome of rolling one [DiceExpression].
class RollResult {
  final DiceExpression expression;
  final RollMode mode;

  /// Every die rolled. One attempt for a normal roll, two for advantage or
  /// disadvantage.
  final List<List<int>> attempts;

  RollResult(this.expression, this.mode, this.attempts);

  List<int> get attemptTotals => [
    for (final attempt in attempts) attempt.reduce((a, b) => a + b),
  ];

  /// The total that counts: the higher attempt for advantage, the lower for
  /// disadvantage.
  int get total => switch (mode) {
    RollMode.normal => attemptTotals.first,
    RollMode.advantage => attemptTotals.reduce(max),
    RollMode.disadvantage => attemptTotals.reduce(min),
  };

  /// Index of the attempt that counts (the first one on a tie).
  int get keptAttempt => attemptTotals.indexOf(total);

  /// One line for display, for example `2d20: [14, 7] = 21`.
  ///
  /// With advantage or disadvantage, [paint] is applied to the kept value so
  /// the caller can colour it.
  String describe({String Function(String kept)? paint}) {
    final single = expression.count == 1;
    if (mode == RollMode.normal) {
      return single
          ? '$expression: $total'
          : '$expression: ${attempts.first} = $total';
    }
    String value(int attempt) {
      final text = '${attemptTotals[attempt]}';
      return paint != null && attempt == keptAttempt ? paint(text) : text;
    }

    final indexes = [for (var i = 0; i < attempts.length; i++) i];
    final shown = single
        ? '[${indexes.map(value).join(', ')}]'
        : indexes.map((i) => '${attempts[i]} = ${value(i)}').join(', ');
    return '$expression (${mode.name}): $shown -> ${value(keptAttempt)}';
  }
}

class Roller {
  final Random _random;

  /// Pass a seeded [Random] for reproducible rolls.
  Roller([Random? random]) : _random = random ?? Random();

  /// Rolls [expression]. With advantage or disadvantage the whole expression
  /// is rolled twice and the higher or lower total is kept.
  RollResult roll(
    DiceExpression expression, {
    RollMode mode = RollMode.normal,
  }) {
    final attemptCount = mode == RollMode.normal ? 1 : 2;
    return RollResult(expression, mode, [
      for (var i = 0; i < attemptCount; i++) _rollOnce(expression),
    ]);
  }

  List<int> _rollOnce(DiceExpression expression) => [
    for (var i = 0; i < expression.count; i++)
      _random.nextInt(expression.sides) + 1,
  ];
}
