import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'public_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserSearchScreen
// ─────────────────────────────────────────────────────────────────────────────
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clear() {
    _ctrl.clear();
    _debounce?.cancel();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                ctrl: _ctrl,
                focus: _focus,
                onChanged: _onChanged,
                onClear: _clear,
              ),
              Expanded(child: _Body(query: _query)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends ConsumerStatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _TopBar({
    required this.ctrl,
    required this.focus,
    required this.onChanged,
    required this.onClear,
  });

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focus.hasFocus);
  }

  @override
  void dispose() {
    widget.focus.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new,
                color: c.textSecondary, size: 18),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.20),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _focused
                        ? c.accent.withValues(alpha: 0.6)
                        : c.border,
                  ),
                ),
                child: _searchFieldContent(c),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchFieldContent(SieColors c) {
    return Row(
      children: [
        const SizedBox(width: 14),
        Icon(
          Icons.search,
          color: _focused ? c.accent : c.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.ctrl,
            focusNode: widget.focus,
            onChanged: widget.onChanged,
            autofocus: true,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'ПОИСК ОПЕРАТИВНИКА...',
              hintStyle: TextStyle(
                color: _focused ? c.textSecondary : c.iconMuted,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (widget.ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: widget.onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.close, color: c.textSecondary, size: 16),
            ),
          )
        else
          const SizedBox(width: 12),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final String query;
  const _Body({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    if (query.length < 2) {
      return const _StatusMessage(
        icon: Icons.radar,
        text: 'ВВЕДИТЕ ИМЯ ДЛЯ ПОИСКА',
        sub: 'Минимум 2 символа',
      );
    }

    final resultsAsync = ref.watch(userSearchProvider(query));

    return resultsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: c.accent, strokeWidth: 1.5),
      ),
      error: (e, _) => _StatusMessage(
        icon: Icons.error_outline,
        text: 'ОШИБКА СОЕДИНЕНИЯ',
        sub: e.toString(),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const _StatusMessage(
            icon: Icons.person_off_outlined,
            text: 'ОПЕРАТИВНИК НЕ НАЙДЕН',
            sub: 'Попробуйте другой запрос',
          );
        }
        return RefreshIndicator(
          color: c.accent,
          backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
          onRefresh: () async {
            ref.invalidate(userSearchProvider(query));
            await ref.read(userSearchProvider(query).future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => RepaintBoundary(
              child: _UserTile(profile: results[i], query: query),
            ),
          ),
        );
      },
    );
  }
}

// ── Status Placeholder ────────────────────────────────────────

class _StatusMessage extends ConsumerWidget {
  final IconData icon;
  final String text;
  final String sub;
  const _StatusMessage(
      {required this.icon, required this.text, required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.iconMuted, size: 36),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: TextStyle(color: c.iconMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── User Tile ─────────────────────────────────────────────────

class _UserTile extends ConsumerStatefulWidget {
  final PublicProfile profile;
  final String query;
  const _UserTile({required this.profile, required this.query});

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    _pressCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 80), curve: Curves.easeIn);
  }

  void _release() {
    _pressCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _navigate() {
    final profile = widget.profile;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final username = widget.profile.username ?? 'UNKNOWN';
    final letter = username.isNotEmpty ? username[0].toUpperCase() : '?';

    final tileContent = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: c.accent.withValues(alpha: 0.5), width: 1),
            color: c.background,
          ),
          child: ClipOval(
            child: widget.profile.avatarUrl != null
                ? Image.network(
                    widget.profile.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _TileLetter(letter: letter),
                  )
                : _TileLetter(letter: letter),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HighlightedName(
                name: username.toUpperCase(),
                query: widget.query.toUpperCase(),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: c.accent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LEVEL ${widget.profile.level}  ·  ${widget.profile.totalXp} XP',
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right,
            color: c.textSecondary.withValues(alpha: 0.6),
            size: 16),
      ],
    );

    return GestureDetector(
      onTap: _navigate,
      onTapDown: _down,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, child) {
          final t = _pressCtrl.value;
          return Transform.scale(
            scale: 1.0 - 0.03 * t,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: c.flatCard(radius: 16),
              child: child,
            ),
          );
        },
        child: tileContent,
      ),
    );
  }
}

class _TileLetter extends ConsumerWidget {
  final String letter;
  const _TileLetter({required this.letter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: c.accent,
          fontSize: 18,
          fontWeight: FontWeight.w200,
        ),
      ),
    );
  }
}

// ── Highlighted Name ──────────────────────────────────────────

class _HighlightedName extends ConsumerWidget {
  final String name;
  final String query;
  const _HighlightedName({required this.name, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final base = TextStyle(
      color: c.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );

    if (query.isEmpty) return Text('', style: base);

    final idx = name.indexOf(query);
    if (idx == -1) return Text(name, style: base);

    return RichText(
      text: TextSpan(style: base, children: [
        TextSpan(text: name.substring(0, idx)),
        TextSpan(
          text: name.substring(idx, idx + query.length),
          style: base.copyWith(color: c.accent, fontWeight: FontWeight.w700),
        ),
        TextSpan(text: name.substring(idx + query.length)),
      ]),
    );
  }
}
