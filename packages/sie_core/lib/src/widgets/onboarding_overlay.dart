import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/sie_colors.dart';

class OnboardingOverlay extends ConsumerStatefulWidget {
  final bool visible;
  final String moduleLabel;
  final String description;
  final String benefit;
  final VoidCallback onAccept;
  final int? xpReward;

  const OnboardingOverlay({
    super.key,
    required this.visible,
    required this.moduleLabel,
    required this.description,
    required this.benefit,
    required this.onAccept,
    this.xpReward,
  });

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  bool _btnPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.visible) _ctrl.forward();
  }

  @override
  void didUpdateWidget(OnboardingOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _ctrl.forward(from: 0);
    } else if (!widget.visible && old.visible) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        ),
        child: _buildOverlayContent(context, c),
      ),
    );
  }

  Widget _buildOverlayContent(BuildContext context, SieColors c) {
    final backdropAlpha = c.isLightMode ? 0.40 : 0.68;
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          color: Colors.black.withValues(alpha: backdropAlpha),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildCard(c, child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status label
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: c.accent,
                                boxShadow: c.isCosmicMode
                                    ? [
                                        BoxShadow(
                                          color: c.accent.withValues(alpha: 0.60),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ПРОТОКОЛ АКТИВИРОВАН',
                              style: TextStyle(
                                color: c.accent,
                                fontSize: 10,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                                shadows: c.isCosmicMode
                                    ? [
                                        Shadow(
                                          color: c.accent.withValues(alpha: 0.55),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Module label
                        Text(
                          widget.moduleLabel,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0.4,
                            height: 1.5,
                            shadows: c.isCosmicMode
                                ? [Shadow(color: c.accent, blurRadius: 6)]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: c.border, height: 1),
                        const SizedBox(height: 16),
                        // Benefit with bullet token
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '◆',
                              style: TextStyle(
                                color: c.accent,
                                fontSize: 10,
                                height: 1.6,
                                shadows: c.isCosmicMode
                                    ? [
                                        Shadow(
                                          color: c.accent.withValues(alpha: 0.80),
                                          blurRadius: 10,
                                        ),
                                        Shadow(
                                          color: c.accent.withValues(alpha: 0.40),
                                          blurRadius: 20,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.benefit,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.xpReward != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: c.accent.withValues(alpha: 0.28),
                              ),
                              color: c.accent.withValues(alpha: 0.04),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '◆',
                                  style: TextStyle(
                                    color: c.accent.withValues(alpha: 0.70),
                                    fontSize: 9,
                                    shadows: c.isCosmicMode
                                        ? [
                                            Shadow(
                                              color: c.accent,
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'REWARD',
                                  style: TextStyle(
                                    color: c.textSecondary.withValues(alpha: 0.70),
                                    fontSize: 9,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '+${widget.xpReward} XP',
                                  style: TextStyle(
                                    color: c.accent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    shadows: c.isCosmicMode
                                        ? [
                                            Shadow(color: c.accent, blurRadius: 10),
                                            Shadow(color: c.accent, blurRadius: 24),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        // Accept button
                        GestureDetector(
                          onTap: widget.onAccept,
                          onTapDown: (_) =>
                              setState(() => _btnPressed = true),
                          onTapUp: (_) =>
                              setState(() => _btnPressed = false),
                          onTapCancel: () =>
                              setState(() => _btnPressed = false),
                          child: AnimatedScale(
                            scale: _btnPressed ? 0.97 : 1.0,
                            duration: _btnPressed
                                ? const Duration(milliseconds: 80)
                                : const Duration(milliseconds: 220),
                            curve: _btnPressed
                                ? Curves.easeIn
                                : Curves.easeOut,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _btnPressed
                                    ? c.accent.withValues(alpha: 0.18)
                                    : c.accent.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: c.accent.withValues(
                                    alpha: _btnPressed ? 1.0 : 0.85,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.accent.withValues(
                                      alpha: _btnPressed ? 0.35 : 0.12,
                                    ),
                                    blurRadius: _btnPressed ? 20 : 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                'ПРИНЯТЬ ПРОТОКОЛ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.5,
                                  shadows: c.isCosmicMode
                                      ? [
                                          Shadow(color: c.accent, blurRadius: 8),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(SieColors c, {required Widget child}) {
    if (c.isLightMode) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: c.surface,
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 24,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: child,
      );
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.accent.withValues(alpha: 0.06),
              c.surface.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
            color: c.accent.withValues(alpha: 0.38),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.10),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: child,
      ),
    );
  }
}
