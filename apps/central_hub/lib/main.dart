import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sie_core/sie_core.dart';
import 'screens/auth_screen.dart';
import 'screens/breathing_exercise_screen.dart';
import 'screens/course_tour_coordinator.dart';
import 'screens/focus_protocol_screen.dart';
import 'screens/habit_tracker_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/meditation_hub_screen.dart';
import 'screens/offline_shell.dart';
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
  // Restore the saved language (or match the device, falling back to English)
  // before the first frame so the UI renders in the right language immediately.
  await initAppLocale();
  await NotificationService.instance.init(onTap: _handleNotificationTap);
  if (!kIsWeb) {
    try {
      registerHomeWidgets();
      await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
    } catch (e) {
      // home_widget requires an App Group / WidgetKit extension on iOS.
      // If neither is configured yet we swallow the error so the app
      // continues to launch normally without widget support.
      debugPrint('SiE Widgets: init skipped — $e');
    }
  }
  runApp(TranslationProvider(child: const ProviderScope(child: SieApp())));
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
    case 'meditation':
      _openModuleScreen(nav, 'widget/meditation',
          () => const MeditationHubScreen());
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

class _SieAppState extends ConsumerState<SieApp> with WidgetsBindingObserver {
  bool _launchComplete = false;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Warm the startup reachability probe now so it resolves during the splash
    // animation instead of adding its latency after the splash dismisses.
    ref.read(appModeProvider);
    if (!kIsWeb) _initWidgetDeepLinks();
  }

  // Display-zoom / rotation changes the logical width — rebuild so the theme
  // and the SieScale factor are recomputed.
  @override
  void didChangeMetrics() => setState(() {});

  Future<void> _initWidgetDeepLinks() async {
    try {
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
    } catch (e) {
      debugPrint('SiE Widgets: deep-link init skipped — $e');
    }

    // Re-render active widgets from the local mirror (handles day rollover and
    // any changes made while the app was closed).
    await refreshHomeWidgetsOnLaunch(ref.read(appDatabaseProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set the proportional UI scale from the real logical width *before* the
    // theme is built, so theme text sizes (and anything tagged `.s`) use the
    // right factor from the first frame. `_globalBuilder` refreshes it again
    // for descendants on every MediaQuery change.
    final view = View.of(context);
    SieScale.update(view.physicalSize.width / view.devicePixelRatio);

    final sieMode = ref.watch(sieThemeModeProvider).valueOrNull
        ?? SieThemeMode.classicDark;
    // Drive locale from the provider so switching language rebuilds the whole
    // tree (and the global `t` accessor re-reads) in the chosen language.
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'SiE',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [_routeTracker],
      theme: SieTheme.themeDataFor(sieMode),
      locale: locale.flutterLocale,
      supportedLocales: AppLocale.values.map((l) => l.flutterLocale).toList(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: _globalBuilder,
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
      data: (isAuthenticated) {
        if (!isAuthenticated) return const AuthScreen();
        // Authenticated (session restored from local storage even offline).
        // Route to the full shell only when the backend was reachable at
        // startup; otherwise run the reduced offline shell.
        final modeAsync = ref.watch(appModeProvider);
        return modeAsync.when(
          data: (mode) => mode == AppMode.offline
              ? const OfflineShell()
              : const MainNavigationShell(),
          loading: () => const _LoadingScreen(),
          // Probe failed unexpectedly — assume online and let the offline-first
          // providers degrade gracefully if it's actually down.
          error: (_, _) => const MainNavigationShell(),
        );
      },
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

  // Mounts the interactive-tour overlay + course coordinator above the whole
  // navigator, so coach marks also render over pushed routes (mission detail,
  // tactical map, etc.). Also clamps the system text scale so an enlarged
  // device font / display-zoom setting (common on Samsung One UI) can't blow
  // up the tightly-spaced, uppercase + letter-spaced layouts.
  static Widget _globalBuilder(BuildContext context, Widget? child) {
    Widget content = child ?? const SizedBox.shrink();
    if (kIsWeb) content = _webConstraint(context, content);
    content = Stack(
      textDirection: TextDirection.ltr,
      children: [
        content,
        const CourseTourCoordinator(),
        const CoachMarkOverlay(),
      ],
    );
    final mq = MediaQuery.of(context);
    // Recompute the proportional UI scale from the current width, so sizes
    // tagged with `.s` shrink on narrow / display-zoomed screens.
    SieScale.update(mq.size.width);
    // Text is scaled globally: clamp the system font scale, then multiply by the
    // width-proportional factor. This shrinks *all* text (theme + explicit
    // fontSize) on narrow / display-zoomed screens without migrating every
    // literal — fonts aren't tagged with `.s` (only non-text sizes are).
    final systemFactor = (mq.textScaler.scale(14.0) / 14.0).clamp(0.0, 1.15);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(systemFactor * SieScale.factor),
      ),
      child: content,
    );
  }
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
