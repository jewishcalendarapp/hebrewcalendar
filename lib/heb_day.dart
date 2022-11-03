import 'package:flutter/material.dart';
import 'package:kosher_dart/kosher_dart.dart';
// import 'package:device_calendar/device_calendar.dart';
import 'local_events.dart';

Color? _getBgColor(JewishCalendar day, bool isToday) {
  if (isToday) return Colors.orange.shade50;
  if (day.getDayOfWeek() == 7 || day.isYomTovAssurBemelacha()) {
    return Colors.blue.shade100;
  }
  if (day.isCholHamoed() ||
      day.getYomTovIndex() == JewishCalendar.HOSHANA_RABBA) {
    return Colors.blue.shade50;
  }
  if (day.isYomTov() && !day.isErevYomTov()) return Colors.yellow.shade50;
  if (day.isTaanis()) return Colors.deepOrange.shade50;
  return null;
}

class JewishDayCell extends StatefulWidget {
  const JewishDayCell(
      {super.key,
      required this.day,
      required this.events,
      required this.isToday,
      required this.isInCurrentMonth,
      required this.isSelected});

  final JewishCalendar day;
  final bool isToday;
  final bool isInCurrentMonth;
  final bool isSelected;
  final List<EventsWithColor> events;

  @override
  State<JewishDayCell> createState() => _JewishDayCell();
}

class _JewishDayCell extends State<JewishDayCell> {
  final formatter = HebrewDateFormatter()..hebrewFormat = true;
  JewishCalendar get day => widget.day;
  Color? get bgColor => _getBgColor(day, widget.isToday);
  String get hebDay =>
      formatter.formatHebrewNumber(widget.day.getJewishDayOfMonth());

  final textStyle = const TextStyle(fontSize: 7);
  final maxWidgets = 5;

  Widget _eventBox(String title, Color color) => Container(
      padding: const EdgeInsets.all(1.0),
      color: color,
      child: Text(
        title,
        style: textStyle,
        textAlign: TextAlign.center,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ));

  List<Widget> _getWidgets() {
    return [
      if (widget.day.isYomTov() || widget.day.isTaanis())
        Text(
          formatter.formatYomTov(widget.day),
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      if (widget.day.isRoshChodesh())
        Text(
          formatter.formatRoshChodesh(widget.day),
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      if (widget.day.getParshah() != Parsha.NONE)
        Text(
          formatter.formatParsha(widget.day),
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      if (widget.day.getSpecialShabbos() != Parsha.NONE)
        Text(
          formatter.formatSpecialParsha(widget.day),
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      ...widget.events
          .map((e) => _eventBox(e.event.title ?? "Untitled event", e.color))
    ];
  }

  List<Widget> _truncateWidgets(List<Widget> widgets) {
    if (widgets.length <= maxWidgets) return widgets;
    final numWidgetsToKeep = maxWidgets - 1;
    final numWidgetsRemoved = widgets.length - numWidgetsToKeep;
    return [
      ...widgets.take(numWidgetsToKeep),
      _eventBox('+$numWidgetsRemoved more events', Colors.blue.shade200)
    ];
  }

  Border _getBorder() {
    return widget.isSelected
        ? Border.all(color: Colors.blue.shade400, width: 1.5)
        : Border.all(color: Colors.black26, width: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: Theme.of(context).copyWith(
            primaryTextTheme:
                const TextTheme(bodyText1: TextStyle(fontSize: 10))),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            // border: _getBorder(),
          ),
          foregroundDecoration: widget.isInCurrentMonth
              ? BoxDecoration(border: _getBorder())
              : BoxDecoration(color: Colors.white60, border: _getBorder()),
          padding: const EdgeInsets.all(2.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.day.getGregorianDayOfMonth().toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    hebDay,
                    style: const TextStyle(fontSize: 10),
                  )
                ],
              ),
              Expanded(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _truncateWidgets(_getWidgets()),
              )),
            ],
          ),
        ));
  }
}
