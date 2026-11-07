import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

final _short = DateFormat('MMM d');
final _withDay = DateFormat('EEE, MMM d');
final _full = DateFormat('EEE, MMM d, y');

String shortDate(DateTime d) => _short.format(d);
String dayDate(DateTime d) => _withDay.format(d);
String fullDate(DateTime d) => _full.format(d);

/// "Today · Sat, Nov 7", "Yesterday · Fri, Nov 6", "Thu, Nov 5".
String relativeDay(DateTime d, DateTime today) {
  if (sameDay(d, today)) return 'Today · ${dayDate(d)}';
  if (sameDay(d, today.subtract(const Duration(days: 1)))) return 'Yesterday · ${dayDate(d)}';
  return dayDate(d);
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

int daysBetween(DateTime from, DateTime to) => dateOnly(to).difference(dateOnly(from)).inDays;
