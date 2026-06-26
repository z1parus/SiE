import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'language_picker.dart';
import 'operations_control_screen.dart';
import 'reminder_settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OfflineShell — the reduced shell shown when the backend was unreachable at
// launch. Two tabs only: the module carousel (everything offline-capable) and a
// stripped-down Hub (identity + the few settings that work without a network).
// Garage and Hall of Fame are intentionally absent (they are network-only).
// ─────────────────────────────────────────────────────────────────────────────
class OfflineShell extends ConsumerStatefulWidget {
  const OfflineShell({super.key});

  @override
  ConsumerState<OfflineShell> createState() => _OfflineShellState();
}

class _OfflineShellState extends ConsumerState<OfflineShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

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
            content: Text(t.operations.exitHint),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SieBackground(
      child: PopScope(
        canPop: !Platform.isAndroid,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBackPress();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const _OfflineBadgeBar(),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: const [
                          OperationsControlScreen(asTab: true, offline: true),
                          OfflineHubScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _OfflineNavBar(
                  activeIndex: _currentIndex,
                  onTabChanged: (i) {
                    if (i == _currentIndex) return;
                    SieHaptics.selection();
                    setState(() => _currentIndex = i);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline badge bar — a thin always-on indicator that the app is running
// without a backend connection.
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineBadgeBar extends ConsumerWidget {
  const _OfflineBadgeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: c.warning.withValues(alpha: 0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 13, color: c.warning),
          const SizedBox(width: 8),
          Text(
            t.common.offline.badge,
            style: TextStyle(
              color: c.warning,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline navigation bar — two tabs.
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineNavBar extends ConsumerWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;

  const _OfflineNavBar({required this.activeIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final items = [
      (icon: Icons.my_location_outlined, label: t.common.offline.tabModules),
      (icon: Icons.person_outline, label: t.common.offline.tabHub),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(bottomInset, 16)),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final active = i == activeIndex;
            final color = active ? c.accent : c.iconMuted;
            return Semantics(
              button: true,
              selected: active,
              label: item.label,
              child: GestureDetector(
                onTap: () => onTabChanged(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 96,
                  height: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: SieMotion.duration(context, SieMotion.fast),
                        curve: Curves.easeOut,
                        width: active ? 28 : 0,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Icon(item.icon, color: color, size: 22),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OfflineHubScreen — identity + the settings that work without a backend.
// ─────────────────────────────────────────────────────────────────────────────
class OfflineHubScreen extends ConsumerStatefulWidget {
  const OfflineHubScreen({super.key});

  @override
  ConsumerState<OfflineHubScreen> createState() => _OfflineHubScreenState();
}

class _OfflineHubScreenState extends ConsumerState<OfflineHubScreen> {
  bool _connecting = false;

  Future<void> _tryConnect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final ok = await ref.read(appModeProvider.notifier).tryConnect();
    if (!mounted) return;
    // On success the app root swaps in the full shell automatically. Refresh
    // the connectivity stream + the branches cache (which loaded the offline
    // fallback list) so the full shell opens with fresh server state.
    if (ok) {
      ref.invalidate(connectivityProvider);
      ref.invalidate(branchesProvider);
      return;
    }
    setState(() => _connecting = false);
    {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(t.common.offline.connectFailed),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDestructive(
      context,
      ref,
      title: t.common.logout.confirmTitle,
      message: t.common.logout.confirmMessage,
      confirmLabel: t.common.logout.action,
    );
    if (!ok) return;
    await SupabaseService.signOut();
    ref.invalidate(userProfileProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(branchesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = ref.watch(sieThemeModeProvider).valueOrNull ??
        SieThemeMode.classicDark;
    final isDark = themeMode == SieThemeMode.classicDark;

    final name = profile?.username?.toUpperCase() ?? t.common.operativeFallback;
    final xp = profile?.totalXp ?? 0;
    final dp = profile?.designPoints ?? 0;
    final level = xp ~/ 1000 + 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          children: [
            Text(
              t.common.offline.terminal,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            _IdentityCard(name: name, level: level, xp: xp, dp: dp, c: c),
            const SizedBox(height: 20),
            _ConnectButton(busy: _connecting, onTap: _tryConnect, c: c),
            const SizedBox(height: 24),
            Text(
              t.common.settings,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            _SettingRow(
              icon: Icons.language,
              label: t.common.language,
              c: c,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(languageLabel(ref.watch(localeProvider)),
                      style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: c.textSecondary, size: 18),
                ],
              ),
              onTap: () => showLanguagePicker(context, ref),
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              label: t.common.darkTheme,
              c: c,
              trailing: Switch(
                value: isDark,
                activeColor: c.accent,
                onChanged: (v) => ref.read(sieThemeModeProvider.notifier).setMode(
                      v ? SieThemeMode.classicDark : SieThemeMode.classicLight,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.notifications_none_rounded,
              label: t.common.notifications,
              c: c,
              trailing: Icon(Icons.chevron_right, color: c.textSecondary, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReminderSettingsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.logout,
              label: t.common.logout.action,
              c: c,
              danger: true,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.level,
    required this.xp,
    required this.dp,
    required this.c,
  });

  final String name;
  final int level;
  final int xp;
  final int dp;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    Widget stat(String value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: c.accent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 10, letterSpacing: 1)),
          ],
        );

    return SieGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.15),
                  border: Border.all(color: c.accent.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.common.offline.level(n: level),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: stat('$xp', t.common.offline.xp)),
              Expanded(child: stat('$dp', t.common.offline.designPoints)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.busy, required this.onTap, required this.c});

  final bool busy;
  final VoidCallback onTap;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: c.accent.withValues(alpha: 0.12),
          border: Border.all(color: c.accent.withValues(alpha: 0.7)),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_tethering, color: c.accent, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    t.common.offline.connect,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.c,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final SieColors c;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? c.danger : c.textPrimary;
    return SieGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: danger ? c.danger : c.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: fg, fontSize: 14),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
