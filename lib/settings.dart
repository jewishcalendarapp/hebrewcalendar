import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';
import 'geolocation.dart';

class _CalendarWithState {
  final Calendar calendar;
  final bool visible;
  _CalendarWithState(this.calendar, this.visible);
}

class _Settings {
  final bool disableLocation;
  final bool disableCalendar;
  final List<_CalendarWithState> calendars;
  _Settings(this.disableLocation, this.disableCalendar, this.calendars);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  final plugin = DeviceCalendarPlugin();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Result<UnmodifiableListView<Calendar>>? _calendars;

  Future<_Settings> _getSettings() async {
    final disableLocation = (await _prefs).getBool(disableLocationKey) ?? false;
    final disableCalendar = (await _prefs).getBool('disableCalendar') ?? false;
    final calendars =
        disableCalendar ? <_CalendarWithState>[] : await _getCalendars();
    return _Settings(disableLocation, disableCalendar, calendars);
  }

  Future<List<_CalendarWithState>> _getCalendars() async {
    _calendars ??= await plugin.retrieveCalendars();
    if (_calendars!.isSuccess) {
      final calendars = _calendars!.data!;
      final prefs = await _prefs;
      final hiddenCals = prefs.getStringList('hiddenCalendars') ?? [];
      return calendars
          .map((cal) => _CalendarWithState(cal, !hiddenCals.contains(cal.id)))
          .toList();
    }
    return [];
  }

  void _toggleLocation(bool? enable) async {
    if (enable == null) return;
    final prefs = await _prefs;
    if (enable) {
      await prefs.remove(disableLocationKey);
      getLocationPermission();
    } else {
      await prefs.setBool(disableLocationKey, true);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _toggleCalendars(bool? enable) async {
    if (enable == null) return;
    final prefs = await _prefs;
    if (enable) {
      await prefs.remove('disableCalendar');
    } else {
      await prefs.setBool('disableCalendar', true);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _updateCalHiddenState(_CalendarWithState cal, bool? shouldShow) async {
    if (shouldShow == null) return;
    if (cal.calendar.id == null) return;
    final prefs = await _prefs;
    final hiddenCals = prefs.getStringList('hiddenCalendars') ?? [];
    if (!shouldShow) {
      hiddenCals.add(cal.calendar.id!);
    } else {
      final removed = hiddenCals.remove(cal.calendar.id);
      if (!removed) return;
    }
    await prefs.setStringList('hiddenCalendars', hiddenCals);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Settings"),
        titleTextStyle: const TextStyle(fontSize: 12),
      ),
      body: Container(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder(
                  future: _getSettings(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text("error, ${snapshot.error}");
                    }
                    if (!snapshot.hasData) {
                      return const Text("Loading");
                    }
                    final settings = snapshot.data!;
                    return Expanded(
                        child: ListView(
                      children: [
                        CheckboxListTile(
                          value: !settings.disableLocation,
                          title: const Text("Enable Location"),
                          onChanged: _toggleLocation,
                        ),
                        CheckboxListTile(
                          value: !settings.disableCalendar,
                          title: const Text("Enable Calendars"),
                          onChanged: _toggleCalendars,
                        ),
                        if (settings.calendars.isNotEmpty)
                          const ListTile(
                            title: Text('Calendars to show:'),
                          ),
                        ...settings.calendars.map((cal) => CheckboxListTile(
                              value: cal.visible,
                              title:
                                  Text(cal.calendar.name ?? "Unknown calendar"),
                              onChanged: (e) => _updateCalHiddenState(cal, e),
                            ))
                      ],
                    ));
                  })
            ],
          )),
    );
  }
}
