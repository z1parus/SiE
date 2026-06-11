import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_decomposition.dart';

class GroqService {
  static GroqService? _instance;

  static GroqService get instance {
    assert(_instance != null,
        'GroqService.initialize() must be called before using GroqService.instance');
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static void initialize(String apiKey) {
    _instance = GroqService._(apiKey);
  }

  final String _apiKey;
  GroqService._(this._apiKey);

  static const _model = 'llama-3.3-70b-versatile';
  static const _maxDailyRequests = 20;
  static const _prefKeyCount = 'groq_calls_count';
  static const _prefKeyDate = 'groq_calls_date';

  static const _systemPrompt = '''
Ты — AI-стратег системы SiE (System in Evolution). Твоя задача — разбить цель пользователя на чёткий, реалистичный план.

Ответь ТОЛЬКО валидным JSON-объектом следующей структуры (без пояснений, без markdown):
{
  "sub_goals": [
    {
      "name": "Название этапа",
      "tasks": [
        { "name": "Конкретное действие", "weight": 1 }
      ]
    }
  ],
  "milestones": [
    { "name": "Название контрольной точки" }
  ]
}

Правила:
- Создавай 3-5 логических этапов (sub_goals)
- В каждом этапе 2-5 конкретных задач (tasks)
- Вес задачи (weight): 1 = простое действие (< 1 часа), 3 = сфокусированная работа (несколько часов), 5 = крупный блок (день и более)
- Создавай 2-3 контрольные точки (milestones) — ключевые результаты, не процессы
- Задачи должны быть конкретными и actionable
- Язык ответа должен СОВПАДАТЬ с языком цели пользователя
''';

  String _buildUserPrompt(String goalName, String? description) {
    final sb = StringBuffer()..write('Цель: "$goalName"');
    if (description != null && description.trim().isNotEmpty) {
      sb.write('\nОписание: ${description.trim()}');
    }
    return sb.toString();
  }

  Future<bool> _checkRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_prefKeyDate) ?? '';
    if (storedDate != today) {
      await prefs.setString(_prefKeyDate, today);
      await prefs.setInt(_prefKeyCount, 0);
      return true;
    }
    final count = prefs.getInt(_prefKeyCount) ?? 0;
    return count < _maxDailyRequests;
  }

  Future<void> _incrementRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_prefKeyCount) ?? 0;
    await prefs.setInt(_prefKeyCount, count + 1);
  }

  Future<DecompositionResult> decomposeGoal(
      String goalName, String? description) async {
    if (!await _checkRateLimit()) {
      throw const GroqRateLimitException();
    }

    final requestBody = jsonEncode({
      'model': _model,
      'temperature': 0.4,
      'max_tokens': 1024,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content': _buildUserPrompt(goalName, description),
        },
      ],
      'response_format': {'type': 'json_object'},
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw GroqApiException('Ошибка сети: $e');
    }

    if (response.statusCode == 429) {
      throw const GroqApiException(
          'Превышен лимит запросов к Groq API. Попробуй позже.');
    }
    if (response.statusCode == 401) {
      throw const GroqApiException('Неверный API-ключ Groq.');
    }
    if (response.statusCode != 200) {
      throw GroqApiException(
          'Ошибка Groq API (${response.statusCode}): ${response.body}');
    }

    await _incrementRateLimit();

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          (json['choices'] as List).first['message']['content'] as String;
      return DecompositionResult.fromRawString(content);
    } catch (e) {
      throw GroqApiException('Не удалось разобрать ответ AI: $e');
    }
  }
}
