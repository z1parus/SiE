import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import '../supabase_service.dart';

// Fallback branch list shown when Supabase is unreachable.
// Slugs must match the navigation logic in operations_control_screen.dart.
const _fallbackBranches = [
  Branch(
    id: 'offline-breathing',
    slug: 'breathing_practices',
    name: 'Breathing Practices',
  ),
  Branch(
    id: 'offline-habits',
    slug: 'habit_archive',
    name: 'Habit Archive',
  ),
  Branch(
    id: 'offline-focus',
    slug: 'focus_protocol',
    name: 'Focus Protocol',
  ),
];

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  try {
    final data = await SupabaseService.client
        .from('branches')
        .select()
        .order('name');
    return data.map((row) => Branch.fromJson(row)).toList();
  } catch (e) {
    debugPrint('SiE Branches: offline fallback — $e');
    return _fallbackBranches;
  }
});
