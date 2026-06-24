// Shared formatting + the curated mood set for the Breathing journal,
// reflection and stats screens.

/// A post-practice mood the user can pick from. The [emoji] is what gets stored
/// and shown in the journal; [label] is the human hint shown while choosing.
class BreathingMood {
  final String emoji;
  final String label;
  const BreathingMood(this.emoji, this.label);
}

/// Curated, fixed set of moods — keeps journal entries uniform and scannable.
const List<BreathingMood> kBreathingMoods = [
  BreathingMood('😣', 'Тяжело'),
  BreathingMood('😕', 'Так себе'),
  BreathingMood('😐', 'Нейтрально'),
  BreathingMood('🙂', 'Неплохо'),
  BreathingMood('😌', 'Спокойно'),
  BreathingMood('😄', 'Бодро'),
  BreathingMood('🤩', 'Превосходно'),
];

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

const List<String> _months = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

/// `Сегодня` / `Вчера` / `5 авг` / `5 авг 2025` relative to today.
String fmtJournalDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  final base = '${dt.day} ${_months[dt.month - 1]}';
  return dt.year == now.year ? base : '$base ${dt.year}';
}

/// Correct Russian declension for "вдох".
String breathsWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'вдох';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'вдоха';
  return 'вдохов';
}

/// Correct Russian declension for "сессия".
String sessionsWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'сессия';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'сессии';
  return 'сессий';
}
