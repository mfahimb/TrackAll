import 'package:flutter/material.dart';
import 'pages/login_page.dart' as login;
import 'pages/company_select_page.dart';
import 'pages/home_page.dart' as home;
import 'pages/npt_entry_page.dart' as npt;
import 'pages/widgets/splash_screen.dart';
import './pages/admin_panel.dart';
import 'pages/sos_page.dart'; // ✅ ONLY ADDITION

void main() {
  runApp(const TrackAllApp());
}

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
        '/login': (context) => const login.LoginPage(),
        '/company_select': (context) => const CompanySelectPage(),
        '/home': (context) => const home.HomePage(),
        '/npt_entry': (context) => const npt.NptEntryPage(),
        '/admin': (context) => const AdminPanelPage(),
        '/sos': (context) => const SOSPage(), // ✅ ONLY ADDITION
        //'/menu_assign': (context) => const MenuAssignPage(),
      },
    );
  }
}
