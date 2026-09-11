import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/phoneOTP.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';

/// Customer login: enter a phone number, receive an OTP and verify it with the
/// existing phone OTP flow. On success the screen returns `true` so the caller
/// (e.g. the booking flow) can continue where it left off.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _brown = Color.fromARGB(255, 169, 97, 14);

  final _phoneCtrl = TextEditingController();
  final _db = Hive.box('myStore');

  bool _sending = false;
  bool _verified = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    var digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 9) digits = '256$digits';
    if (digits.length == 10 && digits.startsWith('0')) {
      digits = '256${digits.substring(1)}';
    }
    return digits;
  }

  bool _validatePhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Uganda mobile: 256 7XXXXXXXX or 0 7XXXXXXXX or 7XXXXXXXX
    final valid = digits.length == 9 ||
        (digits.length == 10 && digits.startsWith('0'));
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid Ugandan phone number (e.g. 0700 000 000)'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return valid;
  }

  Future<void> _continue() async {
    if (_sending) return;
    if (!_validatePhone()) return;

    setState(() => _sending = true);
    // DEV: API call delinked — jump straight to the OTP screen.
    final phone = '+$_normalizedPhone';
    if (mounted) setState(() => _sending = false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneOtpScreen(
          phoneNumber: phone,
          verificationId: 'dev-verification-id',
          onVerified: () {
            setState(() => _verified = true);
            _db.put('phoneNumber', phone);
            _db.put('loginType', 'phone');
          },
        ),
      ),
    );

    if (_verified && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final onSurface = context.appOnSurface;
    final muted = context.appMutedTextColor;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: ThemedPageBackground(
              lightOverlay: true,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ClipOval(
                      child: Image.asset('assets/midLOGO.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Login to Book',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verify your phone number to reserve\nproperties and manage your bookings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: muted),
                  ),
                  const SizedBox(height: 32),

                  // Phone input
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+256',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                              const VerticalDivider(width: 20, indent: 18, endIndent: 18),
                            ],
                          ),
                        ),
                        hintText: '7XX XXX XXX',
                        hintStyle:
                            TextStyle(color: muted.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        disabledBackgroundColor: _brown.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 14, color: muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A one-time code is sent to your phone. '
                            'We never share your number.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded,
                      color: onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}