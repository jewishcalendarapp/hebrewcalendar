import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:kosher_dart/kosher_dart.dart';

import 'heb_day.dart';
import 'zmanim.dart';
import 'geolocation.dart';
import 'utils.dart';
import 'local_events.dart';

String _getMonthsTitle(DateTime day) {
  final firstJday =
      JewishCalendar.fromDateTime(DateTime(day.year, day.month, 1));
  final middleJday =
      JewishCalendar.fromDateTime(DateTime(day.year, day.month, 1));

  final formatter = HebrewDateFormatter()..hebrewFormat = true;

  final lastJday = JewishCalendar.fromDateTime(getLastDayOfEnglishMonth(day));
  final hebyears = [
    firstJday.getJewishYear(),
    if (firstJday.getJewishYear() != lastJday.getJewishYear())
      lastJday.getJewishYear()
  ].map((d) => formatter.formatHebrewNumber(d)).join("-");
  final hebmonths = [
    firstJday,
    if (middleJday.getJewishMonth() != firstJday.getJewishMonth()) middleJday,
    if (lastJday.getJewishMonth() != middleJday.getJewishMonth()) lastJday,
  ].map((d) => formatter.formatMonth(d)).join("/");
  final englishDate = DateFormat.yMMMM().format(day);
  return "$englishDate - $hebmonths $hebyears";
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hebrew Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Hebrew Calendar'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _selectedDay = DateTime.now();
  var _zmanimExpanded = false;
  var _eventsExpanded = false;
  final _firstDay = DateTime(1900);
  final _lastDay = DateTime(2400);

  final formatter = HebrewDateFormatter()..hebrewFormat = true;
  MonthEvents _cachedMonthEvents = MonthEvents(DateTime(1300), {});
  Future<MonthEvents> _monthEvents() async {
    if (_cachedMonthEvents.date.year == _selectedDay.year &&
        _cachedMonthEvents.date.month == _selectedDay.month) {
      return _cachedMonthEvents;
    }
    final events = await getEvents(_selectedDay);
    _cachedMonthEvents = events;
    return events;
  }

  GeoLocation? _cachedGeoLocation;
  Future<GeoLocation> _geoLocation() async {
    if (_cachedGeoLocation != null) return _cachedGeoLocation!;
    final location = await determinePosition();
    _cachedGeoLocation = location;
    return location;
  }

  void _setCurrentDay(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
    });
  }

  void _updateCurrentDay(DateTime focusedDay) {
    setState(() {
      _selectedDay = focusedDay;
    });
  }

  Future<void> _selectMonthYear() async {
    final selectedDate = await showDialog<DateTime?>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Select assignment'),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context,
                      DateTime.now().subtract(const Duration(days: 365)));
                },
                child: const Text('go to last year'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(
                      context, DateTime.now().add(const Duration(days: 365)));
                },
                child: const Text('go to next year'),
              ),
            ],
          );
        });
    if (selectedDate != null) {
      setState(() {
        _selectedDay = selectedDate;
      });
    }
  }

  ExpansionPanel _buildZmanimPanel(AsyncSnapshot<GeoLocation> snapshot) {
    return ExpansionPanel(
      headerBuilder: (BuildContext context, bool isExpanded) {
        return ListTile(
          title: const Text("Zmanim"),
          trailing: snapshot.hasError
              ? const Icon(Icons.error, color: Colors.red)
              : (!snapshot.hasData ? const CircularProgressIndicator() : null),
        );
      },
      body: snapshot.hasData
          ? ZmanimBox(
              day: JewishCalendar.fromDateTime(_selectedDay),
              zmanim: ZmanimCalendar.intGeolocation(snapshot.data!)
                ..setCalendar(_selectedDay))
          : Text('Error getting location for zmanim: ${snapshot.error}'),
      isExpanded:
          (snapshot.hasData || snapshot.hasError) ? _zmanimExpanded : false,
    );
  }

  ExpansionPanel _buildEventsPanel(AsyncSnapshot<MonthEvents> snapshot) {
    final hasData = snapshot.data?.hasDataForDay(_selectedDay) ?? false;
    final events = snapshot.data?.getEvents(_selectedDay) ?? [];
    final noEvents = hasData && events.isEmpty;
    return ExpansionPanel(
      headerBuilder: (BuildContext context, bool isExpanded) {
        return ListTile(
          enabled: !noEvents,
          title: noEvents ? const Text("No Events") : const Text("Events"),
          trailing: snapshot.hasError
              ? const Icon(Icons.error, color: Colors.red)
              : (!hasData && snapshot.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : (noEvents
                      ? null
                      : Chip(label: Text(events.length.toString())))),
        );
      },
      body: snapshot.hasData
          ? Column(
              children: events
                  .map((e) => Container(
                        color: e.color,
                        child: Text(
                          e.event.title ?? "unnamed event",
                        ),
                      ))
                  .toList(),
            )
          : Text('Error getting event data: ${snapshot.error}'),
      isExpanded: (snapshot.hasData || snapshot.hasError) && !noEvents
          ? _eventsExpanded
          : false,
    );
  }

  Widget _buildExpansionPanelList(AsyncSnapshot<GeoLocation> geoSnapshot,
      AsyncSnapshot<MonthEvents> eventsSnapshot) {
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          if (index == 0) _zmanimExpanded = !isExpanded;
          if (index == 1) _eventsExpanded = !isExpanded;
        });
      },
      children: [
        _buildZmanimPanel(geoSnapshot),
        _buildEventsPanel(eventsSnapshot)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_getMonthsTitle(_selectedDay)),
        titleTextStyle: const TextStyle(fontSize: 12),
        actions: [
          IconButton(
              onPressed: () => _selectMonthYear(),
              icon: const Icon(Icons.menu)),
          IconButton(
              onPressed: () => _updateCurrentDay(DateTime.now()),
              icon: const Icon(Icons.calendar_today))
        ],
      ),
      body: FutureBuilder<MonthEvents>(
          future: _monthEvents(),
          builder: (BuildContext context,
                  AsyncSnapshot<MonthEvents> eventsSnapshot) =>
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  TableCalendar(
                    focusedDay: _selectedDay,
                    firstDay: _firstDay,
                    lastDay: _lastDay,
                    onDaySelected: _setCurrentDay,
                    onPageChanged: _updateCurrentDay,
                    rowHeight: 80,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month'
                    },
                    headerVisible: false,
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) {
                        if (day.weekday == DateTime.saturday) {
                          const text = "Sha";

                          return const Center(
                            child: Text(
                              text,
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        return null;
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return JewishDayCell(
                          day: JewishCalendar.fromDateTime(day),
                          events: eventsSnapshot.data?.getEvents(day) ?? [],
                          isToday: true,
                          isInCurrentMonth: day.month == focusedDay.month,
                          isSelected: day == focusedDay,
                        );
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        return JewishDayCell(
                          day: JewishCalendar.fromDateTime(day),
                          events: eventsSnapshot.data?.getEvents(day) ?? [],
                          isToday: false,
                          isInCurrentMonth: true,
                          isSelected: day == focusedDay,
                        );
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        return JewishDayCell(
                          day: JewishCalendar.fromDateTime(day),
                          events: eventsSnapshot.data?.getEvents(day) ?? [],
                          isToday: false,
                          isInCurrentMonth: false,
                          isSelected: day == focusedDay,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.yMMMMd().format(_selectedDay),
                            style: const TextStyle(color: Colors.green),
                          ),
                          Text(
                            formatter.format(
                                JewishCalendar.fromDateTime(_selectedDay)),
                            style: const TextStyle(color: Colors.green),
                          )
                        ],
                      ),
                      Expanded(
                          child: SingleChildScrollView(
                              child: Column(
                        children: [
                          FutureBuilder<GeoLocation>(
                            future: _geoLocation(),
                            builder: (BuildContext context,
                                AsyncSnapshot<GeoLocation> geoSnapshot) {
                              return _buildExpansionPanelList(
                                  geoSnapshot, eventsSnapshot);
                            },
                          ),
                        ],
                      )))
                    ]),
                  ),
                ],
              )),
    );
  }
}
