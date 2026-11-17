import 'dart:convert';
import 'dart:io';

/// What is drawn on the faces of the animated dice.
enum FaceStyle { numbers, dots }

/// User preferences, stored as JSON in the config file.
class Settings {
  final FaceStyle faces;
  final bool animate;
  final bool color;

  const Settings({
    this.faces = FaceStyle.numbers,
    this.animate = true,
    this.color = true,
  });

  Settings copyWith({FaceStyle? faces, bool? animate, bool? color}) => Settings(
    faces: faces ?? this.faces,
    animate: animate ?? this.animate,
    color: color ?? this.color,
  );

  Map<String, Object> toJson() => {
    'faces': faces.name,
    'animate': animate,
    'color': color,
  };

  /// Missing keys fall back to the defaults. Throws a [FormatException] on a
  /// value of the wrong kind.
  factory Settings.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('expected a JSON object');
    const defaults = Settings();
    bool flag(String key, bool fallback) => switch (json[key]) {
      null => fallback,
      bool value => value,
      _ => throw FormatException('"$key" must be true or false'),
    };
    final faces = switch (json['faces']) {
      null => defaults.faces,
      'numbers' => FaceStyle.numbers,
      'dots' => FaceStyle.dots,
      _ => throw const FormatException('"faces" must be "numbers" or "dots"'),
    };
    return Settings(
      faces: faces,
      animate: flag('animate', defaults.animate),
      color: flag('color', defaults.color),
    );
  }
}

/// Reads and writes [Settings]. A null [file] means no config location could
/// be worked out; loading then gives the defaults.
class SettingsStore {
  final File? file;

  const SettingsStore(this.file);

  /// `DUNGEONDICE_CONFIG` if set, otherwise the platform config directory.
  factory SettingsStore.fromEnvironment(Map<String, String> environment) {
    String? set(String key) {
      final value = environment[key];
      return value == null || value.isEmpty ? null : value;
    }

    final override = set('DUNGEONDICE_CONFIG');
    if (override != null) return SettingsStore(File(override));

    final separator = Platform.pathSeparator;
    final home = set('HOME');
    final base = Platform.isWindows
        ? set('APPDATA')
        : set('XDG_CONFIG_HOME') ??
              (home == null ? null : '$home$separator.config');
    if (base == null) return const SettingsStore(null);
    return SettingsStore(
      File([base, 'dungeondice', 'config.json'].join(separator)),
    );
  }

  /// Returns the settings and, if the file could not be used, a warning.
  (Settings, String?) load() {
    final file = this.file;
    if (file == null || !file.existsSync()) return (const Settings(), null);
    try {
      return (Settings.fromJson(jsonDecode(file.readAsStringSync())), null);
    } on FormatException catch (e) {
      return (
        const Settings(),
        'Ignoring ${file.path}: ${e.message}. Using default settings.',
      );
    } on FileSystemException catch (e) {
      return (
        const Settings(),
        'Could not read ${file.path}: ${e.message}. Using default settings.',
      );
    }
  }

  /// Throws a [FileSystemException] if the file cannot be written.
  void save(Settings settings) {
    final file = this.file;
    if (file == null) {
      throw const FileSystemException(
        'No config location found. Set DUNGEONDICE_CONFIG to a file path',
      );
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n',
    );
  }
}
