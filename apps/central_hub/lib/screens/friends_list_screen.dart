import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'public_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FriendsListScreen
// ─────────────────────────────────────────────────────────────────────────────
class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final friendsAsync = ref.watch(friendsProvider);
    final state = friendsAsync.valueOrNull ?? const FriendsState();

    return SieBackground(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: c.flatCard(radius: 18),
                          child: Center(
                            child: Icon(Icons.arrow_back_ios_new,
                                color: c.textSecondary, size: 15),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'МОИ ДРУЗЬЯ',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
                // Tab bar
                Container(
                  decoration:
                      BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                  child: TabBar(
                    labelColor: c.accent,
                    unselectedLabelColor: c.textSecondary,
                    indicatorColor: c.accent,
                    indicatorWeight: 1.5,
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                    tabs: [
                      Tab(
                        child: _TabLabel(
                            text: 'ДРУЗЬЯ', count: state.friends.length),
                      ),
                      Tab(
                        child: _TabLabel(
                            text: 'ИСХОДЯЩИЕ',
                            count: state.sentRequests.length),
                      ),
                      Tab(
                        child: _TabLabel(
                            text: 'ВХОДЯЩИЕ',
                            count: state.receivedRequests.length,
                            highlight: true),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: friendsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                          color: c.accent, strokeWidth: 1.5),
                    ),
                    error: (e, _) => Center(
                      child: Text('Ошибка загрузки',
                          style: TextStyle(color: c.textSecondary)),
                    ),
                    data: (s) => TabBarView(
                      children: [
                        _FriendsList(
                          rows: s.friends,
                          emptyText: 'Пока нет друзей',
                          trailing: (row) => _RemoveBtn(row: row),
                        ),
                        _FriendsList(
                          rows: s.sentRequests,
                          emptyText: 'Нет исходящих запросов',
                          trailing: (row) => _CancelBtn(row: row),
                        ),
                        _FriendsList(
                          rows: s.receivedRequests,
                          emptyText: 'Нет входящих запросов',
                          trailing: (row) => _AcceptDeclineRow(row: row),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab label with optional badge
// ─────────────────────────────────────────────────────────────────────────────
class _TabLabel extends ConsumerWidget {
  final String text;
  final int count;
  final bool highlight;

  const _TabLabel(
      {required this.text, required this.count, this.highlight = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: highlight ? Colors.red : c.accent.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  color: highlight ? Colors.white : c.textPrimary,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends list
// ─────────────────────────────────────────────────────────────────────────────
class _FriendsList extends ConsumerWidget {
  final List<FriendRow> rows;
  final String emptyText;
  final Widget Function(FriendRow) trailing;

  const _FriendsList({
    required this.rows,
    required this.emptyText,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    if (rows.isEmpty) {
      return RefreshIndicator(
        color: c.accent,
        backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          await ref.read(friendsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: c.textSecondary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(emptyText,
                        style: TextStyle(color: c.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
      onRefresh: () async {
        ref.invalidate(friendsProvider);
        await ref.read(friendsProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) =>
            _FriendTile(row: rows[i], trailing: trailing(rows[i])),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friend tile
// ─────────────────────────────────────────────────────────────────────────────
class _FriendTile extends ConsumerWidget {
  final FriendRow row;
  final Widget trailing;

  const _FriendTile({required this.row, required this.trailing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final profile = row.otherUser;
    final username = profile.username ?? '—';
    final letter =
        username.isNotEmpty ? username[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PublicProfileScreen(profile: profile)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: c.flatCard(radius: 16),
        child: Row(
          children: [
            // Avatar 44×44
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.background,
                border: Border.all(color: c.accent.withValues(alpha: 0.4)),
              ),
              child: ClipOval(
                child: profile.avatarUrl != null &&
                        profile.avatarUrl!.isNotEmpty
                    ? Image.network(
                        profile.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _AvatarLetter(letter: letter, c: c),
                      )
                    : _AvatarLetter(letter: letter, c: c),
              ),
            ),
            const SizedBox(width: 12),
            // Name + level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'LEVEL ${profile.level} · ${profile.totalXp} XP',
                    style: TextStyle(
                        fontSize: 10,
                        color: c.textSecondary,
                        letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;
  final SieColors c;
  const _AvatarLetter({required this.letter, required this.c});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(letter,
            style: TextStyle(
                color: c.accent, fontSize: 18, fontWeight: FontWeight.w200)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Action buttons
// ─────────────────────────────────────────────────────────────────────────────
class _RemoveBtn extends ConsumerWidget {
  final FriendRow row;
  const _RemoveBtn({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return IconButton(
      icon: Icon(Icons.person_remove_outlined,
          color: c.textSecondary, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => _confirm(context, ref),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final name = row.otherUser.username ?? 'пользователя';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из друзей?'),
        content: Text('$name будет удалён из вашего списка друзей.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(friendsProvider.notifier)
          .removeFriend(row.friendshipId);
    }
  }
}

class _CancelBtn extends ConsumerWidget {
  final FriendRow row;
  const _CancelBtn({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return IconButton(
      icon: Icon(Icons.cancel_outlined, color: c.textSecondary, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () =>
          ref.read(friendsProvider.notifier).cancelRequest(row.friendshipId),
    );
  }
}

class _AcceptDeclineRow extends ConsumerWidget {
  final FriendRow row;
  const _AcceptDeclineRow({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_outlined,
              color: Colors.green, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => ref
              .read(friendsProvider.notifier)
              .acceptRequest(row.friendshipId),
        ),
        const SizedBox(width: 4),
        Consumer(builder: (_, ref2, _) {
          final c = ref2.watch(sieColorsProvider);
          return IconButton(
            icon: Icon(Icons.close, color: c.textSecondary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref2
                .read(friendsProvider.notifier)
                .declineRequest(row.friendshipId),
          );
        }),
      ],
    );
  }
}
