import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
    await _checkConnection();
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'full_name': username},
    );
    debugPrint(
      'SiE: Registration initiated — confirm email via Mailpit → http://127.0.0.1:54324',
    );
    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> _checkConnection() async {
    try {
      await client.from('branches').select('id').limit(1);
      debugPrint('SiE: Connection Successful!');
    } catch (e) {
      debugPrint('SiE: Connection Failed — $e');
    }
  }
}
