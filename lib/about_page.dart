import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                const Text(
                    "This app is a simple app to show a calendar with zmanim and show events from your calendar."),
                const Text(
                  "About Zmanim",
                  style: TextStyle(height: 2, fontSize: 22),
                ),
                Text.rich(
                  TextSpan(
                      text: 'Jewish dates and Zmanim are calculated using the ',
                      children: [
                        TextSpan(
                          text: 'KosherJava Zmanim project',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                  Uri.parse(
                                      'https://github.com/KosherJava/zmanim'),
                                  mode: LaunchMode.externalApplication);
                            },
                        ),
                        const TextSpan(text: ' as translated into dart as '),
                        TextSpan(
                          text: 'KosherDart',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                  Uri.parse(
                                      'https://github.com/yakir8/kosher_dart'),
                                  mode: LaunchMode.externalApplication);
                            },
                        ),
                        const TextSpan(
                            text:
                                '. The actual calculations are according to the calculations used by '),
                        TextSpan(
                          text: 'Chabad.org',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                  Uri.parse(
                                      'https://www.chabad.org/library/article_cdo/aid/3209349/jewish/About-Our-Zmanim-Calculations.htm'),
                                  mode: LaunchMode.externalApplication);
                            },
                        ),
                      ]),
                ),
                const Text(
                    "Please note: Due to atmospheric conditions - all zmanim may be off by a minute or 2. Please do not rely on them till the last second."),
                const Text(
                  "Data Privacy",
                  style: TextStyle(height: 2, fontSize: 22),
                ),
                const Text(
                    "This app does not collect any data. Location and Calendar events are only used on this device."),
                const Text(
                  "Location data",
                  style: TextStyle(height: 2, fontSize: 22),
                ),
                Text.rich(
                  TextSpan(
                      text:
                          'The name of the nearest city is calculate on device using the list of cities downloaded from ',
                      children: [
                        TextSpan(
                          text: 'GeoNames',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(Uri.parse('http://www.geonames.org/'),
                                  mode: LaunchMode.externalApplication);
                            },
                        ),
                        const TextSpan(text: ' licensed under the '),
                        TextSpan(
                          text:
                              'Creative Commons Attribution 4.0 International (CC BY 4.0)',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                  Uri.parse(
                                      'https://creativecommons.org/licenses/by/4.0/'),
                                  mode: LaunchMode.externalApplication);
                            },
                        ),
                      ]),
                ),
                TextButton(
                  onPressed: () => showLicensePage(context: context),
                  child: const Text('Licenses'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
