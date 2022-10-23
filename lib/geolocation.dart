import 'dart:math';
import "dart:io";

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:kosher_dart/kosher_dart.dart';

Future<GeoLocation> determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }
  await _makeSureDBExists();

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  final position = await Geolocator.getCurrentPosition();
  final location = await _getDbResults(position.latitude, position.longitude);
  final locationTitle = location != null
      ? "${location.cityName}, ${location.adminName}"
      : "Current Location - Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}";
  return GeoLocation.setLocation(locationTitle, position.latitude,
      position.longitude, DateTime.now(), max(0, position.altitude));
}

Future<void> _copyDB(String path) async {
  // Load database from asset and copy
  ByteData data = await rootBundle.load(p.join('assets', 'geo_db.db'));
  List<int> bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  // Save copied asset to documents
  await File(path).writeAsBytes(bytes);
}

Future<String> _dbPath() async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  return p.join(documentsDirectory.path, "geo_db.db");
}

Future<void> _makeSureDBExists() async {
  String path = await _dbPath();

  // Only copy if the database doesn't exist
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    _copyDB(path);
    return;
  }
  // TODO: copy if modified
}

Future<Location?> _getDbResults(double lat, double lon) async {
  String path = await _dbPath();
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  const maxDegDiff = 0.5;
  final maxLat = max(lat - maxDegDiff, lat + maxDegDiff);
  final minLat = min(lat - maxDegDiff, lat + maxDegDiff);
  final maxLon = max(lon - maxDegDiff, lon + maxDegDiff);
  final minLon = min(lon - maxDegDiff, lon + maxDegDiff);
  final ResultSet resultSet = db.select(
      'SELECT * FROM geo_index WHERE minX<=? AND maxX>=? AND minY<=? AND maxY>=?;',
      [maxLat, minLat, maxLon, minLon]);
  final results = resultSet.map((row) {
    final lat2 = row['minX'] as double;
    final lon2 = row['minY'] as double;
    final cityName = row['cityName'] as String;
    final countryCode = row['countryCode'] as String;
    final adminCode = row['adminCode'] as String;
    final distance = Geolocator.distanceBetween(lat, lon, lat2, lon2);

    return Location(
        cityName: cityName,
        lat: lat,
        lon: lon,
        countryCode: countryCode,
        adminName: adminCode,
        distance: distance);
  }).toList();
  results.sort((a, b) =>
      b.distance > a.distance ? -1 : (b.distance < a.distance ? 1 : 0));
  if (results.isNotEmpty) {
    return results.first;
  }
  return null;
}

class Location {
  final double lat;
  final double lon;
  final String cityName;
  final String countryCode;
  final String adminName;
  final double distance;
  Location(
      {required this.cityName,
      required this.lat,
      required this.lon,
      required this.countryCode,
      required this.adminName,
      required this.distance});
}
