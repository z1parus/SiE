import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_decomposition.dart';

class GroqService {
  static final GroqService instance = GroqService._();
  GroqService._();

  // Always available — key lives in Supabase Secrets, not in the app
  static const bool isInitialized = true;

  static const int _maxDailyRequests = 20;
  static const String _prefKeyCount = 'groq_calls_count';
  static const String _prefKeyDate = 'groq_calls_date';

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

    final body = <String, dynamic>{'goalName': goalName};
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-decompose',
        body: body,
      );

      await _incrementRateLimit();

      final data = response.data as Map<String, dynamic>;
      return DecompositionResult.fromJson(data);
    } on FunctionException catch (e) {
      final msg = (e.details as Map?)?['error'] as String?;
      throw GroqApiException(msg ?? 'Ошибка AI-сервиса (${e.status})');
    } catch (e) {
      throw GroqApiException('Не удалось разобрать ответ AI: $e');
    }
  }
}
