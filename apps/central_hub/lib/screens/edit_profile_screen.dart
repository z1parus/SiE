import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sie_core/sie_core.dart';

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
  bool _isSaving = false;

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
          SnackBar(content: Text('ERROR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SieTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: SieTheme.borderDefault),
      ),
      builder: (_) => const _PasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      backgroundColor: SieTheme.background,
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
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SieTheme.accent,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'ERROR: $e',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                data: (p) {
                  if (p == null) return const SizedBox();
                  _init(p);
                  return _buildForm(p);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(Profile profile) {
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
          _InputField(label: 'USERNAME', controller: _usernameCtrl),
          const SizedBox(height: 12),
          _InputField(label: 'FULL NAME', controller: _fullNameCtrl),
          const SizedBox(height: 32),
          const SectionHeader(title: 'SECURITY'),
          const SizedBox(height: 16),
          _EmailRow(
              email: SupabaseService.client.auth.currentUser?.email ?? ''),
          const SizedBox(height: 12),
          _ActionRow(
            label: 'PASSWORD',
            value: '••••••••',
            onTap: _showPasswordSheet,
          ),
          if (_isSaving) ...[
            const SizedBox(height: 32),
            const Center(
              child: CircularProgressIndicator(
                  color: SieTheme.accent, strokeWidth: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback? onSave;
  const _TopBar({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: SieTheme.textSecondary, size: 18),
          ),
          Expanded(
            child: Text(
              'EDIT PROFILE',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: onSave,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: onSave != null
                    ? SieTheme.accent
                    : SieTheme.textSecondary,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar Picker ─────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  final Profile profile;
  final Uint8List? pickedBytes;
  final VoidCallback onTap;
  const _AvatarPicker(
      {required this.profile,
      required this.pickedBytes,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final letter = (profile.username?.isNotEmpty == true)
        ? profile.username![0].toUpperCase()
        : '?';

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: SieTheme.borderAccent, width: 1.5),
                color: SieTheme.surface,
              ),
              child: ClipOval(
                child: pickedBytes != null
                    ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                    : (profile.avatarUrl != null
                        ? Image.network(
                            profile.avatarUrl!,
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
                  color: SieTheme.accent,
                  border:
                      Border.all(color: SieTheme.background, width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    size: 13, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String letter;
  const _Initials({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: SieTheme.accent,
          fontSize: 32,
          fontWeight: FontWeight.w200,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Input Field ───────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _InputField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SieTheme.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: SieTheme.textPrimary,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: SieTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  const BorderSide(color: SieTheme.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  const BorderSide(color: SieTheme.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: SieTheme.accent),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Email Row (read-only display) ─────────────────────────────

class _EmailRow extends StatelessWidget {
  final String email;
  const _EmailRow({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.borderDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EMAIL',
                  style: TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    color: SieTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'READ-ONLY',
            style: TextStyle(
              color: SieTheme.textSecondary,
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

class _ActionRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SieTheme.surface,
          border: Border.all(color: SieTheme.borderDefault),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: SieTheme.textPrimary,
                      fontSize: 13,
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

// ── Password Bottom Sheet ─────────────────────────────────────

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;

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
          SnackBar(content: Text('ERROR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'CHANGE PASSWORD',
            style: Theme.of(context).textTheme.titleMedium,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: SieTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : const Text(
                      'UPDATE PASSWORD',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  const _SheetField(
      {required this.label,
      required this.controller,
      this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SieTheme.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(
            color: SieTheme.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: SieTheme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  const BorderSide(color: SieTheme.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  const BorderSide(color: SieTheme.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: SieTheme.accent),
            ),
          ),
        ),
      ],
    );
  }
}
