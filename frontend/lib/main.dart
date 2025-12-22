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

/// アプリのルート。
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

// class TestScreen extends StatefulWidget {
//   const TestScreen({super.key});

//   @override
//   State<TestScreen> createState() => _TestScreenState();
// }

// class _TestScreenState extends State<TestScreen> {
//   String message = "ボタンを押してデータを取得"; // 初期メッセージ

//   // Flaskからデータを取る関数
//   Future<void> fetchData() async {
//     // 【重要】接続先URL
//     // Androidエミュレータの場合: 'http://10.0.2.2:5000/'
//     // Web(Chrome)の場合: 'http://127.0.0.1:5000/'
//     // 実機(iPhone/Android)の場合: PCのIPアドレス (例: http://192.168.x.x:5000/)
    
//     // ↓ とりあえずWebかAndroidエミュレータで試す想定で書きます
//     const String url = 'http://127.0.0.1:5000/'; 

//     try {
//       final response = await http.get(Uri.parse(url));

//       if (response.statusCode == 200) {
//         // 成功！JSONを分解する
//         final data = jsonDecode(response.body);
//         setState(() {
//           // Flaskから来た "message" を画面に入れる
//           message = data['message']; 
//         });
//       } else {
//         setState(() {
//           message = "エラー: サーバーにつながりません";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         message = "例外発生: $e";
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Flask連携テスト')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               message, // ここにFlaskの言葉が表示される
//               style: const TextStyle(fontSize: 20),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: fetchData, // ボタンを押すと通信開始
//               child: const Text("Flaskからデータを取得"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }