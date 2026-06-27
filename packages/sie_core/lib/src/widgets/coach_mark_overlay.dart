import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/translations.g.dart';
import '../providers/tour_controller.dart';
import '../theme/sie_colors.dart';
import '../theme/sie_haptics.dart';
import 'coach_mark_painter.dart';

/// Full-screen interactive tour overlay: dims the screen, spotlights the
/// current step's target (measured live from its [GlobalKey]) and shows an
/// explanatory card with Skip / Back / Next controls. Mounted as the top child
/// of [MainNavigationShell]'s stack while a tour is active.
class CoachMarkOverlay extends ConsumerStatefulWidget {
  const CoachMarkOverlay({super.key});

  @override
  ConsumerState<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends ConsumerState<CoachMarkOverlay> {
  Rect? _targetRect;
  String _lastSig = '';

  /// Measure the active target relative to this overlay's own box, so the
  /// cutout aligns regardless of where the overlay is mounted.
  void _measure({int attempt = 0}) {
    if (!mounted) return;
    final controller = ref.read(tourControllerProvider.notifier);
    final st = ref.read(tourControllerProvider);
    final step = controller.currentStep;
    final keyId = (st.isCompleting) ? null : step?.targetKey;

    Rect? rect;
    if (keyId != null) {
      final key = controller.existingKey(keyId);
      final targetCtx = key?.currentContext;
      final targetBox = targetCtx?.findRenderObject() as RenderBox?;
      final overlayBox = context.findRenderObject() as RenderBox?;
      if (targetBox != null &&
          targetBox.attached &&
          overlayBox != null &&
          overlayBox.attached &&
          targetBox.hasSize) {
        final globalTopLeft = targetBox.localToGlobal(Offset.zero);
        final local = overlayBox.globalToLocal(globalTopLeft);
        rect = local & targetBox.size;
      }
    }

    if (rect == null && keyId != null && attempt < 8) {
      // Target not laid out yet (e.g. just after a tab switch) — retry briefly.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _measure(attempt: attempt + 1);
      });
      return;
    }
    if (rect != _targetRect) {
      setState(() => _targetRect = rect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(tourControllerProvider);
    final controller = ref.read(tourControllerProvider.notifier);
    final c = ref.watch(sieColorsProvider);

    if (!st.isActive) return const SizedBox.shrink();

    // Re-measure whenever the step / completion state changes.
    final sig = '${st.type}-${st.currentIndex}-${st.isCompleting}';
    if (sig != _lastSig) {
      _lastSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }

    final size = MediaQuery.of(context).size;
    final dimAlpha = c.isLightMode ? 0.55 : 0.72;
    final step = controller.currentStep;
    final total = controller.steps.length;

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        // Absorb all taps — navigation happens only via the card controls.
        child: Stack(
          children: [
            // Dim + spotlight cutout.
            Positioned.fill(
              child: CustomPaint(
                painter: CoachMarkPainter(
                  target: st.isCompleting ? null : _targetRect,
                  dimColor: Colors.black.withValues(alpha: dimAlpha),
                  accent: c.accent,
                ),
              ),
            ),
            // Tooltip / completion card.
            _buildCard(context, c, st, step, total, size),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    SieColors c,
    TourState st,
    TourStep? step,
    int total,
    Size size,
  ) {
    final completing = st.isCompleting;
    final title = completing ? t.tour.complete.title : (step?.title ?? '');
    final body = completing ? t.tour.complete.body : (step?.body ?? '');

    final card = _CardBody(
      c: c,
      title: title,
      body: body,
      stepLabel: completing
          ? null
          : t.tour.actions.step(n: st.currentIndex + 1, total: total),
      isFirst: st.currentIndex == 0 && !completing,
      isCompleting: completing,
      onSkip: () {
        SieHaptics.selection();
        ref.read(tourControllerProvider.notifier).skip();
      },
      onBack: () {
        SieHaptics.selection();
        ref.read(tourControllerProvider.notifier).back();
      },
      onNext: () {
        if (completing) {
          SieHaptics.success();
        } else {
          SieHaptics.selection();
        }
        ref.read(tourControllerProvider.notifier).next();
      },
    );

    // Placement: centred for completion / no-target steps; otherwise above or
    // below the target with a 16px gap.
    final rect = _targetRect;
    if (completing || rect == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: card,
        ),
      );
    }

    final pos = step?.position ?? TargetPosition.auto;
    final placeAbove = pos == TargetPosition.above ||
        (pos == TargetPosition.auto && rect.center.dy > size.height * 0.45);

    const sideInset = 16.0;
    final maxW = size.width - sideInset * 2;
    final cardW = maxW.clamp(0.0, 360.0);
    final left = ((rect.center.dx - cardW / 2))
        .clamp(sideInset, size.width - sideInset - cardW);

    if (placeAbove) {
      return Positioned(
        left: left,
        bottom: (size.height - rect.top + 16).clamp(16.0, size.height - 80),
        width: cardW,
        child: card,
      );
    }
    return Positioned(
      left: left,
      top: (rect.bottom + 16).clamp(16.0, size.height - 120),
      width: cardW,
      child: card,
    );
  }
}

class _CardBody extends StatelessWidget {
  final SieColors c;
  final String title;
  final String body;
  final String? stepLabel;
  final bool isFirst;
  final bool isCompleting;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _CardBody({
    required this.c,
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.isFirst,
    required this.isCompleting,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Protocol label.
        Row(
          children: [
            Container(width: 3, height: 14, color: c.accent),
            const SizedBox(width: 10),
            Text(
              isCompleting
                  ? t.tour.complete.title
                  : (stepLabel ?? '').toUpperCase(),
              style: TextStyle(
                color: c.accent,
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!isCompleting)
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
            ),
          ),
        if (!isCompleting) const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 13,
            height: 1.5,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: Text(
                t.tour.actions.skip,
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            if (!isFirst && !isCompleting) ...[
              _PillButton(
                c: c,
                label: t.tour.actions.back,
                filled: false,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
            ],
            _PillButton(
              c: c,
              label: isCompleting
                  ? t.tour.actions.finish
                  : t.tour.actions.next,
              filled: true,
              onTap: onNext,
            ),
          ],
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: c.isLightMode
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.accent.withValues(alpha: 0.06),
                      c.surface.withValues(alpha: 0.96),
                    ],
                  ),
            color: c.isLightMode ? c.surface : null,
            border: Border.all(color: c.accent.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.10),
                blurRadius: 40,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: inner,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final SieColors c;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.c,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: filled
              ? c.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: c.accent.withValues(alpha: filled ? 0.85 : 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
