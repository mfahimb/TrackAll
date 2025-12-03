import 'package:flutter/material.dart';

// Import pages with optional prefixes to avoid ambiguity
import 'pages/login_page.dart' as login;
import 'pages/home_page.dart' as home;
import 'pages/npt_entry_page.dart';
import 'pages/widgets/splash_screen.dart'; // Import your splash screen

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
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      // Show SplashScreen first
      home: const SplashScreen(),

      // Keep named routes for navigation after splash
      routes: {
        '/login': (context) => const login.LoginPage(),
        '/home': (context) => const home.HomePage(),
        '/npt_entry': (context) => const NPTEntryPage(),
      },
    );
  }
}
