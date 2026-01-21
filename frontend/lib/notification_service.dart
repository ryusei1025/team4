import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 初期化
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(initializationSettings);

    // ★重要：タイムゾーン（日本時間など）を使えるように初期化
    tz.initializeTimeZones();
  }

  // ★追加機能：指定した曜日・時間に通知を予約する関数
  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1=月曜, 7=日曜
    required int hour,    // 何時 (0-23)
    required int minute,  // 何分 (0-59)
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfDayTime(weekday, hour, minute), // 次の通知日時を計算
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'garbage_notification_channel',
          'ゴミ出し通知',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // ★毎週繰り返す設定
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // 次の「〇曜日の〇時〇分」がいつかを計算する計算機
  static tz.TZDateTime _nextInstanceOfDayTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // 今日の日付で、指定された時間を作る
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // もし指定した曜日まで日を進める
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // もしその時間がもう過ぎていたら、来週にする
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  // ★追加機能：通知を全部キャンセル（オフにする時用）
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  // ★追加機能：日付を指定して通知を予約する関数
  static Future<void> scheduleDateNotification({
    required int id,
    required String title,
    required String body,
    required DateTime date, // 通知したい日付
    required int hour,    // 何時 (0-23)
    required int minute,  // 何分 (0-59)
  }) async {
    // 日本時間で日時を作成
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    // もし過去の時間なら予約しない（エラー防止）
    if (scheduledDate.isBefore(now)) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'garbage_notification_channel',
          'ゴミ出し通知',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ★デバッグ用：現在予約されている通知の数とIDをコンソールに出す
  static Future<void> checkPendingNotifications() async {
    final List<PendingNotificationRequest> pendingNotificationRequests =
        await _notificationsPlugin.pendingNotificationRequests();
    
    print('--- 予約済み通知リスト (${pendingNotificationRequests.length}件) ---');
    for (var notification in pendingNotificationRequests) {
      print('ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
    print('-------------------------------------------------------');
  }
}

