import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zcanopy/services/auth_service.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/onboarding_palette.dart';
import 'package:zcanopy/widgets/onboarding_kit.dart';

class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({
    super.key,
    required this.email,
    this.title = 'Verify your email',
    this.subtitle,
  });

  final String email;
  final String title;
  final String? subtitle;

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final _otpCtrl = TextEditingController();
  final _api = GatewayApi();

  bool _verifying = false;
  bool _resending = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 4) {
      _snack('Enter the code sent to ${widget.email}', error: true);
      return;
    }
    setState(() => _verifying = true);
    try {
      await AuthService.instance.confirmOtp(email: widget.email, otpCode: code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Could not verify the code. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _api.sendForgotPasswordOtp(widget.email);
      _snack('A new code has been sent to ${widget.email}');
    } catch (_) {
      _snack('Could not resend the code. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _resending = false);
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
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: BrandMark(small: true),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          widget.title,
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
                          widget.subtitle ??
                              'We sent a verification code to\n${widget.email}',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 26),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: palette.softShadow,
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            cursorColor: OnboardingPalette.gold,
                            style: TextStyle(
                              fontSize: 22,
                              letterSpacing: 8,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: '------',
                              hintStyle: TextStyle(
                                color: palette.muted.withValues(alpha: 0.5),
                                letterSpacing: 8,
                              ),
                              filled: true,
                              fillColor: palette.paper,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: palette.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: palette.line),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: OnboardingPalette.gold,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GoldButton(
                          label: 'Verify',
                          loading: _verifying,
                          onPressed: _verify,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: _resending ? null : _resend,
                            child: Text(
                              _resending ? 'Sending…' : 'Resend code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.deepAccent,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Use a different email',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.muted,
                              ),
                            ),
                          ),
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
