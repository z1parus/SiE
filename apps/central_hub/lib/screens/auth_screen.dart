import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sie_core/sie_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen
// ─────────────────────────────────────────────────────────────────────────────
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _telegramLoading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _registrationPending = false;
  String? _errorMessage;

  bool get _anySocialLoading =>
      _telegramLoading || _googleLoading || _appleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await SupabaseService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // authStateProvider fires → SieApp rebuilds → OperationsControlScreen shown
      } else {
        final response = await SupabaseService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
        );
        if (response.session == null) {
          setState(() => _registrationPending = true);
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message.toUpperCase());
    } catch (_) {
      setState(() => _errorMessage = t.auth.errors.connection);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);

    if (_registrationPending) {
      return _PendingConfirmScreen(
        onContinue: () => setState(() {
          _registrationPending = false;
          _isLogin = true;
        }),
      );
    }

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(c),
                  const SizedBox(height: 32),
                  _buildFormPanel(c),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildError(c),
                  ],
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  if (_isLogin) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: Text(
                          t.auth.actions.forgotPassword,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildTelegramSection(c),
                  const SizedBox(height: 12),
                  _buildToggle(c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithTelegram() async {
    setState(() {
      _telegramLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseService.signInWithTelegram();
      // Session arrives via the sie://auth/callback deep link;
      // authStateProvider fires and the app rebuilds into the main shell.
    } catch (_) {
      if (mounted) setState(() => _errorMessage = t.auth.telegram.error);
    } finally {
      if (mounted) setState(() => _telegramLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseService.signInWithGoogle();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = t.auth.social.googleError);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _appleLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseService.signInWithApple();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = t.auth.social.appleError);
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  Widget _buildTelegramSection(SieColors c) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: c.border, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t.auth.telegram.orDivider,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            Expanded(child: Divider(color: c.border, thickness: 1)),
          ],
        ),
        const SizedBox(height: 12),
        _TelegramButton(
          onTap: _anySocialLoading ? null : _signInWithTelegram,
          loading: _telegramLoading,
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: t.auth.social.signInGoogle,
          loading: _googleLoading,
          onTap: _anySocialLoading ? null : _signInWithGoogle,
          background: Colors.white,
          foreground: const Color(0xFF1F1F1F),
          border: c.border,
          leading: const _GoogleGlyph(),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: t.auth.social.signInApple,
          loading: _appleLoading,
          onTap: _anySocialLoading ? null : _signInWithApple,
          background: const Color(0xFF000000),
          foreground: Colors.white,
          leading: const Icon(Icons.apple, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildHeader(SieColors c) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.accent, c.accentSecondary]),
            boxShadow: c.isLightMode
                ? null
                : [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 16),
        Text(t.auth.header.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? t.auth.header.subtitleLogin
              : t.auth.header.subtitleRegister,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildFormPanel(SieColors c) {
    final form = Form(
      key: _formKey,
      child: Column(
        children: [
          _NeonField(
            controller: _emailController,
            label: t.auth.fields.emailLabel,
            hint: t.auth.fields.emailHint,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? t.auth.fields.emailInvalid
                : null,
          ),
          const SizedBox(height: 16),
          _NeonField(
            controller: _passwordController,
            label: t.auth.fields.passwordLabel,
            hint: '••••••••',
            obscureText: true,
            validator: (v) => (v == null || v.length < 6)
                ? t.auth.fields.passwordTooShort
                : null,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isLogin
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const SizedBox(height: 16),
                      _NeonField(
                        controller: _usernameController,
                        label: t.auth.fields.usernameLabel,
                        hint: t.auth.fields.usernameHint,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? t.auth.fields.usernameRequired
                            : null,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: c.flatCard(radius: 20),
      child: form,
    );
  }

  Widget _buildError(SieColors c) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: c.danger),
          borderRadius: BorderRadius.circular(10),
          color: c.danger.withValues(alpha: c.isLightMode ? 0.1 : 0.14),
        ),
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color: c.danger,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final c = ref.read(sieColorsProvider);
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = t.auth.errors.enterEmailFirst);
      return;
    }
    try {
      await SupabaseService.resetPassword(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: c.surface,
          content: Text(
            t.auth.reset.emailSent(email: email),
            style: TextStyle(color: c.textPrimary),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _errorMessage = t.auth.errors.connection);
    }
  }

  Widget _buildSubmitButton() {
    return _PressButton(
      onTap: _isLoading ? null : _submit,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(
              _isLogin
                  ? t.auth.actions.submitLogin
                  : t.auth.actions.submitRegister,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
    );
  }

  Widget _buildToggle(SieColors c) {
    return TextButton(
      onPressed: () => setState(() {
        _isLogin = !_isLogin;
        _errorMessage = null;
      }),
      child: Text(
        _isLogin
            ? t.auth.actions.toggleToRegister
            : t.auth.actions.toggleToLogin,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Press-scale gradient button ──────────────────────────────────────────────

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
          final pressT = _ctrl.value;
          final gradientColors = [c.accent, c.accentSecondary];
          return Transform.scale(
            scale: 1.0 - 0.03 * pressT,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: gradientColors),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(
                        alpha: (c.isLightMode ? 0.15 : 0.3) + 0.3 * pressT),
                    blurRadius: 12.0 + 8.0 * pressT,
                    spreadRadius: 0,
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

// ─── Neon-glow text field ──────────────────────────────────────────────────────

class _NeonField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _NeonField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  ConsumerState<_NeonField> createState() => _NeonFieldState();
}

class _NeonFieldState extends ConsumerState<_NeonField> {
  final _focus = FocusNode();
  bool _focused = false;
  late bool _obscured = widget.obscureText;

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
    return AnimatedContainer(
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
                      alpha: c.isLightMode ? 0.12 : 0.22),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(
            color: _focused
                ? c.accent.withValues(alpha: 0.9)
                : c.textSecondary,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
          hintStyle: TextStyle(
            color: c.isLightMode
                ? c.textSecondary.withValues(alpha: 0.5)
                : SieTheme.borderAccent,
            fontSize: 13,
          ),
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: c.iconMuted,
                    size: 20,
                  ),
                  tooltip:
                      _obscured ? t.auth.password.show : t.auth.password.hide,
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: TextStyle(
            color: c.danger,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─── Post-registration confirmation screen ───────────────────────────────────

class _PendingConfirmScreen extends ConsumerWidget {
  final VoidCallback onContinue;

  const _PendingConfirmScreen({required this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final theme = Theme.of(context);

    final infoCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.auth.pending.confirmationRequired,
            style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        Text(
          t.auth.pending.confirmBody,
          style: theme.textTheme.bodyMedium,
        ),
        // Dev-only Mailpit hint — never shown in release builds.
        if (!kReleaseMode) ...[
          const SizedBox(height: 12),
          Text(
            t.auth.pending.localDevHint,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'http://127.0.0.1:54324',
            style: TextStyle(color: c.accent, fontSize: 13, letterSpacing: 0.5),
          ),
        ],
      ],
    );

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [c.accent, c.accentSecondary]),
                    boxShadow: c.isLightMode
                        ? null
                        : [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(t.auth.pending.title,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: c.flatCard(radius: 16),
                  child: infoCard,
                ),
                const SizedBox(height: 32),
                _PressButton(
                  onTap: onContinue,
                  child: Text(
                    t.auth.pending.proceed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
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

// ─── Telegram OAuth button (Telegram-blue accent) ────────────────────────────

class _TelegramButton extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _TelegramButton({required this.onTap, required this.loading});

  @override
  ConsumerState<_TelegramButton> createState() => _TelegramButtonState();
}

class _TelegramButtonState extends ConsumerState<_TelegramButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const Color _telegramBlue = Color(0xFF2AABEE);

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
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final pressT = _ctrl.value;
          return Transform.scale(
            scale: 1.0 - 0.03 * pressT,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _telegramBlue,
                boxShadow: [
                  BoxShadow(
                    color: _telegramBlue.withValues(alpha: 0.3 + 0.3 * pressT),
                    blurRadius: 12.0 + 8.0 * pressT,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
        child: widget.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    t.auth.telegram.signIn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Generic social-auth button (Google / Apple brand colours) ───────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final Color? border;
  final Widget leading;

  const _SocialButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.leading,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: background,
          border: border != null ? Border.all(color: border!) : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: foreground, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Simple multi-colour Google "G" glyph rendered from text (no asset needed).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.0,
      ),
    );
  }
}
