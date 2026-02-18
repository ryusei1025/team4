import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:typed_data'; // バイブレーション設定用

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // 初期化処理
  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  // 権限リクエスト
  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission(); 
    }
  }

  // ★スケジュール予約メソッド（修正：IDを日時から生成して重複を防ぐ）
  Future<void> scheduleNotification(DateTime scheduledTime, String body) async {
    // タイムゾーン対応の時間に変換
    final tz.TZDateTime tzScheduledTime =
        tz.TZDateTime.from(scheduledTime, tz.local);

    // ★重要：IDを日時に基づいて生成（これで複数の予約が可能になります）
    // IDが同じだと前の予約が上書きされてしまうため
    final int notificationId = scheduledTime.millisecondsSinceEpoch ~/ 1000;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId, // ここを固定の0から変更しました
        'ゴミ出し通知', // タイトル
        body, // 本文
        tzScheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'garbage_notification_v3', 
            'ゴミ分別通知',
            channelDescription: 'ゴミ出しの時間を通知します',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("予約成功(ID:$notificationId): $tzScheduledTime $body");
    } catch (e) {
      debugPrint("予約エラー: $e");
    }
  }

  // 予約全キャンセル
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint("全ての通知予約をキャンセルしました");
  }
}