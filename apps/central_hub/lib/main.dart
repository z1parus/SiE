import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'screens/auth_screen.dart';
import 'screens/operations_control_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SupabaseService.initialize(
    url: 'http://127.0.0.1:54321',
    anonKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );
  runApp(const ProviderScope(child: SieApp()));
}

class SieApp extends ConsumerWidget {
  const SieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'SiE',
      debugShowCheckedModeBanner: false,
      theme: SieTheme.dark,
      home: authAsync.when(
        data: (isAuthenticated) => isAuthenticated
            ? const OperationsControlScreen()
            : const AuthScreen(),
        loading: () => const _SplashScreen(),
        error: (_, _) => const AuthScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: SieTheme.accent,
          strokeWidth: 1.5,
        ),
      ),
    );
  }
}
