import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sie_core/sie_core.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildForm(),
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
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 40, height: 2, color: SieTheme.accent),
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _SieField(
            controller: _emailController,
            label: 'EMAIL ADDRESS',
            hint: 'operative@sie.dev',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'INVALID EMAIL FORMAT' : null,
          ),
          const SizedBox(height: 16),
          _SieField(
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
                      _SieField(
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
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(4),
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
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: SieTheme.accent,
          foregroundColor: SieTheme.background,
          disabledBackgroundColor: SieTheme.borderAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: SieTheme.background,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isLogin ? 'ACCESS GRANTED' : 'REGISTER OPERATIVE',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
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

// ─── Reusable styled text field ──────────────────────────────────────────────

class _SieField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _SieField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: SieTheme.textPrimary,
        fontSize: 14,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: SieTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
        hintStyle: const TextStyle(color: SieTheme.borderAccent, fontSize: 13),
        filled: true,
        fillColor: SieTheme.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(SieTheme.borderDefault),
        enabledBorder: _border(SieTheme.borderDefault),
        focusedBorder: _border(SieTheme.accent, width: 1.5),
        errorBorder: _border(Colors.redAccent),
        focusedErrorBorder: _border(Colors.redAccent, width: 1.5),
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ─── Post-registration confirmation screen ───────────────────────────────────

class _PendingConfirmScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const _PendingConfirmScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 40, height: 2, color: SieTheme.accent),
              const SizedBox(height: 16),
              Text(
                'REGISTRATION\nINITIATED',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SieTheme.surfaceAlt,
                  border: Border.all(color: SieTheme.borderAccent),
                  borderRadius: BorderRadius.circular(4),
                ),
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
                        color: SieTheme.accent,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onContinue,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SieTheme.borderAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'PROCEED TO SIGN IN',
                    style: TextStyle(
                      color: SieTheme.textPrimary,
                      fontSize: 13,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
