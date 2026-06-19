import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sie_core/sie_core.dart';
import '../widgets/attachment_gallery.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

class TacticalMapView extends ConsumerStatefulWidget {
  const TacticalMapView({super.key, required this.goal, this.canEdit = true});
  final Goal goal;
  final bool canEdit;

  @override
  ConsumerState<TacticalMapView> createState() => _TacticalMapViewState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _TacticalMapViewState extends ConsumerState<TacticalMapView>
    with TickerProviderStateMixin {
  final Map<String, Offset> _positions = {};
  final _tc = TransformationController();
  String? _draggingId;
  String? _hoverTargetId;
  late AnimationController _hoverAnim;
  Timer? _saveTimer;
  final Set<String> _scoutedMapIds = {};

  // ── Tactical Map Evolution Stage 1: map-native elements ───────────────────
  // Live positions for map elements (notes/labels). Seeded from the model and
  // mutated during drag without setState (same pattern as node `_positions`).
  final Map<String, Offset> _elementPositions = {};
  // Live note sizes (dx=w, dy=h), mutated during resize without setState.
  final Map<String, Offset> _elementSizes = {};
  // Active edit-mode tool. `none` = view/select; the rest place new elements.
  _MapTool _tool = _MapTool.none;
  bool _editMode = false;
  // Element whose text is currently being edited inline.
  String? _editingElementId;
  final _elementTextCtrl = TextEditingController();
  Timer? _elementSaveTimer;

  // ── Tactical Map Evolution Stage 4: connectors ───────────────────────────
  // Connector source ref while picking the second endpoint.
  String? _connectorFromRef;

  // ── Stage 5: member filter ────────────────────────────────────────────────
  // When non-null, nodes NOT assigned to this userId are dimmed.
  String? _filterMemberId;

  // ── Stage 8: live collaborative canvas ────────────────────────────────────
  GoalMapLiveService? _live;
  // userId → interpolated remote cursor (logical coords).
  final Map<String, _RemoteCursor> _remoteCursors = {};
  // nodeRef ('node:id'|'el:id') → who is editing + when.
  final Map<String, ({String userId, int atMs})> _editingByNode = {};
  // Latest goal snapshot, so live callbacks can walk the tree off-build.
  Goal? _liveGoal;
  // Per-user identity for cursors/badges (color + display name).
  Map<String, ({Color color, String name})> _memberInfo = const {};
  String? _followUserId;
  Timer? _liveTicker;
  final _liveRepaint = ValueNotifier<int>(0);

  // ── Stage 7: navigation & power tools ─────────────────────────────────────
  bool _mapLocked = false; // from GoalSettings.mapLocked (drag disabled)
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _showMiniMap = true;
  // Smooth camera animation (zoom-to-fit, search jump, minimap tap).
  late final AnimationController _camAnim;
  Animation<Matrix4>? _camTween;
  // Animated re-layout ("Прибраться").
  late final AnimationController _layoutAnim;
  Map<String, Offset>? _layoutFrom;
  Map<String, Offset>? _layoutTo;

  // ── Tactical Map Evolution Stage 3: image cards ───────────────────────────
  // Guard against re-entrant image picker / dialog launches.
  bool _pickingImage = false;

  static const _noteColors = <String>[
    '#C8A84B', '#5AADA0', '#6A8ED8', '#C05080', '#70B870', '#E07830',
  ];

  // Flattened sub-goal list for the current goal, recomputed once per build.
  // Safe to reuse across drag handlers because the goal tree structure does not
  // change during a drag (only positions move).
  List<SubGoal> _flat = const [];
  // Set during build() so _setHoverTarget (called from gesture callbacks) can
  // check whether looping animations are allowed.
  bool _motionEnabled = true;

  // Ticked on every position/hover change during a drag. The dynamic layer
  // (edges + nodes) listens to this, so dragging repaints ONLY that subtree —
  // the root build() (InteractiveViewer, provider .select, grid) is not called.
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  void _bumpRepaint() => _repaint.value++;

  static const double _cx = 2400.0;
  static const double _cs = 4800.0;

  Goal get _goal => widget.goal;

  @override
  void initState() {
    super.initState();
    _hoverAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Stage 7: camera + layout animations.
    _camAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        final tw = _camTween;
        if (tw != null) _tc.value = tw.value;
      });
    _layoutAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(_onLayoutTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerView());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _elementSaveTimer?.cancel();
    _liveTicker?.cancel();
    _live?.dispose();
    _liveRepaint.dispose();
    _elementTextCtrl.dispose();
    _searchCtrl.dispose();
    _camAnim.dispose();
    _layoutAnim.dispose();
    _hoverAnim.dispose();
    _tc.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _centerView() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final s = box.size;
    _tc.value = Matrix4.translationValues(s.width / 2 - _cx, s.height / 2 - _cx, 0);
  }

  // ── Stage 8: live collaboration ───────────────────────────────────────────

  /// Connects the broadcast channel once, only for goals shared with at least
  /// one accepted collaborator. Idempotent.
  void _maybeInitLive(Goal goal) {
    if (_live != null) return;
    final hasCollabs =
        goal.collaborators.any((co) => co.status == 'accepted');
    if (!hasCollabs) return;
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;
    final svc = GoalMapLiveService(goalId: goal.id, userId: uid);
    svc.onCursor = _onRemoteCursor;
    svc.onNodeMove = _onRemoteNodeMove;
    svc.onEditing = _onRemoteEditing;
    svc.connect();
    _live = svc;
  }

  void _onRemoteCursor(LiveCursor c) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _remoteCursors[c.userId];
    if (existing == null) {
      _remoteCursors[c.userId] = _RemoteCursor(c.x, c.y)..lastSeenMs = now;
      // New live participant → refresh the legend (follow button, dot).
      if (mounted) setState(() {});
    } else {
      existing.targetX = c.x;
      existing.targetY = c.y;
      existing.lastSeenMs = now;
    }
    _ensureLiveTicker();
  }

  void _onRemoteNodeMove(LiveNodeMove m) {
    final ref = m.nodeId;
    final newPos = Offset(m.x, m.y);
    if (ref.startsWith('el:')) {
      _elementPositions[ref.substring(3)] = newPos;
      _bumpRepaint();
      return;
    }
    if (!ref.startsWith('node:')) return;
    final id = ref.substring(5);
    if (_draggingId == id) return; // don't fight a local drag
    final old = _positions[id];
    _positions[id] = newPos;
    // If it's a sub-goal, shift its whole family by the same delta so the
    // hierarchy stays visually attached during the remote drag.
    if (old != null) {
      final delta = newPos - old;
      final sg = _findSubGoalById(_liveGoal?.subGoals ?? const [], id);
      if (sg != null) _shiftFamily(sg, delta);
    }
    _bumpRepaint();
  }

  void _onRemoteEditing(LiveEditing e) {
    if (e.active) {
      _editingByNode[e.nodeId] =
          (userId: e.userId, atMs: DateTime.now().millisecondsSinceEpoch);
    } else {
      _editingByNode.remove(e.nodeId);
    }
    _ensureLiveTicker();
    _liveRepaint.value++;
  }

  SubGoal? _findSubGoalById(List<SubGoal> roots, String id) {
    for (final sg in roots) {
      if (sg.id == id) return sg;
      final found = _findSubGoalById(sg.children, id);
      if (found != null) return found;
    }
    return null;
  }

  void _shiftFamily(SubGoal sg, Offset delta) {
    for (final t in sg.tasks) {
      final p = _positions[t.id];
      if (p != null) _positions[t.id] = p + delta;
    }
    for (final child in sg.children) {
      final p = _positions[child.id];
      if (p != null) _positions[child.id] = p + delta;
      _shiftFamily(child, delta);
    }
  }

  /// Converts a viewport-local pointer position to logical (centre-relative)
  /// coordinates and broadcasts it as this user's cursor.
  void _emitCursor(Offset viewportLocal) {
    final svc = _live;
    if (svc == null) return;
    final scene = _tc.toScene(viewportLocal);
    svc.sendCursor(scene.dx - _cx, scene.dy - _cx);
  }

  void _emitNodeMove(String ref, Offset logical) {
    _live?.sendNodeMove(ref, logical.dx, logical.dy);
  }

  void _emitEditing(String ref, bool active) {
    _live?.sendEditing(ref, active);
  }

  /// Single shared ticker (~30 fps) that interpolates remote cursors toward
  /// their targets, expires stale cursors/edit-flags, and drives follow-mode.
  /// Stops itself when there is nothing live to animate (saves CPU).
  void _ensureLiveTicker() {
    _liveTicker ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Expire cursors not seen in 4s.
      final beforeCount = _remoteCursors.length;
      _remoteCursors.removeWhere((_, c) => now - c.lastSeenMs > 4000);
      if (_remoteCursors.length != beforeCount && mounted) {
        // A participant went idle → refresh the legend (drop their dot/follow).
        setState(() {});
        if (_followUserId != null &&
            !_remoteCursors.containsKey(_followUserId)) {
          _followUserId = null;
        }
      }
      // Expire editing flags after 15s (covers ungraceful disconnects).
      _editingByNode.removeWhere((_, e) => now - e.atMs > 15000);
      // Interpolate toward targets.
      for (final c in _remoteCursors.values) {
        c.x += (c.targetX - c.x) * 0.35;
        c.y += (c.targetY - c.y) * 0.35;
      }
      // Follow mode: ease the camera so the followed cursor stays centred.
      if (_followUserId != null) {
        final c = _remoteCursors[_followUserId];
        if (c != null) _followCamera(Offset(_cx + c.x, _cx + c.y));
      }
      _liveRepaint.value++;
      if (_remoteCursors.isEmpty &&
          _editingByNode.isEmpty &&
          _followUserId == null) {
        _liveTicker?.cancel();
        _liveTicker = null;
      }
    });
  }

  /// Eases the InteractiveViewer so [scenePoint] sits at the viewport centre.
  void _followCamera(Offset scenePoint) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final s = box.size;
    final scale = _tc.value.getMaxScaleOnAxis();
    // Target translation that centres scenePoint.
    final targetTx = s.width / 2 - scenePoint.dx * scale;
    final targetTy = s.height / 2 - scenePoint.dy * scale;
    final m = _tc.value.clone();
    final curTx = m.getTranslation().x;
    final curTy = m.getTranslation().y;
    final nextTx = curTx + (targetTx - curTx) * 0.12;
    final nextTy = curTy + (targetTy - curTy) * 0.12;
    m.setTranslationRaw(nextTx, nextTy, 0);
    _tc.value = m;
  }

  void _toggleFollow(String userId) {
    setState(() {
      _followUserId = _followUserId == userId ? null : userId;
    });
    if (_followUserId != null) _ensureLiveTicker();
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  void _ensureSubGoalPositions(SubGoal sg, Map<String, Offset> saved) {
    final children = sg.children;
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      if (!_positions.containsKey(child.id)) {
        final sgPos = _positions[sg.id]!;
        final base = math.atan2(sgPos.dy, sgPos.dx) + math.pi / 2;
        const spread = math.pi * 0.7;
        final angle = children.length <= 1
            ? base
            : base + (-spread / 2 + spread * i / (children.length - 1));
        _positions[child.id] = saved[child.id] ??
            sgPos + Offset(160 * math.cos(angle), 160 * math.sin(angle));
      }
      _ensureSubGoalPositions(child, saved);
    }
    final tasks = sg.tasks;
    for (int j = 0; j < tasks.length; j++) {
      final t = tasks[j];
      if (!_positions.containsKey(t.id)) {
        final sgPos = _positions[sg.id]!;
        final base = math.atan2(sgPos.dy, sgPos.dx);
        const spread = math.pi * 0.8;
        final ta = tasks.length <= 1
            ? base
            : base + (-spread / 2 + spread * j / (tasks.length - 1));
        _positions[t.id] = saved[t.id] ??
            sgPos + Offset(145 * math.cos(ta), 145 * math.sin(ta));
      }
    }
  }

  void _ensurePositions(Goal goal, {bool forceRadial = false}) {
    _positions[goal.id] = Offset.zero;
    // Stage 7: "Прибраться" wipes node positions (elements untouched) and
    // recomputes the radial layout from scratch, ignoring saved positions.
    if (forceRadial) {
      _positions.removeWhere((k, _) => k != goal.id);
    }
    final saved = forceRadial ? const <String, Offset>{} : goal.mapPositions;

    final sgs = goal.subGoals;
    final useRadialLayout = (forceRadial || saved.isEmpty) && sgs.isNotEmpty;

    if (useRadialLayout) {
      // Only compute layout once — don't overwrite positions already set by drag
      if (sgs.any((sg) => !_positions.containsKey(sg.id))) {
        const rootRadius = 380.0;
        final total = sgs.fold(0, (s, sg) => s + _subtreeSize(sg));
        double cursor = -math.pi / 2;
        for (final sg in sgs) {
          final share = 2 * math.pi * _subtreeSize(sg) / total;
          final angle = cursor + share / 2;
          if (!_positions.containsKey(sg.id)) {
            _positions[sg.id] = Offset(rootRadius * math.cos(angle), rootRadius * math.sin(angle));
          }
          _layoutSubGoalRadial(sg, cursor, cursor + share, 0);
          cursor += share;
        }
      }
    } else {
      for (int i = 0; i < sgs.length; i++) {
        final sg = sgs[i];
        if (!_positions.containsKey(sg.id)) {
          final angle =
              (2 * math.pi * i / math.max(sgs.length, 1)) - math.pi / 2;
          _positions[sg.id] = saved[sg.id] ??
              Offset(240 * math.cos(angle), 240 * math.sin(angle));
        }
        _ensureSubGoalPositions(sg, saved);
      }
    }

    final mss = goal.milestones;
    final msRadius = useRadialLayout ? 580.0 : 200.0;
    for (int i = 0; i < mss.length; i++) {
      if (!_positions.containsKey(mss[i].id)) {
        final angle =
            (2 * math.pi * i / math.max(mss.length, 1)) + math.pi / 4;
        _positions[mss[i].id] = saved[mss[i].id] ??
            Offset(msRadius * math.cos(angle), msRadius * math.sin(angle));
      }
    }

    final links = goal.habitLinks;
    final lkRadius = useRadialLayout ? 520.0 : 320.0;
    for (int i = 0; i < links.length; i++) {
      if (!_positions.containsKey(links[i].id)) {
        final angle =
            (2 * math.pi * i / math.max(links.length, 1)) + math.pi / 6;
        _positions[links[i].id] = saved[links[i].id] ??
            Offset(lkRadius * math.cos(angle), lkRadius * math.sin(angle));
      }
    }

    final allSgs = _flat;
    final all = {
      goal.id,
      ...allSgs.map((sg) => sg.id),
      ...allSgs.expand((sg) => sg.tasks).map((t) => t.id),
      ...goal.milestones.map((m) => m.id),
      ...goal.habitLinks.map((l) => l.id),
    };
    _positions.removeWhere((k, _) => !all.contains(k));
  }

  void _scheduleSave(Goal goal) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(planningProvider.notifier).saveMapPositions(goal.id, Map.of(_positions));
    });
  }

  // ── Map elements (Stage 1) ──────────────────────────────────────────────

  void _scheduleSaveElement(Goal goal, String elementId) {
    _elementSaveTimer?.cancel();
    final pos = _elementPositions[elementId];
    if (pos == null) return;
    _elementSaveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref
          .read(planningProvider.notifier)
          .saveMapElementPosition(goal.id, elementId, pos);
    });
  }

  /// Converts a tap inside the canvas (already in 0.._cs space) into logical
  /// coordinates (relative to goal centre) and creates the active element.
  Future<void> _createElementAt(Offset canvasLocal, Goal goal) async {
    final kind = switch (_tool) {
      _MapTool.note => MapElementKind.note,
      _MapTool.label => MapElementKind.label,
      _MapTool.image ||
      _MapTool.connector ||
      _MapTool.none =>
        null,
    };
    if (kind == null) return;
    setState(() => _tool = _MapTool.none); // auto-return to select
    final logical = Offset(canvasLocal.dx - _cx, canvasLocal.dy - _cx);
    final isNote = kind == MapElementKind.note;
    HapticFeedback.lightImpact();
    final id = await ref.read(planningProvider.notifier).addMapElement(
          goalId: goal.id,
          kind: kind,
          x: logical.dx,
          y: logical.dy,
          w: isNote ? 140 : null,
          h: isNote ? 100 : null,
          colorHex: isNote ? _noteColors.first : null,
          content: '',
        );
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Достигнут лимит элементов на карте')));
      }
      return;
    }
    _elementPositions[id] = logical;
    _beginEditElement(id, '');
  }

  // ── Map groups/connectors (Stage 4) ──────────────────────────────────────

  /// Handles a tap on an object while the connector tool is armed. First tap
  /// sets the source ref; second tap creates the connector. `ref` is prefixed
  /// `node:<id>` for plan nodes or `el:<id>` for map elements.
  void _handleConnectorEndpoint(String endRef, Goal goal) {
    if (_connectorFromRef == null) {
      setState(() => _connectorFromRef = endRef);
      HapticFeedback.selectionClick();
      return;
    }
    if (_connectorFromRef == endRef) {
      // Tapping the source again cancels (no self-loops — open question #1).
      setState(() => _connectorFromRef = null);
      return;
    }
    final from = _connectorFromRef!;
    setState(() {
      _connectorFromRef = null;
      _tool = _MapTool.none;
    });
    HapticFeedback.lightImpact();
    ref.read(planningProvider.notifier).addMapElement(
          goalId: goal.id,
          kind: MapElementKind.connector,
          x: 0,
          y: 0,
          fromRef: from,
          toRef: endRef,
          styleJson: const {'dashed': false, 'arrow': 'end'},
        );
  }

  void _showConnectorActions(Goal goal, MapElement el, SieColors c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConnectorActionsSheet(
        element: el,
        sc: c,
        colors: _noteColors,
        onPickColor: (hex) {
          Navigator.pop(context);
          final style = Map<String, dynamic>.from(el.styleJson ?? const {});
          style['color'] = hex;
          ref
              .read(planningProvider.notifier)
              .updateMapElement(goal.id, el.id, styleJson: style);
        },
        onToggleDash: () {
          Navigator.pop(context);
          final style = Map<String, dynamic>.from(el.styleJson ?? const {});
          style['dashed'] = !(style['dashed'] == true);
          ref
              .read(planningProvider.notifier)
              .updateMapElement(goal.id, el.id, styleJson: style);
        },
        onEditLabel: (label) {
          Navigator.pop(context);
          ref
              .read(planningProvider.notifier)
              .updateMapElement(goal.id, el.id, content: label);
        },
        onDelete: () {
          Navigator.pop(context);
          ref.read(planningProvider.notifier).deleteMapElement(goal.id, el.id);
        },
      ),
    );
  }

  // ── Image cards (Stage 3) ─────────────────────────────────────────────────

  /// Returns the logical canvas centre of the current viewport so newly
  /// placed image cards land in a visible area.
  Offset _logicalViewCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return const Offset(80, 80);
    final size = box.size;
    final screenCenter = Offset(size.width / 2, size.height / 2);
    try {
      final inv = Matrix4.inverted(_tc.value);
      final canvas = MatrixUtils.transformPoint(inv, screenCenter);
      return Offset(canvas.dx - _cx, canvas.dy - _cx);
    } catch (_) {
      return const Offset(80, 80);
    }
  }

  /// Shows the source-selection sheet: Gallery or URL.
  void _showImageSourceMenu(Goal goal, SieColors c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            _ActionBtn(
              label: 'Выбрать из галереи',
              icon: Icons.photo_library_outlined,
              color: c.accent,
              sc: c,
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery(goal, c);
              },
            ),
            const SizedBox(height: 10),
            _ActionBtn(
              label: 'Вставить ссылку / URL',
              icon: Icons.link,
              color: c.accentSecondary,
              sc: c,
              onTap: () {
                Navigator.pop(context);
                _showUrlPasteDialog(goal, c);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Picks an image from the gallery, shows a preview with rotate options,
  /// uploads to goal-media, and places the card on the canvas.
  Future<void> _pickImageFromGallery(Goal goal, SieColors c) async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final confirmed = await _showImagePreviewDialog(bytes, c);
      if (confirmed == null || !mounted) return;
      _uploadAndPlaceImage(
          goal: goal,
          bytes: confirmed.bytes,
          quarterTurns: confirmed.quarterTurns,
          origW: confirmed.origW,
          origH: confirmed.origH,
          ext: 'jpg');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  /// Shows a text field for pasting a public image URL (no upload needed).
  void _showUrlPasteDialog(Goal goal, SieColors c) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.border)),
        title: Text('URL изображения',
            style: TextStyle(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'https://example.com/image.jpg',
            hintStyle: TextStyle(color: c.textSecondary),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Отмена',
                style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final url = ctrl.text.trim();
              Navigator.pop(dctx);
              if (url.startsWith('http')) {
                _placeImageCardFromUrl(goal: goal, mediaUrl: url);
              }
            },
            child: Text('Добавить',
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Shows a fullscreen preview with rotate CW/CCW before uploading.
  /// Returns the confirmed bytes + rotation, or null if cancelled.
  Future<({Uint8List bytes, int quarterTurns, double origW, double origH})?>
      _showImagePreviewDialog(Uint8List bytes, SieColors c) async {
    // Decode to get natural dimensions.
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final origW = frame.image.width.toDouble();
    final origH = frame.image.height.toDouble();
    frame.image.dispose();

    if (!mounted) return null;
    return showDialog<({Uint8List bytes, int quarterTurns, double origW, double origH})>(
      context: context,
      builder: (dctx) => _ImagePreviewDialog(
        bytes: bytes,
        origW: origW,
        origH: origH,
        sc: c,
      ),
    );
  }

  /// Uploads bytes to Storage then places the image card at the viewport centre.
  Future<void> _uploadAndPlaceImage({
    required Goal goal,
    required Uint8List bytes,
    required int quarterTurns,
    required double origW,
    required double origH,
    String ext = 'jpg',
  }) async {
    final url = await ref.read(planningProvider.notifier)
        .uploadMapImage(goal.id, bytes, ext: ext);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки изображения')));
      }
      return;
    }
    await _placeImageCardFromUrl(
        goal: goal, mediaUrl: url,
        quarterTurns: quarterTurns, origW: origW, origH: origH);
  }

  /// Creates an image card element using a (possibly remote) URL.
  Future<void> _placeImageCardFromUrl({
    required Goal goal,
    required String mediaUrl,
    int quarterTurns = 0,
    double origW = 400,
    double origH = 300,
  }) async {
    // Swap dimensions when rotated 90°/270° so the canvas box matches the
    // physical rotation.
    final swapped = quarterTurns % 2 == 1;
    final displayW = swapped ? origH : origW;
    final displayH = swapped ? origW : origH;
    final maxSide = math.max(displayW, displayH);
    const target = 220.0;
    final scale = target / math.max(maxSide, 1.0);
    final cardW = (displayW * scale).clamp(80.0, 480.0);
    final cardH = (displayH * scale).clamp(60.0, 480.0);
    final logical = _logicalViewCenter();

    final id = await ref.read(planningProvider.notifier).addMapElement(
          goalId: goal.id,
          kind: MapElementKind.image,
          x: logical.dx,
          y: logical.dy,
          w: cardW,
          h: cardH,
          mediaUrl: mediaUrl,
          styleJson: {'rotation': quarterTurns},
        );
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Достигнут лимит элементов на карте')));
      }
      return;
    }
    _elementPositions[id] = logical;
    _elementSizes[id] = Offset(cardW, cardH);
    _bumpRepaint();
  }

  Widget _imageCardWidget(MapElement el, Goal goal, SieColors c) {
    final pos = _elementPositions[el.id] ?? el.position;
    final size = _elementSizes[el.id] ?? Offset(el.w ?? 200, el.h ?? 150);
    final w = size.dx;
    final h = size.dy;
    final quarterTurns = (el.styleJson?['rotation'] as int?) ?? 0;

    return Positioned(
      key: ValueKey('img-${el.id}'),
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: widget.canEdit
            ? () {
                HapticFeedback.mediumImpact();
                _showImageCardActions(goal, el, c);
              }
            : null,
        onPanStart: (!widget.canEdit || _mapLocked)
            ? null
            : (_) {
                HapticFeedback.lightImpact();
                setState(() => _draggingId = el.id);
              },
        onPanUpdate: (!widget.canEdit || _mapLocked)
            ? null
            : (d) {
                final scale = _tc.value.getMaxScaleOnAxis();
                _elementPositions[el.id] =
                    (_elementPositions[el.id] ?? el.position) + d.delta / scale;
                _bumpRepaint();
                _emitNodeMove('el:${el.id}', _elementPositions[el.id]!);
              },
        onPanEnd: (!widget.canEdit || _mapLocked)
            ? null
            : (_) {
                HapticFeedback.lightImpact();
                _scheduleSaveElement(goal, el.id);
                setState(() => _draggingId = null);
              },
        child: _ImageCardElement(
          element: el,
          quarterTurns: quarterTurns,
          sc: c,
          canEdit: widget.canEdit,
          onResize: (!widget.canEdit || _mapLocked)
              ? null
              : (delta) {
                  final scale = _tc.value.getMaxScaleOnAxis();
                  final cur = _elementSizes[el.id] ??
                      Offset(el.w ?? 200, el.h ?? 150);
                  // Maintain aspect ratio via the longer axis.
                  final aspect = cur.dx / math.max(cur.dy, 1.0);
                  final dw = delta.dx / scale;
                  _elementSizes[el.id] = Offset(
                    (cur.dx + dw).clamp(60.0, 600.0),
                    ((cur.dx + dw) / aspect).clamp(45.0, 600.0),
                  );
                  _bumpRepaint();
                },
          onResizeEnd: () {
            final s = _elementSizes[el.id];
            if (s != null) {
              ref
                  .read(planningProvider.notifier)
                  .updateMapElement(goal.id, el.id, w: s.dx, h: s.dy);
            }
          },
        ),
      ),
    );
  }

  void _showImageCardActions(Goal goal, MapElement el, SieColors c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ImageCardActionsSheet(
        element: el,
        sc: c,
        onEditCaption: (caption) {
          Navigator.pop(context);
          ref.read(planningProvider.notifier)
              .updateMapElement(goal.id, el.id, content: caption);
        },
        onDelete: () {
          Navigator.pop(context);
          _elementPositions.remove(el.id);
          _elementSizes.remove(el.id);
          ref.read(planningProvider.notifier).deleteMapElement(goal.id, el.id);
        },
      ),
    );
  }

  void _beginEditElement(String id, String text) {
    setState(() {
      _editingElementId = id;
      _elementTextCtrl.text = text;
      _elementTextCtrl.selection =
          TextSelection.collapsed(offset: text.length);
    });
    _emitEditing('el:$id', true); // Stage 8: soft-lock broadcast
  }

  void _commitElementText(Goal goal, String id) {
    final text = _elementTextCtrl.text.trim();
    final wasEditing = _editingElementId == id;
    if (!wasEditing) return;
    setState(() => _editingElementId = null);
    _emitEditing('el:$id', false); // Stage 8: release soft-lock
    final el = goal.mapElements.where((e) => e.id == id).firstOrNull;
    if (el == null) return;
    // Empty note/label → discard (no orphan placeholders).
    if (text.isEmpty && (el.content ?? '').isEmpty) {
      ref.read(planningProvider.notifier).deleteMapElement(goal.id, id);
      return;
    }
    if (text != (el.content ?? '')) {
      ref
          .read(planningProvider.notifier)
          .updateMapElement(goal.id, id, content: text);
    }
  }

  void _showElementActions(Goal goal, MapElement el, SieColors c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ElementActionsSheet(
        element: el,
        sc: c,
        colors: _noteColors,
        onPickColor: (hex) {
          Navigator.pop(context);
          ref
              .read(planningProvider.notifier)
              .updateMapElement(goal.id, el.id, colorHex: hex);
        },
        onEditText: () {
          Navigator.pop(context);
          _beginEditElement(el.id, el.content ?? '');
        },
        onDelete: () {
          Navigator.pop(context);
          _elementPositions.remove(el.id);
          _elementSizes.remove(el.id);
          ref.read(planningProvider.notifier).deleteMapElement(goal.id, el.id);
        },
      ),
    );
  }

  static Color? _hexColor(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceAll('#', '');
    final v = int.tryParse('FF$h', radix: 16);
    return v == null ? null : Color(v);
  }

  Widget _elementPosNode(MapElement el, Goal goal, SieColors c) {
    final pos = _elementPositions[el.id] ?? el.position;
    final editing = _editingElementId == el.id;
    final isNote = el.kind == MapElementKind.note;
    final size = _elementSizes[el.id] ?? Offset(el.w ?? 140, el.h ?? 100);
    final w = isNote ? size.dx : 170.0;
    final h = isNote ? size.dy : 46.0;
    final color = _hexColor(el.colorHex) ?? c.accent;

    final Widget content = isNote
        ? _NoteElement(
            element: el,
            color: color,
            sc: c,
            editing: editing,
            controller: editing ? _elementTextCtrl : null,
            canEdit: widget.canEdit,
            onSubmit: () => _commitElementText(goal, el.id),
            onResize: (!widget.canEdit || editing || _mapLocked)
                ? null
                : (delta) {
                    final scale = _tc.value.getMaxScaleOnAxis();
                    final cur = _elementSizes[el.id] ??
                        Offset(el.w ?? 140, el.h ?? 100);
                    _elementSizes[el.id] = Offset(
                      (cur.dx + delta.dx / scale).clamp(90.0, 460.0),
                      (cur.dy + delta.dy / scale).clamp(64.0, 460.0),
                    );
                    _bumpRepaint();
                  },
            onResizeEnd: () {
              final s = _elementSizes[el.id];
              if (s != null) {
                ref
                    .read(planningProvider.notifier)
                    .updateMapElement(goal.id, el.id, w: s.dx, h: s.dy);
              }
            },
          )
        : _LabelElement(
            element: el,
            color: color,
            sc: c,
            editing: editing,
            controller: editing ? _elementTextCtrl : null,
            onSubmit: () => _commitElementText(goal, el.id),
          );

    Widget node = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editing
          ? null
          : () {
              if (_tool == _MapTool.connector && widget.canEdit) {
                _handleConnectorEndpoint('el:${el.id}', goal);
                return;
              }
              if (!widget.canEdit) return;
              HapticFeedback.selectionClick();
              _beginEditElement(el.id, el.content ?? '');
            },
      onLongPress: widget.canEdit
          ? () {
              HapticFeedback.mediumImpact();
              _showElementActions(goal, el, c);
            }
          : null,
      onPanStart: (!widget.canEdit || editing || _mapLocked)
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              setState(() => _draggingId = el.id);
            },
      onPanUpdate: (!widget.canEdit || editing || _mapLocked)
          ? null
          : (d) {
              final scale = _tc.value.getMaxScaleOnAxis();
              _elementPositions[el.id] =
                  (_elementPositions[el.id] ?? el.position) + d.delta / scale;
              _bumpRepaint();
              _emitNodeMove('el:${el.id}', _elementPositions[el.id]!);
            },
      onPanEnd: (!widget.canEdit || editing || _mapLocked)
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              _scheduleSaveElement(goal, el.id);
              setState(() => _draggingId = null);
            },
      child: content,
    );

    return Positioned(
      key: ValueKey('el-${el.id}'),
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: node,
    );
  }

  List<SubGoal> _flatSubGoals(List<SubGoal> roots) {
    final result = <SubGoal>[];
    void visit(SubGoal sg) {
      result.add(sg);
      for (final child in sg.children) visit(child);
    }
    for (final sg in roots) visit(sg);
    return result;
  }

  int _subtreeSize(SubGoal sg) {
    int n = 1 + sg.tasks.length;
    for (final c in sg.children) n += _subtreeSize(c);
    return n;
  }

  void _layoutSubGoalRadial(SubGoal sg, double fromAngle, double toAngle, int depth) {
    final sgPos = _positions[sg.id]!;

    final tasks = sg.tasks;
    if (tasks.isNotEmpty) {
      final radial = math.atan2(sgPos.dy, sgPos.dx);
      const tSpread = math.pi * 0.65;
      const tRadius = 130.0;
      for (int j = 0; j < tasks.length; j++) {
        if (_positions.containsKey(tasks[j].id)) continue;
        final ta = tasks.length == 1
            ? radial
            : radial + (-tSpread / 2 + tSpread * j / (tasks.length - 1));
        _positions[tasks[j].id] =
            sgPos + Offset(tRadius * math.cos(ta), tRadius * math.sin(ta));
      }
    }

    final children = sg.children;
    if (children.isEmpty) return;

    final childRadius = depth == 0 ? 220.0 : 180.0;
    final midAngle = (fromAngle + toAngle) / 2;
    final fan = math.min(toAngle - fromAngle, math.pi * 1.4);
    final totalSize = children.fold(0, (s, c) => s + _subtreeSize(c));
    double cursor = midAngle - fan / 2;

    for (final child in children) {
      final share = fan * _subtreeSize(child) / totalSize;
      final angle = cursor + share / 2;
      if (!_positions.containsKey(child.id)) {
        _positions[child.id] =
            sgPos + Offset(childRadius * math.cos(angle), childRadius * math.sin(angle));
      }
      _layoutSubGoalRadial(child, cursor, cursor + share, depth + 1);
      cursor += share;
    }
  }

  void _stepZoom(double factor) {
    final current = _tc.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.15, 3.0);
    final ratio = next / current;
    if ((ratio - 1.0).abs() < 0.001) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    final scaleM = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(ratio, ratio)
      ..translate(-center.dx, -center.dy);
    setState(() => _tc.value = scaleM * _tc.value);
  }

  void _handleEdgeZoom(double dy) {
    final factor = 1.0 - dy * 0.007;
    final current = _tc.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.15, 3.0);
    if ((next - current).abs() < 0.0001) return;
    final ratio = next / current;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);

    // T(C) * S(ratio) * T(-C) * current — scale about screen-space centre
    final scaleM = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(ratio, ratio)
      ..translate(-center.dx, -center.dy);
    _tc.value = scaleM * _tc.value;
  }

  // ── Stage 7: camera helpers, zoom-to-fit, tidy ────────────────────────────

  /// Smoothly drives the camera to [target] (respects reduced-motion).
  void _animateCameraTo(Matrix4 target) {
    if (!SieMotion.enabled(context)) {
      _tc.value = target;
      return;
    }
    _camTween = Matrix4Tween(begin: _tc.value.clone(), end: target).animate(
      CurvedAnimation(parent: _camAnim, curve: Curves.easeInOutCubic),
    );
    _camAnim
      ..reset()
      ..forward();
  }

  /// Centres the viewport on a logical (centre-relative) point at [scale]
  /// (defaults to the current zoom).
  void _centerOnLogical(Offset logical, {double? scale}) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final s = box.size;
    final sc = (scale ?? _tc.value.getMaxScaleOnAxis()).clamp(0.15, 3.0);
    final canvas = Offset(_cx + logical.dx, _cx + logical.dy);
    final m = Matrix4.identity()
      ..translate(s.width / 2 - canvas.dx * sc, s.height / 2 - canvas.dy * sc)
      ..scale(sc);
    _animateCameraTo(m);
  }

  /// Fits all nodes + map elements into the viewport.
  void _zoomToFit() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pts = <Offset>[];
    _positions.forEach((_, p) => pts.add(Offset(_cx + p.dx, _cx + p.dy)));
    _elementPositions
        .forEach((_, p) => pts.add(Offset(_cx + p.dx, _cx + p.dy)));
    if (pts.isEmpty) return;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const pad = 160.0; // room for node radius + labels
    final rect = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
    final s = box.size;
    final scale = math
        .min(s.width / rect.width, s.height / rect.height)
        .clamp(0.15, 3.0);
    final m = Matrix4.identity()
      ..translate(s.width / 2 - rect.center.dx * scale,
          s.height / 2 - rect.center.dy * scale)
      ..scale(scale);
    _animateCameraTo(m);
  }

  void _onLayoutTick() {
    final from = _layoutFrom, to = _layoutTo;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_layoutAnim.value);
    to.forEach((id, dst) {
      final src = from[id] ?? dst;
      _positions[id] = Offset.lerp(src, dst, t)!;
    });
    _bumpRepaint();
  }

  /// "Прибраться" — recompute the radial layout (nodes only) with an animated
  /// transition, persist it, and offer an undo.
  void _tidyLayout(Goal goal) {
    final prev = Map.of(_positions);
    // Compute the target layout without leaving it applied.
    _ensurePositions(goal, forceRadial: true);
    final target = Map.of(_positions);
    // Restore current positions; animate prev → target.
    _positions
      ..clear()
      ..addAll(prev);

    void persist() => ref
        .read(planningProvider.notifier)
        .saveMapPositions(goal.id, Map.of(_positions));

    if (SieMotion.enabled(context)) {
      _layoutFrom = prev;
      _layoutTo = target;
      _layoutAnim.reset();
      _layoutAnim.forward().whenComplete(() {
        _layoutFrom = null;
        _layoutTo = null;
        _positions
          ..clear()
          ..addAll(target);
        persist();
      });
    } else {
      _positions
        ..clear()
        ..addAll(target);
      _bumpRepaint();
      persist();
    }
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Карта перестроена'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            _positions
              ..clear()
              ..addAll(prev);
            _bumpRepaint();
            ref
                .read(planningProvider.notifier)
                .saveMapPositions(goal.id, Map.of(prev));
          },
        ),
      ),
    );
  }

  void _toggleMapLock(Goal goal) {
    final locked = !(goal.settings.mapLocked);
    HapticFeedback.selectionClick();
    ref
        .read(planningProvider.notifier)
        .updateGoalSettings(goal.id, goal.settings.copyWith(mapLocked: locked));
  }

  /// In-memory search across nodes, milestones and notes/labels.
  List<({String id, String label, IconData icon, Offset pos})> _searchResults(
      Goal goal) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <({String id, String label, IconData icon, Offset pos})>[];
    void add(String id, String label, IconData icon) {
      final p = _positions[id] ?? _elementPositions[id];
      if (p == null) return;
      out.add((id: id, label: label, icon: icon, pos: p));
    }

    for (final sg in _flat) {
      if (sg.name.toLowerCase().contains(q)) {
        add(sg.id, sg.name, Icons.layers_outlined);
      }
      for (final t in sg.tasks) {
        if (t.name.toLowerCase().contains(q)) {
          add(t.id, t.name, Icons.task_alt);
        }
      }
    }
    for (final m in goal.milestones) {
      if (m.name.toLowerCase().contains(q)) {
        add(m.id, m.name, Icons.outlined_flag);
      }
    }
    for (final el in goal.mapElements) {
      final content = el.content;
      if (content != null && content.toLowerCase().contains(q)) {
        add(el.id, content, Icons.sticky_note_2_outlined);
      }
    }
    return out.take(20).toList();
  }

  void _jumpToResult(String id, Offset logical) {
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
      _searchCtrl.clear();
    });
    _centerOnLogical(logical, scale: 1.0);
    _setHoverTarget(id);
    // Auto-clear the highlight after a moment.
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _hoverTargetId == id) _setHoverTarget(null);
    });
  }

  // ── Collision resolution ──────────────────────────────────────────────────

  // Computes every node radius in a single pass over the cached flat tree,
  // instead of re-flattening the whole tree on every lookup (was O(n) per call).
  Map<String, double> _computeRadii(Goal goal) {
    final radii = <String, double>{goal.id: 80.0};
    for (final sg in _flat) {
      radii[sg.id] = 55.0;
      for (final t in sg.tasks) {
        radii[t.id] = switch (t.weight) { 5 => 36.0, 3 => 28.0, _ => 22.0 };
      }
    }
    for (final m in goal.milestones) {
      radii[m.id] = 40.0;
    }
    for (final l in goal.habitLinks) {
      radii[l.id] = 26.0;
    }
    return radii;
  }

  void _resolveCollisions(String movedId, Goal goal) {
    final ids = _positions.keys.toList();
    // Precompute radii once (O(n)) rather than O(n) per pair → kills the O(n³).
    final radii = _computeRadii(goal);
    for (int iter = 0; iter < 30; iter++) {
      bool any = false;
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final a = ids[i];
          final b = ids[j];
          final pa = _positions[a]!;
          final pb = _positions[b]!;
          final minD = (radii[a] ?? 30.0) + (radii[b] ?? 30.0) + 36.0;
          final diff = pb - pa;
          final dist = diff.distance;
          if (dist < minD && dist > 0.001) {
            final push = (minD - dist) / 2.0;
            final dir = diff / dist;
            if (a != movedId && a != goal.id) _positions[a] = pa - dir * push;
            if (b != movedId && b != goal.id) _positions[b] = pb + dir * push;
            any = true;
          }
        }
      }
      if (!any) break;
    }
  }

  // ── Hover target ──────────────────────────────────────────────────────────

  void _setHoverTarget(String? id) {
    if (id == _hoverTargetId) return;
    _hoverTargetId = id; // no setState — dynamic layer repaints via _bumpRepaint
    if (id != null) {
      HapticFeedback.selectionClick();
      _hoverAnim.reset();
      if (_motionEnabled) {
        _hoverAnim.repeat(reverse: true);
      } else {
        _hoverAnim.value = 1.0; // instant highlight, no loop
      }
    } else {
      if (_motionEnabled) {
        _hoverAnim.reverse();
      } else {
        _hoverAnim.value = 0.0;
      }
    }
    _bumpRepaint();
  }

  // Stage 8: per-user color + display name for cursors / editing badges.
  Map<String, ({Color color, String name})> _buildMemberInfo(
      Goal goal, SieColors c) {
    final map = <String, ({Color color, String name})>{};
    map[goal.userId] = (
      color: memberColor(goal.userId, c),
      name: goal.ownerProfile?.username ?? 'Владелец',
    );
    for (final co in goal.collaborators.where((co) => co.status == 'accepted')) {
      map[co.userId] = (
        color: memberColor(co.userId, c),
        name: co.profile?.username ??
            (co.userId.length >= 6 ? co.userId.substring(0, 6) : co.userId),
      );
    }
    return map;
  }

  // Stage 5: look up avatarUrl for a userId from goal owner or collaborators.
  String? _resolveAvatarUrl(Goal goal, String userId) {
    if (goal.userId == userId) return goal.ownerProfile?.avatarUrl;
    return goal.collaborators
        .where((c) => c.userId == userId)
        .firstOrNull
        ?.profile
        ?.avatarUrl;
  }

  String? _nearestSubGoalFor(String draggingId, Goal goal,
      {Set<String> exclude = const {}, double threshold = 75.0}) {
    final pos = _positions[draggingId];
    if (pos == null) return null;
    String? nearest;
    double nearestDist = threshold;
    for (final sg in _flat) {
      if (exclude.contains(sg.id)) continue;
      final sgPos = _positions[sg.id];
      if (sgPos == null) continue;
      final dist = (pos - sgPos).distance;
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = sg.id;
      }
    }
    return nearest;
  }

  Set<String> _descendantIds(String sgId) {
    final result = <String>{};
    void collect(SubGoal sg) {
      for (final c in sg.children) {
        result.add(c.id);
        collect(c);
      }
    }
    for (final sg in _flat) {
      if (sg.id == sgId) {
        collect(sg);
        break;
      }
    }
    return result;
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  void _onTap(String nodeId, Goal goal) {
    if (_tool == _MapTool.connector && widget.canEdit) {
      _handleConnectorEndpoint('node:$nodeId', goal);
      return;
    }
    final c = ref.read(sieColorsProvider);
    if (nodeId == goal.id) {
      _showGoalSheet(goal, c);
      return;
    }
    final allSgs = _flat;
    final sg = allSgs.where((s) => s.id == nodeId).firstOrNull;
    if (sg != null) {
      _showSubGoalSheet(sg, goal, c);
      return;
    }
    final task = allSgs.expand((s) => s.tasks).where((t) => t.id == nodeId).firstOrNull;
    if (task != null) {
      final parent = allSgs.firstWhere((s) => s.tasks.any((t) => t.id == nodeId));
      _showTaskSheet(task, parent, goal, c);
      return;
    }
    final ms = goal.milestones.where((m) => m.id == nodeId).firstOrNull;
    if (ms != null) {
      _showMilestoneSheet(ms, goal, c);
      return;
    }
    final lnk = goal.habitLinks.where((l) => l.id == nodeId).firstOrNull;
    if (lnk != null) _showHabitLinkSheet(lnk, goal, c);
  }

  // ── Bottom sheets ─────────────────────────────────────────────────────────

  void _showGoalSheet(Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _AddNodeSheet(
        sc: c,
        goalId: goal.id,
        canEdit: widget.canEdit,
        onAddSubGoal: (name) {
          ref.read(planningProvider.notifier).addSubGoal(goal.id, name);
          Navigator.pop(ctx);
        },
        onAddMilestone: (name) {
          ref.read(planningProvider.notifier).addMilestone(goal.id, name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showSubGoalSheet(SubGoal sg, Goal goal, SieColors c) {
    final canEdit = widget.canEdit;
    if (canEdit) _emitEditing('node:${sg.id}', true); // Stage 8 soft-lock
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _SubGoalSheet(
        sg: sg,
        sc: c,
        goalId: goal.id,
        canEdit: canEdit,
        onAddTask: canEdit
            ? (name, weight) {
                ref
                    .read(planningProvider.notifier)
                    .addTask(goalId: goal.id, subGoalId: sg.id, name: name, weight: weight);
                Navigator.pop(ctx);
              }
            : null,
        onAddSubGoal: canEdit
            ? (name) {
                ref
                    .read(planningProvider.notifier)
                    .addSubGoal(goal.id, name, parentSubGoalId: sg.id);
                Navigator.pop(ctx);
              }
            : null,
        onComplete: (canEdit && !sg.isCompleted)
            ? () {
                ref
                    .read(planningProvider.notifier)
                    .completeSubGoal(sg.id, goal.id);
                Navigator.pop(ctx);
              }
            : null,
        onUnparent: (canEdit && sg.parentSubGoalId != null)
            ? () {
                ref.read(planningProvider.notifier).unparentSubGoal(sg.id);
                Navigator.pop(ctx);
              }
            : null,
        onDelete: canEdit
            ? () {
                ref.read(planningProvider.notifier).deleteSubGoal(sg.id, goal.id);
                Navigator.pop(ctx);
              }
            : null,
      ),
    ).whenComplete(
        () => canEdit ? _emitEditing('node:${sg.id}', false) : null);
  }

  void _showTaskSheet(PlanningTask task, SubGoal sg, Goal goal, SieColors c) {
    final canEdit = widget.canEdit;
    if (canEdit) _emitEditing('node:${task.id}', true); // Stage 8 soft-lock
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TaskSheet(
        task: task,
        sc: c,
        goalId: goal.id,
        canEdit: canEdit,
        onToggle: canEdit
            ? () {
                ref
                    .read(planningProvider.notifier)
                    .toggleTask(task.id, sg.id, goal.id);
                Navigator.pop(ctx);
              }
            : null,
        onDelete: canEdit
            ? () {
                ref
                    .read(planningProvider.notifier)
                    .deleteTask(task.id, sg.id, goal.id);
                Navigator.pop(ctx);
              }
            : null,
      ),
    ).whenComplete(
        () => canEdit ? _emitEditing('node:${task.id}', false) : null);
  }

  void _showMilestoneSheet(Milestone ms, Goal goal, SieColors c) {
    final canEdit = widget.canEdit;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MilestoneSheet(
        ms: ms,
        sc: c,
        goalId: goal.id,
        canEdit: canEdit,
        onComplete: (canEdit && !ms.isCompleted)
            ? () {
                ref
                    .read(planningProvider.notifier)
                    .completeMilestone(ms.id, goal.id);
                Navigator.pop(ctx);
              }
            : null,
        onDelete: canEdit
            ? () {
                ref
                    .read(planningProvider.notifier)
                    .deleteMilestone(ms.id, goal.id);
                Navigator.pop(ctx);
              }
            : null,
      ),
    );
  }

  void _showHabitLinkSheet(GoalHabitLink lnk, Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _HabitLinkSheet(
        link: lnk,
        sc: c,
        onUnlink: () {
          ref.read(planningProvider.notifier).unlinkHabit(lnk.id, goal.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    // Select only this goal: rebuilds are skipped when an unrelated goal mutates,
    // because the provider reuses unchanged Goal instances across copyWith.
    final goal = ref.watch(planningProvider.select((s) => s.valueOrNull?.goals
            .where((g) => g.id == _goal.id)
            .firstOrNull)) ??
        widget.goal;

    // Flatten the tree once per build; reused by drag handlers until next build.
    _flat = _flatSubGoals(goal.subGoals);
    _motionEnabled = SieMotion.enabled(context);

    // Stage 8: connect live channel + refresh participant identity each build.
    _liveGoal = goal;
    _maybeInitLive(goal);
    _memberInfo = _buildMemberInfo(goal, c);

    // Stage 7: lock state for drag gating.
    _mapLocked = goal.settings.mapLocked;

    _ensurePositions(goal);

    // Seed live positions/sizes for map elements (only once per id, like nodes).
    for (final el in goal.mapElements) {
      _elementPositions.putIfAbsent(el.id, () => el.position);
      if (el.kind == MapElementKind.note ||
          el.kind == MapElementKind.image) {
        _elementSizes.putIfAbsent(
            el.id,
            () => Offset(
                  el.w ?? (el.kind == MapElementKind.image ? 200 : 140),
                  el.h ?? (el.kind == MapElementKind.image ? 150 : 100),
                ));
      }
    }

    final fogEnabled = goal.settings.isFogOfWarEnabled;
    final visibleIds = fogEnabled
        ? computeFogVisibleIds(goal.subGoals, _scoutedMapIds, true)
        : null;
    bool isHidden(String id) => visibleIds != null && !visibleIds.contains(id);

    // Recomputed every frame the dynamic layer rebuilds (cheap O(n)); kept as a
    // closure so the ValueListenableBuilder can rebuild edges from live positions
    // without re-running the whole build().
    List<_Edge> buildEdges() {
      final goalPos = _positions[goal.id] ?? Offset.zero;
      final edges = <_Edge>[];
      void addSubGoalEdges(SubGoal sg, Offset parentPos, _EType edgeType) {
        final sgPos = _positions[sg.id];
        if (sgPos == null) return;
        edges.add(_Edge(parentPos, sgPos, edgeType, fogHidden: isHidden(sg.id)));
        for (final t in sg.tasks) {
          final tp = _positions[t.id];
          if (tp != null) {
            edges.add(_Edge(sgPos, tp, _EType.subTask, fogHidden: isHidden(sg.id)));
          }
        }
        for (final child in sg.children) {
          addSubGoalEdges(child, sgPos, _EType.subSub);
        }
      }
      for (final sg in goal.subGoals) {
        addSubGoalEdges(sg, goalPos, _EType.goalSub);
      }
      for (final ms in goal.milestones) {
        final mp = _positions[ms.id];
        if (mp != null) edges.add(_Edge(goalPos, mp, _EType.goalMs));
      }
      for (final l in goal.habitLinks) {
        final lp = _positions[l.id];
        if (lp != null) edges.add(_Edge(goalPos, lp, _EType.goalHabit));
      }
      // Dependency edges (Stage 8): predecessor → dependent (arrow points to
      // the task that gets unblocked). Drawn last so they sit atop hierarchy.
      for (final sg in _flat) {
        for (final t in sg.tasks) {
          if (t.dependsOn.isEmpty) continue;
          final dstPos = _positions[t.id];
          if (dstPos == null) continue;
          for (final depId in t.dependsOn) {
            final srcPos = _positions[depId];
            if (srcPos != null) {
              edges.add(_Edge(srcPos, dstPos, _EType.dependency));
            }
          }
        }
      }
      return edges;
    }

    // Stage 7: content presence gates the nav overlays (minimap/search/fit).
    final hasContent = _flat.isNotEmpty || goal.mapElements.isNotEmpty;
    final box = context.findRenderObject() as RenderBox?;
    final viewportSize = (box != null && box.hasSize)
        ? box.size
        : MediaQuery.of(context).size;

    return Stack(
      children: [
        Listener(
          // Stage 8: broadcast this user's cursor. Listener sits outside the
          // gesture arena, so it never steals pans/drags from nodes.
          onPointerHover: _live == null ? null : (e) => _emitCursor(e.localPosition),
          onPointerMove: _live == null ? null : (e) => _emitCursor(e.localPosition),
          child: GestureDetector(
          // Stage 7: double-tap empty canvas → zoom-to-fit.
          onDoubleTap: hasContent ? _zoomToFit : null,
          child: InteractiveViewer(
      transformationController: _tc,
      constrained: false,
      // Stage 8: taking the camera cancels follow-mode (you took control).
      onInteractionStart:
          _followUserId == null ? null : (_) => setState(() => _followUserId = null),
      boundaryMargin: const EdgeInsets.all(800),
      minScale: 0.15,
      maxScale: 3.0,
      panEnabled: _draggingId == null,
      scaleEnabled: _draggingId == null,
      child: SizedBox(
        width: _cs,
        height: _cs,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Grid — static layer, isolated so node/edge repaints don't touch it
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _GridPainter(c)),
              ),
            ),
            // Dynamic layer: edges + all draggable nodes. Listens to _repaint so a
            // drag rebuilds ONLY this subtree (root build is not called mid-drag).
            Positioned.fill(
              child: RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _repaint,
                  builder: (_, _, _) {
                    final edges = buildEdges();
                    // Resolve connector endpoints to canvas-space offsets;
                    // drop connectors whose endpoints no longer exist (Stage 4).
                    final connectors = <_ConnectorData>[];
                    final orphanConnectorIds = <String>[];
                    Offset? resolveRef(String r) {
                      Offset? logical;
                      if (r.startsWith('node:')) {
                        logical = _positions[r.substring(5)];
                      } else if (r.startsWith('el:')) {
                        logical = _elementPositions[r.substring(3)];
                      }
                      if (logical == null) return null;
                      return Offset(_cx + logical.dx, _cx + logical.dy);
                    }
                    for (final el in goal.mapElements) {
                      if (el.kind != MapElementKind.connector) continue;
                      final f = el.fromRef, t = el.toRef;
                      final src = f == null ? null : resolveRef(f);
                      final dst = t == null ? null : resolveRef(t);
                      if (src == null || dst == null) {
                        orphanConnectorIds.add(el.id);
                        continue;
                      }
                      final style = el.styleJson ?? const <String, dynamic>{};
                      final colorHex = style['color'] as String?;
                      connectors.add(_ConnectorData(
                        id: el.id,
                        src: src,
                        dst: dst,
                        label: (el.content?.isNotEmpty ?? false)
                            ? el.content
                            : null,
                        dashed: style['dashed'] == true,
                        color: _hexColor(colorHex) ?? c.accentSecondary,
                      ));
                    }
                    if (orphanConnectorIds.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        for (final id in orphanConnectorIds) {
                          ref
                              .read(planningProvider.notifier)
                              .deleteMapElement(goal.id, id);
                        }
                      });
                    }
                    // Obstacles for smart connector routing (node bounding circles).
                    final obstacles = <_ObstacleCircle>[];
                    _computeRadii(goal).forEach((id, radius) {
                      final logical = _positions[id];
                      if (logical == null) return;
                      obstacles.add(_ObstacleCircle(
                        center: Offset(_cx + logical.dx, _cx + logical.dy),
                        radius: radius,
                      ));
                    });
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Edges (hierarchy + dependencies)
                        Positioned.fill(
                          child: CustomPaint(
                              painter: _EdgePainter(edges, _cx, c)),
                        ),
                        // Free connectors — above hierarchy edges, below nodes.
                        if (connectors.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter:
                                  _ConnectorPainter(connectors, c, obstacles),
                            ),
                          ),
                        // Connector midpoint tap targets (edit only).
                        if (widget.canEdit)
                          for (final conn in connectors)
                            Positioned(
                              left: (conn.src.dx + conn.dst.dx) / 2 - 20,
                              top: (conn.src.dy + conn.dst.dy) / 2 - 20,
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  final el = goal.mapElements
                                      .where((e) => e.id == conn.id)
                                      .firstOrNull;
                                  if (el != null) {
                                    _showConnectorActions(goal, el, c);
                                  }
                                },
                                child: const SizedBox.expand(),
                              ),
                            ),
                        // Habit links
                        for (final l in goal.habitLinks)
                          _posNode(
                            l.id,
                            42,
                            42,
                            goal,
                            _HabitLinkNode(
                                link: l, sc: c, dragging: _draggingId == l.id),
                          ),
                        // Milestones
                        for (final ms in goal.milestones)
                          _posNode(
                            ms.id,
                            80,
                            80,
                            goal,
                            _MilestoneNode(
                                ms: ms, sc: c, dragging: _draggingId == ms.id,
                                attachmentCount: goal.attachmentsFor(ms.id).length),
                          ),
                        // Tasks and nested sub-goals (all depths)
                        for (final sg in _flat) ...[
                          for (final t in sg.tasks)
                            _taskPosNode(t, sg.id, goal, c,
                                hidden: isHidden(sg.id)),
                          _subGoalPosNode(sg, goal, c,
                              hidden: isHidden(sg.id),
                              onHiddenTap: () =>
                                  setState(() => _scoutedMapIds.add(sg.id))),
                        ],
                        // Image cards — above nodes so they stay draggable /
                        // resizable (a centred image would otherwise sit behind
                        // the node cluster and never receive gestures).
                        for (final el in goal.mapElements)
                          if (el.kind == MapElementKind.image)
                            _imageCardWidget(el, goal, c),
                        // Map-native notes/labels — above nodes.
                        for (final el in goal.mapElements)
                          if (el.kind == MapElementKind.note ||
                              el.kind == MapElementKind.label)
                            _elementPosNode(el, goal, c),
                        // Stage 8: live cursors + editing badges (topmost).
                        if (_live != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ValueListenableBuilder<int>(
                                valueListenable: _liveRepaint,
                                builder: (_, _, _) => _LiveOverlayLayer(
                                  cursors: _remoteCursors,
                                  editing: _editingByNode,
                                  positions: _positions,
                                  elementPositions: _elementPositions,
                                  memberInfo: _memberInfo,
                                  cx: _cx,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Tap-catcher for placing a note/label (nodes capture their own
            // taps first because they paint on top with opaque hit-testing).
            if (_tool == _MapTool.note || _tool == _MapTool.label)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _createElementAt(d.localPosition, goal),
                ),
              ),
            // Goal (fixed, topmost) — never moves, kept out of the dynamic layer
            Positioned(
              left: _cx - 80,
              top: _cx - 80,
              child: _GoalNode(
                goal: goal,
                sc: c,
                attachmentCount: goal.attachmentsFor(goal.id).length,
                onTap: () {
                  if (_tool == _MapTool.connector && widget.canEdit) {
                    _handleConnectorEndpoint('node:${goal.id}', goal);
                    return;
                  }
                  HapticFeedback.selectionClick();
                  if (widget.canEdit) _showGoalSheet(goal, c);
                },
              ),
            ),
          ],
        ),
      ),
        ),
        ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 24,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) => _handleEdgeZoom(d.delta.dy),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 24,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) => _handleEdgeZoom(d.delta.dy),
          ),
        ),
        Positioned(
          right: 32,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stage 7: power tools.
              if (hasContent)
                _ZoomButton(
                    icon: Icons.search,
                    onTap: () => setState(() => _searchOpen = true),
                    sc: c),
              if (hasContent) const SizedBox(height: 4),
              if (hasContent)
                _ZoomButton(
                    icon: Icons.fit_screen_outlined,
                    onTap: _zoomToFit,
                    sc: c),
              if (hasContent) const SizedBox(height: 4),
              if (widget.canEdit && _flat.isNotEmpty)
                _ZoomButton(
                    icon: Icons.auto_fix_high_outlined,
                    onTap: () => _tidyLayout(goal),
                    sc: c),
              if (widget.canEdit && _flat.isNotEmpty)
                const SizedBox(height: 4),
              if (widget.canEdit)
                _ZoomButton(
                    icon: _mapLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                    onTap: () => _toggleMapLock(goal),
                    sc: c,
                    active: _mapLocked),
              if (widget.canEdit) const SizedBox(height: 10),
              _ZoomButton(icon: Icons.add, onTap: () => _stepZoom(1.25), sc: c),
              const SizedBox(height: 4),
              _ZoomButton(icon: Icons.remove, onTap: () => _stepZoom(0.8), sc: c),
            ],
          ),
        ),
        // Stage 7: mini-map (top-right). Listens to camera + node moves.
        if (hasContent && _showMiniMap)
          Positioned(
            top: 16,
            right: 16,
            child: _MiniMap(
              positions: _positions,
              elementPositions: _elementPositions,
              repaint: _repaint,
              tc: _tc,
              viewportSize: viewportSize,
              cx: _cx,
              sc: c,
              onTapCanvas: (logical) => _centerOnLogical(logical),
            ),
          ),
        // Stage 7: search overlay.
        if (_searchOpen)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _SearchPanel(
              ctrl: _searchCtrl,
              sc: c,
              results: _searchResults(goal),
              onChanged: (q) => setState(() => _searchQuery = q),
              onPick: _jumpToResult,
              onClose: () => setState(() {
                _searchOpen = false;
                _searchQuery = '';
                _searchCtrl.clear();
              }),
            ),
          ),
        // Tool palette — slides up while edit mode is on.
        if (widget.canEdit)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MapToolPalette(
              visible: _editMode,
              tool: _tool,
              sc: c,
              onPick: (t) {
                if (t == _MapTool.image) {
                  if (!_pickingImage) _showImageSourceMenu(goal, c);
                  return;
                }
                setState(() {
                  _tool = _tool == t ? _MapTool.none : t;
                  _connectorFromRef = null;
                });
              },
            ),
          ),
        // Edit-mode toggle (only owners/editors). Declared AFTER the palette so
        // it renders above it, and lifts above the palette while edit mode is on
        // so the "Готово" button stays tappable.
        if (widget.canEdit)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: 16,
            bottom: _editMode ? 84 : 16,
            child: _EditModeButton(
              active: _editMode,
              sc: c,
              onTap: () => setState(() {
                _editMode = !_editMode;
                if (!_editMode) {
                  _tool = _MapTool.none;
                  _connectorFromRef = null;
                }
              }),
            ),
          ),
        // Connector first-endpoint hint banner.
        if (widget.canEdit &&
            _tool == _MapTool.connector &&
            _connectorFromRef != null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Выберите цель стрелки',
                    style: TextStyle(
                      color: c.background,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Stage 5/8: member legend overlay (only when goal has accepted collabs).
        if (goal.collaborators.any((co) => co.status == 'accepted'))
          Positioned(
            left: 16,
            top: 16,
            child: _MemberLegendOverlay(
              goal: goal,
              sc: c,
              filterMemberId: _filterMemberId,
              liveUserIds: _remoteCursors.keys.toSet(),
              followingId: _followUserId,
              onMemberTap: (userId) => setState(() {
                _filterMemberId =
                    _filterMemberId == userId ? null : userId;
              }),
              onFollow: _toggleFollow,
            ),
          ),
      ],
    );
  }

  double _taskW(int w) => switch (w) { 5 => 124, 3 => 104, _ => 84 };

  Widget _taskPosNode(PlanningTask task, String currentSgId, Goal goal, SieColors c,
      {bool hidden = false}) {
    final pos = _positions[task.id];
    if (pos == null) return const SizedBox.shrink();
    final w = _taskW(task.weight);
    const h = 40.0;
    Widget node = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _onTap(task.id, goal);
      },
      onPanStart: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              setState(() => _draggingId = task.id);
            },
      onPanUpdate: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (d) {
              final scale = _tc.value.getMaxScaleOnAxis();
              // Mutate + bump (no setState) → only the dynamic layer repaints.
              _positions[task.id] = _positions[task.id]! + d.delta / scale;
              _bumpRepaint();
              _emitNodeMove('node:${task.id}', _positions[task.id]!);
              _setHoverTarget(_nearestSubGoalFor(task.id, goal, exclude: {task.id}));
            },
      onPanEnd: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (_) {
              _tryReparentTask(task.id, currentSgId, goal);
              _resolveCollisions(task.id, goal);
              HapticFeedback.lightImpact();
              _setHoverTarget(null);
              _scheduleSave(goal);
              setState(() => _draggingId = null);
            },
      child: _TaskNode(
          task: task,
          sc: c,
          dragging: _draggingId == task.id,
          attachmentCount: goal.attachmentsFor(task.id).length,
          assigneeId: task.assigneeIds.firstOrNull,
          assigneeAvatarUrl: task.assigneeIds.firstOrNull != null
              ? _resolveAvatarUrl(goal, task.assigneeIds.first)
              : null),
    );
    if (hidden) node = Opacity(opacity: 0.25, child: node);
    final filteredOut = _filterMemberId != null &&
        !task.assigneeIds.contains(_filterMemberId);
    if (filteredOut) node = Opacity(opacity: 0.2, child: node);
    return Positioned(
      key: ValueKey(task.id),
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: node,
    );
  }

  void _tryReparentTask(String taskId, String currentSgId, Goal goal) {
    final taskPos = _positions[taskId];
    if (taskPos == null) return;
    const threshold = 75.0;
    String? nearestSgId;
    double nearestDist = threshold;
    for (final sg in _flat) {
      final sgPos = _positions[sg.id];
      if (sgPos == null) continue;
      final dist = (taskPos - sgPos).distance;
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestSgId = sg.id;
      }
    }
    if (nearestSgId != null && nearestSgId != currentSgId) {
      HapticFeedback.mediumImpact();
      ref.read(planningProvider.notifier).moveTask(taskId, nearestSgId);
    }
  }

  Widget _subGoalPosNode(SubGoal sg, Goal goal, SieColors c,
      {bool hidden = false, VoidCallback? onHiddenTap}) {
    final pos = _positions[sg.id];
    if (pos == null) return const SizedBox.shrink();
    const w = 158.0, h = 68.0;
    Widget node = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hidden
          ? onHiddenTap
          : () {
              HapticFeedback.selectionClick();
              _onTap(sg.id, goal);
            },
      onPanStart: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              setState(() => _draggingId = sg.id);
            },
      onPanUpdate: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (d) {
              final scale = _tc.value.getMaxScaleOnAxis();
              final delta = d.delta / scale;
              _positions[sg.id] = _positions[sg.id]! + delta;
              // Move own tasks + all descendants (sub-goals and their tasks) with the same delta
              void moveFamily(SubGoal s) {
                for (final t in s.tasks) {
                  final p = _positions[t.id];
                  if (p != null) _positions[t.id] = p + delta;
                }
                for (final child in s.children) {
                  final p = _positions[child.id];
                  if (p != null) _positions[child.id] = p + delta;
                  moveFamily(child);
                }
              }
              moveFamily(sg);
              _bumpRepaint();
              _emitNodeMove('node:${sg.id}', _positions[sg.id]!);
              final excluded = {sg.id, ..._descendantIds(sg.id)};
              _setHoverTarget(_nearestSubGoalFor(sg.id, goal, exclude: excluded));
            },
      onPanEnd: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (_) {
              _tryReparentSubGoal(sg, goal);
              _resolveCollisions(sg.id, goal);
              HapticFeedback.lightImpact();
              _setHoverTarget(null);
              _scheduleSave(goal);
              setState(() => _draggingId = null);
            },
      child: _SubGoalNode(
        sg: sg,
        sc: c,
        dragging: _draggingId == sg.id,
        isHoverTarget: _hoverTargetId == sg.id,
        hoverAnim: _hoverTargetId == sg.id ? _hoverAnim : null,
        onAdd: widget.canEdit ? () => _showSubGoalSheet(sg, goal, c) : null,
        attachmentCount: goal.attachmentsFor(sg.id).length,
        assigneeId: sg.assigneeIds.firstOrNull,
        assigneeAvatarUrl: sg.assigneeIds.firstOrNull != null
            ? _resolveAvatarUrl(goal, sg.assigneeIds.first)
            : null,
      ),
    );
    if (hidden) node = Opacity(opacity: 0.25, child: node);
    final sgFilteredOut = _filterMemberId != null &&
        !sg.assigneeIds.contains(_filterMemberId);
    if (sgFilteredOut) node = Opacity(opacity: 0.2, child: node);
    return Positioned(
      key: ValueKey(sg.id),
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: node,
    );
  }

  void _tryReparentSubGoal(SubGoal sg, Goal goal) {
    final excluded = {sg.id, ..._descendantIds(sg.id)};
    final nearest = _nearestSubGoalFor(sg.id, goal, exclude: excluded);
    if (nearest != null && nearest != sg.parentSubGoalId) {
      HapticFeedback.mediumImpact();
      ref.read(planningProvider.notifier).moveSubGoal(sg.id, nearest);
    }
  }

  Widget _posNode(String id, double w, double h, Goal goal, Widget child,
      {bool hidden = false, VoidCallback? onHiddenTap}) {
    final pos = _positions[id];
    if (pos == null) return const SizedBox.shrink();
    Widget inner = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hidden
          ? onHiddenTap
          : () {
              HapticFeedback.selectionClick();
              _onTap(id, goal);
            },
      onPanStart: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              setState(() => _draggingId = id);
            },
      onPanUpdate: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (d) {
              final scale = _tc.value.getMaxScaleOnAxis();
              _positions[id] = _positions[id]! + d.delta / scale;
              _bumpRepaint();
              _emitNodeMove('node:$id', _positions[id]!);
            },
      onPanEnd: (hidden || !widget.canEdit || _mapLocked)
          ? null
          : (_) {
              _resolveCollisions(id, goal);
              HapticFeedback.lightImpact();
              _scheduleSave(goal);
              setState(() => _draggingId = null);
            },
      child: child,
    );
    if (hidden) inner = Opacity(opacity: 0.25, child: inner);
    return Positioned(
      key: ValueKey(id),
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: inner,
    );
  }
}

