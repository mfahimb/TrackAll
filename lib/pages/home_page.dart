import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/top_menu_bar.dart'; // Adjust path if needed

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _saveLastPage();
    _checkSession();
  }

  /// Save last visited page
  Future<void> _saveLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPage', '/home');
  }

  /// Check session validity
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final loginTime = prefs.getInt('loginTime');

    if (userId == null || loginTime == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - loginTime > 3600 * 1000) { // 1 hour session
      await prefs.clear();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          TopMenuBar(), // Top menu bar with logout
          Expanded(
            child: Center(
              child: Text(
                "Welcome to TrackAll Dashboard",
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
