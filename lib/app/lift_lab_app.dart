import 'package:flutter/material.dart';

import '../features/tracker/tracker_home_page.dart';
import 'theme.dart';

class LiftLabApp extends StatelessWidget {
  const LiftLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lift Lab',
      debugShowCheckedModeBanner: false,
      theme: buildLiftLabTheme(),
      home: const TrackerHomePage(),
    );
  }
}

