import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

LiquidGlassSettings _glassSettings({double glowIntensity = 0.88}) =>
    LiquidGlassSettings(
      blur: 3.5,
      thickness: 24,
      refractiveIndex: 1.45,
      glassColor: const Color(0x0A0A0E1A),
      lightAngle: GlassDefaults.lightAngle,
      lightIntensity: 0.72,
      glowIntensity: glowIntensity,
      saturation: 1.4,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientStrength: 0.08,
      chromaticAberration: 0.015,
    );

// ─────────────────────────────────────────────────────────────────────────────
// EditProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  Uint8List? _pickedBytes;
  bool _initialized = false;
  bool _isSaving    = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    super.dispose();
  }

  void _init(Profile profile) {
    if (_initialized) return;
    _initialized = true;
    _usernameCtrl.text = profile.username ?? '';
    _fullNameCtrl.text = profile.fullName ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _pickedBytes = bytes);
  }

  Future<void> _save(Profile profile) async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('USERNAME CANNOT BE EMPTY')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await updateProfileInfo(
        username: username,
        fullName: _fullNameCtrl.text.trim(),
      );
      if (_pickedBytes != null) {
        await uploadAvatar(_pickedBytes!);
      }
      ref.invalidate(userProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проверьте подключение к интернету')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPasswordSheet() {
    final c = ref.read(sieColorsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          c.isCosmicMode ? const Color(0xFF0B1E30) : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(
          color: c.isCosmicMode ? const Color(0xFF1A3A5C) : c.border,
        ),
      ),
      builder: (_) => const _PasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c            = ref.watch(sieColorsProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile      = profileAsync.valueOrNull;

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onSave: profile != null && !_isSaving
                    ? () => _save(profile)
                    : null,
              ),
              Expanded(
                child: profileAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                        color: c.accent, strokeWidth: 1.5),
                  ),
                  error: (e, _) => const Center(
                    child: _NoConnectionMessage(),
                  ),
                  data: (p) {
                    if (p == null) return const SizedBox();
                    _init(p);
                    return _buildForm(p, c);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Profile profile, SieColors c) {
    Widget identityCard({required Widget child}) => c.isCosmicMode
        ? GlassCard(
            padding: const EdgeInsets.all(20),
            shape: LiquidRoundedSuperellipse(borderRadius: 20),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            clipBehavior: Clip.antiAlias,
            settings: _glassSettings(),
            child: child,
          )
        : Container(
            padding: const EdgeInsets.all(20),
            decoration: c.flatCard(radius: 20),
            child: child,
          );

    Widget securityCard({required Widget child}) => c.isCosmicMode
        ? GlassCard(
            padding: const EdgeInsets.all(4),
            shape: LiquidRoundedSuperellipse(borderRadius: 20),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            clipBehavior: Clip.antiAlias,
            settings: _glassSettings(),
            child: child,
          )
        : Container(
            decoration: c.flatCard(radius: 20),
            child: child,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarPicker(
            profile: profile,
            pickedBytes: _pickedBytes,
            onTap: _pickImage,
          ),
          const SizedBox(height: 32),
          const SectionHeader(title: 'IDENTITY'),
          const SizedBox(height: 16),
          identityCard(
            child: Column(
              children: [
                _NeonField(label: 'USERNAME', controller: _usernameCtrl),
                const SizedBox(height: 16),
                _NeonField(label: 'FULL NAME', controller: _fullNameCtrl),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeader(title: 'SECURITY'),
          const SizedBox(height: 16),
          securityCard(
            child: Column(
              children: [
                _EmailRow(
                    email: SupabaseService.client.auth.currentUser?.email ??
                        ''),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: c.border,
                ),
                _ActionRow(
                  label: 'PASSWORD',
                  value: '••••••••',
                  onTap: _showPasswordSheet,
                ),
              ],
            ),
          ),
          if (_isSaving) ...[
            const SizedBox(height: 32),
            Center(
              child: CircularProgressIndicator(
                  color: c.accent, strokeWidth: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final VoidCallback? onSave;
  const _TopBar({required this.onSave});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new,
                color: c.textSecondary, size: 18),
          ),
          Expanded(
            child: Text(
              'EDIT PROFILE',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          _SaveButton(onTap: onSave),
        ],
      ),
    );
  }
}

// ── Save Button ───────────────────────────────────────────────

class _SaveButton extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  const _SaveButton({required this.onTap});

  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (widget.onTap == null) return;
    _ctrl.animateTo(1.0,
        duration: const Duration(milliseconds: 80), curve: Curves.easeIn);
  }

  void _release() {
    _ctrl.animateTo(0.0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = _ctrl.value;
          return Transform.scale(
            scale: 1.0 - 0.03 * t,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: widget.onTap != null
                    ? LinearGradient(
                        colors: [
                          Color.lerp(c.accent,
                              c.accent.withValues(alpha: 0.8), t)!,
                          Color.lerp(c.accentSecondary,
                              c.accentSecondary.withValues(alpha: 0.9), t)!,
                        ],
                      )
                    : null,
                color: widget.onTap == null ? Colors.transparent : null,
                boxShadow: widget.onTap != null
                    ? [
                        BoxShadow(
                          color: c.accent.withValues(
                              alpha: 0.2 + 0.3 * t),
                          blurRadius: 8.0 + 6.0 * t,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'SAVE',
                style: TextStyle(
                  color: widget.onTap != null
                      ? Colors.white
                      : c.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Avatar Picker ─────────────────────────────────────────────

class _AvatarPicker extends ConsumerStatefulWidget {
  final Profile profile;
  final Uint8List? pickedBytes;
  final VoidCallback onTap;
  const _AvatarPicker({
    required this.profile,
    required this.pickedBytes,
    required this.onTap,
  });

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final letter = (widget.profile.username?.isNotEmpty == true)
        ? widget.profile.username![0].toUpperCase()
        : '?';

    return Center(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _ctrl.animateTo(1.0,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeIn),
        onTapUp: (_) => _ctrl.animateTo(0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut),
        onTapCancel: () => _ctrl.animateTo(0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.scale(
            scale: 1.0 - 0.03 * _ctrl.value,
            child: child,
          ),
          child: Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: c.accent.withValues(alpha: 0.6), width: 1.5),
                  color: c.surface,
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.pickedBytes != null
                      ? Image.memory(widget.pickedBytes!, fit: BoxFit.cover)
                      : (widget.profile.avatarUrl != null
                          ? Image.network(
                              widget.profile.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _Initials(letter: letter),
                            )
                          : _Initials(letter: letter)),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [c.accent, c.accentSecondary]),
                    border: Border.all(color: c.background, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends ConsumerWidget {
  final String letter;
  const _Initials({required this.letter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: c.accent,
          fontSize: 32,
          fontWeight: FontWeight.w200,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Neon-glow Input Field ─────────────────────────────────────

class _NeonField extends ConsumerStatefulWidget {
  final String label;
  final TextEditingController controller;
  const _NeonField({required this.label, required this.controller});

  @override
  ConsumerState<_NeonField> createState() => _NeonFieldState();
}

class _NeonFieldState extends ConsumerState<_NeonField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: _focused
                ? c.accent.withValues(alpha: 0.9)
                : c.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? c.accent : c.border,
              width: _focused ? 1.5 : 1.0,
            ),
            color: c.isLightMode
                ? c.border.withValues(alpha: 0.3)
                : const Color(0x1A0A0E1A),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: c.accent.withValues(
                          alpha: c.isLightMode ? 0.10 : 0.22),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Email Row (read-only display) ─────────────────────────────

class _EmailRow extends ConsumerWidget {
  final String email;
  const _EmailRow({required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMAIL',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            'READ-ONLY',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable Action Row ───────────────────────────────────────

class _ActionRow extends ConsumerStatefulWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.label, required this.value, required this.onTap});

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.animateTo(1.0,
          duration: const Duration(milliseconds: 80), curve: Curves.easeIn),
      onTapUp: (_) => _ctrl.animateTo(0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut),
      onTapCancel: () => _ctrl.animateTo(0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Transform.scale(
          scale: 1.0 - 0.03 * _ctrl.value,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value,
                        style:
                            TextStyle(color: c.textPrimary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: c.textSecondary.withValues(
                      alpha: 0.6 + 0.4 * _ctrl.value),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Password Bottom Sheet ─────────────────────────────────────

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving       = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPwd = _newCtrl.text;
    if (newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PASSWORD MUST BE AT LEAST 6 CHARACTERS')),
      );
      return;
    }
    if (newPwd != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PASSWORDS DO NOT MATCH')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await changePassword(newPwd);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PASSWORD UPDATED')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Проверьте подключение к интернету')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: c.isLightMode ? c.border : SieTheme.borderAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'CHANGE PASSWORD',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 20),
          _SheetField(
              label: 'NEW PASSWORD', controller: _newCtrl, obscure: true),
          const SizedBox(height: 12),
          _SheetField(
              label: 'CONFIRM PASSWORD',
              controller: _confirmCtrl,
              obscure: true),
          const SizedBox(height: 24),
          _PressButton(
            onTap: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'UPDATE PASSWORD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends ConsumerStatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  const _SheetField(
      {required this.label, required this.controller, this.obscure = false});

  @override
  ConsumerState<_SheetField> createState() => _SheetFieldState();
}

class _SheetFieldState extends ConsumerState<_SheetField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: _focused
                ? c.accent.withValues(alpha: 0.9)
                : c.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? c.accent : c.border,
              width: _focused ? 1.5 : 1.0,
            ),
            color: c.isLightMode
                ? c.border.withValues(alpha: 0.3)
                : const Color(0x1A0A0E1A),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: c.accent.withValues(
                          alpha: c.isLightMode ? 0.10 : 0.20),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure,
            style: TextStyle(color: c.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Press-scale gradient button ───────────────────────────────

class _PressButton extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressButton({required this.child, required this.onTap});

  @override
  ConsumerState<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends ConsumerState<_PressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (widget.onTap == null) return;
    _ctrl.animateTo(1.0,
        duration: const Duration(milliseconds: 80), curve: Curves.easeIn);
  }

  void _release() {
    _ctrl.animateTo(0.0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final t = _ctrl.value;
          return Transform.scale(
            scale: 1.0 - 0.03 * t,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(c.accent, c.accent.withValues(alpha: 0.8),
                        t)!,
                    Color.lerp(c.accentSecondary,
                        c.accentSecondary.withValues(alpha: 0.9), t)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(
                        alpha: (c.isLightMode ? 0.15 : 0.3) + 0.3 * t),
                    blurRadius: 12.0 + 8.0 * t,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _NoConnectionMessage extends ConsumerWidget {
  const _NoConnectionMessage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_outlined, color: c.iconMuted, size: 36),
        const SizedBox(height: 12),
        Text(
          'Подключение к интернету отсутствует',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.iconMuted,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
