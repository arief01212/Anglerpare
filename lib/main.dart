import 'package:flutter/material.dart';

import 'ui/map_screen.dart';

void main() {
  runApp(const FishingSolunarApp());
}

class FishingSolunarApp extends StatelessWidget {
  const FishingSolunarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fishing Solunar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6E8C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
