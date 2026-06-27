import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'garage_screen.dart';
import 'leaderboard_screen.dart';
import 'operations_control_screen.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainNavigationShell — root navigation shell with persistent nav bar
// ─────────────────────────────────────────────────────────────────────────────
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 1;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSync());
  }

  void _setupSync() {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      SyncService.fromWidgetRef(ref).syncAll().then((_) {
        if (mounted) ref.invalidate(planningProvider);
      });
    }

    ref.listenManual<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final wasOffline = previous?.valueOrNull == false;
      final isNowOnline = next.valueOrNull == true;
      if (wasOffline && isNowOnline) {
        SyncService.fromWidgetRef(ref).syncAll().then((_) {
          if (mounted) ref.invalidate(planningProvider);
        });
      }
    });
  }

  void _handleBackPress() {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
    } else {
      _lastBackPress = now;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(t.mainNav.backToExit),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The interactive tour drives the active tab as it walks through the steps.
    ref.listen<TourState>(tourControllerProvider, (prev, next) {
      final tab = ref.read(tourControllerProvider.notifier).desiredTab;
      if (tab != null && tab != _currentIndex) {
        setState(() => _currentIndex = tab);
      }
    });

    return SieBackground(
      child: PopScope(
        canPop: !Platform.isAndroid,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBackPress();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    const OfflineBanner(),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          ProfileScreen(asTab: true),
                          OperationsControlScreen(asTab: true),
                          const GarageScreen(asTab: true),
                          LeaderboardScreen(asTab: true, isActive: _currentIndex == 3),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _ShellNavBar(
                    key: ref.read(tourControllerProvider.notifier).keyFor('nav_bar'),
                    activeIndex: _currentIndex,
                    onTabChanged: (i) {
                      if (i == _currentIndex) return;
                      SieHaptics.selection();
                      setState(() => _currentIndex = i);
                    },
                  ),
                ),
                const CoachMarkOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _ShellNavBar extends ConsumerWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;

  const _ShellNavBar({
    required this.activeIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = ref.watch(sieColorsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final items = [
      (icon: Icons.language_outlined,    label: t.mainNav.tabs.hub),
      (icon: Icons.my_location_outlined, label: t.mainNav.tabs.operations),
      (icon: Icons.shield_outlined,      label: t.mainNav.tabs.garage),
      (icon: Icons.star_outline,         label: t.mainNav.tabs.hallOfFame),
    ];

    final navContent = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(items.length, (i) {
        final item = items[i];
        return _NavItem(
          icon: item.icon,
          label: item.label,
          isActive: i == activeIndex,
          activeColor: c.accent,
          inactiveColor: c.iconMuted,
          onTap: () => onTabChanged(i),
        );
      }),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(bottomInset, 16)),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.border),
        ),
        child: navContent,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Item
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated active indicator — fades/grows in instead of snapping.
              AnimatedContainer(
                duration: SieMotion.duration(context, SieMotion.fast),
                curve: Curves.easeOut,
                width: isActive ? 28 : 0,
                height: 2,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
