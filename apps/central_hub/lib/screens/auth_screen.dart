import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sie_core/sie_core.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);

LiquidGlassSettings _glassSettings({double glowIntensity = 0.88}) =>
    LiquidGlassSettings(
      blur: 4.0,
      thickness: 28,
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
// AuthScreen
// ─────────────────────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _registrationPending = false;
  String? _errorMessage;

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
      setState(() => _errorMessage = 'CONNECTION ERROR');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_registrationPending) {
      return _PendingConfirmScreen(
        onContinue: () => setState(() {
          _registrationPending = false;
          _isLogin = true;
        }),
      );
    }

    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildFormPanel(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildError(),
                  ],
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                  _buildToggle(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_kCyan, _kPurple]),
            boxShadow: [
              BoxShadow(
                color: Color(0x8000E5FF),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'OPERATIVE\nAUTHENTICATION',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin ? 'ENTER CLEARANCE CREDENTIALS' : 'REGISTER NEW OPERATIVE',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildFormPanel() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      shape: LiquidRoundedSuperellipse(borderRadius: 20),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      settings: _glassSettings(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _NeonField(
              controller: _emailController,
              label: 'EMAIL ADDRESS',
              hint: 'operative@sie.dev',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'INVALID EMAIL FORMAT' : null,
            ),
            const SizedBox(height: 16),
            _NeonField(
              controller: _passwordController,
              label: 'PASSPHRASE',
              hint: '••••••••',
              obscureText: true,
              validator: (v) => (v == null || v.length < 6)
                  ? 'MIN 6 CHARACTERS REQUIRED'
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
                          label: 'OPERATIVE ID',
                          hint: 'codename',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'OPERATIVE ID REQUIRED'
                              : null,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF1A0808),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return _PressButton(
      onTap: _isLoading ? null : _submit,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              _isLogin ? 'ACCESS GRANTED' : 'REGISTER OPERATIVE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
    );
  }

  Widget _buildToggle() {
    return TextButton(
      onPressed: () => setState(() {
        _isLogin = !_isLogin;
        _errorMessage = null;
      }),
      child: Text(
        _isLogin ? 'NO CLEARANCE?  REGISTER →' : 'ALREADY CLEARED?  SIGN IN →',
        style: const TextStyle(
          color: SieTheme.textSecondary,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Press-scale gradient button ──────────────────────────────────────────────

class _PressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressButton({required this.child, required this.onTap});

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton>
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
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(const Color(0xFF00E5FF), const Color(0xFF00BFFF), t)!,
                    Color.lerp(const Color(0xFF7000FF), const Color(0xFF9000FF), t)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kCyan.withValues(alpha: 0.3 + 0.3 * t),
                    blurRadius: 12.0 + 8.0 * t,
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

class _NeonField extends StatefulWidget {
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
  State<_NeonField> createState() => _NeonFieldState();
}

class _NeonFieldState extends State<_NeonField> {
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused ? _kCyan : SieTheme.borderDefault,
          width: _focused ? 1.5 : 1.0,
        ),
        color: const Color(0x1A0A0E1A),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: _kCyan.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(
            color: _focused
                ? _kCyan.withValues(alpha: 0.9)
                : SieTheme.textSecondary,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
          hintStyle: const TextStyle(color: SieTheme.borderAccent, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: const TextStyle(
            color: Colors.redAccent,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─── Post-registration confirmation screen ───────────────────────────────────

class _PendingConfirmScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const _PendingConfirmScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_kCyan, _kPurple]),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x8000E5FF),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'REGISTRATION\nINITIATED',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  shape: LiquidRoundedSuperellipse(borderRadius: 16),
                  useOwnLayer: true,
                  quality: GlassQuality.standard,
                  clipBehavior: Clip.antiAlias,
                  settings: _glassSettings(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONFIRMATION REQUIRED',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm your email to activate operative access.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Local dev — check Mailpit:',
                        style: TextStyle(
                          color: SieTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'http://127.0.0.1:54324',
                        style: TextStyle(
                          color: _kCyan,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _PressButton(
                  onTap: onContinue,
                  child: const Text(
                    'PROCEED TO SIGN IN',
                    style: TextStyle(
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
