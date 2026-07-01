import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CrownOfOlympusApp());
}

class CrownOfOlympusApp extends StatelessWidget {
  const CrownOfOlympusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crown of Olympus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const LoadingScreen(),
    );
  }
}
