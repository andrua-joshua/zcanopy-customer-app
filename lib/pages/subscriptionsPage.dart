import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _apiService = ApiService();
  final database = Hive.box('myStore');

  bool _isLoading = true;
  String? _error;

  // Tiers as returned by the backend GetAvailableTiers endpoint.
  // Each tier carries the full set of properties defined at the backend:
  // tier, name, price, currency, expiryDays, advantages[], limits{}.
  List<Map<String, dynamic>> _tiers = [];

  // Currently selected (active) tier + subscription expiry timestamp.
  String _activeTier = 'prop';
  DateTime? _expiresAt;

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userID = database.get('userID');

    try {
      final isSessionValid = await SessionService.validateSession();
      if (!isSessionValid) {
        if (mounted) {
          await _forceLogout();
        }
        return;
      }

      // Fetch tiers + current broker subscription in parallel.
      final results = await Future.wait([
        _apiService.getSubscriptionPackages(),
        if (userID != null) _apiService.getBroker(userID) else Future.value(<String, dynamic>{}),
      ]);

      final packagesRes = results[0];
      final brokerRes = results.length > 1 ? results[1] : <String, dynamic>{};

      final tiers = <Map<String, dynamic>>[];
      if (packagesRes['success'] == true && packagesRes['tiers'] != null) {
        for (final t in (packagesRes['tiers'] as List)) {
          tiers.add(Map<String, dynamic>.from(t as Map));
        }
      } else if (packagesRes['tiers'] != null) {
        for (final t in (packagesRes['tiers'] as List)) {
          tiers.add(Map<String, dynamic>.from(t as Map));
        }
      }

      // Fall back to the backend-defined defaults if the API is unavailable.
      if (tiers.isEmpty) tiers.addAll(_defaultTiers());

      String activeTier = 'prop';
      DateTime? expiresAt;
      if (brokerRes.isNotEmpty) {
        activeTier = brokerRes['subscriptionTier']?.toString() ??
            brokerRes['subscription_tier']?.toString() ??
            'prop';
        final rawExpiry = brokerRes['subscriptionExpiresAt'] ??
            brokerRes['subscription_expires_at'];
        if (rawExpiry != null) {
          expiresAt = DateTime.tryParse(rawExpiry.toString());
        }
      }

      setState(() {
        _tiers = tiers;
        _activeTier = activeTier;
        _expiresAt = expiresAt;
        _isLoading = false;
      });

      _startCountdown();
    } catch (e) {
      print('Load subscription data error: $e');
      if (mounted) {
        setState(() {
          _tiers = _defaultTiers();
          _isLoading = false;
          _error = 'Could not load subscription data. Showing default plans.';
        });
        _startCountdown();
      }
    }
  }

  /// Backend-defined tiers (broker.service.ts GetAvailableTiers) used as a
  /// resilient fallback when the API is unreachable.
  List<Map<String, dynamic>> _defaultTiers() {
    return [
      {
        'tier': 'prop',
        'name': 'Prop',
        'price': 0,
        'currency': 'UGX',
        'expiryDays': 0,
        'advantages': [
          'Up to 5 properties',
          '15 photos per property',
          '1 video per property',
          '500MB max video size',
        ],
        'limits': {
          'maxProperties': 5,
          'maxPhotosPerProperty': 15,
          'maxVideosPerProperty': 1,
          'maxVideoSizeMB': 500,
        },
      },
      {
        'tier': 'buttress',
        'name': 'Buttress',
        'price': 50000,
        'currency': 'UGX',
        'expiryDays': 30,
        'advantages': [
          'Up to 16 properties',
          '50 photos per property',
          '4 videos per property',
          '4GB max video size',
          'Priority support',
        ],
        'limits': {
          'maxProperties': 16,
          'maxPhotosPerProperty': 50,
          'maxVideosPerProperty': 4,
          'maxVideoSizeMB': 4 * 1024,
        },
      },
      {
        'tier': 'fibrous',
        'name': 'Fibrous',
        'price': 25000,
        'currency': 'UGX',
        'expiryDays': 30,
        'advantages': [
          'Up to 12 properties',
          '25 photos per property',
          '2 videos per property',
          '12GB max video size',
          'Premium support',
          'Advanced analytics',
        ],
        'limits': {
          'maxProperties': 12,
          'maxPhotosPerProperty': 25,
          'maxVideosPerProperty': 2,
          'maxVideoSizeMB': 12 * 1024,
        },
      },
    ];
  }

  void _startCountdown() {
    _updateRemaining();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (_expiresAt == null) return;
    final diff = _expiresAt!.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  String _formatCountdown(Duration d) {
    if (_activeTier == 'prop' || _expiresAt == null) return 'Lifetime';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }

  Map<String, dynamic> get _activeTierData {
    return _tiers.firstWhere(
      (t) => t['tier'] == _activeTier,
      orElse: () => _tiers.isNotEmpty
          ? _tiers.first
          : {'tier': 'prop', 'name': 'Prop', 'price': 0, 'currency': 'UGX'},
    );
  }

  String _tierIcon(String tier) {
    switch (tier) {
      case 'buttress':
        return 'assets/buttress-root.svg';
      case 'fibrous':
        return 'assets/fibrous-root.svg';
      case 'prop':
      default:
        return 'assets/prop-root.svg';
    }
  }

  String _formatPrice(Map<String, dynamic> tier) {
    final price = tier['price'] ?? 0;
    final currency = tier['currency'] ?? 'UGX';
    if (price == 0) return 'Free';
    final grouped = price
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},');
    return '$currency $grouped';
  }

  Future<void> _forceLogout() async {
    await database.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Subscriptions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 169, 97, 14),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: ZLoadingIndicator(
                color: Color.fromARGB(255, 169, 97, 14),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color.fromARGB(255, 169, 97, 14),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    _buildActiveTierCard(),
                    const SizedBox(height: 24),
                    const Text(
                      "Available Plans",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._tiers.map((tier) => _buildTierCard(tier)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActiveTierCard() {
    final tier = _activeTierData;
    final isFree = _activeTier == 'prop';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5D4037),
            Color(0xFFE65100),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  _tierIcon(_activeTier),
                  height: 56,
                  width: 56,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "CURRENT PLAN",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tier['name'] ?? 'Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatPrice(tier),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    isFree ? "Free plan — no expiry" : "Time remaining",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCountdown(_remaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier) {
    final isActive = tier['tier'] == _activeTier;
    final limits = Map<String, dynamic>.from(tier['limits'] ?? {});
    final advantages = List<dynamic>.from(tier['advantages'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isActive
            ? Border.all(
                color: const Color.fromARGB(255, 169, 97, 14),
                width: 2,
              )
            : Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  _tierIcon(tier['tier']),
                  height: 40,
                  width: 40,
                  colorFilter: const ColorFilter.mode(
                    Color.fromARGB(255, 169, 97, 14),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _formatPrice(tier),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 169, 97, 14),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "ACTIVE",
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  tier['expiryDays'] == 0 || tier['expiryDays'] == null
                      ? "No expiry (lifetime)"
                      : "Renews every ${tier['expiryDays']} days",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 6),
            const Text(
              "What's included",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...advantages.map((a) => _buildAdvantageRow(a.toString())),
            if (limits.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLimitChip(
                    Icons.home_work_outlined,
                    "${limits['maxProperties']} properties",
                  ),
                  _buildLimitChip(
                    Icons.photo_library_outlined,
                    "${limits['maxPhotosPerProperty']} photos",
                  ),
                  _buildLimitChip(
                    Icons.videocam_outlined,
                    "${limits['maxVideosPerProperty']} videos",
                  ),
                  _buildLimitChip(
                    Icons.storage_outlined,
                    _formatVideoSize(limits['maxVideoSizeMB']),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActive
                    ? null
                    : () => _openPaymentDialog(tier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 169, 97, 14),
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isActive ? "Current Plan" : "Activate",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvantageRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Color.fromARGB(255, 169, 97, 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 169, 97, 14).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color.fromARGB(255, 169, 97, 14),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 169, 97, 14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatVideoSize(dynamic mb) {
    final value = (mb ?? 0) as num;
    if (value >= 1024) {
      return "${(value / 1024).toStringAsFixed(0)}GB max";
    }
    return "${value}MB max";
  }

  void _openPaymentDialog(Map<String, dynamic> tier) {
    int selectedMethod = 0; // 0 = MTN, 1 = Airtel
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Column(
                children: [
                  SvgPicture.asset(
                    _tierIcon(tier['tier']),
                    height: 44,
                    width: 44,
                    colorFilter: const ColorFilter.mode(
                      Color.fromARGB(255, 169, 97, 14),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Activate ${tier['name']}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatPrice(tier),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 169, 97, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Choose payment method",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _paymentOption(
                        "MTN Mobile Money",
                        selectedMethod == 0,
                        Colors.yellow.shade700,
                        'assets/mtnSym.png',
                        0,
                        (i) => setDialogState(() => selectedMethod = i),
                      ),
                      const SizedBox(height: 8),
                      _paymentOption(
                        "Airtel Money",
                        selectedMethod == 1,
                        Colors.red.shade600,
                        'assets/airtelSym.png',
                        1,
                        (i) => setDialogState(() => selectedMethod = i),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: context.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.appInputFillColor,
                          contentPadding: const EdgeInsets.all(12),
                          prefixIcon: const Icon(Icons.phone),
                          hintText: "Enter mobile number (075**)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 169, 97, 14),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final phone = phoneCtrl.text.trim();
                    if (phone.length != 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Enter a valid 10-digit number"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _activateTier(
                      tier: tier,
                      method: selectedMethod == 0 ? 'MTN' : 'AIRTEL',
                      phoneNumber: phone,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 169, 97, 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Confirm Payment",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _paymentOption(
    String text,
    bool selected,
    Color color,
    String iconPath,
    int index,
    Function(int) onTap,
  ) {
    final isDark = context.isDarkMode;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
          color: isDark
              ? (selected ? color.withOpacity(0.15) : const Color(0xFF2A2A2A))
              : Colors.white,
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6)]
              : [],
        ),
        child: ListTile(
          leading: Image.asset(iconPath, width: 22, height: 22),
          title: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          trailing: selected ? Icon(Icons.check_circle, color: color) : null,
        ),
      ),
    );
  }

  Future<void> _activateTier({
    required Map<String, dynamic> tier,
    required String method,
    required String phoneNumber,
  }) async {
    final userID = database.get('userID');
    if (userID == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            ZLoadingIndicator(
              size: 22,
              strokeWidth: 2,
              color: Color.fromARGB(255, 169, 97, 14),
            ),
            SizedBox(width: 16),
            Text("Activating plan..."),
          ],
        ),
      ),
    );

    try {
      final response = await _apiService.subscribeToPackage(
        userId: userID,
        packageId: tier['tier'],
        paymentMethod: method,
        phoneNumber: phoneNumber,
      );

      if (mounted) Navigator.pop(context);

      final success = response['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Payment initiated for ${tier['name']} via $method"
                : (response['message'] ?? "Activation failed"),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Activation error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
