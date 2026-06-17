import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit_template.dart';
import 'connectivity_provider.dart';

/// Curated habit library (Stage 8). Loads system templates from Supabase when
/// online and falls back to the built-in seed offline / on failure so the
/// library always has content.
final habitTemplatesProvider =
    FutureProvider.autoDispose<List<HabitTemplate>>((ref) async {
  final isOnline = ref.watch(connectivityProvider).valueOrNull ?? false;
  if (!isOnline) return HabitTemplate.fallbackSeed;

  try {
    final rows = await Supabase.instance.client
        .from('habit_templates')
        .select()
        .eq('is_system', true)
        .order('sort_order');
    if (rows.isEmpty) return HabitTemplate.fallbackSeed;
    return rows.map((r) => HabitTemplate.fromMap(r)).toList();
  } catch (e) {
    debugPrint('SiE HabitTemplates: load failed, using built-in seed — $e');
    return HabitTemplate.fallbackSeed;
  }
});
