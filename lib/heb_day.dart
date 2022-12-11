import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kosher_dart/kosher_dart.dart';
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
      required this.isSelected,
      required this.height});

  final JewishCalendar day;
  final bool isToday;
  final bool isInCurrentMonth;
  final bool isSelected;
  final List<EventsWithColor> events;
  final double height;

  @override
  State<JewishDayCell> createState() => _JewishDayCell();
}

const padding = 2.0;

class _JewishDayCell extends State<JewishDayCell> {
  final formatter = HebrewDateFormatter()..hebrewFormat = true;
  JewishCalendar get day => widget.day;
  Color? get bgColor => _getBgColor(day, widget.isToday);
  String get hebDay =>
      formatter.formatHebrewNumber(widget.day.getJewishDayOfMonth());

  double get availableSpace {
    const top = (padding * 2) + 14; // 14 is the height of the day numbers
    return widget.height - top;
  }

  int get roomForWidgets {
    return (availableSpace / 10).floor();
  }

  final minWidgets = 4;

  int get widgetsToShow => max(minWidgets, roomForWidgets);

  Widget _eventBox(String title, Color color, TextStyle style) => Container(
      padding: const EdgeInsets.all(1.0),
      color: color,
      child: Text(
        title,
        style: style,
        textAlign: TextAlign.center,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ));

  List<Widget> _getWidgets() {
    final holidayTexts = [
      if (widget.day.isYomTov() || widget.day.isTaanis())
        formatter.formatYomTov(widget.day),
      if (widget.day.isRoshChodesh()) formatter.formatRoshChodesh(widget.day),
      if (widget.day.getParshah() != Parsha.NONE)
        formatter.formatParsha(widget.day),
      if (widget.day.getSpecialShabbos() != Parsha.NONE)
        formatter.formatSpecialParsha(widget.day),
    ];
    var widgetTextStyle = const TextStyle(fontSize: 7);

    var numWidgetsToShow = holidayTexts.length + widget.events.length;

    if (roomForWidgets < holidayTexts.length + widget.events.length) {
      // we need to truncate or resize the text
      final hasEvents = widget.events.isNotEmpty;
      final absoluteMinWidgets = holidayTexts.length + (hasEvents ? 1 : 0);
      if (roomForWidgets < absoluteMinWidgets) {
        // we need to resize font
        final fontSize =
            ((availableSpace / absoluteMinWidgets) - 3).floorToDouble();
        widgetTextStyle = TextStyle(fontSize: fontSize);
      }
      numWidgetsToShow = max(absoluteMinWidgets, roomForWidgets);
    }

    return [
      ...holidayTexts.map((e) => Text(
            e,
            style: widgetTextStyle,
            textAlign: TextAlign.center,
          )),
      ..._truncatedHolidays(
          widget.events
              .map((e) => _eventBox(e.title, e.color, widgetTextStyle))
              .toList(),
          numWidgetsToShow - holidayTexts.length,
          widgetTextStyle)
    ];
  }

  List<Widget> _truncatedHolidays(
      List<Widget> holidayWidgets, int space, TextStyle textStyle) {
    if (holidayWidgets.length <= space) return holidayWidgets;
    final numWidgetsToKeep = space - 1;
    final numWidgetsRemoved = holidayWidgets.length - numWidgetsToKeep;
    return [
      ...holidayWidgets.take(numWidgetsToKeep),
      _eventBox(
          '+$numWidgetsRemoved more events', Colors.blue.shade200, textStyle)
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
          padding: const EdgeInsets.all(padding),
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
                children: _getWidgets(),
              )),
            ],
          ),
        ));
  }
}
