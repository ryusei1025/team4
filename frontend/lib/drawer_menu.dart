import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart'; // 上記で作成したファイルをインポート

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
      _isNotificationOn = prefs.getBool('isNotificationOn') ?? true;
    });
  }

  // スイッチを切り替えた時の処理
  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationOn', value);
    setState(() {
      _isNotificationOn = value;
    });

    // オンにした時にテスト通知を送信
    if (value) {
      NotificationService.showNotification(
        title: widget.lang == UiLang.ja ? "通知設定" : "Notification Settings",
        body: widget.lang == UiLang.ja
            ? "ゴミ出し通知が有効になりました"
            : "Garbage notifications are now enabled",
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
