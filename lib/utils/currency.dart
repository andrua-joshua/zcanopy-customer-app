String formatThousands(dynamic value) {
  if (value == null) return '0';
  final num? amount = value is num ? value : num.tryParse(value.toString());
  final rounded = (amount ?? 0).round();
  return rounded.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

String formatUgx(dynamic value) => 'UGX ${formatThousands(value)}';