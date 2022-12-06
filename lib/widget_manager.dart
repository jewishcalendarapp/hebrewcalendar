import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hebrew_calendar/geolocation.dart';
import 'package:hebrew_calendar/zman_types.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:workmanager/workmanager.dart';

const updateWidgetExactTimeTask =
    "com.jewish_calendar.hebrew_calendar.updateWidgetNow";
const simplePeriodicTask =
    "com.jewish_calendar.hebrew_calendar.simplePeriodicTask";

Future<void> _sendData(
  String dayOfMonth,
  String monthName,
) async {
  try {
    Future.wait([
      HomeWidget.saveWidgetData<String>('dayOfMonth', dayOfMonth),
      HomeWidget.saveWidgetData<String>('monthName', monthName),
    ]);
  } on PlatformException catch (exception) {
    debugPrint('Error Sending Data. $exception');
  }
}

Future<void> _updateWidget() async {
  try {
    HomeWidget.updateWidget(
        name: 'BasicDateHomeWidgetProvider',
        qualifiedAndroidName:
            'com.jewish_calendar.hebrew_calendar.BasicDateHomeWidgetProvider');
  } on PlatformException catch (exception) {
    debugPrint('Error Updating Widget. $exception');
  }
}

Future<DateTime?> _getTzeis(DateTime date) async {
  final latestLocation = await getLastKnownLocation();
  if (latestLocation == null) return null;
  final zmanim = ZmanimCalendar.intGeolocation(latestLocation.location)
    ..setCalendar(date);
  return getTzais6(zmanim);
}

Future<void> updateWidget(bool setInstantUpdate) async {
  final now = DateTime.now();
  final jewishDate = JewishCalendar.fromDateTime(now);
  final formatter = HebrewDateFormatter()..hebrewFormat = true;
  var tzeis = await _getTzeis(now);

  var switchTime = tzeis ??
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  if (now.isAfter(switchTime)) {
    tzeis = await _getTzeis(now.add(const Duration(days: 1)));
    switchTime = tzeis ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    jewishDate.forward();
  }
  final delay = switchTime.add(const Duration(seconds: 5)).difference(now);
  await _sendData(
    formatter.format(jewishDate, pattern: 'dd'),
    formatter.formatMonth(jewishDate),
  );
  await _updateWidget();
  if (!setInstantUpdate) return;
  await Workmanager().registerOneOffTask(
      updateWidgetExactTimeTask, updateWidgetExactTimeTask,
      initialDelay: delay, existingWorkPolicy: ExistingWorkPolicy.replace);
}
