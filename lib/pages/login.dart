import 'package:flutter/material.dart';
import 'package:zcanopy/pages/email_otp.dart';
import 'package:zcanopy/pages/forgot_password.dart';
import 'package:zcanopy/services/auth_service.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/onboarding_palette.dart';
import 'package:zcanopy/widgets/onboarding_kit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.startInSignUp = false});

  final bool startInSignUp;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late bool _signUp;
  bool _working = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _signUp = widget.startInSignUp;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _normalizedPhone(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 9) digits = '256$digits';
    if (digits.length == 10 && digits.startsWith('0')) {
      digits = '256${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _submit() async {
    if (_working) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() => _working = true);
    try {
      if (_signUp) {
        final phone = _normalizedPhone(_phoneCtrl.text);
        await AuthService.instance.register(
          email: email,
          password: password,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phoneNumber: phone.isEmpty ? null : phone,
        );
        if (!mounted) return;
        setState(() => _working = false);
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => EmailOtpScreen(email: email)),
        );
        if (verified == true && mounted) Navigator.pop(context, true);
        return;
      }

      await AuthService.instance.signIn(email: email, password: password);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!_signUp &&
          e.message.toLowerCase().contains('not verified') &&
          mounted) {
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EmailOtpScreen(
              email: email,
              subtitle:
                  'Your email is not verified yet. Enter the code sent to\n$email',
            ),
          ),
        );
        if (verified == true && mounted) {
          Navigator.pop(context, true);
          return;
        }
      }
      _showError(e.message);
    } catch (_) {
      _showError('Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _toggleMode() {
    setState(() {
      _signUp = !_signUp;
      _formKey.currentState?.reset();
    });
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordPage(initialEmail: _emailCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    children: [
                      OnboardingIconButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (_signUp)
                        TextButton(
                          onPressed: _working
                              ? null
                              : () => Navigator.pop(context, false),
                          child: Text(
                            'Not now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: BrandMark(small: true),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _signUp ? 'Create your account' : 'Welcome back',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              letterSpacing: -0.5,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _signUp
                                ? 'Save searches, shortlist homes and book with confidence.'
                                : 'Sign in to access your saved properties, bookings and payments.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_signUp) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: _firstNameCtrl,
                                    label: 'First name',
                                    icon: Icons.person_outline,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    controller: _lastNameCtrl,
                                    label: 'Last name',
                                    icon: Icons.person_outline,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          _field(
                            controller: _emailCtrl,
                            label: 'Email address',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (!_isEmail(value ?? '')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          if (_signUp) ...[
                            const SizedBox(height: 12),
                            _field(
                              controller: _phoneCtrl,
                              label: 'Phone number (optional)',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _field(
                            controller: _passwordCtrl,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscure,
                            textInputAction: _signUp
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onSubmitted: _signUp ? null : (_) => _submit(),
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: palette.muted,
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return 'Use at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          if (_signUp) ...[
                            const SizedBox(height: 12),
                            _field(
                              controller: _confirmCtrl,
                              label: 'Confirm password',
                              icon: Icons.lock_outline,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (value != _passwordCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 22),
                          GoldButton(
                            label: _signUp ? 'Create account' : 'Sign in',
                            loading: _working,
                            onPressed: _submit,
                          ),
                          if (!_signUp)
                            Center(
                              child: TextButton(
                                onPressed: _working
                                    ? null
                                    : _openForgotPassword,
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: palette.deepAccent,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _signUp
                                    ? 'Already have an account?'
                                    : 'New to ZCanopy?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.muted,
                                ),
                              ),
                              TextButton(
                                onPressed: _working ? null : _toggleMode,
                                child: Text(
                                  _signUp ? 'Sign in' : 'Create account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: palette.deepAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_signUp)
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Continue browsing as a guest',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          if (_signUp)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'By continuing you agree to our Terms and Privacy Policy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    final palette = OnboardingPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.line),
    );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      cursorColor: OnboardingPalette.gold,
      style: TextStyle(fontSize: 15, color: palette.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14, color: palette.muted),
        floatingLabelStyle: TextStyle(color: palette.deepAccent),
        prefixIcon: Icon(icon, size: 20, color: palette.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: palette.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: OnboardingPalette.gold, width: 1.6),
        ),
      ),
    );
  }
}
