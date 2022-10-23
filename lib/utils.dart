import 'package:kosher_dart/kosher_dart.dart';

const monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

int _getNumDays(int month, bool isLeapYear) {
  if (month == 2 && isLeapYear) return 29;

  return monthDays[month - 1];
}

DateTime getLastDayOfEnglishMonth(DateTime day) {
  final isLeapYear = JewishDate().isGregorianLeapYear(day.year);
  return DateTime(day.year, day.month, _getNumDays(day.month, isLeapYear));
}
