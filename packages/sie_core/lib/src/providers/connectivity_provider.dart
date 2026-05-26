import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final service = ConnectivityService();
  // Emit current state immediately, then stream changes.
  yield await service.checkNow();
  yield* service.isOnlineStream;
});
