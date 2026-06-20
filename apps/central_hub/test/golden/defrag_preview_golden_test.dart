import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:central_hub/widgets/defrag_preview.dart';

/// Golden render of the ДЕФРАГМЕНТАЦИЯ carousel card — the shared-gold
/// defragmentation motif (scattered glass shards settling into an ordered
/// orbit around a glowing gold-sand core). Full screens need a live
/// Supabase/Riverpod backend, so we golden the self-contained card instead.
/// Animation is frozen (`motion: false`) for a deterministic settled frame.
void main() {
  testWidgets('Defrag card — dark theme golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1C1C22), // app dark background
          body: Center(
            child: RepaintBoundary(
              key: const Key('defrag.dark'),
              child: _defragCard(isLight: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('defrag.dark')),
      matchesGoldenFile('goldens/defrag_card_dark.png'),
    );
  });

  testWidgets('Defrag card — light theme golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F6FA), // app light background
          body: Center(
            child: RepaintBoundary(
              key: const Key('defrag.light'),
              child: _defragCard(isLight: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('defrag.light')),
      matchesGoldenFile('goldens/defrag_card_light.png'),
    );
  });
}

/// A static replica of the carousel card shell (`_BranchCarouselCard`) wrapping
/// [DefragPreview], using the same SieColors dark/light tokens.
Widget _defragCard({required bool isLight}) {
  const gold = Color(0xFFC8A84B);
  const gold2Dark = Color(0xFFAA7744);
  const gold2Light = Color(0xFFE5C16C);
  const goldLight = Color(0xFFD9BB65);
  final surface = isLight ? const Color(0xFFFFFFFF) : const Color(0xFF252529);
  final border = isLight ? const Color(0xFFE4E4EE) : const Color(0xFF3E3E48);
  final textPrimary = isLight ? const Color(0xFF1C1C22) : const Color(0xFFE4E4EC);
  final glass = isLight ? const Color(0xFF5B6480) : const Color(0xFFFFFFFF);

  return Container(
    width: 300,
    height: 420,
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border, width: 1),
      boxShadow: isLight
          ? const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ]
          : null,
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        // Top 5/8 — preview art.
        Expanded(
          flex: 5,
          child: DefragPreview(
            size: 260,
            gold: gold,
            gold2: isLight ? gold2Light : gold2Dark,
            goldLight: goldLight,
            glass: glass,
            trackColor: border,
            isLight: isLight,
            motion: false, // frozen settled state
          ),
        ),
        Divider(height: 1, thickness: 1, color: border),
        // Bottom 3/8 — label row.
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ДЕФРАГМЕНТАЦИЯ',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                    height: 1.1,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SESSION READY',
                      style: TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: gold, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}