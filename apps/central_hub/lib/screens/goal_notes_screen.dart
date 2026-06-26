import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

// ─── Date helpers ─────────────────────────────────────────────────────────────

String _relativeDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return t.goalNotes.date.justNow;
  if (diff.inMinutes < 60) return t.goalNotes.date.minutesAgo(n: diff.inMinutes);
  final time = '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
  if (diff.inHours < 24 && now.day == d.day) {
    return t.goalNotes.date.today(time: time);
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (d.day == yesterday.day && d.month == yesterday.month && d.year == yesterday.year) {
    return t.goalNotes.date.yesterday(time: time);
  }
  return '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class GoalNotesScreen extends ConsumerWidget {
  const GoalNotesScreen({
    super.key,
    required this.goal,
    this.canEdit = true,
  });

  final Goal goal;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final notesAsync = ref.watch(goalNotesProvider(goal.id));

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: canEdit
            ? FloatingActionButton(
                onPressed: () => _openEditor(context, ref),
                backgroundColor: sc.accent,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _NotesHeader(goal: goal, sc: sc),
              Expanded(
                child: notesAsync.when(
                  loading: () => Center(
                      child: CircularProgressIndicator(color: sc.accent)),
                  error: (_, __) => _EmptyState(
                    sc: sc,
                    icon: Icons.cloud_off_outlined,
                    text: t.goalNotes.list.loadError,
                  ),
                  data: (notes) {
                    if (notes.isEmpty) {
                      return _EmptyState(
                        sc: sc,
                        icon: Icons.sticky_note_2_outlined,
                        text: canEdit
                            ? t.goalNotes.list.emptyEditable
                            : t.goalNotes.list.empty,
                      );
                    }
                    return RefreshIndicator(
                      color: sc.accent,
                      backgroundColor:
                          sc.isLightMode ? Colors.white : sc.surface,
                      onRefresh: () async {
                        ref.invalidate(goalNotesProvider(goal.id));
                        await ref.read(goalNotesProvider(goal.id).future);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _NoteCard(
                          note: notes[i],
                          sc: sc,
                          accent: goal.color,
                          onTap: canEdit
                              ? () => _openEditor(context, ref, note: notes[i])
                              : null,
                          onDelete: canEdit
                              ? () => _confirmDelete(context, ref, notes[i])
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, {GoalNote? note}) {
    final sc = ref.read(sieColorsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NoteEditorSheet(goalId: goal.id, note: note, sc: sc),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, GoalNote note) async {
    final sc = ref.read(sieColorsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: sc.surface,
        title: Text(t.goalNotes.delete.title,
            style: TextStyle(color: sc.textPrimary, fontSize: 17)),
        content: Text(
          t.goalNotes.delete.message,
          style: TextStyle(color: sc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.goalNotes.delete.cancel,
                style: TextStyle(color: sc.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.goalNotes.delete.confirm,
                style: TextStyle(color: sc.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(goalNotesProvider(note.goalId).notifier).deleteNote(note.id);
    }
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _NotesHeader extends StatelessWidget {
  const _NotesHeader({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: sc.surface,
        border: Border(bottom: BorderSide(color: sc.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: sc.textPrimary, size: 22),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: goal.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.goalNotes.header.title,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  goal.name,
                  style: TextStyle(color: sc.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.menu_book_outlined, size: 18, color: sc.textSecondary),
        ],
      ),
    );
  }
}

// ─── Note card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.sc,
    required this.accent,
    this.onTap,
    this.onDelete,
  });

  final GoalNote note;
  final SieColors sc;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: sc.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: accent.withValues(alpha: 0.7), width: 3),
              top: BorderSide(color: sc.border),
              right: BorderSide(color: sc.border),
              bottom: BorderSide(color: sc.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.hasTitle) ...[
                      Text(
                        note.title!,
                        style: TextStyle(
                          color: sc.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (note.body.isNotEmpty) const SizedBox(height: 4),
                    ],
                    if (note.body.isNotEmpty)
                      Text(
                        note.body,
                        style: TextStyle(
                          color: note.hasTitle ? sc.textSecondary : sc.textPrimary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _relativeDate(note.updatedAt),
                      style: TextStyle(color: sc.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 19, color: sc.textSecondary),
                  onPressed: onDelete,
                  tooltip: t.goalNotes.card.deleteTooltip,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.sc, required this.icon, required this.text});

  final SieColors sc;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: sc.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: sc.textSecondary, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Editor sheet ─────────────────────────────────────────────────────────────

class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({required this.goalId, required this.sc, this.note});

  final String goalId;
  final GoalNote? note;
  final SieColors sc;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.body ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _bodyCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    // Need at least a title or a body to make a note.
    if (body.isEmpty && title.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(goalNotesProvider(widget.goalId).notifier);
    if (widget.note == null) {
      await notifier.addNote(title: title, body: body);
    } else {
      await notifier.updateNote(widget.note!.id, title: title, body: body);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.note != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? t.goalNotes.editor.titleEdit : t.goalNotes.editor.titleNew,
              style: TextStyle(
                color: sc.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: t.goalNotes.editor.titleHint,
                hintStyle: TextStyle(color: sc.textSecondary, fontSize: 16),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: sc.border)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: sc.accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              autofocus: true,
              minLines: 3,
              maxLines: 10,
              style: TextStyle(color: sc.textPrimary, fontSize: 15, height: 1.4),
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: t.goalNotes.editor.bodyHint,
                hintStyle: TextStyle(color: sc.textSecondary, fontSize: 15),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: sc.border)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: sc.accent)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: sc.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEdit ? t.goalNotes.editor.save : t.goalNotes.editor.add,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
