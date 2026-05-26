import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sie_theme.dart';

const _kCyan = Color(0xFF00E5FF);

class OnboardingOverlay extends StatefulWidget {
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
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
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
        child: _buildOverlayContent(context),
      ),
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          color: Colors.black.withValues(alpha: 0.68),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _kCyan.withValues(alpha: 0.06),
                          const Color(0xFF0A0E1A).withValues(alpha: 0.90),
                        ],
                      ),
                      border: Border.all(
                        color: _kCyan.withValues(alpha: 0.38),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kCyan.withValues(alpha: 0.10),
                          blurRadius: 40,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
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
                                color: _kCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: _kCyan.withValues(alpha: 0.60),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ПРОТОКОЛ АКТИВИРОВАН',
                              style: TextStyle(
                                color: _kCyan,
                                fontSize: 10,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    color: _kCyan.withValues(alpha: 0.55),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Module label
                        Text(
                          widget.moduleLabel,
                          style: const TextStyle(
                            color: SieTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description with cyan glow
                        Text(
                          widget.description,
                          style: const TextStyle(
                            color: SieTheme.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0.4,
                            height: 1.5,
                            shadows: [
                              Shadow(color: _kCyan, blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: SieTheme.borderDefault, height: 1),
                        const SizedBox(height: 16),
                        // Benefit with glowing bullet token
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '◆',
                              style: TextStyle(
                                color: _kCyan,
                                fontSize: 10,
                                height: 1.6,
                                shadows: [
                                  Shadow(
                                    color: _kCyan.withValues(alpha: 0.80),
                                    blurRadius: 10,
                                  ),
                                  Shadow(
                                    color: _kCyan.withValues(alpha: 0.40),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.benefit,
                                style: const TextStyle(
                                  color: SieTheme.textPrimary,
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
                                color: _kCyan.withValues(alpha: 0.28),
                              ),
                              color: _kCyan.withValues(alpha: 0.04),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '◆',
                                  style: TextStyle(
                                    color: _kCyan.withValues(alpha: 0.70),
                                    fontSize: 9,
                                    shadows: [
                                      Shadow(
                                        color: _kCyan,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'REWARD',
                                  style: TextStyle(
                                    color: SieTheme.textSecondary
                                        .withValues(alpha: 0.70),
                                    fontSize: 9,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '+${widget.xpReward} XP',
                                  style: const TextStyle(
                                    color: _kCyan,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    shadows: [
                                      Shadow(color: _kCyan, blurRadius: 10),
                                      Shadow(color: _kCyan, blurRadius: 24),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        // Accept button with press scale + specular flash
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
                                    ? _kCyan.withValues(alpha: 0.18)
                                    : _kCyan.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: _kCyan.withValues(
                                    alpha: _btnPressed ? 1.0 : 0.85,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kCyan.withValues(
                                      alpha: _btnPressed ? 0.35 : 0.12,
                                    ),
                                    blurRadius: _btnPressed ? 20 : 8,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'ПРИНЯТЬ ПРОТОКОЛ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _kCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.5,
                                  shadows: [
                                    Shadow(color: _kCyan, blurRadius: 8),
                                  ],
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
      ),
    );
  }
}
