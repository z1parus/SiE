import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'public_profile_screen.dart';

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
    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(ctrl: _ctrl, focus: _focus, onChanged: _onChanged, onClear: _clear),
            Expanded(child: _Body(query: _query)),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatefulWidget {
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
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(() {
      if (mounted) setState(() => _focused = widget.focus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: SieTheme.textSecondary, size: 18),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: SieTheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _focused ? SieTheme.accent : SieTheme.borderDefault,
                  width: _focused ? 1.5 : 1.0,
                ),
              ),
              child: TextField(
                controller: widget.ctrl,
                focusNode: widget.focus,
                onChanged: widget.onChanged,
                autofocus: true,
                style: const TextStyle(
                  color: SieTheme.textPrimary,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  border: InputBorder.none,
                  hintText: 'ПОИСК ОПЕРАТИВНИКА...',
                  hintStyle: const TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                  prefixIcon: const Icon(Icons.search,
                      color: SieTheme.textSecondary, size: 18),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: widget.ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: widget.onClear,
                          child: const Icon(Icons.close,
                              color: SieTheme.textSecondary, size: 16),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final String query;
  const _Body({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.length < 2) {
      return const _StatusMessage(
        icon: Icons.radar,
        text: 'ВВЕДИТЕ ИМЯ ДЛЯ ПОИСКА',
        sub: 'Минимум 2 символа',
      );
    }

    final resultsAsync = ref.watch(userSearchProvider(query));

    return resultsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            color: SieTheme.accent, strokeWidth: 1.5),
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
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _UserTile(profile: results[i], query: query),
        );
      },
    );
  }
}

// ── Status Placeholder ────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String sub;
  const _StatusMessage(
      {required this.icon, required this.text, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SieTheme.borderAccent, size: 36),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: SieTheme.textSecondary,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(
                color: SieTheme.borderAccent, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── User Tile ─────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final PublicProfile profile;
  final String query;
  const _UserTile({required this.profile, required this.query});

  @override
  Widget build(BuildContext context) {
    final username = profile.username ?? 'UNKNOWN';
    final letter = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              PublicProfileScreen(profile: profile),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SieTheme.surface,
          border: Border.all(color: SieTheme.borderDefault),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: SieTheme.borderAccent, width: 1),
                color: SieTheme.background,
              ),
              child: ClipOval(
                child: profile.avatarUrl != null
                    ? Image.network(
                        profile.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _TileLetter(letter: letter),
                      )
                    : _TileLetter(letter: letter),
              ),
            ),
            const SizedBox(width: 14),
            // Name + level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightedName(name: username.toUpperCase(), query: query.toUpperCase()),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: SieTheme.borderAccent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'LEVEL ${profile.level}  ·  ${profile.totalXp} XP',
                      style: const TextStyle(
                        color: SieTheme.accent,
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: SieTheme.borderAccent, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TileLetter extends StatelessWidget {
  final String letter;
  const _TileLetter({required this.letter});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: SieTheme.accent,
            fontSize: 18,
            fontWeight: FontWeight.w200,
          ),
        ),
      );
}

// ── Highlighted Name ──────────────────────────────────────────

class _HighlightedName extends StatelessWidget {
  final String name;
  final String query;
  const _HighlightedName({required this.name, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: SieTheme.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );

    if (query.isEmpty) return const Text('', style: base);

    final idx = name.indexOf(query);
    if (idx == -1) return Text(name, style: base);

    return RichText(
      text: TextSpan(style: base, children: [
        TextSpan(text: name.substring(0, idx)),
        TextSpan(
          text: name.substring(idx, idx + query.length),
          style: base.copyWith(
              color: SieTheme.accent, fontWeight: FontWeight.w700),
        ),
        TextSpan(text: name.substring(idx + query.length)),
      ]),
    );
  }
}
