import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

import 'leaderboard_screen.dart';
import 'operations_control_screen.dart';
import 'profile_screen.dart';

// Connectivity + sync imports accessed via sie_core exports.

const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);
const _kMuted  = Color(0xFF90A4AE);

// ─────────────────────────────────────────────────────────────────────────────
// MainNavigationShell — root navigation shell with persistent glass nav bar
// ─────────────────────────────────────────────────────────────────────────────
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  // Start on the Operations tab (index 1), matching the legacy entry point.
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSync());
  }

  void _setupSync() {
    // Fire sync once at startup if online.
    final isOnline =
        ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) SyncService.fromWidgetRef(ref).syncAll();

    // Re-sync whenever connectivity is restored.
    ref.listenManual<AsyncValue<bool>>(connectivityProvider,
        (previous, next) {
      final wasOffline = previous?.valueOrNull == false;
      final isNowOnline = next.valueOrNull == true;
      if (wasOffline && isNowOnline) {
        SyncService.fromWidgetRef(ref).syncAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  // IndexedStack keeps all tab states alive — no rebuilds or
                  // state loss when switching tabs.
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      ProfileScreen(asTab: true),
                      OperationsControlScreen(asTab: true),
                      const _GarageTab(),
                      LeaderboardScreen(asTab: true),
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
                activeIndex: _currentIndex,
                onTabChanged: (i) => setState(() => _currentIndex = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Garage placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _GarageTab extends StatelessWidget {
  const _GarageTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'GARAGE\nINITIALISING',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF90A4AE),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell Navigation Bar — extracted from OperationsControlScreen._FloatingNavBar
// ─────────────────────────────────────────────────────────────────────────────
class _ShellNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;

  const _ShellNavBar({
    required this.activeIndex,
    required this.onTabChanged,
  });

  static const _items = [
    (icon: Icons.language_outlined,    label: 'Hub'),
    (icon: Icons.my_location_outlined, label: 'Operations'),
    (icon: Icons.shield_outlined,      label: 'Garage'),
    (icon: Icons.star_outline,         label: 'Hall of Fame'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(bottomInset, 16)),
      child: GlassCard(
        height: 68,
        padding: EdgeInsets.zero,
        shape: LiquidRoundedSuperellipse(borderRadius: 28),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: LiquidGlassSettings(
          blur: 3.5,
          thickness: 24,
          refractiveIndex: 1.45,
          glassColor: const Color(0x0A0A0E1A),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.72,
          glowIntensity: 0.92,
          saturation: 1.4,
          specularSharpness: GlassSpecularSharpness.sharp,
          ambientStrength: 0.08,
          chromaticAberration: 0.015,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            return _NavItem(
              icon: item.icon,
              label: item.label,
              isActive: i == activeIndex,
              onTap: () => onTabChanged(i),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kCyan : _kMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 68,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isActive)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.1,
                      colors: [
                        _kCyan.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isActive)
                  Container(
                    width: 28,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kCyan, _kPurple],
                      ),
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: _kCyan.withValues(alpha: 0.7),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 6),
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
