import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kKey = 'user_timezone_offset_min';

class UserTimezoneNotifier extends AsyncNotifier<Duration> {
  @override
  Future<Duration> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_kKey);
    Duration offset;
    if (stored == null) {
      offset = DateTime.now().timeZoneOffset;
      await prefs.setInt(_kKey, offset.inMinutes);
    } else {
      offset = Duration(minutes: stored);
    }
    // Sync to Supabase profile so the server-side leaderboard can filter by tz.
    _syncToSupabase(offset.inMinutes);
    return offset;
  }

  Future<void> setOffset(Duration offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKey, offset.inMinutes);
    state = AsyncData(offset);
    _syncToSupabase(offset.inMinutes);
  }

  void _syncToSupabase(int minutes) {
    Supabase.instance.client
        .rpc('update_timezone_offset', params: {'p_offset_minutes': minutes})
        .then((_) {})
        .catchError((e) => debugPrint('tz sync error: $e'));
  }
}

final userTimezoneProvider =
    AsyncNotifierProvider<UserTimezoneNotifier, Duration>(
  UserTimezoneNotifier.new,
);

/// Convenience: formats a Duration (UTC offset) as "+HH:MM" or "-HH:MM".
String formatUtcOffset(Duration offset) {
  final sign     = offset.isNegative ? '-' : '+';
  final abs      = offset.abs();
  final h        = abs.inHours.toString().padLeft(2, '0');
  final m        = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$h:$m';
}

/// All standard UTC offsets (offset in minutes, label, example cities).
const kTimezoneOptions = <(int, String, String)>[
  (-720, 'UTC-12:00', 'Остров Бейкер'),
  (-660, 'UTC-11:00', 'Ниуэ, Паго-Пого'),
  (-600, 'UTC-10:00', 'Гавайи, Таити'),
  (-570, 'UTC-9:30',  'Маркизские острова'),
  (-540, 'UTC-9:00',  'Аляска'),
  (-480, 'UTC-8:00',  'Лос-Анджелес, Ванкувер'),
  (-420, 'UTC-7:00',  'Денвер, Финикс'),
  (-360, 'UTC-6:00',  'Чикаго, Мехико'),
  (-300, 'UTC-5:00',  'Нью-Йорк, Торонто'),
  (-270, 'UTC-4:30',  'Каракас'),
  (-240, 'UTC-4:00',  'Сантьяго, Ла-Пас'),
  (-210, 'UTC-3:30',  'Ньюфаундленд'),
  (-180, 'UTC-3:00',  'Буэнос-Айрес, Бразилиа'),
  (-120, 'UTC-2:00',  'Южная Георгия'),
  (-60,  'UTC-1:00',  'Азорские острова'),
  (0,    'UTC+0:00',  'Лондон, Дублин, Лиссабон'),
  (60,   'UTC+1:00',  'Берлин, Париж, Рим'),
  (120,  'UTC+2:00',  'Каир, Хельсинки, Киев'),
  (180,  'UTC+3:00',  'Москва, Стамбул, Эр-Рияд'),
  (210,  'UTC+3:30',  'Тегеран'),
  (240,  'UTC+4:00',  'Баку, Дубай, Тбилиси'),
  (270,  'UTC+4:30',  'Кабул'),
  (300,  'UTC+5:00',  'Карачи, Ташкент, Екатеринбург'),
  (330,  'UTC+5:30',  'Мумбаи, Нью-Дели'),
  (345,  'UTC+5:45',  'Катманду'),
  (360,  'UTC+6:00',  'Алматы, Дакка, Омск'),
  (390,  'UTC+6:30',  'Янгон'),
  (420,  'UTC+7:00',  'Бангкок, Джакарта, Новосибирск'),
  (480,  'UTC+8:00',  'Пекин, Сингапур, Гонконг'),
  (510,  'UTC+8:30',  'Пхеньян'),
  (525,  'UTC+8:45',  'Юкла'),
  (540,  'UTC+9:00',  'Токио, Сеул, Якутск'),
  (570,  'UTC+9:30',  'Аделаида, Дарвин'),
  (600,  'UTC+10:00', 'Сидней, Владивосток, Гуам'),
  (630,  'UTC+10:30', 'Лорд-Хау'),
  (660,  'UTC+11:00', 'Магадан, Нумеа'),
  (720,  'UTC+12:00', 'Окленд, Фиджи'),
  (765,  'UTC+12:45', 'Острова Чатем'),
  (780,  'UTC+13:00', 'Апиа, Нукуалофа'),
  (840,  'UTC+14:00', 'Остров Рождества'),
];
