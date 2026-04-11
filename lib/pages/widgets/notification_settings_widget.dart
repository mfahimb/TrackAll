import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyScanNotifId = 1001;
  static const int _testNotifId = 1002;

  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
      debugPrint("⚠️ Timezone fallback to UTC: $e");
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint("🔔 Notification permission: $granted");

      
    }

    debugPrint("✅ NotificationService initialized");
  }

  void _onTap(NotificationResponse response) {
    debugPrint("🔔 Notification tapped: payload=${response.payload}");
  }

  Future<void> showInstantNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_scan_channel',
      'Daily Scan Reminder',
      channelDescription: 'Reminds you to scan production lines every day',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      9999,
      "TrackAll — Instant Test",
      "✅ Channel is working! Now test scheduled.",
      const NotificationDetails(android: androidDetails),
    );

    debugPrint("✅ Instant notification shown");
  }

  Future<void> scheduleTestNotification() async {
    await _plugin.cancel(_testNotifId);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime fireTime = now.add(const Duration(minutes: 2));

    debugPrint("🕐 Now:       $now");
    debugPrint("🧪 Fire time: $fireTime");

    const androidDetails = AndroidNotificationDetails(
      'daily_scan_channel',
      'Daily Scan Reminder',
      channelDescription: 'Reminds you to scan production lines every day',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    await _plugin.zonedSchedule(
      _testNotifId,
      "TrackAll — Scheduled Test",
      "✅ Scheduled notifications work!",
      fireTime,
      const NotificationDetails(android: androidDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'test',
    );

    debugPrint("✅ Test notification scheduled for: $fireTime");
  }

  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
    String title = "TrackAll Reminder",
    String body = "Scan your lines",
  }) async {
    await _plugin.cancel(_dailyScanNotifId);

    final tz.TZDateTime scheduleTime = _nextInstanceOf(hour, minute);
    debugPrint("📅 Next daily notification: $scheduleTime");

    const androidDetails = AndroidNotificationDetails(
      'daily_scan_channel',
      'Daily Scan Reminder',
      channelDescription: 'Reminds you to scan production lines every day',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Scan Reminder',
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      _dailyScanNotifId,
      title,
      body,
      scheduleTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_scan',
    );

    debugPrint("✅ Daily notification scheduled at $hour:$minute");
  }

  Future<void> cancelDailyNotification() async {
    await _plugin.cancel(_dailyScanNotifId);
    debugPrint("🗑️ Daily notification cancelled");
  }

  

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<bool> isDailyNotificationScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => n.id == _dailyScanNotifId);
  }
}