// Shared formatting + the curated mood set for the Breathing journal,
// reflection and stats screens.

import 'package:sie_core/sie_core.dart';

/// A post-practice mood the user can pick from. The [emoji] is what gets stored
/// and shown in the journal; [label] is the human hint shown while choosing.
class BreathingMood {
  final String emoji;
  final String label;
  const BreathingMood(this.emoji, this.label);
}

/// Fixed emoji set — language-independent, stored verbatim in the journal.
const List<String> _moodEmojis = ['😣', '😕', '😐', '🙂', '😌', '😄', '🤩'];

/// Curated, fixed set of moods — labels are localized, emoji order is stable so
/// the stored emoji keeps its meaning across languages.
List<BreathingMood> breathingMoods() {
  final labels = t.breathingShared.moodLabels;
  return [
    for (var i = 0; i < _moodEmojis.length; i++)
      BreathingMood(_moodEmojis[i], labels[i]),
  ];
}

/// `M:SS` for short durations / holds, `H:MM:SS` once it crosses an hour.
String fmtDuration(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// `14:05` wall-clock time of a session.
String fmtClock(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// `Today` / `Yesterday` / `5 Aug` / `5 Aug 2025` relative to today.
String fmtJournalDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return t.breathingShared.today;
  if (diff == 1) return t.breathingShared.yesterday;
  final base = '${dt.day} ${t.breathingShared.months[dt.month - 1]}';
  return dt.year == now.year ? base : '$base ${dt.year}';
}

/// Correct localized declension for "breath".
String breathsWord(int n) => t.breathingShared.breathsWord(n: n);

/// Correct localized declension for "session".
String sessionsWord(int n) => t.breathingShared.sessionsWord(n: n);
