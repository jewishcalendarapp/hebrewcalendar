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

int getWeeksInMonth(DateTime day) {
  final isLeapYear = JewishDate().isGregorianLeapYear(day.year);
  final numDays = _getNumDays(day.month, isLeapYear);
  final dayOfWeek = DateTime(day.year, day.month, 1).weekday % 7; // sunday is 0
  return ((numDays + dayOfWeek) / 7).ceil();
}
