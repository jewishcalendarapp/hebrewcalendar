import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart';

import 'utils.dart';

final _timeFormatter = DateFormat.jm();
String? _nativeTimeZone;

void initializeTzData() async {
  initializeTimeZones();
  await ensureLocalTzSet();
}

Future<void> ensureLocalTzSet() async {
  if (_nativeTimeZone != null) return;
  _nativeTimeZone = await FlutterNativeTimezone.getLocalTimezone();
  var localTz = getLocation(_nativeTimeZone!);
  setLocalLocation(localTz);
}

final _colors = [
  Colors.blue.shade200,
  Colors.red.shade200,
  Colors.green.shade200,
  Colors.teal.shade200,
  Colors.amber.shade200,
  Colors.brown.shade200,
  Colors.deepPurple.shade200,
];

Future<bool> _getCalendarPermissions() async {
  final deviceCalendarPlugin = DeviceCalendarPlugin();
  try {
    var permissionsGranted = await deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess &&
        (permissionsGranted.data == null || permissionsGranted.data == false)) {
      permissionsGranted = await deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess ||
          permissionsGranted.data == null ||
          permissionsGranted.data == false) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('disableCalendar', true);
        return false;
      }
    }
  } on PlatformException catch (_) {
    return false;
  }
  return true;
}

class EventsWithColor {
  final Event event;
  final Color color;
  EventsWithColor(this.event, this.color);

  String get title =>
      (event.title?.isEmpty ?? true) ? '(no title)' : event.title!;
  String get description => event.description ?? '';
  bool get allDay => event.allDay ?? false;
  bool get showStartTime => !allDay && event.start != null;
  TZDateTime? get start => event.start;
  TZDateTime? get startLocal => event.start == null
      ? null
      : TZDateTime.fromMicrosecondsSinceEpoch(
          getLocation(_nativeTimeZone!), event.start!.microsecondsSinceEpoch);
  TZDateTime? get end => event.end;
  TZDateTime? get endLocal => event.end == null
      ? null
      : TZDateTime.fromMicrosecondsSinceEpoch(
          getLocation(_nativeTimeZone!), event.end!.microsecondsSinceEpoch);
  String? get startTimeFormatted =>
      event.start == null ? null : _timeFormatter.format(startLocal!);
  String? get endTimeFormatted =>
      event.end == null ? null : _timeFormatter.format(endLocal!);
  List<Attendee> get attendees =>
      event.attendees?.whereType<Attendee>().toList() ?? [];
  String get location => event.location ?? '';
}

class MonthEvents {
  final DateTime date;
  final Map<String, List<EventsWithColor>> _eventsByDay;
  MonthEvents(this.date, this._eventsByDay);
  List<EventsWithColor> getEvents(DateTime day) =>
      _eventsByDay[_dateKey(day)] ?? [];
  bool hasDataForDay(DateTime day) =>
      _eventsByDay.containsKey(_dateKey(day)) ||
      (day.year == date.year && day.month == date.month);
}

String _dateKey(DateTime day) => '${day.month}_${day.day}';

Future<MonthEvents> getEvents(DateTime day) async {
  final prefs = await SharedPreferences.getInstance();
  final disableCalendar = prefs.getBool('disableCalendar') ?? false;
  if (disableCalendar) {
    return MonthEvents(day, {});
  }
  final hasPermission = await _getCalendarPermissions();
  if (!hasPermission) {
    return MonthEvents(day, {});
  }
  await ensureLocalTzSet();
  final allEvents = <String, List<EventsWithColor>>{};
  final firstDayOfMonth = DateTime(day.year, day.month, 1);
  final firstDayInCalendar =
      firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));
  final lastDayOfMonth = getLastDayOfEnglishMonth(day);
  final lastDayInCalendar =
      lastDayOfMonth.add(Duration(days: 7 - (lastDayOfMonth.weekday % 7)));
  final plugin = DeviceCalendarPlugin();
  final calendars = await plugin.retrieveCalendars();
  if (calendars.isSuccess) {
    final hiddenCals = prefs.getStringList('hiddenCalendars') ?? [];
    final calendarEvents = await Future.wait(calendars.data!
        .where((cal) => !hiddenCals.contains(cal.id ?? ''))
        .map((e) => plugin.retrieveEvents(
            e.id,
            RetrieveEventsParams(
                startDate: firstDayInCalendar, endDate: lastDayInCalendar))));
    for (final events in calendarEvents) {
      if (events.isSuccess) {
        for (final event in events.data ?? <Event>[]) {
          final key = _dateKey(event.start!);
          final color = _colors[event.calendarId.hashCode % _colors.length];
          allEvents
              .putIfAbsent(key, () => <EventsWithColor>[])
              .add(EventsWithColor(event, color));
        }
      }
    }
  }
  for (final value in allEvents.values) {
    value.sort(_sortEvents);
  }
  return MonthEvents(day, allEvents);
}

int _sortEvents(EventsWithColor a, EventsWithColor b) {
  if (a.allDay && b.allDay) return 0;
  if (a.allDay) return -1;
  if (b.allDay) return 1;
  final aStart = a.start;
  final bStart = b.start;
  if (aStart == null && bStart == null) return 0;
  if (aStart == null) return 1;
  if (bStart == null) return -1;
  return aStart.microsecondsSinceEpoch - bStart.microsecondsSinceEpoch;
}
