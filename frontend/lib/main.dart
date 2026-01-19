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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white, // 基準の色を白に
          surface: Colors.green, // メニューやダイアログを含む全体の背景を緑に
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CalendarScreen(),
        '/search': (context) => const SearchScreen(),
        '/camera': (context) => const CameraScreen(), 
      },
    );
  }
}

// main.dart の一番下に追加
Widget buildCommonDrawer(BuildContext context) {
  return Drawer(
    backgroundColor: Colors.white, // 下のリスト部分は白
    child: Column(
      children: [
        // ★ ここが青い部分（ヘッダー）の設定です
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.red, // ← ここを好きな色（Colors.green など）に変えてください！
          ),
          child: const Text(
            'メニュー',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 下のメニュー項目
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('ホーム(カレンダー)'),
          onTap: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('ゴミ分別辞書'),
          onTap: () => Navigator.pushNamed(context, '/search'),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('AIカメラ判定'),
          onTap: () => Navigator.pushNamed(context, '/camera'),
        ),
      ],
    ),
  );
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