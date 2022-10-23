import 'package:flutter/material.dart';
import 'package:kosher_dart/kosher_dart.dart';
// import 'package:device_calendar/device_calendar.dart';
import 'local_events.dart';

Color? _getBgColor(JewishCalendar day, bool isSelected, bool isToday) {
  if (isSelected) return Colors.blue.shade300;
  if (isToday) return Colors.blue.shade100;
  if (day.isYomTovAssurBemelacha()) return Colors.yellow;
  if (day.getDayOfWeek() == 7) return Colors.orange;
  if (day.isCholHamoed() ||
      day.getYomTovIndex() == JewishCalendar.HOSHANA_RABBA) {
    return Colors.yellow.shade600;
  }
  if (day.isTaanis()) return Colors.deepOrange.shade200;
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
  Color? get bgColor => _getBgColor(day, widget.isSelected, widget.isToday);
  String get hebDay =>
      formatter.formatHebrewNumber(widget.day.getJewishDayOfMonth());

  final textStyle = const TextStyle(fontSize: 7);

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: Theme.of(context).copyWith(
            primaryTextTheme:
                const TextTheme(bodyText1: TextStyle(fontSize: 10))),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: const Border(
              top: BorderSide.none,
              left: BorderSide.none,
              right: BorderSide(color: Colors.black26),
              bottom: BorderSide(color: Colors.black26),
            ),
          ),
          foregroundDecoration: widget.isInCurrentMonth
              ? null
              : const BoxDecoration(color: Colors.white60),
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
                children: [
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
                  ...widget.events.map((e) => Container(
                      padding: const EdgeInsets.all(1.0),
                      color: e.color,
                      child: Text(
                        e.event.title ?? "Untitled event",
                        style: textStyle,
                        textAlign: TextAlign.center,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      )))
                ],
              )),
            ],
          ),
        ));
  }
}
