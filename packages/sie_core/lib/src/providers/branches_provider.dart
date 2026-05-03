import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import '../supabase_service.dart';

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final data = await SupabaseService.client
      .from('branches')
      .select()
      .order('name');
  return data.map((row) => Branch.fromJson(row)).toList();
});