// ─── Edge types & data ────────────────────────────────────────────────────────

enum _EType { goalSub, subSub, subTask, goalMs, goalHabit, dependency }

class _Edge {
  const _Edge(this.src, this.dst, this.type, {this.fogHidden = false});
  final Offset src;
  final Offset dst;
  final _EType type;
  final bool fogHidden;
}

// ─── Grid painter ─────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter(this.c);
  final SieColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = c.border.withValues(alpha: c.isLightMode ? 0.45 : 0.25)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.c != c;
}

// ─── Edge painter ─────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.edges, this.center, this.c);
  final List<_Edge> edges;
  final double center;
  final SieColors c;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final src = Offset(center + e.src.dx, center + e.src.dy);
      final dst = Offset(center + e.dst.dx, center + e.dst.dy);

      var (color, width, dashed) = switch (e.type) {
        _EType.goalSub => (c.accent.withValues(alpha: 0.38), 2.0, false),
        _EType.subSub => (c.border.withValues(alpha: 0.9), 1.5, true),
        _EType.subTask => (c.border.withValues(alpha: 0.8), 1.5, false),
        _EType.goalMs => (c.accentSecondary.withValues(alpha: 0.45), 1.5, true),
        _EType.goalHabit => (c.dp.withValues(alpha: 0.35), 1.2, false),
        _EType.dependency => (c.warning.withValues(alpha: 0.7), 1.6, true),
      };
      if (e.fogHidden) {
        color = color.withValues(alpha: color.a * 0.4);
        dashed = true;
      }

      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final diff = dst - src;
      final dist = diff.distance;
      if (dist < 1) continue;

      // Dependency edges are drawn as a straight dashed line with an arrowhead
      // at the dependent end — visually distinct from hierarchical curves.
      if (e.type == _EType.dependency) {
        final dir = diff / dist;
        // Stop short of the node so the arrow is visible.
        final tip = dst - dir * 22.0;
        final straight = Path()
          ..moveTo(src.dx, src.dy)
          ..lineTo(tip.dx, tip.dy);
        _drawDashed(canvas, straight, paint);
        _drawArrowHead(canvas, tip, dir, color);
        continue;
      }
      final px = -diff.dy / dist * dist * 0.28;
      final py = diff.dx / dist * dist * 0.28;
      final cp1 = Offset(src.dx + diff.dx * 0.38 + px, src.dy + diff.dy * 0.38 + py);
      final cp2 = Offset(src.dx + diff.dx * 0.62 - px, src.dy + diff.dy * 0.62 - py);

      final path = Path()
        ..moveTo(src.dx, src.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, dst.dx, dst.dy);

      if (dashed) {
        _drawDashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    for (final m in path.computeMetrics()) {
      double d = 0;
      bool draw = true;
      while (d < m.length) {
        final len = draw ? dash : gap;
        if (draw) {
          canvas.drawPath(
              m.extractPath(d, math.min(d + len, m.length)), paint);
        }
        d += len;
        draw = !draw;
      }
    }
  }

  // Filled triangle arrowhead at [tip], pointing along unit vector [dir].
  void _drawArrowHead(Canvas canvas, Offset tip, Offset dir, Color color) {
    const size = 9.0;
    final back = tip - dir * size;
    final normal = Offset(-dir.dy, dir.dx) * (size * 0.5);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + normal.dx, back.dy + normal.dy)
      ..lineTo(back.dx - normal.dx, back.dy - normal.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      !identical(old.edges, edges) || old.c != c;
}

