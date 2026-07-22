import 'package:flutter/material.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showAgreeButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_showAgreeButton) {
        setState(() => _showAgreeButton = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.appSurface,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.appPrimaryBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms of Agreement',
          style: TextStyle(
            color: context.appPrimaryBrown,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ThemedPageBackground(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Effective Date: July 21, 2026',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.brown,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to ZCanopy. These Terms of Agreement govern your use of the ZCanopy platform. '
                'By accessing or using the Platform, you agree to be bound by these terms. '
                'If you do not agree with any part of these terms, you must not use the Platform.',
                style: TextStyle(height: 1.6, color: context.appOnSurface, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _section('1. Acceptance of Terms',
                  'By creating an account or using the Platform, you confirm that you have read, understood, and agree to these Terms of Agreement. '
                  'You further agree to comply with all applicable laws, regulations, and policies referenced herein.'),
              _section('2. Changes to the Terms',
                  'We may revise these Terms of Agreement at any time without prior notice. '
                  'Continued use of the Platform after any changes take effect constitutes your acceptance of the revised terms. '
                  'It is your responsibility to review these terms periodically.'),
              _section('3. User Obligations',
                  'You agree to provide accurate, current, and complete information when using the Platform. '
                  'You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account. '
                  'You agree not to misuse the Platform or assist others in doing so.'),
              _section('4. Fraud, Investigations & Cooperation with Authorities',
                  'ZCanopy has zero tolerance for fraud. In the event that fraudulent, criminal, or otherwise unlawful activity is suspected or reported '
                  'in connection with your account or transactions, you expressly consent and agree that ZCanopy may disclose your personal and account '
                  'information — including your full name, identity documents, phone number, email address, transaction history, and any related records — '
                  'to the relevant law enforcement agencies, regulatory bodies, or other competent authorities.\n\n'
                  'This disclosure may occur with or without prior notice to you, to the extent permitted by applicable law, and you waive any objection '
                  'to such disclosure where it is made in good faith for the purpose of investigating, preventing, or prosecuting fraud or other unlawful conduct.\n\n'
                  'You agree to cooperate fully with ZCanopy and any authorities in any investigation relating to your use of the Platform.'),
              _section('5. Commissions, Fees & Payments',
                  'Brokers agree to the applicable subscription fees, platform commissions, and payment terms as displayed on the Platform. '
                  'ZCanopy may deduct platform commissions from transactions processed through the Platform. '
                  'All fees are non-refundable unless otherwise stated.'),
              _section('6. Limitation of Liability',
                  'ZCanopy acts as a marketplace connecting brokers and clients. We are not a party to the agreements between brokers and their clients '
                  'and are not liable for the conduct of any user or the accuracy of any listing. '
                  'To the fullest extent permitted by law, ZCanopy shall not be liable for any indirect, incidental, special, or consequential damages.'),
              _section('7. Privacy',
                  'We collect and process personal data in accordance with applicable data protection laws. '
                  'By using the Platform you consent to the collection, storage, and processing of your data for the purposes of operating the Platform, '
                  'verifying identities, and — where necessary — cooperating with authorities as described in Section 4.'),
              _section('8. Suspension & Termination',
                  'ZCanopy may suspend or terminate your access to the Platform at any time, with or without notice, if you breach these terms or engage '
                  'in conduct that harms the Platform, other users, or the public. '
                  'Upon termination, all licenses granted hereunder shall immediately cease.'),
              _section('9. Changes to These Terms',
                  'We may update these terms from time to time. Continued use of the Platform after changes take effect constitutes acceptance of the revised terms. '
                  'Material changes will be communicated through the Platform or via email.'),
              _section('10. Contact Us',
                  'For questions about these terms, contact us at:\n\n'
                  'Email: support@zcanopy.com\n'
                  'Phone: +256741882818\n'
                  'Address: Kampala, Uganda'),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade200 : Colors.brown,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(height: 1.6, color: context.appOnSurface, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
