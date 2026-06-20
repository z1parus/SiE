import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sie_core/sie_core.dart';
import 'screens/auth_screen.dart';
import 'screens/breathing_exercise_screen.dart';
import 'screens/focus_protocol_screen.dart';
import 'screens/habit_tracker_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/planning_screen.dart';
import 'screens/splash_screen.dart';

/// Root navigator used to route notification taps into the planning module.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Mirrors the root navigator's stack so widget deep-links can de-duplicate
/// module screens. `Navigator` exposes no way to inspect its stack, so we track
/// it by route identity here (registered as a `navigatorObserver`).
final _RouteTracker _routeTracker = _RouteTracker();

class _RouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  bool containsName(String name) =>
      _stack.any((r) => r.settings.name == name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) _stack[i] = newRoute;
  }
}

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
  await NotificationService.instance.init(onTap: _handleNotificationTap);
  if (!kIsWeb) {
    registerHomeWidgets();
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }
  runApp(const ProviderScope(child: SieApp()));
}

/// Routes a `sie://widget/<host>` deep-link (whole-widget tap) into the app.
void _handleWidgetUri(Uri? uri) {
  if (uri == null || uri.host != 'widget') return;
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  final module = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  switch (module) {
    case 'focus':
      _openModuleScreen(nav, 'widget/focus',
          () => const FocusProtocolScreen());
    case 'planning':
      _openModuleScreen(nav, 'widget/planning',
          () => const PlanningScreen());
    case 'breathing':
      _openModuleScreen(nav, 'widget/breathing',
          () => const BreathingExerciseScreen());
    case 'habits':
    default:
      _openModuleScreen(nav, 'widget/habits',
          () => const HabitTrackerScreen());
  }
}

/// Opens a module screen from a widget tap, de-duplicating against repeated
/// taps. If a screen with [routeName] is already anywhere in the stack we
/// surface it (pop back to it, discarding any deeper screens the user pushed on
/// top) instead of pushing another copy — otherwise repeated widget taps would
/// stack identical screens the user must dismiss one by one.
void _openModuleScreen(
    NavigatorState nav, String routeName, Widget Function() builder) {
  if (_routeTracker.containsName(routeName)) {
    nav.popUntil((route) => route.settings.name == routeName);
  } else {
    nav.push(MaterialPageRoute(
      builder: (_) => builder(),
      settings: RouteSettings(name: routeName),
    ));
  }
}

void _handleNotificationTap(String? payload) {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  if (payload == 'habits') {
    nav.push(MaterialPageRoute(builder: (_) => const HabitTrackerScreen()));
  } else {
    nav.push(MaterialPageRoute(builder: (_) => const PlanningScreen()));
  }
}

class SieApp extends ConsumerStatefulWidget {
  const SieApp({super.key});

  @override
  ConsumerState<SieApp> createState() => _SieAppState();
}

class _SieAppState extends ConsumerState<SieApp> {
  bool _launchComplete = false;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _initWidgetDeepLinks();
  }

  Future<void> _initWidgetDeepLinks() async {
    // App launched by tapping a widget (cold start).
    final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (launchUri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Defer until the auth gate has settled so the route lands on top.
        Future.delayed(const Duration(milliseconds: 600),
            () => _handleWidgetUri(launchUri));
      });
    }
    // Widget tapped while app already running.
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);

    // Re-render active widgets from the local mirror (handles day rollover and
    // any changes made while the app was closed).
    await refreshHomeWidgetsOnLaunch(ref.read(appDatabaseProvider));
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sieMode = ref.watch(sieThemeModeProvider).valueOrNull
        ?? SieThemeMode.classicDark;

    return MaterialApp(
      title: 'SiE',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [_routeTracker],
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

class _LoadingScreen extends ConsumerWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Scaffold(
      backgroundColor: c.background,
      body: const SizedBox.shrink(),
    );
  }
}
