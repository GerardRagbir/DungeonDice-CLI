/// ANSI colour helpers that turn into no-ops when colour is disabled.
class Ansi {
  final bool enabled;

  const Ansi(this.enabled);

  String green(String text) => _wrap('1;32', text);
  String red(String text) => _wrap('1;31', text);
  String dim(String text) => _wrap('2', text);

  String _wrap(String code, String text) =>
      enabled ? '\x1b[${code}m$text\x1b[0m' : text;
}
