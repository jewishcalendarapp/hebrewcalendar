import 'dart:math';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:hebrew_calendar/about_page.dart';
import 'package:hebrew_calendar/settings.dart';
import 'package:hebrew_calendar/widget_manager.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'heb_day.dart';
import 'zmanim.dart';
import 'geolocation.dart';
import 'utils.dart';
import 'local_events.dart';

@pragma('vm:entry-point') // Mandatory if the App is using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await updateWidget(taskName != updateWidgetExactTimeTask);

    return Future.value(true);
  });
}

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
  WidgetsFlutterBinding.ensureInitialized();
  updateWidget(true);
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    simplePeriodicTask,
    simplePeriodicTask,
    frequency: const Duration(hours: 3),
    initialDelay: const Duration(seconds: 10),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
  initializeTzData();
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
      localizationsDelegates: const [
        MonthYearPickerLocalizations.delegate,
        // ... app-specific localization delegate[s] here
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
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
    try {
      final location = await determinePosition();
      _cachedGeoLocation = location.location;
      updateWidget(true);
      return location.location;
    } catch (e) {
      return Future.error(e);
    }
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

  void _selectMonthYear() async {
    Navigator.of(context).pop();
    final selectedDate = await showMonthYearPicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(1900),
      lastDate: DateTime(2300),
    );
    if (!mounted) return;
    if (selectedDate != null) {
      setState(() {
        _selectedDay = selectedDate;
      });
    }
  }

  String _formatEventTime(EventsWithColor event) {
    if (event.allDay) return 'Full Day Event';
    if (event.start != null && event.end != null) {
      final start =
          '${event.startTimeFormatted} ${event.startLocal!.timeZoneName}';
      final end = '${event.endTimeFormatted} ${event.endLocal!.timeZoneName}';
      return '$start - $end';
    }
    return 'No Time Set';
  }

  String _getAttendeeName(Attendee a) {
    final name = a.name ?? '';
    if (name.isNotEmpty) return name;
    return a.emailAddress ?? 'Unknown person';
  }

  ListTile _getAttendeeRow(Attendee a, {bool showLeadingWidget = false}) {
    final statusIcon = _getAttendeeStatus(a);
    final name = _getAttendeeName(a);
    return ListTile(
      leading: Icon(Icons.people,
          color: showLeadingWidget ? null : Colors.transparent),
      title: Text(name),
      subtitle: a.isOrganiser ? const Text('Organizer') : null,
      trailing: statusIcon,
      visualDensity: VisualDensity.compact,
    );
  }

  ExpansionTile _getAttendeesRow(List<Attendee> attendees) {
    return ExpansionTile(
      leading: const Icon(Icons.people),
      title: Text('Attendees (${attendees.length})'),
      children: attendees.map(_getAttendeeRow).toList(),
    );
  }

  Icon? _getAttendeeStatus(Attendee a) {
    switch (a.androidAttendeeDetails?.attendanceStatus) {
      case AndroidAttendanceStatus.Accepted:
        return const Icon(Icons.check, color: Colors.green);
      case AndroidAttendanceStatus.Declined:
        return const Icon(
          Icons.not_interested,
          color: Colors.red,
        );
      default:
        return null;
    }
  }

  SimpleDialog _createEventDialog(EventsWithColor event) {
    return SimpleDialog(
      title: Text(event.title),
      contentPadding: const EdgeInsets.all(8),
      children: [
        ListTile(
          leading: const Icon(Icons.access_time),
          title: Text(_formatEventTime(event)),
          visualDensity: VisualDensity.compact,
        ),
        if (event.location.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(event.location),
            visualDensity: VisualDensity.compact,
          ),
        if (event.attendees.length == 1)
          _getAttendeeRow(event.attendees.single, showLeadingWidget: true),
        if (event.attendees.length > 1) _getAttendeesRow(event.attendees),
        if (event.description.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Linkify(
              text: event.description,
              onOpen: (link) async {
                final url = Uri.parse(link.url);
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
          )
      ],
    );
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
          : Container(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  const Text('Error getting location for zmanim:'),
                  Text('${snapshot.error}'),
                  MaterialButton(
                    color: Colors.blue,
                    textColor: Colors.white,
                    onPressed: _goToSettingsPage,
                    child: const Text('Open settings'),
                  )
                ],
              )),
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
                  .map(
                    (e) => Container(
                      margin: const EdgeInsets.all(4.0),
                      child: InkWell(
                        onTap: () => showDialog(
                            context: context,
                            builder: ((context) => _createEventDialog(e))),
                        child: Ink(
                          padding: const EdgeInsets.all(4.0),
                          color: e.color,
                          child: Text((e.showStartTime
                                  ? '${e.startTimeFormatted}: '
                                  : '') +
                              e.title),
                        ),
                      ),
                    ),
                  )
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
          if (index == 0) _zmanimExpanded = !_zmanimExpanded;
          if (index == 1) _eventsExpanded = !_eventsExpanded;
        });
      },
      children: [
        _buildZmanimPanel(geoSnapshot),
        _buildEventsPanel(eventsSnapshot)
      ],
    );
  }

  void _goToSettingsPage() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const SettingsPage()));
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
    setState(() {
      _cachedGeoLocation = null;
      _cachedMonthEvents = MonthEvents(DateTime(1300), {});
    });
  }

  void _goToAboutPage() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const AboutPage()));
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  Widget _getDrawer() {
    return Drawer(
        child: ListView(
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(
            color: Colors.blue,
          ),
          child: Text('Hebrew Calendar'),
        ),
        ListTile(
          title: const Text("Go to month"),
          onTap: _selectMonthYear,
        ),
        ListTile(
          title: const Text("Settings"),
          onTap: _goToSettingsPage,
        ),
        ListTile(
          title: const Text("About"),
          onTap: _goToAboutPage,
        )
      ],
    ));
  }

  Container _createCalendar(MonthEvents? events, double height, double width) {
    const daysOfWeekHeight = 24.0;
    final weeksInMonth = getWeeksInMonth(_selectedDay);
    final rowHeight = min(74.0, (height - daysOfWeekHeight) / weeksInMonth);
    return Container(
      constraints: width > height
          ? BoxConstraints(
              maxHeight: height,
              minHeight: height,
              maxWidth: width,
              minWidth: width)
          : null,
      child: TableCalendar(
        focusedDay: _selectedDay,
        firstDay: _firstDay,
        lastDay: _lastDay,
        onDaySelected: _setCurrentDay,
        onPageChanged: _updateCurrentDay,
        rowHeight: rowHeight,
        daysOfWeekHeight: daysOfWeekHeight,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
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
              events: events?.getEvents(day) ?? [],
              isToday: true,
              isInCurrentMonth: day.month == focusedDay.month,
              isSelected: day == focusedDay,
              height: rowHeight,
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            return JewishDayCell(
              day: JewishCalendar.fromDateTime(day),
              events: events?.getEvents(day) ?? [],
              isToday: false,
              isInCurrentMonth: true,
              isSelected: day == focusedDay,
              height: rowHeight,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            return JewishDayCell(
              day: JewishCalendar.fromDateTime(day),
              events: events?.getEvents(day) ?? [],
              isToday: false,
              isInCurrentMonth: false,
              isSelected: day == focusedDay,
              height: rowHeight,
            );
          },
        ),
      ),
    );
  }

  Container _dayDetail(AsyncSnapshot<MonthEvents> eventsSnapshot) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(children: [
                Expanded(
                    child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  direction: Axis.horizontal,
                  children: [
                    Text(
                      DateFormat.yMMMMd().format(_selectedDay),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      formatter
                          .format(JewishCalendar.fromDateTime(_selectedDay)),
                      style: const TextStyle(fontSize: 14),
                    )
                  ],
                ))
              ])),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(
            children: [
              FutureBuilder<GeoLocation>(
                future: _geoLocation(),
                builder: (BuildContext context,
                    AsyncSnapshot<GeoLocation> geoSnapshot) {
                  return _buildExpansionPanelList(geoSnapshot, eventsSnapshot);
                },
              ),
            ],
          )))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(_getMonthsTitle(_selectedDay)),
        titleTextStyle: const TextStyle(fontSize: 12),
        actions: [
          IconButton(
              onPressed: () => _updateCurrentDay(DateTime.now()),
              icon: const Icon(Icons.calendar_today))
        ],
      ),
      drawer: _getDrawer(),
      body: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.biggest.height;
        final width = constraints.biggest.width;
        final orientation =
            width > height ? Orientation.landscape : Orientation.portrait;
        return FutureBuilder<MonthEvents>(
          future: _monthEvents(),
          builder: (BuildContext context,
                  AsyncSnapshot<MonthEvents> eventsSnapshot) =>
              orientation == Orientation.portrait
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        _createCalendar(eventsSnapshot.data, height, width),
                        Expanded(
                          child: _dayDetail(eventsSnapshot),
                        ),
                      ],
                    )
                  : Row(children: <Widget>[
                      _createCalendar(eventsSnapshot.data, height, width - 250),
                      Expanded(
                        child: _dayDetail(eventsSnapshot),
                      ),
                    ]),
        );
      }),
    );
    // },
    // );
  }
}
