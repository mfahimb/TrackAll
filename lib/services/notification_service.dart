import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:io';

class NotificationService {
  static String? lastTappedPayload;
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Notification IDs ──────────────────────────────────────────────
  static const _prodBaseId      = 2001;
  static const _kanbanBoardId   = 3001;
  static const _kanbanSosId     = 3002;
  static const _incentiveAmId   = 4001;
  static const _incentivePmId   = 4002;
  static const _testNotifId     = 1002;
  static const _pocBaseId       = 5001;

  // ── Channel IDs ───────────────────────────────────────────────────
  static const _prodChannel      = 'prod_entry_channel';
  static const _kanbanChannel    = 'kanban_channel';
  static const _incentiveChannel = 'incentive_channel';
  static const _pocChannel       = 'poc_approval_channel';

  // ❌ REMOVED duplicate lastTappedPayload here

  // ── Initialize ────────────────────────────────────────────────────
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
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidPlugin?.requestNotificationsPermission();
      debugPrint("🔔 Notification permission: $granted");
    }

    debugPrint("✅ NotificationService initialized");
  }

  // ── Tap handler ───────────────────────────────────────────────────
  void _onTap(NotificationResponse response) {
    debugPrint("🔔 Tapped: payload=${response.payload}");
    lastTappedPayload = response.payload;
  }


  // ── PRODUCTION GROUP — 08:00, 11:00, 14:00, 17:00, 20:00 ─────────
  Future<void> scheduleProductionNotifications({
    required List<int> assignedMenuIds,
  }) async {
    for (int i = 0; i < 5; i++) {
      await _plugin.cancel(_prodBaseId + i);
    }

    final parts = <String>[];
    if (assignedMenuIds.any((id) => [11, 205].contains(id)))
      parts.add("Production");
    if (assignedMenuIds.contains(133)) parts.add("QC");
    if (assignedMenuIds.any((id) => [37, 206].contains(id)))
      parts.add("Packing");
    if (assignedMenuIds.any((id) => [40, 165].contains(id)))
      parts.add("Downtime");

    if (parts.isEmpty) {
      debugPrint("ℹ️ No production-group menu IDs — skipping.");
      return;
    }

    final body = "📋 Enter your ${parts.join(' / ')} data now.";

    const times = [
      [8, 0],
      [11, 0],
      [14, 0],
      [17, 0],
      [20, 0],
    ];

    const androidDetails = AndroidNotificationDetails(
      _prodChannel,
      'Production Reminders',
      channelDescription:
          'Reminds you to enter production / QC / packing / downtime data',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    for (int i = 0; i < times.length; i++) {
      final hour   = times[i][0];
      final minute = times[i][1];
      final id     = _prodBaseId + i;

      await _plugin.zonedSchedule(
        id,
        "TrackAll — Time to Update",
        body,
        _nextInstanceOf(hour, minute),
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'prod_entry',
      );

      debugPrint(
          "✅ Prod notif #$id at $hour:${minute.toString().padLeft(2, '0')}");
    }
  }

  Future<void> cancelProductionNotifications() async {
    for (int i = 0; i < 5; i++) await _plugin.cancel(_prodBaseId + i);
    debugPrint("🗑️ Production notifications cancelled");
  }

  // ── KANBAN BOARD — daily 12:00 ────────────────────────────────────
  Future<void> scheduleKanbanBoardNotification() async {
    await _plugin.cancel(_kanbanBoardId);

    const androidDetails = AndroidNotificationDetails(
      _kanbanChannel,
      'Kanban Reminders',
      channelDescription: 'Daily Kanban board & line status reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      _kanbanBoardId,
      "TrackAll — Kanban Board",
      "📌 Check your Kanban Board now.",
      _nextInstanceOf(12, 0),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'kanban_board',
    );

    debugPrint("✅ Kanban Board notif scheduled at 12:00");
  }

  // ── KANBAN SOS / Line Status — daily 12:00 ───────────────────────
  Future<void> scheduleKanbanSosNotification() async {
    await _plugin.cancel(_kanbanSosId);

    const androidDetails = AndroidNotificationDetails(
      _kanbanChannel,
      'Kanban Reminders',
      channelDescription: 'Daily Kanban board & line status reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      _kanbanSosId,
      "TrackAll — Kanban Line Status",
      "🔲 Check your Kanban Line status now.",
      _nextInstanceOf(12, 0),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'kanban_sos',
    );

    debugPrint("✅ Kanban SOS notif scheduled at 12:00");
  }

  Future<void> cancelKanbanNotifications() async {
    await _plugin.cancel(_kanbanBoardId);
    await _plugin.cancel(_kanbanSosId);
    debugPrint("🗑️ Kanban notifications cancelled");
  }

  // ── INCENTIVE — 08:00 and 14:00 daily ────────────────────────────
  Future<void> scheduleIncentiveNotifications() async {
    await _plugin.cancel(_incentiveAmId);
    await _plugin.cancel(_incentivePmId);

    const androidDetails = AndroidNotificationDetails(
      _incentiveChannel,
      'Incentive Reminders',
      channelDescription: 'Reminds you to scan lines for incentive',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    // 08:00
    await _plugin.zonedSchedule(
      _incentiveAmId,
      "TrackAll — Incentive",
      "🏭 Scan your lines for Incentive.",
      _nextInstanceOf(8, 0),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'incentive',
    );

    // 14:00
    await _plugin.zonedSchedule(
      _incentivePmId,
      "TrackAll — Incentive",
      "🏭 Scan your lines for Incentive.",
      _nextInstanceOf(14, 0),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'incentive',
    );

    debugPrint("✅ Incentive notifs scheduled at 08:00 and 14:00");
  }

  Future<void> cancelIncentiveNotifications() async {
    await _plugin.cancel(_incentiveAmId);
    await _plugin.cancel(_incentivePmId);
    debugPrint("🗑️ Incentive notifications cancelled");
  }

  // ── POC APPROVAL — instant system notification ────────────────────
  // Called from TopMenuBar when new pending counts are detected.
  // idOffset: 0 = IE, 1 = Coaster, 2 = FC
  Future<void> showPocApprovalNotification({
    required String stage,
    required String subtitle,
    required int count,
    required int idOffset,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _pocChannel,
      'POC Approval Alerts',
      channelDescription:
          'Notifies when POC approval items are pending your action',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      _pocBaseId + idOffset,
      "TrackAll — $stage",
      "📋 $count item${count == 1 ? '' : 's'} awaiting your approval.",
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'poc_approval_$idOffset',
    );

    debugPrint(
        "🔔 POC system notif shown: $stage ($count pending) [id=${_pocBaseId + idOffset}]");
  }

  Future<void> cancelPocApprovalNotifications() async {
    await _plugin.cancel(_pocBaseId + 0);
    await _plugin.cancel(_pocBaseId + 1);
    await _plugin.cancel(_pocBaseId + 2);
    debugPrint("🗑️ POC approval notifications cancelled");
  }

  // ── MASTER SCHEDULER ──────────────────────────────────────────────
  Future<void> scheduleAllForUser(List<int> assignedMenuIds) async {
    await scheduleProductionNotifications(assignedMenuIds: assignedMenuIds);

    if (assignedMenuIds.contains(232)) await scheduleKanbanBoardNotification();
    if (assignedMenuIds.contains(231)) await scheduleKanbanSosNotification();

    if (assignedMenuIds.any((id) => [106, 109, 262].contains(id))) {
      await scheduleIncentiveNotifications();
    }

    debugPrint("✅ scheduleAllForUser complete");
  }

  // ── Cancel all ────────────────────────────────────────────────────
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    debugPrint("🗑️ All notifications cancelled");
  }

  // ── Instant test ──────────────────────────────────────────────────
  Future<void> showInstantNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _prodChannel,
      'Production Reminders',
      channelDescription:
          'Reminds you to enter production / QC / packing / downtime data',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin.show(
      9999,
      "TrackAll — Instant Test",
      "✅ Channel working!",
      const NotificationDetails(android: androidDetails),
    );
    debugPrint("✅ Instant notification shown");
  }

  // ── Scheduled test (fires in 2 min) ──────────────────────────────
  Future<void> scheduleTestNotification() async {
    await _plugin.cancel(_testNotifId);
    final fireTime =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));

    const androidDetails = AndroidNotificationDetails(
      _prodChannel,
      'Production Reminders',
      channelDescription: 'Test',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    await _plugin.zonedSchedule(
      _testNotifId,
      "TrackAll — Scheduled Test",
      "✅ Scheduled works!",
      fireTime,
      const NotificationDetails(android: androidDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'test',
    );
    debugPrint("✅ Test notif scheduled for: $fireTime");
  }

  // ── Open Android exact-alarm permission settings ──────────────────
  Future<void> openAlarmPermissionSettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  // ── Helpers ───────────────────────────────────────────────────────
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<bool> isDailyNotificationScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => n.id == _prodBaseId);
  }
}
