import 'dart:convert'; // JSONデコード用
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle用
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

enum UiLang { ja, en, zh, ko, ru, vi, id }

// --- 言語選択ウィジェット ---
class LanguageSelector extends StatelessWidget {
  final UiLang currentLang;
  final ValueChanged<UiLang> onChanged;
  final String Function(String) t;

  const LanguageSelector({
    super.key,
    required this.currentLang,
    required this.onChanged,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UiLang>(
              value: currentLang,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              isDense: true,
              onChanged: (UiLang? newValue) {
                if (newValue != null) onChanged(newValue);
              },
              items: UiLang.values.map((UiLang lang) {
                final String key = 'lang_${lang.name}';
                return DropdownMenuItem<UiLang>(
                  value: lang,
                  child: Text(
                    t(key),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                );
              }).toList(),
            ),
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
  final ValueChanged<UiLang> onLangChanged;

  const LeftMenuDrawer({
    super.key,
    required this.lang,
    required this.selectedArea,
    required this.onLangChanged,
  });

  @override
  State<LeftMenuDrawer> createState() => _LeftMenuDrawerState();
}

class _LeftMenuDrawerState extends State<LeftMenuDrawer> {
  Map<String, dynamic> _trans = {};
  late UiLang _currentLang;

  // 設定状態管理用
  bool _isNotificationOn = false;
  String _targetWard = '中央区';
  String _targetArea = '中央区1';
  
  // 次回の予定データ
  int? _nextTrashId;
  DateTime? _nextNotificationTime;

  bool _notifyDayBefore = true;
  bool _notifyDayOf = true;
  TimeOfDay _timeDayBefore = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _timeDayOf = const TimeOfDay(hour: 8, minute: 0);

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
    _currentLang = widget.lang;
    _loadTranslations();
    _loadSettings();
    final service = NotificationService();
    service.init();
  }

  @override
  void didUpdateWidget(covariant LeftMenuDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang) {
      setState(() {
        _currentLang = widget.lang;
      });
      _loadTranslations();
    }
  }

  Future<void> _saveLanguage(UiLang lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang.name);
  }