// ─── Goal Node ────────────────────────────────────────────────────────────────

class _GoalNode extends StatelessWidget {
  const _GoalNode({
    required this.goal,
    required this.sc,
    required this.onTap,
    this.attachmentCount = 0,
  });
  final Goal goal;
  final SieColors sc;
  final VoidCallback onTap;
  final int attachmentCount;

  @override
  Widget build(BuildContext context) {
    final progress = goalProgress(goal) / 100;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GoalRingPainter(goal: goal, progress: progress),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      goal.name,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sc.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (attachmentCount > 0)
              Positioned(
                top: 14,
                right: 14,
                child: _AttachmentBadge(count: attachmentCount, sc: sc),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  const _GoalRingPainter({required this.goal, required this.progress});
  final Goal goal;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = goal.color.withValues(alpha: 0.13)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = goal.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 4),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = goal.color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 4),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = goal.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) => old.progress != progress;
}

// ─── SubGoal Node ─────────────────────────────────────────────────────────────

class _SubGoalNode extends StatelessWidget {
  const _SubGoalNode({
    required this.sg,
    required this.sc,
    required this.dragging,
    required this.isHoverTarget,
    this.onAdd,
    this.hoverAnim,
    this.attachmentCount = 0,
    this.assigneeId,
    this.assigneeAvatarUrl,
  });
  final SubGoal sg;
  final SieColors sc;
  final bool dragging;
  final bool isHoverTarget;
  final Animation<double>? hoverAnim;
  final VoidCallback? onAdd;
  final int attachmentCount;
  final String? assigneeId;
  final String? assigneeAvatarUrl;

