import 'package:flutter/material.dart';
import 'map_screen.dart';

void main() {
  runApp(const DummyApp());
}

class DummyApp extends StatelessWidget {
  const DummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TrashBinMapScreen(),
    );
  }
}
