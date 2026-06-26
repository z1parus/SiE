import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sie_core/sie_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoalExportSheet
// Bottom-sheet: choose Markdown or PNG, generate, share.
// ─────────────────────────────────────────────────────────────────────────────

class GoalExportSheet extends ConsumerStatefulWidget {
  const GoalExportSheet({
    super.key,
    required this.goal,
    required this.sc,
    required this.mapMode,
    this.mapRepaintKey,
  });

  final Goal goal;
  final SieColors sc;
  /// Whether TacticalMapView is currently rendered (PNG only available in map mode).
  final bool mapMode;
  /// Key wrapping the RepaintBoundary around TacticalMapView. Null when not in map mode.
  final GlobalKey? mapRepaintKey;

  @override
  ConsumerState<GoalExportSheet> createState() => _GoalExportSheetState();
}

class _GoalExportSheetState extends ConsumerState<GoalExportSheet> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ios_share_outlined, color: c.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                t.goalExport.header.title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.goal.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: c.accent,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(t.goalExport.status.generating,
                        style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            if (_error != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE03050).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: Color(0xFFE03050), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _ExportOption(
              icon: Icons.description_outlined,
              title: t.goalExport.markdown.title,
              subtitle: t.goalExport.markdown.subtitle,
              sc: c,
              onTap: _exportMarkdown,
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.image_outlined,
              title: t.goalExport.png.title,
              subtitle: widget.mapMode
                  ? t.goalExport.png.subtitleAvailable
                  : t.goalExport.png.subtitleUnavailable,
              sc: c,
              enabled: widget.mapMode && widget.mapRepaintKey != null,
              onTap: _exportPng,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportMarkdown() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final md = goalToMarkdown(widget.goal);
      final dir = await getTemporaryDirectory();
      final safeName = widget.goal.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final date =
          DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
      final file = File('${dir.path}/${safeName}_$date.md');
      await file.writeAsString(md, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/markdown')],
        subject: widget.goal.name,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = t.goalExport.errors.generic(error: e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPng() async {
    final key = widget.mapRepaintKey;
    if (key == null || key.currentContext == null) {
      setState(() => _error = t.goalExport.errors.mapNotRendered);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boundary = key.currentContext!.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw t.goalExport.errors.repaintBoundaryNotFound;
      }

      // Clamp pixel ratio to avoid exceeding GPU texture limit
      const maxDim = 4096.0;
      final size = boundary.size;
      final maxRatio =
          maxDim / (size.width > size.height ? size.width : size.height);
      final pixelRatio = (maxRatio < 2.0 ? maxRatio : 2.0).clamp(0.5, 3.0);

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw t.goalExport.errors.imageSaveFailed;

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final safeName = widget.goal.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final date =
          DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
      final file = File('${dir.path}/${safeName}_$date.png');
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: widget.goal.name,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = t.goalExport.errors.generic(error: e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── _ExportOption ────────────────────────────────────────────────────────────

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sc,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final SieColors sc;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    final dimmed = !enabled;
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: c.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: c.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
