String formatPrice(double value) {
  if (value == 0) return '\$0.00';
  if (value >= 1) return '\$${_grouped(value, 2)}';
  if (value >= 0.01) return '\$${value.toStringAsFixed(4)}';
  return '\$${value.toStringAsFixed(8)}';
}

String formatCompactCurrency(double value) {
  if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
  if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
  return '\$${value.toStringAsFixed(2)}';
}

String formatNumber(double value) {
  if (value == 0) return 'N/A';
  if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
  return _grouped(value, value >= 1 ? 2 : 6);
}

String _grouped(double value, int decimals) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return parts.length == 1 ? buffer.toString() : '${buffer.toString()}.${parts[1]}';
}
