import '../l10n/app_localizations.dart';

/// "42 s", "1 min 05", "2 h 10".
String formatDuration(Duration d, AppLocalizations l) {
  final seconds = d.inSeconds < 1 ? 1 : d.inSeconds;
  if (seconds < 60) return l.durationSeconds(seconds);
  String two(int v) => v.toString().padLeft(2, '0');
  if (seconds < 3600) {
    return l.durationMinutes(seconds ~/ 60, two(seconds % 60));
  }
  return l.durationHours(seconds ~/ 3600, two(seconds % 3600 ~/ 60));
}
