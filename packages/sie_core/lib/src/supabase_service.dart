import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  /// The project URL passed to [initialize]. Exposed so lightweight reachability
  /// probes (see ConnectivityService) can ping the backend the app actually
  /// depends on, rather than some unrelated third-party host.
  static String? supabaseUrl;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    supabaseUrl = url;
    await Supabase.initialize(url: url, anonKey: anonKey);
    // Fire-and-forget connectivity diagnostic. It MUST NOT be awaited: a real
    // network round-trip here on the cold-start path is what made the app hang
    // for the full socket timeout when the backend was unreachable.
    unawaited(_checkConnection());
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

  /// Sends a password-reset email to [email]. The recovery link is handled by
  /// Supabase's configured redirect flow.
  static Future<void> resetPassword({required String email}) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static Future<void> _checkConnection() async {
    try {
      await client
          .from('branches')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 4));
      debugPrint('SiE: Connection Successful!');
    } catch (e) {
      debugPrint('SiE: Connection Failed — $e');
    }
  }
}