  @override
  Widget build(BuildContext context) {
    if (hoverAnim != null) {
      return AnimatedBuilder(
        animation: hoverAnim!,
        builder: (_, __) => _buildBody(hoverAnim!.value),
      );
    }
    return _buildBody(0.0);
  }

  Widget _buildBody(double t) {
    final prog = subGoalProgress(sg);
    final done = sg.isCompleted;
    final c = sc;
    final assigned = assigneeId != null;

    final baseFill = done
        ? c.accent.withValues(alpha: 0.28)
        : prog > 0
            ? c.accent.withValues(alpha: 0.12)
            : c.surface;
    final fill = isHoverTarget
        ? Color.lerp(baseFill, c.accent.withValues(alpha: 0.22), t) ?? baseFill
        : baseFill;

    final memberC = assigned ? memberColor(assigneeId!, c) : null;
    final borderColor = (dragging || isHoverTarget)
        ? c.accent
        : assigned
            ? memberC!
            : (done ? c.accent : prog > 0 ? c.accent.withValues(alpha: 0.5) : c.border);
    final borderWidth = dragging ? 2.5 : (isHoverTarget ? 1.5 + t * 1.5 : assigned ? 2.0 : 1.5);

    final shadow = dragging
        ? [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: 2)]
        : isHoverTarget
            ? [BoxShadow(color: c.accent.withValues(alpha: 0.15 + t * 0.15), blurRadius: 14)]
            : null;

