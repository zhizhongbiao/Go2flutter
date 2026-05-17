// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/lawn_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait – point cloud map is designed for vertical layout.
  // Remove if you want landscape support.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full-screen immersive for maximum map area
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:         Colors.transparent,
    statusBarBrightness:    Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const LawnMapApp());
}

class LawnMapApp extends StatelessWidget {
  const LawnMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiDAR Point Cloud Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xff1db954),
          secondary: Color(0xff52d46e),
          surface:   Color(0xff0d1a0e),
        ),
        scaffoldBackgroundColor: const Color(0xff080f09),
        useMaterial3: true,
      ),
      home: const LawnMapScreen(),
    );
  }
}
