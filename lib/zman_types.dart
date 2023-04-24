import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kosher_dart/kosher_dart.dart';

// Used for netz and shkia
const normalOffset = 90.0 + 0.833;

// used for shaa zmanis calculations
const amitisOffset = 90.0 + 1.583;

// Calculates from netz amitis to shkia amitis
DateTime? _getTimeFromShaaZmanis(ZmanimCalendar zmanim, double hours) {
  final sunrise = zmanim.getSunriseOffsetByDegrees(amitisOffset);
  final sunset = zmanim.getSunsetOffsetByDegrees(amitisOffset);
  if (sunrise == null || sunset == null) return null;
  return zmanim.getShaahZmanisBasedZman(sunrise, sunset, hours);
}

DateTime? getTzais6(ZmanimCalendar zmanim) {
  const tzeis6Offset = ZmanimCalendar.ZENITH_8_POINT_5 - 2.5;
  return zmanim.getSunsetOffsetByDegrees(tzeis6Offset);
}

enum ZmanType {
  alos19point9,
  sunrise,
  kriasShmaRav,
  eatChometz,
  burnChometz,
  chatzos,
  minchaGedola,
  earlyCandleLighting,
  sunset,
  lateCandleLighting,
  tzeis6,
  tzeis8point5,
}

List<Zman> getZmanim(List<ZmanType> types, JewishCalendar day,
        ZmanimCalendar zmanim, DateFormat formatter) =>
    types
        .map((type) => _zmanTypeToZman(type, day, zmanim, formatter))
        .where((element) => element != null)
        .map((e) => e!)
        .toList();

Zman? _zmanTypeToZman(ZmanType type, JewishCalendar day, ZmanimCalendar zmanim,
    DateFormat formatter) {
  switch (type) {
    case ZmanType.alos19point9:
      final time = zmanim.getSunriseOffsetByDegrees(
              ZmanimCalendar.ZENITH_16_POINT_1 + .8) ??
          zmanim.getChatzos();
      return Zman(_alosText(day), time, formatter);
    case ZmanType.sunrise:
      return Zman("Sunrise",
          _roundUp(zmanim.getSunriseOffsetByDegrees(normalOffset)), formatter);
    case ZmanType.kriasShmaRav:
      return Zman(
          "Sof Zman Krias Shma", _getTimeFromShaaZmanis(zmanim, 3), formatter);
    case ZmanType.eatChometz:
      final isErevPesach = day.getJewishMonth() == JewishDate.NISSAN &&
          day.getJewishDayOfMonth() == 14;
      return isErevPesach
          ? Zman("Eat Chometz Before", _getTimeFromShaaZmanis(zmanim, 4),
              formatter)
          : null;
    case ZmanType.burnChometz:
      final isErevPesach = day.getJewishMonth() == JewishDate.NISSAN &&
          day.getJewishDayOfMonth() == 14;
      return isErevPesach
          ? Zman("Burn Chometz Before", _getTimeFromShaaZmanis(zmanim, 5),
              formatter)
          : null;
    case ZmanType.chatzos:
      return Zman("Chatzos", zmanim.getChatzos(), formatter);
    case ZmanType.minchaGedola:
      return Zman("Earliest Mincha",
          _roundUp(_getTimeFromShaaZmanis(zmanim, 6.5)), formatter);
    case ZmanType.earlyCandleLighting:
      if (_earlyCandleLighting(day)) {
        return Zman("Candle Lighting", zmanim.getCandleLighting(), formatter);
      }
      return null;
    case ZmanType.sunset:
      return Zman(_sunsetText(day), zmanim.getSeaLevelSunset(), formatter);
    case ZmanType.lateCandleLighting:
      if (_lateCandleLighting(day)) {
        return Zman(
            "Light Candles after", _roundUp(zmanim.getTzais()), formatter);
      }
      return null;
    case ZmanType.tzeis6:
      if (day.getDayOfWeek() == 7 || day.isYomTovAssurBemelacha()) return null;
      return Zman(_endText(day), _roundUp(getTzais6(zmanim)), formatter);
    case ZmanType.tzeis8point5:
      if (day.getDayOfWeek() == 7 || day.isYomTovAssurBemelacha()) {
        return Zman(_endText(day), _roundUp(zmanim.getTzais()), formatter);
      }
      return null;
  }
}

DateTime? _roundUp(DateTime? datetime) =>
    datetime?.add(const Duration(minutes: 1));

String _endText(JewishCalendar day) {
  if (day.isTaanis()) return "Fast Ends";
  if ((day.getDayOfWeek() == 7 || day.isYomTovAssurBemelacha()) &&
      !day.isTomorrowShabbosOrYomTov()) {
    if (day.getDayOfWeek() == 7) return "Shabbos ends";
    return "Yom Tov ends";
  }
  return "Tzeis";
}

String _alosText(JewishCalendar day) {
  if (day.isTaanis() &&
      ![JewishCalendar.TISHA_BEAV, JewishCalendar.YOM_KIPPUR]
          .contains(day.getYomTovIndex())) {
    return "Fast Begins";
  }
  return "Alos";
}

String _sunsetText(JewishCalendar day) {
  if ([JewishCalendar.TISHA_BEAV, JewishCalendar.YOM_KIPPUR]
      .contains((day.clone()..forward()).getYomTovIndex())) {
    return "Fast Begins";
  }
  return "Sunset";
}

bool _earlyCandleLighting(JewishCalendar day) {
  return day.hasCandleLighting() &&
      (day.getDayOfWeek() == 6 || !day.isYomTovAssurBemelacha());
}

bool _lateCandleLighting(JewishCalendar day) {
  return day.hasCandleLighting() && !_earlyCandleLighting(day);
}

class Zman {
  final String name;
  final DateTime? time;
  final DateFormat formatter;
  String get formattedTime {
    if (time == null) return "Unable to calculate";
    return formatter.format(time!);
  }

  Zman(this.name, this.time, this.formatter);

  Widget toWidget() => SizedBox(
        height: 25,
        child: Center(child: Text('$name: $formattedTime')),
      );
}