  Future<void> _loadTranslations() async {
    try {
      final langCode = _currentLang.name;
      final jsonString = await rootBundle.loadString('assets/translations/$langCode.json');
      final data = json.decode(jsonString);

      if (mounted) {
        setState(() {
          _trans = Map<String, dynamic>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading translations: $e');
    }
  }

  String t(String key) {
    return _trans[key] ?? key;
  }

  String _getWeekdayString(int weekday) {
    if (widget.lang == UiLang.ja) {
      const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      return weekdays[weekday - 1];
    } else {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[weekday - 1];
    }
  }

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
      
      _nextTrashId = prefs.getInt('noti_next_id');
      final timeStr = prefs.getString('noti_next_time');
      if (timeStr != null) {
        _nextNotificationTime = DateTime.tryParse(timeStr);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noti_is_on', _isNotificationOn);
    await prefs.setString('noti_ward', _targetWard);
    await prefs.setString('noti_area', _targetArea);
    await prefs.setBool('noti_day_before', _notifyDayBefore);
    await prefs.setBool('noti_day_of', _notifyDayOf);
    await prefs.setString('noti_time_before', '${_timeDayBefore.hour}:${_timeDayBefore.minute}');
    await prefs.setString('noti_time_of', '${_timeDayOf.hour}:${_timeDayOf.minute}');
    
    if (_nextTrashId != null) {
      await prefs.setInt('noti_next_id', _nextTrashId!);
    } else {
      await prefs.remove('noti_next_id');
    }
    
    if (_nextNotificationTime != null) {
      await prefs.setString('noti_next_time', _nextNotificationTime!.toIso8601String());
    } else {
      await prefs.remove('noti_next_time');
    }
  }

  void _handleSwitchChange(bool value) async {
    if (value) {
      bool hasPermission = await _checkPermission();
      if (!hasPermission) return;
      _showAreaSelectionDialog();
    } else {
      _turnOffNotifications();
    }
  }

  Future<bool> _checkPermission() async {
    var status = await Permission.notification.status;
    if (status.isDenied) {
      status = await Permission.notification.request();
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t('msg_disabled')),
            content: Text(t('msg_perm_request')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('btn_cancel')),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: Text(t('btn_open_settings')),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return status.isGranted;
  }

  Future<void> _turnOffNotifications() async {
    setState(() {
      _isNotificationOn = false;
      _nextTrashId = null;
      _nextNotificationTime = null;
    });
    await _saveSettings();
    await NotificationService().cancelAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('msg_off'))),
      );
    }
  }

  void _showAreaSelectionDialog() {
    String tempWard = _targetWard;
    String tempArea = _targetArea;

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
              title: Text(t('dialog_area_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('dialog_area_msg')),
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('btn_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    _targetWard = tempWard;
                    _targetArea = tempArea;
                    Navigator.pop(context);
                    _showTimeSettingDialog();
                  },
                  child: Text(t('btn_next')),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
              title: Text(t('dialog_time_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('dialog_time_msg')),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: Text(t('time_day_before')),
                    value: tempDayBefore,
                    onChanged: (val) {
                      setStateDialog(() => tempDayBefore = val ?? false);
                    },
                  ),
                  if (tempDayBefore)
                    ListTile(
                      title: Text(
                        '${t('time_label')}: ${tempTimeBefore.format(context)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => pickTime(true),
                    ),
                  const Divider(),
                  CheckboxListTile(
                    title: Text(t('time_morning_of')),
                    value: tempDayOf,
                    onChanged: (val) {
                      setStateDialog(() => tempDayOf = val ?? false);
                    },
                  ),
                  if (tempDayOf)
                    ListTile(
                      title: Text(
                        '${t('time_label')}: ${tempTimeOf.format(context)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => pickTime(false),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('btn_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!tempDayBefore && !tempDayOf) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('msg_select_one'))),
                      );
                      return;
                    }

                    setState(() {
                      _notifyDayBefore = tempDayBefore;
                      _notifyDayOf = tempDayOf;
                      _timeDayBefore = tempTimeBefore;
                      _timeDayOf = tempTimeOf;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('msg_saving')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    _performNotificationScheduling();
                  },
                  child: Text(t('btn_done')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performNotificationScheduling() async {
    await NotificationService().cancelAll();

    try {
      final rawData = await DefaultAssetBundle.of(context)
          .loadString('assets/schedules.csv');
      List<List<dynamic>> rows = const CsvToListConverter().convert(rawData);

      if (rows.isEmpty) return;
      final header = rows[0].map((e) => e.toString()).toList();
      final columnIndex = header.indexOf(_targetArea);
      if (columnIndex == -1) return;

      final now = DateTime.now();
      int scheduledCount = 0;
      DateTime? nearestNotificationTime;
      int? nearestGarbageId;

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
              trashDate.year,
              trashDate.month,
              trashDate.day - 1,
              _timeDayBefore.hour,
              _timeDayBefore.minute,
            );
            if (scheduledDateTime.isAfter(now)) {
              final weekday = _getWeekdayString(trashDate.weekday);
              // 通知メッセージは予約時点の言語で固定
              final message = widget.lang == UiLang.ja
                  ? "明日（$weekday）のゴミは$trashNameです。"
                  : "Tomorrow($weekday) is $trashName day.";

              await NotificationService().scheduleNotification(
                scheduledDateTime,
                message,
              );
              scheduledCount++;

              if (nearestNotificationTime == null ||
                  scheduledDateTime.isBefore(nearestNotificationTime)) { // ここは ! を削除すると別のエラーになる可能性があるため、ロジックとして残しますが警告が出る場合は削除してください
                  // もしここで警告が出る場合、nearestNotificationTime! の ! を削除してください
                nearestNotificationTime = scheduledDateTime;
                nearestGarbageId = garbageId;
              }
            }
          }

          // 当日通知
          if (_notifyDayOf) {
            final scheduledDateTime = DateTime(
              trashDate.year,
              trashDate.month,
              trashDate.day,
              _timeDayOf.hour,
              _timeDayOf.minute,
            );
            if (scheduledDateTime.isAfter(now)) {
              final weekday = _getWeekdayString(trashDate.weekday);
              final message = widget.lang == UiLang.ja
                  ? "今日（$weekday）のゴミは$trashNameです。"
                  : "Today($weekday) is $trashName day.";

              await NotificationService().scheduleNotification(
                scheduledDateTime,
                message,
              );
              scheduledCount++;

              // 修正箇所：警告回避のため ! を削除 (if文でnullチェック済み)
              if (nearestNotificationTime == null ||
                  scheduledDateTime.isBefore(nearestNotificationTime)) { // 警告が出る場合は ! を削除
                nearestNotificationTime = scheduledDateTime;
                nearestGarbageId = garbageId;
              }
            }
          }
        }
      }

      if (nearestNotificationTime != null) {
        _nextTrashId = nearestGarbageId;
        _nextNotificationTime = nearestNotificationTime;
      } else {
        _nextTrashId = null;
        _nextNotificationTime = null;
      }

      _isNotificationOn = true;
      await _saveSettings();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('msg_saved') + ": $_targetArea ($scheduledCount)"),
          ),
        );
      }
    } catch (e) {
      debugPrint('Schedule Error: $e');
    }
  }

  // 表示用にリアルタイムでテキストを作る
  String _buildNextScheduleString() {
    // ローカル変数にコピーしてNullチェックを確実にする
    final trashId = _nextTrashId;
    final notifTime = _nextNotificationTime;

    if (trashId == null || notifTime == null) {
      return t('no_schedule');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final checkDate = DateTime(notifTime.year, notifTime.month, notifTime.day);

    String dayLabel;
    if (checkDate.isAtSameMomentAs(tomorrow)) {
      dayLabel = t('tomorrow');
    } else if (checkDate.isAtSameMomentAs(today)) {
      dayLabel = t('today');
    } else {
      dayLabel = "${notifTime.month}/${notifTime.day}";
    }

    final timeStr = "${notifTime.hour}:${notifTime.minute.toString().padLeft(2, '0')}";
    
    // 現在の言語設定でゴミの名前を取得
    final trashName = _getTrashNameFromId(trashId);

    String fmt = t('next_schedule_fmt');
    if (fmt == 'next_schedule_fmt') fmt = "Next: {name} ({day} {time})";

    return fmt
        .replaceAll('{name}', trashName)
        .replaceAll('{day}', dayLabel)
        .replaceAll('{time}', timeStr);
  }

  String _getTrashNameFromId(int id) {
    switch (id) {
      case 1:
        return t('trash_burnable');
      case 2:
        return t('trash_non_burnable');
      case 8:
        return t('trash_recyclable');
      case 9:
        return t('trash_plastic');
      case 10:
        return t('trash_paper');
      case 11:
        return t('trash_green');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      t('menu'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    LanguageSelector(
                      currentLang: _currentLang,
                      onChanged: (newLang) {
                        _saveLanguage(newLang);
                        widget.onLangChanged(newLang);
                        setState(() {
                          _currentLang = newLang;
                        });
                        _loadTranslations();
                      },
                      t: t,
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
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(t('home')),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/',
                    arguments: widget.lang,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(t('dictionary')),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/search',
                    arguments: widget.lang,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(t('map')),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/map',
                    arguments: widget.lang,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(t('camera')),
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
          Container(
            color: _isNotificationOn ? const Color(0xFFF0F7F0) : null,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    _isNotificationOn
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: _isNotificationOn ? Colors.orange : Colors.grey,
                  ),
                  title: Text(
                    t('settings_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: _isNotificationOn
                      ? Text(
                          _buildNextScheduleString(),
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        )
                      : Text(t('settings_off_desc')),
                  value: _isNotificationOn,
                  onChanged: _handleSwitchChange,
                ),
                if (_isNotificationOn)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.settings,
                      size: 20,
                      color: Colors.grey,
                    ),
                    title: Text(
                      t('settings_edit'),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                    onTap: _showAreaSelectionDialog,
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