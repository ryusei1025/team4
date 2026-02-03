import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'notification_service.dart';
import 'calendar_page.dart';
import 'bunbetujisho.dart';
import 'camera_screen.dart';
import 'map_screen.dart'; // ★追加

void main() async {
  // Flutterの初期化待ち
  WidgetsFlutterBinding.ensureInitialized();

  // タイムゾーンデータのロード
  tz.initializeTimeZones();
  
  // 通知サービスの初期化
  final notificationService = NotificationService();
  await notificationService.init();

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
        // 元のTheme設定を活かしつつ、アプリ全体のトーンを少し緑に寄せています
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green, // 基準色を緑に
          surface: Colors.white, // 全体の背景を白に
        ),
        useMaterial3: true,
        // AppBarのデザイン統一
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CalendarScreen(),
        '/dictionary': (context) => const SearchScreen(),
        '/camera': (context) => const CameraScreen(),
        '/map': (context) => const TrashBinMapScreen(), // ★マップ画面のルートを追加
      },
    );
  }
}

// --- 元々のコードにあった共通Drawerヘルパーも保持 ---
// ※各画面で独自に LeftMenuDrawer を呼んでいる場合は使いませんが、
//   コードとして残しておくことで既存の依存関係を壊さないようにします。
Widget buildCommonDrawer(BuildContext context) {
  return Drawer(
    backgroundColor: Colors.white,
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.green),
          child: Text(
            'メニュー',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('ごみ収集カレンダー'),
          onTap: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('分別辞書'),
          onTap: () => Navigator.pushReplacementNamed(context, '/search'),
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text('ゴミ箱マップ'),
          onTap: () => Navigator.pushReplacementNamed(context, '/map'),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('AIカメラ判定'),
          onTap: () => Navigator.pushReplacementNamed(context, '/camera'),
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