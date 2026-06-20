import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tip.dart';
import '../supabase_service.dart';

final tipsProvider = FutureProvider.autoDispose<List<Tip>>((ref) async {
  try {
    final data = await SupabaseService.client
        .from('tips')
        .select()
        .eq('is_active', true)
        .order('created_at');
    return (data as List).map(Tip.fromJson).toList();
  } catch (e) {
    debugPrint('SiE Tips: fetch failed — $e');
    return const [];
  }
});

final allTipsProvider = FutureProvider.autoDispose<List<Tip>>((ref) async {
  try {
    final data = await SupabaseService.client
        .from('tips')
        .select()
        .order('created_at');
    return (data as List).map(Tip.fromJson).toList();
  } catch (e) {
    debugPrint('SiE Tips (all): fetch failed — $e');
    return const [];
  }
});