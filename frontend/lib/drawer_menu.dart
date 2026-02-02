import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'notification_service.dart';
// 権限チェック用（もし未インストールの場合は flutter pub add permission_handler を実行、
// またはこの行と _checkPermission メソッドを削除してください）
import 'package:permission_handler/permission_handler.dart';

enum UiLang { ja, en }

// --- 言語選択ウィジェット (変更なし) ---
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
                    fontWeight: FontWeight.bold),
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

// --- メインメニュー ---
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

  // 曜日を言語設定に合わせて変換するメソッド
  String _getWeekdayString(int weekday) {
    if (widget.lang == UiLang.ja) {
      const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      return weekdays[weekday - 1];
    } else {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[weekday - 1];
    }
  }

  // 設定状態管理用の変数
  bool _isNotificationOn = false;
  String _targetWard = '中央区'; 
  String _targetArea = '中央区1'; 

  // 次回の通知予定を表示するためのテキスト
  String _nextScheduleText = '';

  // 時刻設定用の変数
  bool _notifyDayBefore = true; // 前日
  bool _notifyDayOf = true;     // 当日
  TimeOfDay _timeDayBefore = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _timeDayOf = const TimeOfDay(hour: 8, minute: 0);

  // 地域データ
  final Map<String, List<String>> _areaData = {
    '中央区': ['中央区1', '中央区2', '中央区3', '中央区4', '中央区5', '中央区6'],
    '豊平区': ['豊平区1', '豊平区2', '豊平区3', '豊平区4'],
    '清田区': ['清田区1', '清田区2'],
    '北区': ['北区1', '北区2', '北区3', '北区4', '北区5', '北区6'],
    '東区': ['東区1', '東区2', '東区3', '東区4', '東区5', '東区6'],
    '白石区': ['白石区1', '白石区2', '白石区3', '白石区4'],
    '厚別区': ['厚別区1', '厚別区2', '厚別区3', '厚別区4'],
    '南区': ['南区1', '南区2', '南区3', '南区4', '南区5', '南区6', '南区7'],
    '西区': ['西区1', '西区2', '西区3', '西区4'],
    '手稲区': ['手稲区1', '手稲区2', '手稲区3'],
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    // 通知権限の初期化
    final service = NotificationService();
    service.init();
  }

  // 設定の読み込み
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationOn = prefs.getBool('noti_is_on') ?? false;
      _targetWard = prefs.getString('noti_ward') ?? _areaData.keys.first;
      _targetArea = prefs.getString('noti_area') ?? _areaData[_targetWard]!.first;
      _notifyDayBefore = prefs.getBool('noti_day_before') ?? true;
      _notifyDayOf = prefs.getBool('noti_day_of') ?? true;
      
      final tb = prefs.getString('noti_time_before');
      if (tb != null) {
        final p = tb.split(':');
        _timeDayBefore = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
      final to = prefs.getString('noti_time_of');
      if (to != null) {
        final p = to.split(':');
        _timeDayOf = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
      // 保存された「次回の予定」があれば読み込む
      _nextScheduleText = prefs.getString('noti_next_text') ?? '';
    });
  }

  // 設定の保存
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noti_is_on', _isNotificationOn);
    await prefs.setString('noti_ward', _targetWard);
    await prefs.setString('noti_area', _targetArea);
    await prefs.setBool('noti_day_before', _notifyDayBefore);
    await prefs.setBool('noti_day_of', _notifyDayOf);
    await prefs.setString('noti_time_before', '${_timeDayBefore.hour}:${_timeDayBefore.minute}');
    await prefs.setString('noti_time_of', '${_timeDayOf.hour}:${_timeDayOf.minute}');
    // 次回の予定テキストも保存
    await prefs.setString('noti_next_text', _nextScheduleText);
  }

  // スイッチ切り替え時の処理フロー
  void _handleSwitchChange(bool value) async {
    if (value) {
      // ONにする場合：まず権限チェック
      bool hasPermission = await _checkPermission();
      if (!hasPermission) return; // 権限がない、または拒否された場合はここで中断

      // 権限OKなら設定ダイアログへ
      _showAreaSelectionDialog();
    } else {
      // OFFにする場合
      _turnOffNotifications();
    }
  }

  // 【UX改善】権限チェックと誘導
  Future<bool> _checkPermission() async {
    // permission_handlerを使用
    var status = await Permission.notification.status;
    
    if (status.isDenied) {
      // まだ聞いていない、あるいは一度拒否された場合
      status = await Permission.notification.request();
    }

    if (status.isPermanentlyDenied) {
      // 「二度と表示しない」で拒否されている場合、設定画面へ誘導
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(widget.lang == UiLang.ja ? '通知が無効です' : 'Notifications Disabled'),
            content: Text(widget.lang == UiLang.ja 
              ? '通知を受け取るには、設定画面で通知を許可してください。' 
              : 'Please enable notifications in settings to receive alerts.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(widget.lang == UiLang.ja ? 'キャンセル' : 'Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings(); // 設定画面を開く
                },
                child: Text(widget.lang == UiLang.ja ? '設定を開く' : 'Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return status.isGranted;
  }

  // 通知OFF処理
  Future<void> _turnOffNotifications() async {
    setState(() {
      _isNotificationOn = false;
      _nextScheduleText = ''; // 予定テキスト消去
    });
    await _saveSettings();
    await NotificationService().cancelAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == UiLang.ja ? '通知をOFFにしました' : 'Notifications OFF')),
      );
    }
  }

  // Step 1: 地域選択ダイアログ
  void _showAreaSelectionDialog() {
    String tempWard = _targetWard;
    String tempArea = _targetArea;

    // 通知がまだOFFの場合のみ、現在地を初期値として提案（既存設定の上書き防止）
    if (!_isNotificationOn) {
      for (final ward in _areaData.keys) {
        if (widget.selectedArea.startsWith(ward)) {
          tempWard = ward;
          if (_areaData[ward]!.contains(widget.selectedArea)) {
            tempArea = widget.selectedArea;
          } else {
            tempArea = _areaData[ward]!.first;
          }
          break;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(widget.lang == UiLang.ja ? '地域の設定' : 'Select Area'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.lang == UiLang.ja 
                    ? 'ゴミ出しカレンダーの地域を選択してください' 
                    : 'Select your garbage collection area'),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempWard,
                    items: _areaData.keys.map((ward) {
                      return DropdownMenuItem(value: ward, child: Text(ward));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          tempWard = val;
                          tempArea = _areaData[val]!.first;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempArea,
                    items: _areaData[tempWard]!.map((area) {
                      return DropdownMenuItem(value: area, child: Text(area));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => tempArea = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); 
                  },
                  child: Text(widget.lang == UiLang.ja ? 'キャンセル' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _targetWard = tempWard;
                    _targetArea = tempArea;
                    Navigator.pop(context);
                    _showTimeSettingDialog(); // 次へ
                  },
                  child: Text(widget.lang == UiLang.ja ? '次へ' : 'Next'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Step 2: 時刻設定ダイアログ
  void _showTimeSettingDialog() {
    bool tempDayBefore = _notifyDayBefore;
    bool tempDayOf = _notifyDayOf;
    TimeOfDay tempTimeBefore = _timeDayBefore;
    TimeOfDay tempTimeOf = _timeDayOf;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickTime(bool isBefore) async {
              final initial = isBefore ? tempTimeBefore : tempTimeOf;
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked != null) {
                setStateDialog(() {
                  if (isBefore) tempTimeBefore = picked;
                  else tempTimeOf = picked;
                });
              }
            }

            return AlertDialog(
              title: Text(widget.lang == UiLang.ja ? '通知時刻の設定' : 'Time Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.lang == UiLang.ja 
                      ? '通知を受け取るタイミングを選択してください' 
                      : 'Select when to be notified'),
                  const SizedBox(height: 10),
                  
                  CheckboxListTile(
                    title: Text(widget.lang == UiLang.ja ? '前日' : 'Day Before'),
                    value: tempDayBefore,
                    onChanged: (val) {
                      setStateDialog(() => tempDayBefore = val ?? false);
                    },
                  ),
                  if (tempDayBefore)
                    ListTile(
                      title: Text(
                        widget.lang == UiLang.ja 
                          ? '時刻: ${tempTimeBefore.format(context)}' 
                          : 'Time: ${tempTimeBefore.format(context)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => pickTime(true),
                    ),

                  const Divider(),

                  CheckboxListTile(
                    title: Text(widget.lang == UiLang.ja ? '当日' : 'Morning Of'),
                    value: tempDayOf,
                    onChanged: (val) {
                      setStateDialog(() => tempDayOf = val ?? false);
                    },
                  ),
                  if (tempDayOf)
                    ListTile(
                      title: Text(
                        widget.lang == UiLang.ja 
                          ? '時刻: ${tempTimeOf.format(context)}' 
                          : 'Time: ${tempTimeOf.format(context)}',
                         style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => pickTime(false),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(widget.lang == UiLang.ja ? 'キャンセル' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () { // ここから変更
                    if (!tempDayBefore && !tempDayOf) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(widget.lang == UiLang.ja 
                          ? 'どちらか1つは選択してください' : 'Please select at least one')),
                      );
                      return;
                    }

                    // 1. まずUIの状態（スイッチONなど）を即座に更新する
                    setState(() {
                      _notifyDayBefore = tempDayBefore;
                      _notifyDayOf = tempDayOf;
                      _timeDayBefore = tempTimeBefore;
                      _timeDayOf = tempTimeOf;
                    });
                    
                    // 2. ★ここがポイント！先にダイアログを閉じて、ユーザーを解放する
                    Navigator.pop(context);

                    // 3. ユーザーには「保存を開始しました」と軽く伝える（任意）
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.lang == UiLang.ja 
                          ? '設定を反映中...' 
                          : 'Saving settings...'),
                        duration: const Duration(seconds: 1), // 短めに表示
                      ),
                    );

                    // 4. 重い処理は裏側で勝手にやらせる（awaitを外す）
                    // 処理が終わったら、_performNotificationScheduling 内で
                    // 「〇〇件予約しました」というSnackBarが後から追っかけて表示されます。
                    _performNotificationScheduling();
                    
                  },
                  child: Text(widget.lang == UiLang.ja ? '完了' : 'Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 予約処理＆次回予定の計算
  Future<void> _performNotificationScheduling() async {
    // 既存の通知をキャンセル
    await NotificationService().cancelAll();
    
    try {
      final rawData = await DefaultAssetBundle.of(context).loadString('assets/schedules.csv');
      List<List<dynamic>> rows = const CsvToListConverter().convert(rawData);

      if (rows.isEmpty) return; // 失敗したらONにならない

      final header = rows[0].map((e) => e.toString()).toList();
      final columnIndex = header.indexOf(_targetArea);

      if (columnIndex == -1) return; // 地域が見つからなければONにならない

      final now = DateTime.now();
      int scheduledCount = 0;
      
      DateTime? nearestNotificationTime;
      String nearestTrashName = '';

      // --- ループ処理 (変更なし) ---
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= columnIndex) continue;

        final dateStr = row[1].toString(); 
        DateTime? trashDate;
        try {
          trashDate = DateTime.parse(dateStr);
        } catch (e) {
          continue;
        }

        if (trashDate.isBefore(DateTime(now.year, now.month, now.day))) continue;

        final cellValue = row[columnIndex];
        final garbageId = int.tryParse(cellValue.toString());

        if (garbageId != null) {
          String trashName = _getTrashNameFromId(garbageId);
          if (trashName.isEmpty) continue;

          // 前日通知
          if (_notifyDayBefore) {
            final scheduledDateTime = DateTime(
              trashDate.year, trashDate.month, trashDate.day - 1,
              _timeDayBefore.hour, _timeDayBefore.minute,
            );
            if (scheduledDateTime.isAfter(now)) {
              final weekday = _getWeekdayString(trashDate.weekday);
              final message = widget.lang == UiLang.ja
                  ? "明日（$weekday）のゴミは$trashNameです。"
                  : "Tomorrow($weekday) is $trashName day.";
              
              await NotificationService().scheduleNotification(scheduledDateTime, message);
              scheduledCount++;

              if (nearestNotificationTime == null || scheduledDateTime.isBefore(nearestNotificationTime)) {
                nearestNotificationTime = scheduledDateTime;
                nearestTrashName = trashName;
              }
            }
          }

          // 当日通知
          if (_notifyDayOf) {
            final scheduledDateTime = DateTime(
              trashDate.year, trashDate.month, trashDate.day,
              _timeDayOf.hour, _timeDayOf.minute,
            );
            if (scheduledDateTime.isAfter(now)) {
              final weekday = _getWeekdayString(trashDate.weekday);
              final message = widget.lang == UiLang.ja
                  ? "今日（$weekday）のゴミは$trashNameです。"
                  : "Today($weekday) is $trashName day.";

              await NotificationService().scheduleNotification(scheduledDateTime, message);
              scheduledCount++;

              if (nearestNotificationTime == null || scheduledDateTime.isBefore(nearestNotificationTime)) {
                nearestNotificationTime = scheduledDateTime;
                nearestTrashName = trashName;
              }
            }
          }
        }
      }
      // --- ループ処理終了 ---

      // 次回予定テキスト作成
      String nextText = '';
      if (nearestNotificationTime != null) {
        final dateStr = "${nearestNotificationTime.month}/${nearestNotificationTime.day}";
        final timeStr = "${nearestNotificationTime.hour}:${nearestNotificationTime.minute.toString().padLeft(2, '0')}";
        
        String dayLabel = dateStr;
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final today = DateTime(now.year, now.month, now.day);
        
        final checkDate = DateTime(nearestNotificationTime.year, nearestNotificationTime.month, nearestNotificationTime.day);

        if (checkDate.isAtSameMomentAs(tomorrow)) {
          dayLabel = widget.lang == UiLang.ja ? "明日" : "Tomorrow";
        } else if (checkDate.isAtSameMomentAs(today)) {
          dayLabel = widget.lang == UiLang.ja ? "今日" : "Today";
        }

        nextText = widget.lang == UiLang.ja 
            ? "次回: $nearestTrashName ($dayLabel $timeStr)"
            : "Next: $nearestTrashName ($dayLabel $timeStr)";
      } else {
        nextText = widget.lang == UiLang.ja ? "予定されている通知はありません" : "No upcoming notifications";
      }

      // ★★★ 修正ポイント ★★★
      
      // 1. 変数を更新（まだ画面更新はしない）
      _isNotificationOn = true; // ★ここで初めてONにする
      _nextScheduleText = nextText;

      // 2. 画面の状態に関わらず、確実に保存する
      await _saveSettings();

      // 3. もし画面が開いていたら、UI上のスイッチもパチンとONに変える
      if (mounted) {
        setState(() {
          // ここは再描画のためだけ
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lang == UiLang.ja 
              ? '設定完了: $_targetArea ($scheduledCount件予約)' 
              : 'Setup Complete: $_targetArea ($scheduledCount scheduled)'),
          ),
        );
      }

    } catch (e) {
      debugPrint('Schedule Error: $e');
      // エラー時はONにしない（_isNotificationOnはfalseのまま）
    }
  }

  String _getTrashNameFromId(int id) {
    switch (id) {
      case 1: return widget.lang == UiLang.ja ? '燃やせるごみ・スプレー缶類' : 'Burnable・Spray Cans';
      case 2: return widget.lang == UiLang.ja ? '燃やせないごみ' : 'Non-burnable'; // 短縮
      case 8: return widget.lang == UiLang.ja ? 'びん・缶・ペット' : 'Bottles/Cans'; // 短縮
      case 9: return widget.lang == UiLang.ja ? 'プラスチック' : 'Plastic';
      case 10: return widget.lang == UiLang.ja ? '雑がみ' : 'Paper';
      case 11: return widget.lang == UiLang.ja ? '枝・葉' : 'Leaves';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
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
                  title: Text(widget.lang == UiLang.ja ? 'ホーム(カレンダー)' : 'Home'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/'),
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: Text(widget.lang == UiLang.ja ? 'ゴミ分別辞書' : 'Dictionary'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/dictionary'),
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(widget.lang == UiLang.ja ? 'ゴミ箱マップ' : 'Map'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/map'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(widget.lang == UiLang.ja ? 'AIカメラ判定' : 'AI Camera'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/camera'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- 通知設定エリア ---
          Container(
            color: _isNotificationOn ? const Color(0xFFF0F7F0) : null, // ONのとき少し色を変える
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    _isNotificationOn ? Icons.notifications_active : Icons.notifications_off,
                    color: _isNotificationOn ? Colors.orange : Colors.grey,
                  ),
                  title: Text(
                    widget.lang == UiLang.ja ? '通知設定' : 'Notifications',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // 【UX改善】サブタイトルに次回の予定を表示
                  subtitle: _isNotificationOn
                      ? Text(_nextScheduleText, style: const TextStyle(color: Colors.blueGrey, fontSize: 12))
                      : Text(widget.lang == UiLang.ja ? '設定して通知をONにする' : 'Tap to setup'),
                  value: _isNotificationOn,
                  onChanged: _handleSwitchChange,
                ),
                
                // 【UX改善】ONの時だけ表示される「設定変更」ボタン
                if (_isNotificationOn)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.settings, size: 20, color: Colors.grey),
                    title: Text(
                      widget.lang == UiLang.ja ? '地域や時間を変更' : 'Edit Settings',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () {
                      // 編集モードとしてダイアログを開く
                      _showAreaSelectionDialog();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}