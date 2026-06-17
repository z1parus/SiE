import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sie_core/sie_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttachmentGallery
// Horizontal strip of attachment thumbnails with an optional add-button.
// Reused in both the Tactical Map node sheets and the list-mode tile details.
// ─────────────────────────────────────────────────────────────────────────────

class AttachmentGallery extends ConsumerWidget {
  const AttachmentGallery({
    super.key,
    required this.goalId,
    required this.nodeType,
    required this.nodeId,
    required this.attachments,
    required this.canEdit,
    this.compactMode = false,
  });

  final String goalId;
  final String nodeType;
  final String nodeId;
  final List<NodeAttachment> attachments;
  final bool canEdit;
  /// Compact mode shows smaller thumbnails (used on map node sheets).
  final bool compactMode;

  static const double _thumbSize = 72;
  static const double _thumbSizeCompact = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final ts = compactMode ? _thumbSizeCompact : _thumbSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compactMode) ...[
          Text(
            'ВЛОЖЕНИЯ',
            style: TextStyle(
                color: sc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: ts,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing thumbnails
              for (final att in attachments)
                _AttachmentThumb(
                  key: ValueKey(att.id),
                  attachment: att,
                  size: ts,
                  sc: sc,
                  canDelete: canEdit,
                  onTap: () => _openViewer(context, ref, sc, att),
                  onDelete: () => ref.read(planningProvider.notifier)
                      .deleteAttachment(goalId, nodeId, att.id),
                ),
              // Add button (editors only)
              if (canEdit) ...[
                if (attachments.isNotEmpty) const SizedBox(width: 8),
                _AddAttachmentButton(
                  size: ts,
                  sc: sc,
                  onTap: () => _showAddSheet(context, ref, sc),
                ),
              ],
              if (attachments.isEmpty && !canEdit)
                Center(
                  child: Text('Нет вложений',
                      style: TextStyle(color: sc.textSecondary, fontSize: 13)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openViewer(
      BuildContext context, WidgetRef ref, SieColors sc, NodeAttachment tapped) {
    final idx = attachments.indexOf(tapped);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _AttachmentViewer(
        attachments: attachments,
        initialIndex: idx,
        goalId: goalId,
        nodeId: nodeId,
        sc: sc,
        canDelete: canEdit,
        onDelete: (att) => ref.read(planningProvider.notifier)
            .deleteAttachment(goalId, nodeId, att.id),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, SieColors sc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddAttachmentSheet(
        goalId: goalId,
        nodeType: nodeType,
        nodeId: nodeId,
        sc: sc,
        onAdded: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ─── _AttachmentThumb ─────────────────────────────────────────────────────────

class _AttachmentThumb extends ConsumerStatefulWidget {
  const _AttachmentThumb({
    super.key,
    required this.attachment,
    required this.size,
    required this.sc,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });
  final NodeAttachment attachment;
  final double size;
  final SieColors sc;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  ConsumerState<_AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends ConsumerState<_AttachmentThumb> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    try {
      final url = await ref.read(planningProvider.notifier)
          .getSignedUrl(widget.attachment.storagePath);
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final att = widget.attachment;
    final s = widget.size;

    Widget content;
    if (att.localPath != null) {
      content = Image.file(File(att.localPath!), fit: BoxFit.cover,
          width: s, height: s);
    } else if (att.isImage && _signedUrl != null) {
      content = CachedNetworkImage(
        imageUrl: _signedUrl!,
        cacheKey: att.storagePath,
        fit: BoxFit.cover,
        width: s,
        height: s,
        placeholder: (_, __) => Container(
          color: sc.surface,
          width: s,
          height: s,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: sc.accent),
            ),
          ),
        ),
        errorWidget: (_, __, ___) =>
            _filePlaceholder(att, s, sc),
      );
    } else {
      content = _filePlaceholder(att, s, sc);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.canDelete
            ? () => _confirmDelete(context)
            : null,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: s,
                height: s,
                color: sc.surface,
                child: content,
              ),
            ),
            if (widget.canDelete)
              Positioned(
                top: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: sc.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 11, color: sc.background),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filePlaceholder(NodeAttachment att, double s, SieColors sc) {
    IconData icon;
    if (att.isPdf) {
      icon = Icons.picture_as_pdf_outlined;
    } else if (att.mimeType.contains('word') ||
        att.mimeType.contains('document')) {
      icon = Icons.description_outlined;
    } else if (att.mimeType.contains('zip') ||
        att.mimeType.contains('archive')) {
      icon = Icons.folder_zip_outlined;
    } else {
      icon = Icons.attach_file;
    }
    return Container(
      width: s,
      height: s,
      color: sc.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: sc.textSecondary, size: s * 0.38),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              att.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: sc.textSecondary, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: widget.sc.surface,
        title: Text('Удалить вложение?',
            style: TextStyle(color: widget.sc.textPrimary)),
        content: Text(widget.attachment.fileName,
            style: TextStyle(color: widget.sc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Отмена',
                style: TextStyle(color: widget.sc.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              widget.onDelete();
            },
            child: Text('Удалить',
                style: TextStyle(
                    color: widget.sc.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── _AddAttachmentButton ─────────────────────────────────────────────────────

class _AddAttachmentButton extends StatelessWidget {
  const _AddAttachmentButton(
      {required this.size, required this.sc, required this.onTap});
  final double size;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sc.border, width: 1.5),
          color: sc.surface,
        ),
        child: Icon(Icons.add, color: sc.textSecondary, size: size * 0.4),
      ),
    );
  }
}

// ─── _AddAttachmentSheet ──────────────────────────────────────────────────────

class _AddAttachmentSheet extends ConsumerStatefulWidget {
  const _AddAttachmentSheet({
    required this.goalId,
    required this.nodeType,
    required this.nodeId,
    required this.sc,
    required this.onAdded,
  });
  final String goalId;
  final String nodeType;
  final String nodeId;
  final SieColors sc;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddAttachmentSheet> createState() =>
      _AddAttachmentSheetState();
}

class _AddAttachmentSheetState extends ConsumerState<_AddAttachmentSheet> {
  bool _uploading = false;

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // close the sheet
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      await ref.read(planningProvider.notifier).addAttachment(
            goalId: widget.goalId,
            nodeType: widget.nodeType,
            nodeId: widget.nodeId,
            bytes: bytes,
            fileName: file.name,
            mimeType: mimeType,
          );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickFile() async {
    Navigator.pop(context);
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      final mimeType = _mimeFromExt(file.extension ?? '');
      await ref.read(planningProvider.notifier).addAttachment(
            goalId: widget.goalId,
            nodeType: widget.nodeType,
            nodeId: widget.nodeId,
            bytes: file.bytes!,
            fileName: file.name,
            mimeType: mimeType,
          );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          if (_uploading) ...[
            const SizedBox(height: 16),
            CircularProgressIndicator(color: c.accent),
            const SizedBox(height: 16),
            Text('Загрузка…',
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
          ] else ...[
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Галерея',
              sc: c,
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Камера',
              sc: c,
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _SheetOption(
              icon: Icons.attach_file,
              label: 'Файл',
              sc: c,
              onTap: _pickFile,
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption(
      {required this.icon,
      required this.label,
      required this.sc,
      required this.onTap});
  final IconData icon;
  final String label;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sc.border),
          color: sc.surface,
        ),
        child: Row(
          children: [
            Icon(icon, color: sc.accent, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── _AttachmentViewer ────────────────────────────────────────────────────────

class _AttachmentViewer extends ConsumerStatefulWidget {
  const _AttachmentViewer({
    required this.attachments,
    required this.initialIndex,
    required this.goalId,
    required this.nodeId,
    required this.sc,
    required this.canDelete,
    required this.onDelete,
  });
  final List<NodeAttachment> attachments;
  final int initialIndex;
  final String goalId;
  final String nodeId;
  final SieColors sc;
  final bool canDelete;
  final ValueChanged<NodeAttachment> onDelete;

  @override
  ConsumerState<_AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends ConsumerState<_AttachmentViewer> {
  late final PageController _pc;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pc = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    final att = widget.attachments[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.attachments.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => _AttachmentPage(
              attachment: widget.attachments[i],
              sc: c,
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
          // File name
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  att.fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (widget.canDelete) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDelete(att);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Удалить',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Page indicator
          if (widget.attachments.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.attachments.length}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentPage extends ConsumerStatefulWidget {
  const _AttachmentPage({required this.attachment, required this.sc});
  final NodeAttachment attachment;
  final SieColors sc;

  @override
  ConsumerState<_AttachmentPage> createState() => _AttachmentPageState();
}

class _AttachmentPageState extends ConsumerState<_AttachmentPage> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final url = await ref.read(planningProvider.notifier)
          .getSignedUrl(widget.attachment.storagePath);
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachment;
    if (att.localPath != null) {
      return InteractiveViewer(
        child: Center(child: Image.file(File(att.localPath!))),
      );
    }
    if (att.isImage && _signedUrl != null) {
      return InteractiveViewer(
        child: Center(
          child: CachedNetworkImage(
            imageUrl: _signedUrl!,
            cacheKey: att.storagePath,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
          ),
        ),
      );
    }
    // Non-image or pending sign
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.attach_file, color: Colors.white54, size: 56),
          const SizedBox(height: 12),
          Text(att.fileName,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          if (!att.isImage)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Превью недоступно',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
