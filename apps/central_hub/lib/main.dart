import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/splash_screen.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  await SupabaseService.initialize(
    url: 'https://bvqlqvzcqfgojzxztvrm.supabase.co',
    anonKey: 'sb_publishable_x54jsqL5s9ohcOJoyOTklw_5G8lbd9l',
  );
  GroqService.initialize(groqApiKey);
  runApp(const ProviderScope(child: SieApp()));
}

class SieApp extends ConsumerStatefulWidget {
  const SieApp({super.key});

  @override
  ConsumerState<SieApp> createState() => _SieAppState();
}

class _SieAppState extends ConsumerState<SieApp> {
  bool _launchComplete = false;

  @override
  Widget build(BuildContext context) {
    final sieMode = ref.watch(sieThemeModeProvider).valueOrNull
        ?? SieThemeMode.classicDark;

    return MaterialApp(
      title: 'SiE',
      debugShowCheckedModeBanner: false,
      theme: SieTheme.themeDataFor(sieMode),
      builder: kIsWeb ? _webConstraint : null,
      home: !_launchComplete
          ? SieSplashScreen(
              onComplete: () => setState(() => _launchComplete = true),
            )
          : _authGate(),
    );
  }

  Widget _authGate() {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      data: (isAuthenticated) =>
          isAuthenticated ? const MainNavigationShell() : const AuthScreen(),
      loading: () => const _LoadingScreen(),
      error: (_, _) => const AuthScreen(),
    );
  }

  static Widget _webConstraint(BuildContext context, Widget? child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: child!,
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1C1C22),
      body: SizedBox.shrink(),
    );
  }
}
