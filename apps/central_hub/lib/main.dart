import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait lock is a mobile-only API; browsers silently ignore or crash on it.
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
  // Pre-warms liquid-glass shaders — eliminates the white flash on first render
  // and compiles the Impeller pipeline on iOS/Android.
  await LiquidGlassWidgets.initialize();
  // GlassBackdropScope at root lets all glass surfaces share one GPU backdrop
  // capture, roughly halving blit cost when multiple cards are on screen.
  runApp(
    LiquidGlassWidgets.wrap(
      child: const ProviderScope(child: SieApp()),
      adaptiveQuality: true,
    ),
  );
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
    return MaterialApp(
      title: 'SiE',
      debugShowCheckedModeBanner: false,
      theme: SieTheme.cyberpunkDarkTheme,
      // On wide screens constrain the app to a phone-like column so the
      // terminal aesthetic stays intact.  Dialogs and overlays live inside
      // the Navigator, so they are constrained too — intentional.
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
      backgroundColor: Color(0xFF0A0E1A),
      body: SizedBox.shrink(),
    );
  }
}
