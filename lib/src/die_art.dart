import 'dart:math';

import 'settings.dart';

/// Lines in one drawn die.
const int dieHeight = 5;

/// The largest value written as a standard Roman numeral.
const int maxRoman = 3999;

const List<(int, String)> _romanParts = [
  (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'),
  (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'), //
];

/// [value] as a Roman numeral. Valid from 1 to [maxRoman].
String roman(int value) {
  RangeError.checkValueInInterval(value, 1, maxRoman, 'value');
  final buffer = StringBuffer();
  var rest = value;
  for (final (amount, numeral) in _romanParts) {
    while (rest >= amount) {
      buffer.write(numeral);
      rest -= amount;
    }
  }
  return buffer.toString();
}

/// Pip positions for faces 1 to 6 on a 3x3 grid, row by row.
const List<String> _pips = [
  '....o....',
  'o.......o',
  'o...o...o',
  'o.o...o.o',
  'o.o.o.o.o',
  'o.oo.oo.o',
];

/// How one kind of die is drawn in a given [FaceStyle].
///
/// In [FaceStyle.dots], dice with up to six sides show pips and larger dice
/// show Roman numerals (plain numbers past [maxRoman] sides). The box is
/// sized for the widest face so it does not change size while tumbling.
class DieArt {
  static const int _minInnerWidth = 7;
  static final Map<int, int> _longestRoman = {};

  final int sides;
  final FaceStyle style;

  const DieArt(this.sides, this.style);

  bool get _usesPips => style == FaceStyle.dots && sides <= 6;
  bool get _usesRoman =>
      style == FaceStyle.dots && sides > 6 && sides <= maxRoman;

  String _label(int value) => _usesRoman ? roman(value) : '$value';

  int get _innerWidth {
    if (_usesPips) return _minInnerWidth;
    final longest = _usesRoman
        ? _longestRoman.putIfAbsent(sides, () {
            var length = 0;
            for (var value = 1; value <= sides; value++) {
              length = max(length, roman(value).length);
            }
            return length;
          })
        : '$sides'.length;
    return max(_minInnerWidth, longest + 2);
  }

  /// Printed width of one die, including its border.
  int get width => _innerWidth + 2;

  /// The [dieHeight] lines of a die showing [value].
  List<String> face(int value) {
    final inner = _innerWidth;
    final blank = ' ' * inner;
    final List<String> rows;
    if (_usesPips) {
      final cells = _pips[value - 1].replaceAll('.', ' ');
      rows = [
        for (var row = 0; row < 3; row++)
          ' ${cells.substring(row * 3, row * 3 + 3).split('').join(' ')} ',
      ];
    } else {
      final label = _label(value);
      final left = (inner - label.length) ~/ 2;
      rows = [blank, (' ' * left + label).padRight(inner), blank];
    }
    return [
      '.${'-' * inner}.',
      for (final row in rows) '|$row|',
      "'${'-' * inner}'",
    ];
  }

  /// Draws [attempts] (each a list of face values) as rows of dice.
  ///
  /// Attempts sit side by side when that fits in [columns], otherwise one
  /// above the other. Returns null when even one attempt is too wide.
  /// [paint], if given, colours the text of each attempt by its index.
  List<String>? layout(
    List<List<int>> attempts, {
    required int columns,
    String Function(int attempt, String text)? paint,
  }) {
    const gap = '   ';
    final attemptWidth =
        attempts.first.length * width + attempts.first.length - 1;
    if (attemptWidth >= columns) return null;

    final blocks = [
      for (final (index, attempt) in attempts.indexed)
        [
          for (var line = 0; line < dieHeight; line++)
            () {
              final text = [for (final value in attempt) face(value)[line]]
                  .join(' ');
              return paint == null ? text : paint(index, text);
            }(),
        ],
    ];

    final sideBySide =
        attemptWidth * attempts.length + gap.length * (attempts.length - 1);
    if (sideBySide >= columns) return [for (final block in blocks) ...block];
    return [
      for (var line = 0; line < dieHeight; line++)
        [for (final block in blocks) block[line]].join(gap),
    ];
  }
}
