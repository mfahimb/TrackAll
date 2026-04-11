import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:trackall_app/pages/qc_entry_page.dart';
import 'package:trackall_app/services/notification/poc_notification/poc_notification_service.dart';
import 'package:trackall_app/services/notification/poc_notification/poc_notification_overlay.dart';
import 'package:trackall_app/services/notification_service.dart';

import 'pages/login_page.dart' as login;
import 'pages/company_select_page.dart';
import 'pages/home_page.dart' as home;
import 'pages/npt_entry_page.dart' as npt;
import 'pages/ctl_npt_entry_page.dart' as ctl_npt;
import 'pages/widgets/splash_screen.dart';
import 'pages/admin_panel.dart';
import 'pages/sos_page.dart';
import 'pages/production_entry_page.dart';
import 'pages/Plan no wise production entry page.dart';
import 'pages/user_log.dart';
import 'pages/packing_production_entry_page.dart';
import 'pages/plan_wise_packing_entry_page.dart';
import 'pages/incentive/line_wise_staff_scan_page.dart';

// ─────────────────────────────────────────────────────────────────────
// BACKGROUND FCM HANDLER
// Must be a top-level function (not inside any class).
// Called when a push notification arrives and the app is fully closed
// or in the background. The system notification is automatically shown
// by FCM using the "notification" payload the backend sends.
// ─────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only runs on Android/iOS — safe to call initializeApp() here
  await Firebase.initializeApp();
  debugPrint("📨 FCM background message received: ${message.data}");
}

// ─────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Only initialize Firebase on Android / iOS.
  // Web requires FirebaseOptions passed in code — we don't support web.
  // This guard also prevents the crash when running in Flutter DevTools
  // or any browser-based debug environment.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint("✅ Firebase initialized");
  }

  // ✅ Initialize local notification service (scheduled reminders +
  //    in-app banner support for POC approvals)
  try {
    await NotificationService().init();
    debugPrint("✅ NotificationService ready");
  } catch (e) {
    debugPrint("⚠️ Notification init failed (non-fatal): $e");
  }

  runApp(const TrackAllApp());
}

// ─────────────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────────────
class TrackAllApp extends StatelessWidget {
  const TrackAllApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackAll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
      routes: {
        '/login':            (context) => const login.LoginPage(),
        '/company_select':   (context) => const CompanySelectPage(),
        '/home':             (context) => const home.HomePage(),
        '/npt_entry':        (context) => const npt.NptEntryPage(),
        '/ctl_npt_entry':    (context) => const ctl_npt.CtlNptEntryPage(),
        '/admin':            (context) => const AdminPanelPage(),
        '/sos':              (context) => const SOSPage(),
        '/qc_entry':         (context) => const QCEntryPage(),
        '/production_entry': (context) => const ProductionEntryPage(),
        '/line-staff-scan':  (context) => LineWiseStaffScanPage(),
      },
      // ✅ PocNotificationOverlay wraps the entire app so in-app banners
      //    can appear on top of any screen, and pocOverlayKey is wired up.
      builder: (context, child) => _UpdateWrapper(
        child: PocNotificationOverlay(
          key:   pocOverlayKey,
          child: child!,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// IN-APP UPDATE WRAPPER
// ─────────────────────────────────────────────────────────────────────
class _UpdateWrapper extends StatefulWidget {
  final Widget child;
  const _UpdateWrapper({required this.child});

  @override
  State<_UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<_UpdateWrapper> {
  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (!mounted) return;

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint("🔄 Update available — forcing immediate update");
        await InAppUpdate.performImmediateUpdate();
      } else {
        debugPrint("✅ App is up to date");
      }
    } catch (e) {
      debugPrint("ℹ️ In-app update check skipped: $e");
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}