    final completedTasks = sg.tasks.where((t) => t.isCompleted).length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (done)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle, size: 11, color: c.accent),
                          ),
                        Expanded(
                          child: Text(
                            sg.name,
                            maxLines: sg.tasks.isNotEmpty ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              decoration: done ? TextDecoration.lineThrough : null,
                              decorationColor: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sg.tasks.isNotEmpty)
                      Text(
                        '$completedTasks/${sg.tasks.length}',
                        style: TextStyle(color: c.textSecondary, fontSize: 9),
                      ),
                  ],
                ),
              ),
              if (prog > 0 && !done)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    child: LinearProgressIndicator(
                      value: prog / 100,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent.withValues(alpha: 0.55)),
                      minHeight: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (onAdd != null)
          Positioned(
            top: -9,
            right: -9,
            child: GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                child: Icon(Icons.add, size: 13, color: c.background),
              ),
            ),
          ),
        if (attachmentCount > 0)
          Positioned(
            bottom: -8,
            left: 6,
            child: _AttachmentBadge(count: attachmentCount, sc: c),
          ),
        if (assigned)
          Positioned(
            bottom: -8,
            right: 6,
            child: _MiniAvatar(
              userId: assigneeId!,
              avatarUrl: assigneeAvatarUrl,
              color: memberC!,
              sc: c,
            ),
          ),
      ],
    );
  }
}

