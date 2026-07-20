import '../../data/models/app_transaction.dart';

String formatVnd(num value, {bool withSign = false}) {
  final rounded = value.round();
  final sign = rounded < 0
      ? '-'
      : withSign && rounded > 0
      ? '+'
      : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  return '$sign${buffer.toString()} ₫';
}

String formatTransactionAmount(AppTransaction transaction) {
  final value = transaction.type == AppTransactionType.income
      ? transaction.amount
      : -transaction.amount;
  return formatVnd(value, withSign: true);
}

String formatShortDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;

  if (difference == 0) return 'Hôm nay';
  if (difference == 1) return 'Hôm qua';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '--';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String monthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

bool isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
