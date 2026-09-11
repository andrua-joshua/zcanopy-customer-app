import 'package:flutter/material.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/utils/currency.dart';

class PaymentSheet {
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> property,
    required Future<void> Function({
      required String phone,
      required String email,
      required String amount,
    })
        onSubmit,
  }) async {
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final price = property['price'] is num
        ? (property['price'] as num).toDouble()
        : double.tryParse(property['price'].toString()) ?? 0.0;
    final fee = property['bookingFee'] is num
        ? (property['bookingFee'] as num).toDouble()
        : price;
    final amountText = _formatPrice(fee);
    final showPropertyPrice = fee != price && price > 0;
    final methods = ['Mobile Money', 'Card', 'Bank Transfer'];
    String selectedMethod = methods.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Complete Booking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property['name']?.toString() ?? 'Property',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brown.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.brown.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Booking Fee', amountText),
                        if (showPropertyPrice)
                          _detailRow('Property Price', _formatPrice(price)),
                        _detailRow('Type',
                            property['type']?.toString() ?? '—'),
                        _detailRow('Location',
                            property['location']?.toString() ?? '—'),
                        const Divider(height: 16),
                        _detailRow('Broker',
                            property['brokerName']?.toString() ?? '—'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Phone number'),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.black),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                        'e.g. +256701234567'),
                  ),
                  const SizedBox(height: 12),
                  _label('Email (optional)'),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.black),
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !v.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                    decoration:
                        _inputDecoration('e.g. you@example.com'),
                  ),
                  const SizedBox(height: 12),
                  _label('Payment method'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMethod,
                        isExpanded: true,
                        items: methods
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) =>
                            setSheet(() => selectedMethod = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              setSheet(() => submitting = true);
                              try {
                                await onSubmit(
                                  phone: phoneCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  amount: amountText,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Payment failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setSheet(() => submitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brown,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Pay & Book',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  static String _formatPrice(double price) => formatUgx(price);
}
