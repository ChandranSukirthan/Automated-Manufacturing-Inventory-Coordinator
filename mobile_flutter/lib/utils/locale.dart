String formatMoney(num amount, {String currency = 'LKR'}) {
  if (!amount.isFinite) return 'Not available';
  final code = RegExp(r'^[A-Z]{3}$').hasMatch(currency.toUpperCase())
      ? currency.toUpperCase()
      : 'LKR';
  final parts = amount.toStringAsFixed(2).split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '$code $grouped.${parts[1]}';
}
