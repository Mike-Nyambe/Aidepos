import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  runApp(const AideposApp());
}

class AideposApp extends StatelessWidget {
  const AideposApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIDEPOS',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'SF Pro Display', // iOS-like font
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
