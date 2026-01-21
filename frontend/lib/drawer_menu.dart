import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart'; // 上記で作成したファイルをインポート
import 'constants.dart'; // ★API通信に必要
import 'package:http/http.dart' as http; // ★API通信に必要
import 'dart:convert'; // ★JSON解析に必要

enum UiLang { ja, en }

/// 全画面共通：言語選択ボタン
class LanguageSelector extends StatelessWidget {
  final UiLang currentLang;
  final ValueChanged<UiLang> onChanged;

  const LanguageSelector({
    super.key,
    required this.currentLang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFFE7EBF3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLang == UiLang.ja ? '言語: ' : 'Lang: ',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<UiLang>(
                  value: currentLang,
                  isDense: true,
                  icon: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Colors.black,
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  items: const [
                    DropdownMenuItem(value: UiLang.ja, child: Text('日本語')),
                    DropdownMenuItem(value: UiLang.en, child: Text('English')),
                  ],
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全画面共通：サイドメニュー（通知スイッチ付き）
class LeftMenuDrawer extends StatefulWidget {
  final UiLang lang;
  final String selectedArea;

  const LeftMenuDrawer({
    super.key,
    required this.lang,
    required this.selectedArea,
  });

  @override
  State<LeftMenuDrawer> createState() => _LeftMenuDrawerState();
}

class _LeftMenuDrawerState extends State<LeftMenuDrawer> {
  bool _isNotificationOn = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  // 保存されている設定を読み込む
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationOn = prefs.getBool('isNotificationOn') ?? false;
    });
  }

// 実際のスケジュールを取得して通知セット
  Future<void> _toggleNotification(bool value) async {
    setState(() {
      _isNotificationOn = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_on', value);

    if (value) {
      // ONにした場合：サーバーからデータを取って通知登録
      // ※注意：本来は「中央区1」のような正確なIDが必要ですが、
      // ここでは仮に widget.selectedArea に「中央区1」が入っている、
      // または固定値としてテスト用に「中央区1」を使います。
      
      // 今の時期を取得
      final now = DateTime.now();
      
      // エラーが出ないように try-catch で囲む
      try {
        await NotificationService.cancelAll(); // 一旦古い予約をクリア

        // 今月と来月のデータを取得して通知をセットする関数を呼ぶ
        await _fetchAndSchedule(now.year, now.month, '中央区1');
        
        // 来月分も予備で取っておくと親切
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        await _fetchAndSchedule(nextMonth.year, nextMonth.month, '中央区1');

        await NotificationService.checkPendingNotifications();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ゴミ出しスケジュールの通知を予約しました')),
        );

      } catch (e) {
        debugPrint('通知予約エラー: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通知予約に失敗しました: $e')),
        );
      }

    } else {
      // OFFにした場合：予約を全消し
      await NotificationService.cancelAll();
    }
  }

  // サーバーから指定月のスケジュールを取得し、通知を登録するヘルパー関数
  Future<void> _fetchAndSchedule(int year, int month, String areaId) async {
    // APIのエンドポイント（calendar_pageで使っているものと同じ想定）
    final url = Uri.parse('${AppConstants.baseUrl}/api/schedules?year=$year&month=$month&area=$areaId');
    
    final response = await http.get(url);
    if (response.statusCode != 200) return; // エラーなら何もしない

    final List<dynamic> data = jsonDecode(response.body);

    int notificationId = year * 10000 + month * 100; // IDが被らないように工夫

    for (var item in data) {
      // データ例: {"date": "2025-10-01", "trash_type": {"name": "燃やせるゴミ", ...}, ...}
      if (item['trash_type'] == null) continue; // ゴミがない日はスキップ

      final String dateStr = item['date']; // "2025-10-01"
      final DateTime trashDate = DateTime.parse(dateStr);
      final String trashName = item['trash_type']['name'];

      // --- ① 前日の夜21時に通知 ---
      // ゴミの日の前日
      final DateTime prevDay = trashDate.subtract(const Duration(days: 1));
      
      await NotificationService.scheduleDateNotification(
        id: notificationId++, 
        title: '明日のゴミ出し',
        body: '明日は「$trashName」の日です。準備をしましょう。',
        date: prevDay, 
        hour: 21, 
        minute: 0,
      );

      // --- ② 当日の朝7時に通知 ---
      await NotificationService.scheduleDateNotification(
        id: notificationId++, 
        title: '今日のゴミ出し',
        body: '今日は「$trashName」の日です。忘れずに出しましょう！',
        date: trashDate, 
        hour: 7, 
        minute: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // 上部：ナビゲーション項目
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 123, 226, 132),
                  ),
                  child: Text(
                    widget.lang == UiLang.ja ? 'メニュー' : 'Menu',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    widget.lang == UiLang.ja ? 'ホーム(カレンダー)' : 'Home(Calendar)',
                  ),
                  onTap: () => Navigator.pushReplacementNamed(context, '/'),
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: Text(
                    widget.lang == UiLang.ja ? 'ゴミ分別辞書' : 'Dictionary',
                  ),
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/search'),
                ),
                // 追加：ゴミ箱マップ
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(
                    widget.lang == UiLang.ja ? 'ゴミ箱マップ' : 'Trash Bin Map',
                  ),
                  onTap: () => Navigator.pushReplacementNamed(context, '/map'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(
                    widget.lang == UiLang.ja ? 'AIカメラ判定' : 'AI Camera',
                  ),
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/camera'),
                ),
              ],
            ),
          ),

          // 下部：通知スイッチエリア
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SwitchListTile(
              secondary: Icon(
                _isNotificationOn
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _isNotificationOn ? Colors.orange : Colors.grey,
              ),
              title: Text(
                widget.lang == UiLang.ja ? '通知設定' : 'Notifications',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                _isNotificationOn
                    ? (widget.lang == UiLang.ja ? 'オン' : 'ON')
                    : (widget.lang == UiLang.ja ? 'オフ' : 'OFF'),
                style: const TextStyle(fontSize: 12),
              ),
              value: _isNotificationOn,
              onChanged: _toggleNotification,
            ),
          ),
          const SizedBox(height: 10), // 画面最下部の余白
        ],
      ),
    );
  }
}
