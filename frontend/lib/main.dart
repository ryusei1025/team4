import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'calendar_page.dart';
import 'bunbetujisho.dart';
import 'camera_screen.dart'; // ★コメントアウトを外す

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('通知初期化エラー: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ごみ分別アプリ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CalendarScreen(),
        '/search': (context) => const SearchScreen(),
        '/camera': (context) => const CameraScreen(), // ★コメントアウトを外す
      },
    );
  }
}
