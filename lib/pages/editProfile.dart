import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zcanopy/services/auth_service.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';

class ProfilePageEdit extends StatefulWidget {
  const ProfilePageEdit({super.key});

  @override
  State<ProfilePageEdit> createState() => _ProfilePageEditState();
}

class _ProfilePageEditState extends State<ProfilePageEdit> {
  final _phoneCtrl = TextEditingController();
  final _api = GatewayApi();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = AuthService.instance.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _normalizedPhone(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 9) digits = '256$digits';
    if (digits.length == 10 && digits.startsWith('0')) {
      digits = '256${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _save() async {
    final phone = _normalizedPhone(_phoneCtrl.text);
    if (phone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number, e.g. 0700 000 000'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.updateCustomerPhone(phone);
      await AuthService.instance.refreshProfile();
      if (!mounted) return;
      _phoneCtrl.text = AuthService.instance.phoneNumber ?? phone;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number updated'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your phone number'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthService.instance.isSignedIn;
    final name = AuthService.instance.displayName;
    final email = AuthService.instance.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: context.appPrimaryBrown,
        foregroundColor: Colors.white,
      ),
      body: ThemedPageBackground(
        lightOverlay: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 16),
              if (!signedIn)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You are browsing as a guest. Sign in to manage your account details.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                _readOnly('Name', name),
                const SizedBox(height: 12),
                _readOnly('Email', email),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '0700 000 000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A phone number is needed so brokers can reach you about a booking.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appPrimaryBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save changes'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnly(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appPrimaryBrown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
