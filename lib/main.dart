import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF9D00FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9D00FF),
          secondary: Color(0xFFB266FF),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}