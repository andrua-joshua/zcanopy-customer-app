import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/onboarding_palette.dart';
import 'package:zcanopy/widgets/onboarding_kit.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = GatewayApi();
  late final TextEditingController _emailCtrl;
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0;
  bool _working = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim();

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _working = true);
    try {
      await _api.sendForgotPasswordOtp(_email);
      if (!mounted) return;
      setState(() => _step = 1);
      _snack('If an account exists, a reset code has been sent to $_email');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Could not send the code. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 4) {
      _snack('Enter the code from your email', error: true);
      return;
    }
    setState(() => _working = true);
    try {
      final result = await _api.verifyForgotPasswordOtp(
        email: _email,
        otp: code,
      );
      if (result['valid'] != true && result['success'] != true) {
        throw ApiException(
          400,
          result['message']?.toString() ?? 'Invalid code',
        );
      }
      if (!mounted) return;
      setState(() => _step = 2);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Could not verify the code. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _working = true);
    try {
      await _api.resetCustomerPassword(
        email: _email,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Could not reset your password. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : OnboardingPalette.goldDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    final titles = const [
      'Reset your password',
      'Enter the reset code',
      'Choose a new password',
    ];
    final subtitles = [
      'Enter the email address linked to your ZCanopy account.',
      'We sent a 6-digit code to $_email.',
      'Create a new password with at least 6 characters.',
    ];
    final labels = const ['Send reset code', 'Verify code', 'Reset password'];

    return Scaffold(
      backgroundColor: palette.background,
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
                        onTap: () {
                          if (_step > 0 && !_working) {
                            setState(() => _step -= 1);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const Spacer(),
                      OnboardingDots(count: 3, index: _step, onTap: (_) {}),
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
                          const SizedBox(height: 26),
                          Text(
                            titles[_step],
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
                            subtitles[_step],
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(height: 26),
                          if (_step == 0)
                            _input(
                              controller: _emailCtrl,
                              label: 'Email address',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                final valid = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email);
                                return valid ? null : 'Enter a valid email';
                              },
                            ),
                          if (_step == 1)
                            _input(
                              controller: _otpCtrl,
                              label: 'Verification code',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: (value) {
                                return (value?.trim().length ?? 0) < 4
                                    ? 'Enter the code'
                                    : null;
                              },
                            ),
                          if (_step == 2) ...[
                            _input(
                              controller: _passwordCtrl,
                              label: 'New password',
                              obscureText: _obscure,
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
                                return (value ?? '').length < 6
                                    ? 'Use at least 6 characters'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _input(
                              controller: _confirmCtrl,
                              label: 'Confirm new password',
                              obscureText: _obscure,
                              validator: (value) {
                                return value != _passwordCtrl.text
                                    ? 'Passwords do not match'
                                    : null;
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          GoldButton(
                            label: labels[_step],
                            loading: _working,
                            onPressed: _step == 0
                                ? _sendCode
                                : _step == 1
                                ? _verifyCode
                                : _resetPassword,
                          ),
                          if (_step == 1)
                            Center(
                              child: TextButton(
                                onPressed: _working ? null : _sendCode,
                                child: Text(
                                  'Resend code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: palette.deepAccent,
                                  ),
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

  Widget _input({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final palette = OnboardingPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.line),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        validator: validator,
        cursorColor: OnboardingPalette.gold,
        style: TextStyle(fontSize: 15, color: palette.ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: palette.muted),
          suffixIcon: suffix,
          filled: true,
          fillColor: palette.paper,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: OnboardingPalette.gold, width: 1.6),
          ),
        ),
      ),
    );
  }
}