// ─── Task Node ────────────────────────────────────────────────────────────────

class _TaskNode extends StatelessWidget {
  const _TaskNode({
    required this.task,
    required this.sc,
    required this.dragging,
    this.attachmentCount = 0,
    this.assigneeId,
    this.assigneeAvatarUrl,
  });
  final PlanningTask task;
  final SieColors sc;
  final bool dragging;
  final int attachmentCount;
  final String? assigneeId;
  final String? assigneeAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    final assigned = assigneeId != null;
    final memberC = assigned ? memberColor(assigneeId!, c) : null;
    final alpha = switch (task.weight) { 5 => 0.27, 3 => 0.16, _ => 0.08 };
    final fill = c.accent.withValues(alpha: task.isCompleted ? alpha + 0.05 : alpha);
    final baseBorder = task.isCompleted ? c.accent : c.accent.withValues(alpha: 0.3 + task.weight * 0.06);
    final border = dragging ? c.accent : (assigned ? memberC! : baseBorder);
    final borderWidth = dragging ? 2.5 : (assigned ? 2.0 : 1.5);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: dragging
            ? [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: 2)]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                task.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 10,
                  fontWeight: task.weight == 5 ? FontWeight.w600 : FontWeight.w400,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: c.textSecondary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 5,
            bottom: 2,
            child: Text(
              '×${task.weight}',
              style: TextStyle(color: c.textSecondary, fontSize: 8, fontWeight: FontWeight.w500),
            ),
          ),
          if (task.isCompleted)
            Positioned(
              left: 5,
              top: 0,
              bottom: 0,
              child: Center(child: Icon(Icons.check, size: 10, color: c.accent)),
            ),
          if (attachmentCount > 0)
            Positioned(
              right: 5,
              top: 2,
              child: _AttachmentBadge(count: attachmentCount, sc: c),
            ),
          if (assigned)
            Positioned(
              left: 4,
              top: 2,
              child: _MiniAvatar(
                userId: assigneeId!,
                avatarUrl: assigneeAvatarUrl,
                color: memberC!,
                sc: c,
                size: 14,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Milestone Node ───────────────────────────────────────────────────────────

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({required this.ms, required this.sc, required this.dragging, this.attachmentCount = 0});
  final Milestone ms;
  final SieColors sc;
  final bool dragging;
  final int attachmentCount;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    final sec = c.accentSecondary;
    final fill = ms.isCompleted ? sec.withValues(alpha: 0.35) : sec.withValues(alpha: 0.14);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sec, width: dragging ? 2.5 : 2.0),
              boxShadow: dragging
                  ? [BoxShadow(color: sec.withValues(alpha: 0.3), blurRadius: 10)]
                  : null,
            ),
            child: Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Icon(
                  ms.isCompleted ? Icons.flag : Icons.outlined_flag,
                  size: 18,
                  color: sec,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 78,
          child: Text(
            ms.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 8),
          ),
        ),
        if (ms.targetDate != null)
          Text(
            '${ms.targetDate!.day}.${ms.targetDate!.month.toString().padLeft(2, '0')}',
            style: TextStyle(color: c.textSecondary.withValues(alpha: 0.6), fontSize: 7),
          ),
        if (attachmentCount > 0)
          _AttachmentBadge(count: attachmentCount, sc: c),
      ],
    );
  }
}

// ─── Habit Link Node ──────────────────────────────────────────────────────────

class _HabitLinkNode extends StatelessWidget {
  const _HabitLinkNode({required this.link, required this.sc, required this.dragging});
  final GoalHabitLink link;
  final SieColors sc;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: c.dp.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: c.dp, width: dragging ? 2.0 : 1.5),
        boxShadow: dragging
            ? [BoxShadow(color: c.dp.withValues(alpha: 0.28), blurRadius: 8)]
            : null,
      ),
      child: Icon(Icons.link, size: 16, color: c.dp),
    );
  }
}

// ─── Sheet: Add node (SubGoal / Milestone) ────────────────────────────────────

class _AddNodeSheet extends ConsumerStatefulWidget {
  const _AddNodeSheet({
    required this.sc,
    required this.goalId,
    required this.canEdit,
    required this.onAddSubGoal,
    required this.onAddMilestone,
  });
  final SieColors sc;
  final String goalId;
  final bool canEdit;
  final ValueChanged<String> onAddSubGoal;
  final ValueChanged<String> onAddMilestone;

  @override
  ConsumerState<_AddNodeSheet> createState() => _AddNodeSheetState();
}

class _AddNodeSheetState extends ConsumerState<_AddNodeSheet> {
  final _ctrl = TextEditingController();
  String _mode = 'subgoal';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    final attachments = ref.watch(
      planningProvider.select((s) {
        final goals = s.valueOrNull?.goals ?? const [];
        for (final g in goals) {
          if (g.id == widget.goalId) return g.attachmentsFor(widget.goalId);
        }
        return const <NodeAttachment>[];
      }),
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachments.isNotEmpty || widget.canEdit) ...[
            AttachmentGallery(
              goalId: widget.goalId,
              nodeType: 'goal',
              nodeId: widget.goalId,
              attachments: attachments,
              canEdit: widget.canEdit,
              compactMode: true,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              _Chip(label: 'Под-цель', selected: _mode == 'subgoal', sc: c,
                  onTap: () => setState(() => _mode = 'subgoal')),
              const SizedBox(width: 8),
              _Chip(label: 'Чекпоинт', selected: _mode == 'milestone', sc: c,
                  onTap: () => setState(() => _mode = 'milestone')),
            ],
          ),
          const SizedBox(height: 14),
          _StyledTextField(
            ctrl: _ctrl,
            hint: _mode == 'subgoal' ? 'Название под-цели' : 'Название чекпоинта',
            sc: c,
            onSubmit: _submit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _submit([String? _]) {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    if (_mode == 'subgoal') {
      widget.onAddSubGoal(v);
    } else {
      widget.onAddMilestone(v);
    }
  }
}

// ─── Sheet: SubGoal ───────────────────────────────────────────────────────────

class _SubGoalSheet extends ConsumerStatefulWidget {
  const _SubGoalSheet({
    required this.sg,
    required this.sc,
    required this.goalId,
    this.canEdit = true,
    this.onAddTask,
    this.onAddSubGoal,
    this.onComplete,
    this.onUnparent,
    this.onDelete,
  });
  final SubGoal sg;
  final SieColors sc;
  final String goalId;
  final bool canEdit;
  final void Function(String name, int weight)? onAddTask;
  final ValueChanged<String>? onAddSubGoal;
  final VoidCallback? onComplete;
  final VoidCallback? onUnparent;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_SubGoalSheet> createState() => _SubGoalSheetState();
}

class _SubGoalSheetState extends ConsumerState<_SubGoalSheet> {
  bool _adding = false;
  bool _addingSubGoal = false;
  final _ctrl = TextEditingController();
  final _sgCtrl = TextEditingController();
  int _weight = 1;

  @override
  void dispose() {
    _ctrl.dispose();
    _sgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    final attachments = ref.watch(
      planningProvider.select((s) {
        final goals = s.valueOrNull?.goals ?? const [];
        for (final g in goals) {
          if (g.id == widget.goalId) return g.attachmentsFor(widget.sg.id);
        }
        return const <NodeAttachment>[];
      }),
    );
    final (assigneeIds, collabs, ownerProfile, ownerId) = ref.watch(
      planningProvider.select((s) {
        final g = s.valueOrNull?.goals
            .where((g) => g.id == widget.goalId)
            .firstOrNull;
        if (g == null) {
          return (widget.sg.assigneeIds, const <GoalCollaborator>[], null as PublicProfile?, '');
        }
        SubGoal? find(List<SubGoal> sgs) {
          for (final sg in sgs) {
            if (sg.id == widget.sg.id) return sg;
            final found = find(sg.children);
            if (found != null) return found;
          }
          return null;
        }
        final ids = find(g.subGoals)?.assigneeIds ?? widget.sg.assigneeIds;
        final accepted = g.collaborators
            .where((co) => co.status == 'accepted')
            .toList();
        return (ids, accepted, g.ownerProfile, g.userId);
      }),
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: widget.sg.name, icon: Icons.layers_outlined, sc: c),
          const SizedBox(height: 12),
          AttachmentGallery(
            goalId: widget.goalId,
            nodeType: 'subgoal',
            nodeId: widget.sg.id,
            attachments: attachments,
            canEdit: widget.canEdit,
            compactMode: true,
          ),
          const SizedBox(height: 8),
          _AssigneeRow(
            nodeType: 'subgoal',
            nodeId: widget.sg.id,
            goalId: widget.goalId,
            assigneeIds: assigneeIds,
            collabs: collabs,
            ownerProfile: ownerProfile,
            ownerId: ownerId,
            canEdit: widget.canEdit,
            sc: c,
          ),
          const SizedBox(height: 12),
          if (!_adding && !_addingSubGoal) ...[
            if (widget.onComplete != null) ...[
              _ActionBtn(
                  label: 'Завершить',
                  icon: Icons.check_circle_outline,
                  color: c.accent,
                  sc: c,
                  onTap: widget.onComplete!),
              const SizedBox(height: 8),
            ],
            if (widget.onAddTask != null) ...[
              _ActionBtn(
                  label: 'Добавить задачу',
                  icon: Icons.add_task,
                  color: c.accent,
                  sc: c,
                  onTap: () => setState(() => _adding = true)),
              const SizedBox(height: 8),
            ],
            if (widget.onAddSubGoal != null) ...[
              _ActionBtn(
                  label: 'Добавить под-этап',
                  icon: Icons.account_tree_outlined,
                  color: c.accent,
                  sc: c,
                  onTap: () => setState(() => _addingSubGoal = true)),
              const SizedBox(height: 8),
            ],
            if (widget.onUnparent != null) ...[
              _ActionBtn(
                  label: 'Вынести на уровень выше',
                  icon: Icons.arrow_upward_outlined,
                  color: c.textSecondary,
                  sc: c,
                  onTap: widget.onUnparent!),
              const SizedBox(height: 8),
            ],
            if (widget.onDelete != null)
              _ActionBtn(
                  label: 'Удалить',
                  icon: Icons.delete_outline,
                  color: const Color(0xFFE03050),
                  sc: c,
                  onTap: widget.onDelete!),
          ] else if (_addingSubGoal) ...[
            _StyledTextField(ctrl: _sgCtrl, hint: 'Название под-этапа', sc: c,
                onSubmit: _submitSubGoal),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _addingSubGoal = false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Отмена', style: TextStyle(color: c.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitSubGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.background,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
          ] else ...[
            _StyledTextField(ctrl: _ctrl, hint: 'Название задачи', sc: c, onSubmit: _submitTask),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Вес:', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                for (final w in [1, 3, 5])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _weight = w),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _weight == w ? c.accent : c.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _weight == w ? c.accent : c.border),
                        ),
                        child: Text('×$w',
                            style: TextStyle(
                              color: _weight == w ? c.background : c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _adding = false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Отмена', style: TextStyle(color: c.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submitTask(null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.background,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _submitTask([String? _]) {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onAddTask?.call(v, _weight);
  }

  void _submitSubGoal([String? _]) {
    final v = _sgCtrl.text.trim();
    if (v.isEmpty) return;
    widget.onAddSubGoal?.call(v);
  }
}

// ─── Sheet: Task ──────────────────────────────────────────────────────────────

class _TaskSheet extends ConsumerWidget {
  const _TaskSheet({
    required this.task,
    required this.sc,
    required this.goalId,
    this.canEdit = true,
    this.onToggle,
    this.onDelete,
  });
  final PlanningTask task;
  final SieColors sc;
  final String goalId;
  final bool canEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = sc;
    final attachments = ref.watch(
      planningProvider.select((s) {
        final goals = s.valueOrNull?.goals ?? const [];
        for (final g in goals) {
          if (g.id == goalId) return g.attachmentsFor(task.id);
        }
        return const <NodeAttachment>[];
      }),
    );
    final (assigneeIds, collabs, ownerProfile, ownerId) = ref.watch(
      planningProvider.select((s) {
        final g = s.valueOrNull?.goals
            .where((g) => g.id == goalId)
            .firstOrNull;
        if (g == null) {
          return (task.assigneeIds, const <GoalCollaborator>[], null as PublicProfile?, '');
        }
        List<String> findIds(List<SubGoal> sgs) {
          for (final sg in sgs) {
            for (final t in sg.tasks) {
              if (t.id == task.id) return t.assigneeIds;
            }
            final found = findIds(sg.children);
            if (found.isNotEmpty) return found;
          }
          return task.assigneeIds;
        }
        final ids = findIds(g.subGoals);
        final accepted = g.collaborators
            .where((co) => co.status == 'accepted')
            .toList();
        return (ids, accepted, g.ownerProfile, g.userId);
      }),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SheetHeader(title: task.name, icon: Icons.task_alt, sc: c),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('×${task.weight}',
                    style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AttachmentGallery(
            goalId: goalId,
            nodeType: 'task',
            nodeId: task.id,
            attachments: attachments,
            canEdit: canEdit,
            compactMode: true,
          ),
          const SizedBox(height: 8),
          _AssigneeRow(
            nodeType: 'task',
            nodeId: task.id,
            goalId: goalId,
            assigneeIds: assigneeIds,
            collabs: collabs,
            ownerProfile: ownerProfile,
            ownerId: ownerId,
            canEdit: canEdit,
            sc: c,
          ),
          const SizedBox(height: 12),
          if (onToggle != null) ...[
            _ActionBtn(
              label: task.isCompleted ? 'Отметить невыполненной' : 'Выполнено',
              icon: task.isCompleted ? Icons.radio_button_unchecked : Icons.check_circle_outline,
              color: c.accent,
              sc: c,
              onTap: onToggle!,
            ),
            const SizedBox(height: 8),
          ],
          if (onDelete != null)
            _ActionBtn(
                label: 'Удалить',
                icon: Icons.delete_outline,
                color: const Color(0xFFE03050),
                sc: c,
                onTap: onDelete!),
        ],
      ),
    );
  }
}

// ─── Sheet: Milestone ─────────────────────────────────────────────────────────

class _MilestoneSheet extends ConsumerWidget {
  const _MilestoneSheet({
    required this.ms,
    required this.sc,
    required this.goalId,
    this.canEdit = true,
    this.onComplete,
    this.onDelete,
  });
  final Milestone ms;
  final SieColors sc;
  final String goalId;
  final bool canEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = sc;
    final attachments = ref.watch(
      planningProvider.select((s) {
        final goals = s.valueOrNull?.goals ?? const [];
        for (final g in goals) {
          if (g.id == goalId) return g.attachmentsFor(ms.id);
        }
        return const <NodeAttachment>[];
      }),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
              title: ms.name,
              icon: ms.isCompleted ? Icons.flag : Icons.outlined_flag,
              sc: c,
              iconColor: c.accentSecondary),
          if (ms.targetDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Цель: ${ms.targetDate!.day}.${ms.targetDate!.month.toString().padLeft(2, '0')}.${ms.targetDate!.year}',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          AttachmentGallery(
            goalId: goalId,
            nodeType: 'milestone',
            nodeId: ms.id,
            attachments: attachments,
            canEdit: canEdit,
            compactMode: true,
          ),
          const SizedBox(height: 12),
          if (onComplete != null) ...[
            _ActionBtn(
                label: 'Достигнут',
                icon: Icons.flag,
                color: c.accentSecondary,
                sc: c,
                onTap: onComplete!),
            const SizedBox(height: 8),
          ],
          if (onDelete != null)
            _ActionBtn(
                label: 'Удалить',
                icon: Icons.delete_outline,
                color: const Color(0xFFE03050),
                sc: c,
                onTap: onDelete!),
        ],
      ),
    );
  }
}

