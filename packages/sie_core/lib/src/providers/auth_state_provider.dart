import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_service.dart';

/// Emits true when a session is active, false when signed out.
/// Supabase emits an initialSession event immediately on subscription,
/// so the loading state resolves before the first frame.
final authStateProvider = StreamProvider<bool>((ref) {
  return SupabaseService.client.auth.onAuthStateChange
      .map((state) => state.session != null);
});
