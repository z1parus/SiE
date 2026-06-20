import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:central_hub/widgets/focus_orbit_timer.dart';

/// Golden test for the FOCUS PROTOCOL hero visual (the tangled-orbit timer).
///
/// Full screens need a live Supabase/Riverpod backend (see widget_test.dart),
/// so we golden the screen's self-contained centrepiece instead. Animation is
/// frozen (`motion: false`) and progress fixed so the frame is deterministic.
void main() {
  testWidgets('FocusOrbitTimer — static frame golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1C1C22), // app dark background
          body: Center(
            child: RepaintBoundary(
              child: FocusOrbitTimer(
                size: 220,
                timeText: '25',
                progress: 0.35,
                demo: false, // follow fixed progress, not the demo loop
                motion: false, // freeze all animation for a stable golden
                gold: const Color(0xFFC8A84B), // SieColors.accent
                gold2: const Color(0xFFE5C16C), // SieColors.accentSecondary
                glass: Colors.white,
                centerFontSize: 44,
                glow: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FocusOrbitTimer),
      matchesGoldenFile('goldens/focus_orbit_timer.png'),
    );
  });
}