// ─── Sheet: Habit Link ────────────────────────────────────────────────────────

class _HabitLinkSheet extends StatelessWidget {
  const _HabitLinkSheet(
      {required this.link, required this.sc, required this.onUnlink});
  final GoalHabitLink link;
  final SieColors sc;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: 'Связанная привычка', icon: Icons.link, sc: c, iconColor: c.dp),
          const SizedBox(height: 16),
          _ActionBtn(
              label: 'Отвязать привычку',
              icon: Icons.link_off,
              color: const Color(0xFFE03050),
              sc: c,
              onTap: onUnlink),
        ],
      ),
    );
  }
}

// ─── Attachment badge (map nodes) ─────────────────────────────────────────────

class _AttachmentBadge extends StatelessWidget {
  const _AttachmentBadge({required this.count, required this.sc});
  final int count;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: sc.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sc.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 8, color: sc.textSecondary),
          Text(
            '$count',
            style: TextStyle(color: sc.textSecondary, fontSize: 8, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Stage 5: Member Legend Overlay ──────────────────────────────────────────

// ─── Stage 8: live collaboration ─────────────────────────────────────────────

/// Interpolated state for a remote participant's cursor (logical coords).
class _RemoteCursor {
  _RemoteCursor(this.targetX, this.targetY)
      : x = targetX,
        y = targetY;
  double x, y; // current (eased) position
  double targetX, targetY; // latest received position
  int lastSeenMs = 0;
}

/// Canvas-space overlay: remote cursors + "editing" soft-lock badges.
/// Lives inside the canvas SizedBox, so positions map as `cx + logical`.
class _LiveOverlayLayer extends StatelessWidget {
  const _LiveOverlayLayer({
    required this.cursors,
    required this.editing,
    required this.positions,
    required this.elementPositions,
    required this.memberInfo,
    required this.cx,
  });
  final Map<String, _RemoteCursor> cursors;
  final Map<String, ({String userId, int atMs})> editing;
  final Map<String, Offset> positions;
  final Map<String, Offset> elementPositions;
  final Map<String, ({Color color, String name})> memberInfo;
  final double cx;

  @override
  Widget build(BuildContext context) {
    const fallback = Color(0xFF888898);
    final children = <Widget>[];

    editing.forEach((ref, e) {
      Offset? pos;
      if (ref.startsWith('node:')) {
        pos = positions[ref.substring(5)];
      } else if (ref.startsWith('el:')) {
        pos = elementPositions[ref.substring(3)];
      }
      if (pos == null) return;
      final info = memberInfo[e.userId];
      children.add(Positioned(
        left: cx + pos.dx,
        top: cx + pos.dy - 30,
        child: FractionalTranslation(
          translation: const Offset(-0.5, 0),
          child: _EditingBadge(
              color: info?.color ?? fallback, name: info?.name ?? '…'),
        ),
      ));
    });

    cursors.forEach((userId, cur) {
      final info = memberInfo[userId];
      children.add(Positioned(
        left: cx + cur.x,
        top: cx + cur.y,
        child: _CursorMarker(
            color: info?.color ?? fallback, name: info?.name ?? '…'),
      ));
    });

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class _CursorMarker extends StatelessWidget {
  const _CursorMarker({required this.color, required this.name});
  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.rotate(
          angle: -math.pi / 5,
          child: Icon(Icons.navigation, size: 18, color: color, shadows: const [
            Shadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EditingBadge extends StatelessWidget {
  const _EditingBadge({required this.color, required this.name});
  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 9, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$name редактирует',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MemberLegendOverlay extends ConsumerWidget {
  const _MemberLegendOverlay({
    required this.goal,
    required this.sc,
    required this.filterMemberId,
    required this.onMemberTap,
    this.liveUserIds = const {},
    this.followingId,
    this.onFollow,
  });
  final Goal goal;
  final SieColors sc;
  final String? filterMemberId;
  final ValueChanged<String> onMemberTap;
  // Stage 8: users currently broadcasting a live cursor + follow-mode wiring.
  final Set<String> liveUserIds;
  final String? followingId;
  final ValueChanged<String>? onFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = sc;
    final members = <({String userId, String? avatarUrl, String label})>[];
    members.add((
      userId: goal.userId,
      avatarUrl: goal.ownerProfile?.avatarUrl,
      label: goal.ownerProfile?.username ?? 'Владелец',
    ));
    for (final co in goal.collaborators.where((co) => co.status == 'accepted')) {
      members.add((
        userId: co.userId,
        avatarUrl: co.profile?.avatarUrl,
        label: co.profile?.username ?? co.userId.substring(0, 6),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Участники',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          for (final m in members)
            GestureDetector(
              onTap: () => onMemberTap(m.userId),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: filterMemberId == m.userId
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: memberColor(m.userId, c), width: 2))
                          : null,
                      child: _MiniAvatar(
                        userId: m.userId,
                        avatarUrl: m.avatarUrl,
                        color: memberColor(m.userId, c),
                        sc: c,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      m.label,
                      style: TextStyle(
                        color: filterMemberId == m.userId
                            ? memberColor(m.userId, c)
                            : c.textSecondary,
                        fontSize: 9,
                        fontWeight: filterMemberId == m.userId
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    // Stage 8: live presence dot + follow toggle.
                    if (liveUserIds.contains(m.userId)) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Color(0xFF27AE60)),
                      ),
                      if (onFollow != null) ...[
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: () => onFollow!(m.userId),
                          child: Icon(
                            followingId == m.userId
                                ? Icons.my_location
                                : Icons.location_searching,
                            size: 12,
                            color: followingId == m.userId
                                ? memberColor(m.userId, c)
                                : c.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stage 5: Assignee row in sheets ─────────────────────────────────────────

class _AssigneeRow extends ConsumerWidget {
  const _AssigneeRow({
    required this.nodeType,
    required this.nodeId,
    required this.goalId,
    required this.assigneeIds,
    required this.collabs,
    required this.ownerProfile,
    required this.ownerId,
    required this.canEdit,
    required this.sc,
  });
  final String nodeType;
  final String nodeId;
  final String goalId;
  final List<String> assigneeIds;
  final List<GoalCollaborator> collabs;
  final PublicProfile? ownerProfile;
  final String ownerId;
  final bool canEdit;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = sc;
    if (collabs.isEmpty && assigneeIds.isEmpty) return const SizedBox.shrink();

    final allMembers = <({String userId, String? avatarUrl, String label})>[
      (
        userId: ownerId,
        avatarUrl: ownerProfile?.avatarUrl,
        label: ownerProfile?.username ?? 'Владелец',
      ),
      for (final co in collabs)
        (
          userId: co.userId,
          avatarUrl: co.profile?.avatarUrl,
          label: co.profile?.username ?? co.userId.substring(0, 6),
        ),
    ];

    return Row(
      children: [
        Icon(Icons.person_outline, size: 14, color: c.textSecondary),
        const SizedBox(width: 6),
        Text('Исполнитель',
            style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(width: 8),
        if (assigneeIds.isEmpty)
          Text('не назначен',
              style: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.6), fontSize: 11))
        else
          for (final uid in assigneeIds)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _MiniAvatar(
                userId: uid,
                avatarUrl: allMembers
                    .where((m) => m.userId == uid)
                    .firstOrNull
                    ?.avatarUrl,
                color: memberColor(uid, c),
                sc: c,
                size: 20,
              ),
            ),
        if (canEdit && allMembers.isNotEmpty) ...[
          const Spacer(),
          GestureDetector(
            onTap: () => _showPicker(context, ref, allMembers),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Изменить',
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<({String userId, String? avatarUrl, String label})> members,
  ) {
    final c = sc;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Назначить исполнителя',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            for (final m in members) ...[
              Consumer(builder: (_, ref2, __) {
                final ids = ref2.watch(planningProvider.select((s) {
                  final g = s.valueOrNull?.goals
                      .where((g) => g.id == goalId)
                      .firstOrNull;
                  if (g == null) return assigneeIds;
                  if (nodeType == 'task') {
                    List<String> find(List<SubGoal> sgs) {
                      for (final sg in sgs) {
                        for (final t in sg.tasks) {
                          if (t.id == nodeId) return t.assigneeIds;
                        }
                        final f = find(sg.children);
                        if (f.isNotEmpty) return f;
                      }
                      return assigneeIds;
                    }
                    return find(g.subGoals);
                  } else {
                    SubGoal? find(List<SubGoal> sgs) {
                      for (final sg in sgs) {
                        if (sg.id == nodeId) return sg;
                        final f = find(sg.children);
                        if (f != null) return f;
                      }
                      return null;
                    }
                    return find(g.subGoals)?.assigneeIds ?? assigneeIds;
                  }
                }));
                final isAssigned = ids.contains(m.userId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _MiniAvatar(
                    userId: m.userId,
                    avatarUrl: m.avatarUrl,
                    color: memberColor(m.userId, c),
                    sc: c,
                    size: 32,
                  ),
                  title: Text(m.label,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  trailing: isAssigned
                      ? Icon(Icons.check_circle, color: c.accent, size: 20)
                      : Icon(Icons.radio_button_unchecked,
                          color: c.border, size: 20),
                  onTap: () {
                    if (isAssigned) {
                      ref2.read(planningProvider.notifier).unassignNode(
                            nodeType: nodeType,
                            nodeId: nodeId,
                            userId: m.userId,
                            goalId: goalId,
                          );
                    } else {
                      ref2.read(planningProvider.notifier).assignNode(
                            nodeType: nodeType,
                            nodeId: nodeId,
                            userId: m.userId,
                            goalId: goalId,
                          );
                    }
                  },
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Mini avatar badge for assigned nodes ────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({
    required this.userId,
    required this.color,
    required this.sc,
    this.avatarUrl,
    this.size = 18,
  });
  final String userId;
  final String? avatarUrl;
  final Color color;
  final SieColors sc;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.85),
        border: Border.all(color: sc.background, width: 1),
      ),
      child: avatarUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initial(),
              ),
            )
          : _initial(),
    );
  }

  Widget _initial() {
    final letter = userId.isNotEmpty ? userId[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Shared sheet widgets ─────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(
      {required this.title,
      required this.icon,
      required this.sc,
      this.iconColor});
  final String title;
  final IconData icon;
  final SieColors sc;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Row(
      children: [
        Icon(icon, color: iconColor ?? c.accent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
                color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.sc,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.selected,
      required this.sc,
      required this.onTap});
  final String label;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.background : c.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Zoom Button ──────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  const _ZoomButton(
      {required this.icon,
      required this.onTap,
      required this.sc,
      this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final SieColors sc;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? sc.accent.withValues(alpha: 0.9)
              : sc.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? sc.accent : sc.border),
        ),
        child: Icon(icon,
            size: 16, color: active ? sc.background : sc.textSecondary),
      ),
    );
  }
}

// ─── Stage 7: mini-map ────────────────────────────────────────────────────────

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.positions,
    required this.elementPositions,
    required this.repaint,
    required this.tc,
    required this.viewportSize,
    required this.cx,
    required this.sc,
    required this.onTapCanvas,
  });
  final Map<String, Offset> positions;
  final Map<String, Offset> elementPositions;
  final Listenable repaint;
  final TransformationController tc;
  final Size viewportSize;
  final double cx;
  final SieColors sc;
  final ValueChanged<Offset> onTapCanvas; // logical coords

  static const double _size = 110;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: sc.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AnimatedBuilder(
          animation: Listenable.merge([tc, repaint]),
          builder: (_, __) {
            final bounds = _contentBounds();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handleTap(d.localPosition, bounds),
              onPanUpdate: (d) => _handleTap(d.localPosition, bounds),
              child: CustomPaint(
                size: const Size(_size, _size),
                painter: _MiniMapPainter(
                  positions: positions,
                  elementPositions: elementPositions,
                  bounds: bounds,
                  tc: tc,
                  viewportSize: viewportSize,
                  cx: cx,
                  dot: sc.textSecondary,
                  accent: sc.accent,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Square bounding box of all content in CANVAS coords (with padding).
  Rect _contentBounds() {
    final pts = <Offset>[];
    positions.forEach((_, p) => pts.add(Offset(cx + p.dx, cx + p.dy)));
    elementPositions.forEach((_, p) => pts.add(Offset(cx + p.dx, cx + p.dy)));
    if (pts.isEmpty) {
      return Rect.fromLTWH(cx - 400, cx - 400, 800, 800);
    }
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const pad = 220.0;
    final r = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
    final side = math.max(r.width, r.height);
    return Rect.fromCenter(center: r.center, width: side, height: side);
  }

  void _handleTap(Offset local, Rect bounds) {
    final fx = (local.dx / _size).clamp(0.0, 1.0);
    final fy = (local.dy / _size).clamp(0.0, 1.0);
    final canvasX = bounds.left + fx * bounds.width;
    final canvasY = bounds.top + fy * bounds.height;
    onTapCanvas(Offset(canvasX - cx, canvasY - cx));
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.positions,
    required this.elementPositions,
    required this.bounds,
    required this.tc,
    required this.viewportSize,
    required this.cx,
    required this.dot,
    required this.accent,
  });
  final Map<String, Offset> positions;
  final Map<String, Offset> elementPositions;
  final Rect bounds;
  final TransformationController tc;
  final Size viewportSize;
  final double cx;
  final Color dot;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    Offset toMini(Offset canvasPt) => Offset(
          (canvasPt.dx - bounds.left) / bounds.width * size.width,
          (canvasPt.dy - bounds.top) / bounds.height * size.height,
        );

    final elPaint = Paint()..color = accent.withValues(alpha: 0.45);
    elementPositions.forEach((_, p) {
      canvas.drawCircle(toMini(Offset(cx + p.dx, cx + p.dy)), 1.1, elPaint);
    });

    final dotPaint = Paint()..color = dot.withValues(alpha: 0.75);
    positions.forEach((_, p) {
      canvas.drawCircle(toMini(Offset(cx + p.dx, cx + p.dy)), 1.7, dotPaint);
    });

    // Viewport frame: visible canvas region derived from the live transform.
    final tl = tc.toScene(Offset.zero);
    final br = tc.toScene(Offset(viewportSize.width, viewportSize.height));
    final frame = Rect.fromPoints(toMini(tl), toMini(br));
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent;
    canvas.drawRect(frame, framePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => true;
}

// ─── Stage 7: search panel ────────────────────────────────────────────────────

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.ctrl,
    required this.sc,
    required this.results,
    required this.onChanged,
    required this.onPick,
    required this.onClose,
  });
  final TextEditingController ctrl;
  final SieColors sc;
  final List<({String id, String label, IconData icon, Offset pos})> results;
  final ValueChanged<String> onChanged;
  final void Function(String id, Offset pos) onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: c.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Поиск по карте…',
                      hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: c.textSecondary),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          if (results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final r = results[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(r.icon, size: 18, color: c.accent),
                    title: Text(
                      r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                    ),
                    onTap: () => onPick(r.id, r.pos),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField(
      {required this.ctrl,
      required this.hint,
      required this.sc,
      this.onSubmit});
  final TextEditingController ctrl;
  final String hint;
  final SieColors sc;
  final ValueChanged<String>? onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return TextField(
      controller: ctrl,
      autofocus: true,
      style: TextStyle(color: c.textPrimary),
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary),
        filled: true,
        fillColor: c.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}

// ─── Tactical Map Evolution Stage 1: map-native elements UI ───────────────────

/// Active placement tool in edit mode.
enum _MapTool { none, note, label, connector, image }

/// Floating button to enter/exit the map edit mode.
class _EditModeButton extends StatelessWidget {
  const _EditModeButton(
      {required this.active, required this.onTap, required this.sc});
  final bool active;
  final VoidCallback onTap;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? sc.accent.withValues(alpha: 0.16) : sc.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? sc.accent : sc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.check : Icons.edit_outlined,
                size: 15, color: active ? sc.accent : sc.textSecondary),
            const SizedBox(width: 7),
            Text(
              active ? 'ГОТОВО' : 'РЕДАКТ.',
              style: TextStyle(
                color: active ? sc.accent : sc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom tool palette shown while edit mode is active.
class _MapToolPalette extends StatelessWidget {
  const _MapToolPalette(
      {required this.visible,
      required this.tool,
      required this.onPick,
      required this.sc});
  final bool visible;
  final _MapTool tool;
  final ValueChanged<_MapTool> onPick;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: sc.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sc.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MapToolChip(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Заметка',
                  selected: tool == _MapTool.note,
                  sc: sc,
                  onTap: () => onPick(_MapTool.note),
                ),
                const SizedBox(width: 8),
                _MapToolChip(
                  icon: Icons.text_fields,
                  label: 'Метка',
                  selected: tool == _MapTool.label,
                  sc: sc,
                  onTap: () => onPick(_MapTool.label),
                ),
                const SizedBox(width: 8),
                _MapToolChip(
                  icon: Icons.arrow_forward,
                  label: 'Связь',
                  selected: tool == _MapTool.connector,
                  sc: sc,
                  onTap: () => onPick(_MapTool.connector),
                ),
                const SizedBox(width: 8),
                _MapToolChip(
                  icon: Icons.image_outlined,
                  label: 'Изобр.',
                  selected: false,
                  sc: sc,
                  onTap: () => onPick(_MapTool.image),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapToolChip extends StatelessWidget {
  const _MapToolChip(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
      required this.sc});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? sc.accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? sc.accent : sc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? sc.accent : sc.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? sc.accent : sc.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sticky note element on the canvas.
class _NoteElement extends StatelessWidget {
  const _NoteElement({
    required this.element,
    required this.color,
    required this.sc,
    required this.editing,
    required this.canEdit,
    required this.onSubmit,
    this.controller,
    this.onResize,
    this.onResizeEnd,
  });
  final MapElement element;
  final Color color;
  final SieColors sc;
  final bool editing;
  final bool canEdit;
  final VoidCallback onSubmit;
  final TextEditingController? controller;
  final ValueChanged<Offset>? onResize;
  final VoidCallback? onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final text = element.content ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.65), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: editing && controller != null
              ? TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(color: sc.textPrimary, fontSize: 13, height: 1.3),
                  cursorColor: color,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Заметка…',
                    hintStyle: TextStyle(color: sc.textSecondary, fontSize: 13),
                  ),
                  onTapOutside: (_) => onSubmit(),
                )
              : Text(
                  text.isEmpty ? 'Заметка…' : text,
                  style: TextStyle(
                    color: text.isEmpty ? sc.textSecondary : sc.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
        ),
        if (!editing && canEdit && onResize != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onResize!(d.delta),
              onPanEnd: (_) => onResizeEnd?.call(),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.bottomRight,
                child: Icon(Icons.open_in_full,
                    size: 13, color: color.withValues(alpha: 0.8)),
              ),
            ),
          ),
      ],
    );
  }
}

/// A free text label element (no background).
class _LabelElement extends StatelessWidget {
  const _LabelElement({
    required this.element,
    required this.color,
    required this.sc,
    required this.editing,
    required this.onSubmit,
    this.controller,
  });
  final MapElement element;
  final Color color;
  final SieColors sc;
  final bool editing;
  final VoidCallback onSubmit;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final text = element.content ?? '';
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: editing && controller != null
          ? TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
              cursorColor: color,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Метка…',
                hintStyle: TextStyle(color: sc.textSecondary, fontSize: 16),
              ),
              onTapOutside: (_) => onSubmit(),
              onSubmitted: (_) => onSubmit(),
            )
          : Text(
              text.isEmpty ? 'Метка…' : text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text.isEmpty ? sc.textSecondary : color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(color: sc.background.withValues(alpha: 0.8), blurRadius: 6),
                ],
              ),
            ),
    );
  }
}

/// Long-press actions for a map element: recolor / edit text / delete.
class _ElementActionsSheet extends StatelessWidget {
  const _ElementActionsSheet({
    required this.element,
    required this.sc,
    required this.colors,
    required this.onPickColor,
    required this.onEditText,
    required this.onDelete,
  });
  final MapElement element;
  final SieColors sc;
  final List<String> colors;
  final ValueChanged<String> onPickColor;
  final VoidCallback onEditText;
  final VoidCallback onDelete;

  Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: sc.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            element.kind == MapElementKind.note ? 'ЗАМЕТКА' : 'МЕТКА',
            style: TextStyle(
                color: sc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 14),
          Text('Цвет',
              style: TextStyle(color: sc.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final hex in colors) ...[
                GestureDetector(
                  onTap: () => onPickColor(hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _hex(hex).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: element.colorHex == hex ? sc.textPrimary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _ActionBtn(
            label: 'Изменить текст',
            icon: Icons.edit_outlined,
            color: sc.accent,
            sc: sc,
            onTap: onEditText,
          ),
          const SizedBox(height: 10),
          _ActionBtn(
            label: 'Удалить',
            icon: Icons.delete_outline,
            color: sc.danger,
            sc: sc,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Tactical Map Evolution Stage 4: connectors ────────────────────────────────

/// Resolved connector geometry (canvas-space) plus its rendered style.
class _ConnectorData {
  const _ConnectorData({
    required this.id,
    required this.src,
    required this.dst,
    required this.dashed,
    required this.color,
    this.label,
  });
  final String id;
  final Offset src; // canvas space
  final Offset dst; // canvas space
  final bool dashed;
  final Color color;
  final String? label;
}

/// A node bounding circle used as a routing obstacle for connectors.
class _ObstacleCircle {
  const _ObstacleCircle({required this.center, required this.radius});
  final Offset center; // canvas space
  final double radius;
}

/// Paints free connectors with smart routing — a Bezier that bends around node
/// obstacles lying close to the straight src→dst line. Distinct from
/// [_EdgePainter] (hierarchy/dependencies) by colour, curvature and arrowhead.
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter(this.connectors, this.c, this.obstacles);
  final List<_ConnectorData> connectors;
  final SieColors c;
  final List<_ObstacleCircle> obstacles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connectors) {
      _drawConnector(canvas, conn);
    }
  }

  void _drawConnector(Canvas canvas, _ConnectorData conn) {
    final diff = conn.dst - conn.src;
    final dist = diff.distance;
    if (dist < 2) return;
    final dir = diff / dist;

    final path = _routeConnector(conn.src, conn.dst, dir, dist);
    final paint = Paint()
      ..color = conn.color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (conn.dashed) {
      _drawDashed(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    final tip = conn.dst - dir * 20.0;
    _drawArrowHead(canvas, tip, dir, conn.color);

    if (conn.label != null) {
      final mid = _pathMidpoint(path);
      final tp = TextPainter(
        text: TextSpan(
          text: conn.label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      final bgRect = Rect.fromCenter(
          center: mid, width: tp.width + 12, height: tp.height + 6);
      final rr = RRect.fromRectAndRadius(bgRect, const Radius.circular(4));
      canvas.drawRRect(
          rr, Paint()..color = c.surface.withValues(alpha: 0.9));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = conn.color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Builds a cubic path from src→dst, deflected sideways to avoid obstacles
  /// near the mid-section of the straight line (cheap path-avoidance).
  Path _routeConnector(Offset src, Offset dst, Offset dir, double dist) {
    final normal = Offset(-dir.dy, dir.dx);
    double deflect = 0;
    for (final obs in obstacles) {
      // Projection of the obstacle centre onto the src→dst line.
      final rel = obs.center - src;
      final t = rel.dx * dir.dx + rel.dy * dir.dy;
      if (t < dist * 0.1 || t > dist * 0.9) continue;
      final closest = src + dir * t.clamp(0.0, dist);
      final closeDist = (closest - obs.center).distance;
      final threshold = obs.radius + 28.0;
      if (closeDist < threshold) {
        final pen = threshold - closeDist;
        // Which side is the obstacle on? Push the curve the other way.
        final side = rel.dx * (dst - src).dy - rel.dy * (dst - src).dx;
        deflect += side > 0 ? -pen * 1.8 : pen * 1.8;
      }
    }
    final cp1 = Offset(
      src.dx + dir.dx * dist * 0.35 + normal.dx * deflect * 0.6,
      src.dy + dir.dy * dist * 0.35 + normal.dy * deflect * 0.6,
    );
    final cp2 = Offset(
      src.dx + dir.dx * dist * 0.65 + normal.dx * deflect * 0.6,
      src.dy + dir.dy * dist * 0.65 + normal.dy * deflect * 0.6,
    );
    return Path()
      ..moveTo(src.dx, src.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, dst.dx, dst.dy);
  }

  Offset _pathMidpoint(Path path) {
    for (final m in path.computeMetrics()) {
      final tangent = m.getTangentForOffset(m.length / 2);
      if (tangent != null) return tangent.position;
    }
    return Offset.zero;
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 7.0, gap = 4.0;
    for (final m in path.computeMetrics()) {
      double d = 0;
      bool draw = true;
      while (d < m.length) {
        final len = draw ? dash : gap;
        if (draw) {
          canvas.drawPath(
              m.extractPath(d, math.min(d + len, m.length)), paint);
        }
        d += len;
        draw = !draw;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset dir, Color color) {
    const sz = 9.0;
    final back = tip - dir * sz;
    final n = Offset(-dir.dy, dir.dx) * (sz * 0.5);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + n.dx, back.dy + n.dy)
      ..lineTo(back.dx - n.dx, back.dy - n.dy)
      ..close();
    canvas.drawPath(
        path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      !identical(old.connectors, connectors) || old.c != c;
}

/// Long-press / tap-midpoint actions for a connector: label / style / delete.
class _ConnectorActionsSheet extends StatefulWidget {
  const _ConnectorActionsSheet({
    required this.element,
    required this.sc,
    required this.colors,
    required this.onPickColor,
    required this.onToggleDash,
    required this.onEditLabel,
    required this.onDelete,
  });
  final MapElement element;
  final SieColors sc;
  final List<String> colors;
  final ValueChanged<String> onPickColor;
  final VoidCallback onToggleDash;
  final ValueChanged<String> onEditLabel;
  final VoidCallback onDelete;

  @override
  State<_ConnectorActionsSheet> createState() => _ConnectorActionsSheetState();
}

class _ConnectorActionsSheetState extends State<_ConnectorActionsSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.element.content ?? '');

  Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    final isDashed = widget.element.styleJson?['dashed'] == true;
    final styleColor = widget.element.styleJson?['color'] as String?;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('СВЯЗЬ',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Text('Подпись',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: TextStyle(color: c.textPrimary),
                onSubmitted: widget.onEditLabel,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Без подписи…',
                  hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.accent)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => widget.onEditLabel(_ctrl.text.trim()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                    color: c.accent, borderRadius: BorderRadius.circular(10)),
                child: Text('OK',
                    style: TextStyle(
                        color: c.background, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _ActionBtn(
            label: isDashed ? 'Сделать сплошной' : 'Сделать пунктирной',
            icon: isDashed ? Icons.horizontal_rule : Icons.more_horiz,
            color: c.accent,
            sc: c,
            onTap: widget.onToggleDash,
          ),
          const SizedBox(height: 14),
          Text('Цвет',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final hex in widget.colors) ...[
                GestureDetector(
                  onTap: () => widget.onPickColor(hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _hex(hex).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: styleColor == hex
                            ? c.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _ActionBtn(
            label: 'Удалить',
            icon: Icons.delete_outline,
            color: const Color(0xFFE03050),
            sc: c,
            onTap: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Tactical Map Evolution Stage 3: image cards ──────────────────────────────

/// An image card rendered on the canvas background layer. Displays a
/// [CachedNetworkImage] with an optional caption strip below it.
/// Rotation is stored in `styleJson['rotation']` as quarter-turns (0–3).
class _ImageCardElement extends StatelessWidget {
  const _ImageCardElement({
    required this.element,
    required this.quarterTurns,
    required this.sc,
    required this.canEdit,
    this.onResize,
    this.onResizeEnd,
  });
  final MapElement element;
  final int quarterTurns;
  final SieColors sc;
  final bool canEdit;
  final ValueChanged<Offset>? onResize;
  final VoidCallback? onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final caption =
        element.content?.isNotEmpty == true ? element.content! : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sc.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              children: [
                Expanded(
                  child: RotatedBox(
                    quarterTurns: quarterTurns,
                    child: CachedNetworkImage(
                      imageUrl: element.mediaUrl ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) => Container(
                        color: sc.surface,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: sc.accent),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: sc.surface,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: sc.textSecondary, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                if (caption != null)
                  Container(
                    width: double.infinity,
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    color: sc.surface.withValues(alpha: 0.92),
                    alignment: Alignment.center,
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sc.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (canEdit && onResize != null)
          Positioned(
            right: -4,
            bottom: -4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onResize!(d.delta),
              onPanEnd: (_) => onResizeEnd?.call(),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: sc.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: sc.border),
                ),
                child: Icon(Icons.open_in_full,
                    size: 12, color: sc.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

/// Preview dialog shown before placing an image. Lets the user rotate 90° CW/CCW.
class _ImagePreviewDialog extends StatefulWidget {
  const _ImagePreviewDialog({
    required this.bytes,
    required this.origW,
    required this.origH,
    required this.sc,
  });
  final Uint8List bytes;
  final double origW;
  final double origH;
  final SieColors sc;

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('Предпросмотр',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.rotate_left, color: c.textSecondary),
                    tooltip: 'Повернуть влево',
                    onPressed: () => setState(
                        () => _quarterTurns = (_quarterTurns - 1 + 4) % 4),
                  ),
                  IconButton(
                    icon: Icon(Icons.rotate_right, color: c.textSecondary),
                    tooltip: 'Повернуть вправо',
                    onPressed: () =>
                        setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 340),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: c.background,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.memory(widget.bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Text('Отмена',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.textSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(
                        context,
                        (
                          bytes: widget.bytes,
                          quarterTurns: _quarterTurns,
                          origW: widget.origW,
                          origH: widget.origH,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Разместить',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.background,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Long-press actions for an image card: edit caption and delete.
class _ImageCardActionsSheet extends StatefulWidget {
  const _ImageCardActionsSheet({
    required this.element,
    required this.sc,
    required this.onEditCaption,
    required this.onDelete,
  });
  final MapElement element;
  final SieColors sc;
  final ValueChanged<String> onEditCaption;
  final VoidCallback onDelete;

  @override
  State<_ImageCardActionsSheet> createState() => _ImageCardActionsSheetState();
}

class _ImageCardActionsSheetState extends State<_ImageCardActionsSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.element.content ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'ИЗОБРАЖЕНИЕ',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 14),
            Text('Подпись',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Добавить подпись…',
                      hintStyle: TextStyle(color: c.textSecondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => widget.onEditCaption(_ctrl.text.trim()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('OK',
                        style: TextStyle(
                            color: c.background,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ActionBtn(
              label: 'Удалить',
              icon: Icons.delete_outline,
              color: const Color(0xFFE03050),
              sc: c,
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
