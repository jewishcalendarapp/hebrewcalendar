import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kosher_dart/kosher_dart.dart';

import 'zman_types.dart';

final types = [
  ZmanType.alos19point9,
  ZmanType.sunrise,
  ZmanType.kriasShmaRav,
  ZmanType.eatChometz,
  ZmanType.burnChometz,
  ZmanType.chatzos,
  ZmanType.minchaGedola,
  ZmanType.earlyCandleLighting,
  ZmanType.sunset,
  ZmanType.lateCandleLighting,
  ZmanType.tzeis6,
  ZmanType.tzeis8point5,
];

class ZmanimBox extends StatefulWidget {
  const ZmanimBox({super.key, required this.day, required this.zmanim});

  final JewishCalendar day;
  final ZmanimCalendar? zmanim;

  @override
  State<ZmanimBox> createState() => _ZmanimBox();
}

class _ZmanimBox extends State<ZmanimBox> {
  final formatter = HebrewDateFormatter()..hebrewFormat = true;
  final timeFormatter = DateFormat.jm();
  JewishCalendar get day => widget.day;
  String get timeZoneName => DateTime(day.getGregorianYear(),
          day.getGregorianMonth(), day.getGregorianDayOfMonth(), 12)
      .timeZoneName;

  @override
  Widget build(BuildContext context) {
    final zmanim = widget.zmanim;
    if (zmanim == null) return Container();
    return Container(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Times are for ${zmanim.geoLocation.getLocationName()}"),
          Text("Timezone: $timeZoneName"),
          ...getZmanim(types, day, zmanim, timeFormatter)
              .map((e) => e.toWidget())
        ],
      ),
    );
  }
}
