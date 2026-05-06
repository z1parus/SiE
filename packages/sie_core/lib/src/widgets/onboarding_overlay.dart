import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sie_theme.dart';

class OnboardingOverlay extends StatefulWidget {
  final bool visible;
  final String moduleLabel;
  final String description;
  final String benefit;
  final VoidCallback onAccept;

  const OnboardingOverlay({
    super.key,
    required this.visible,
    required this.moduleLabel,
    required this.description,
    required this.benefit,
    required this.onAccept,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: SieTheme.surface.withValues(alpha: 0.92),
                border: Border.all(color: SieTheme.borderAccent),
                borderRadius: BorderRadius.circular(4),
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
                        color: SieTheme.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ПРОТОКОЛ АКТИВИРОВАН',
                        style: TextStyle(
                          color: SieTheme.accent,
                          fontSize: 10,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w600,
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
                  // Description
                  Text(
                    widget.description,
                    style: const TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.4,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: SieTheme.borderDefault, height: 1),
                  const SizedBox(height: 16),
                  // Benefit
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ЭФФЕКТ',
                        style: TextStyle(
                          color: SieTheme.accent.withValues(alpha: 0.8),
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  const SizedBox(height: 28),
                  // Accept button
                  GestureDetector(
                    onTap: widget.onAccept,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: SieTheme.accent.withValues(alpha: 0.1),
                        border: Border.all(color: SieTheme.accent),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'ПРИНЯТЬ ПРОТОКОЛ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SieTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
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
    );
  }
}
