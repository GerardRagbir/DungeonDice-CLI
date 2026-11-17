/// A parsed dice expression such as `d20` or `2d6`.
class DiceExpression {
  static const int maxCount = 1000;
  static const int minSides = 2;
  static const int maxSides = 1000000;

  /// The `d` is optional only when there is no count, so `20` is one d20 and
  /// `220` is one d220, never 22d0.
  static final RegExp _pattern = RegExp(r'^(?:(\d+)?d)?(\d+)$');

  final int count;
  final int sides;

  DiceExpression(this.count, this.sides) {
    if (count < 1 || count > maxCount) {
      throw FormatException('Number of dice must be between 1 and $maxCount.');
    }
    if (sides < minSides || sides > maxSides) {
      throw FormatException(
        'Number of sides must be between $minSides and $maxSides.',
      );
    }
  }

  /// Parses `20`, `d20` or `2d20` (case-insensitive).
  ///
  /// Throws a [FormatException] with a user-facing message on bad input.
  factory DiceExpression.parse(String input) {
    final text = input.trim().toLowerCase();
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException(
        '"$input" is not a dice expression. Try 20, d20 or 2d20.',
      );
    }
    // tryParse returns null when the digits overflow an int; map that to a
    // value the range checks reject.
    final countText = match.group(1);
    final count = countText == null ? 1 : int.tryParse(countText) ?? -1;
    final sides = int.tryParse(match.group(2)!) ?? -1;
    return DiceExpression(count, sides);
  }

  @override
  String toString() => count == 1 ? 'd$sides' : '${count}d$sides';

  @override
  bool operator ==(Object other) =>
      other is DiceExpression && other.count == count && other.sides == sides;

  @override
  int get hashCode => Object.hash(count, sides);
}
