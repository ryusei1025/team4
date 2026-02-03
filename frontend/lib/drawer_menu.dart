import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 言語設定の定義
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.9),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UiLang>(
          value: currentLang,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
          style: const TextStyle(
            color: Colors.green,
            fontSize: 14,
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
    );
  }
}

/// 全画面共通：サイドメニュー（通知スイッチ付き）
class LeftMenuDrawer extends StatefulWidget {
  final UiLang lang;
  final String selectedArea;
  final ValueChanged<UiLang> onLangChanged; // ★ これがないとエラーになります

  const LeftMenuDrawer({
    super.key,
    required this.lang,
    required this.selectedArea,
    required this.onLangChanged, // ★ 必須
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

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationOn = prefs.getBool('isNotificationOn') ?? false;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() {
      _isNotificationOn = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationOn', value);

    if (value) {
      try {
        await NotificationService.cancelAll();

        final now = DateTime.now();
        String areaId = "1";

        await _fetchAndSchedule(now.year, now.month, areaId);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        await _fetchAndSchedule(nextMonth.year, nextMonth.month, areaId);

        await NotificationService.checkPendingNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.lang == UiLang.ja
                    ? 'ゴミ出し通知を予約しました'
                    : 'Notifications scheduled',
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('通知予約エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('通知予約に失敗しました: $e')));
        }
      }
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> _fetchAndSchedule(int year, int month, String areaId) async {
    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/schedules?year=$year&month=$month&area=$areaId',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final List<dynamic> data = jsonDecode(response.body);
      int notificationBaseId = year * 10000 + month * 100;
      int counter = 0;

      for (var item in data) {
        if (item['type'] == null) continue;

        final String dateStr = item['date'];
        final DateTime trashDate = DateTime.parse(dateStr);
        final String trashName = item['type'];

        final DateTime prevDay = trashDate.subtract(const Duration(days: 1));
        await NotificationService.scheduleDateNotification(
          id: notificationBaseId + counter,
          title: widget.lang == UiLang.ja ? '明日のゴミ出し' : 'Tomorrow\'s Garbage',
          body: widget.lang == UiLang.ja
              ? '明日は「$trashName」の日です。'
              : 'Tomorrow is $trashName day.',
          date: prevDay,
          hour: 21,
          minute: 0,
        );
        counter++;

        await NotificationService.scheduleDateNotification(
          id: notificationBaseId + counter + 50,
          title: widget.lang == UiLang.ja ? '今日のゴミ出し' : 'Today\'s Garbage',
          body: widget.lang == UiLang.ja
              ? '今日は「$trashName」の日です。忘れずに出しましょう！'
              : 'Today is $trashName day.',
          date: trashDate,
          hour: 7,
          minute: 0,
        );
        counter++;
      }
    } catch (e) {
      debugPrint('スケジュール取得エラー: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJa = widget.lang == UiLang.ja;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.green),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isJa ? 'メニュー' : 'Menu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    LanguageSelector(
                      currentLang: widget.lang,
                      onChanged: widget.onLangChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Area: ${widget.selectedArea}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ★ ここで言語設定 (widget.lang) を次の画面に渡しています
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(isJa ? 'ホーム' : 'Home'),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/',
                    arguments: widget.lang,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(isJa ? '分別辞書' : 'Dictionary'),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/search',
                    arguments: widget.lang,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(isJa ? 'ゴミ箱マップ' : 'Trash Bin Map'),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/map',
                    arguments: widget.lang,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(isJa ? 'AI判定' : 'AI Scan'),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/camera',
                    arguments: widget.lang,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(
              _isNotificationOn
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _isNotificationOn ? Colors.orange : Colors.grey,
            ),
            title: Text(isJa ? '通知設定' : 'Notifications'),
            subtitle: Text(
              _isNotificationOn ? (isJa ? 'オン' : 'ON') : (isJa ? 'オフ' : 'OFF'),
              style: const TextStyle(fontSize: 12),
            ),
            value: _isNotificationOn,
            onChanged: _toggleNotification,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
